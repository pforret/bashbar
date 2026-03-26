#!/usr/bin/env bash
# <xbar.title>AI API Usage</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Show AI API spend/usage for OpenRouter, OpenAI, Anthropic, EdenAI</xbar.desc>
# <xbar.dependencies>curl</xbar.dependencies>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## CONFIGURATION via .env / .apiusage.env
##
## Only providers with a key set will be queried.
## Admin keys enable spend tracking; regular keys only validate.
#####################################################################

OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
OPENAI_ADMIN_KEY="${OPENAI_ADMIN_KEY:-}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
ANTHROPIC_ADMIN_KEY="${ANTHROPIC_ADMIN_KEY:-}"
EDENAI_API_KEY="${EDENAI_API_KEY:-}"

#####################################################################
## JSON HELPERS
#####################################################################

json_field() {
  local json="${1}" field="${2}"
  if command -v jq &>/dev/null; then
    printf '%s' "${json}" | jq -r ".${field} // empty" 2>/dev/null
  else
    local last_key="${field##*.}"
    printf '%s' "${json}" | grep -o "\"${last_key}\"[[:space:]]*:[[:space:]]*[^,}]*" \
      | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" '
  fi
}

## Sum all "amount" values from Anthropic cost_report response (amounts are cents)
json_sum_cents() {
  local json="${1}"
  if command -v jq &>/dev/null; then
    printf '%s' "${json}" | jq -r '[.data[].results[].amount | tonumber] | add // 0' 2>/dev/null
  else
    printf '%s' "${json}" \
      | grep -oE '"amount"[[:space:]]*:[[:space:]]*"[0-9.]+"' \
      | sed 's/.*"amount"[[:space:]]*:[[:space:]]*"//' \
      | tr -d '"' \
      | awk '{s+=$1}END{printf "%.2f", s}'
  fi
}

cents_to_dollars() {
  local cents="${1}"
  awk "BEGIN {printf \"%.2f\", ${cents:-0} / 100}"
}

## Sum all "total_cost" values from EdenAI cost_management response
json_sum_total_cost() {
  local json="${1}"
  if command -v jq &>/dev/null; then
    printf '%s' "${json}" \
      | jq -r '[.response[].data | to_entries[].value | to_entries[].value.total_cost] | add // 0' 2>/dev/null
  else
    printf '%s' "${json}" \
      | grep -oE '"total_cost"[[:space:]]*:[[:space:]]*[0-9.]+' \
      | grep -oE '[0-9.]+$' \
      | awk '{s+=$1}END{printf "%.2f", s}'
  fi
}

#####################################################################
## PROVIDER CHECK FUNCTIONS
##
## Each prints: STATUS|spend|limit|detail
##   STATUS = OK (has spend), VALID (key works, no spend), ERROR
#####################################################################

check_openrouter() {
  local json
  json="$(curl --silent --max-time 10 "https://openrouter.ai/api/v1/auth/key" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" 2>/dev/null)"
  if [[ -z "${json}" ]]; then
    echo "ERROR|timeout||"
    return
  fi
  local usage limit
  usage="$(json_field "${json}" "data.usage")"
  if [[ -z "${usage}" ]]; then
    echo "ERROR|invalid key||"
    return
  fi
  limit="$(json_field "${json}" "data.limit")"
  echo "OK|${usage}|${limit}|"
}

check_openai() {
  if [[ -n "${OPENAI_ADMIN_KEY}" ]]; then
    local start_time end_time json
    start_time="$(date -v-30d +%s 2>/dev/null || date -d '30 days ago' +%s 2>/dev/null)"
    end_time="$(date +%s)"
    json="$(curl --silent --max-time 10 \
      "https://api.openai.com/v1/organization/costs?start_time=${start_time}&end_time=${end_time}" \
      -H "Authorization: Bearer ${OPENAI_ADMIN_KEY}" \
      -H "Content-Type: application/json" 2>/dev/null)"
    if [[ -n "${json}" ]] && [[ "${json}" != *'"error"'* ]] && [[ "${json}" != *'"code"'* ]]; then
      local total
      if command -v jq &>/dev/null; then
        total="$(printf '%s' "${json}" | jq -r '[.data[]?.results[]?.amount.value // 0] | add // 0' 2>/dev/null)"
      else
        total="$(printf '%s' "${json}" | grep -oE '"value"[[:space:]]*:[[:space:]]*[0-9.]+' \
          | grep -oE '[0-9.]+$' | awk '{s+=$1}END{printf "%.2f", s}')"
      fi
      if [[ -n "${total}" ]] && [[ "${total}" != "0" ]] && [[ "${total}" != "0.00" ]]; then
        echo "OK|${total}||admin"
        return
      fi
      # Got response but zero cost — still show as OK
      echo "OK|0.00||admin"
      return
    fi
  fi
  # Fall back to key validation
  local key="${OPENAI_ADMIN_KEY:-${OPENAI_API_KEY}}"
  local status
  status="$(curl --silent --max-time 10 -o /dev/null -w "%{http_code}" \
    "https://api.openai.com/v1/models" \
    -H "Authorization: Bearer ${key}" 2>/dev/null)"
  if [[ "${status}" == "200" ]]; then
    echo "VALID|||"
  else
    echo "ERROR|HTTP ${status}||"
  fi
}

check_anthropic() {
  if [[ -n "${ANTHROPIC_ADMIN_KEY}" ]]; then
    local start_date end_date json total_cents total_dollars
    start_date="$(date +%Y-%m)-01T00:00:00Z"
    end_date="$(date -v+1d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -d tomorrow +%Y-%m-%dT00:00:00Z 2>/dev/null)"
    json="$(curl --silent --max-time 10 \
      "https://api.anthropic.com/v1/organizations/cost_report?starting_at=${start_date}&ending_at=${end_date}&bucket_width=1d" \
      --header "anthropic-version: 2023-06-01" \
      --header "x-api-key: ${ANTHROPIC_ADMIN_KEY}" 2>/dev/null)"
    if [[ -n "${json}" ]] && [[ "${json}" != *'"error"'* ]]; then
      total_cents="$(json_sum_cents "${json}")"
      total_dollars="$(cents_to_dollars "${total_cents}")"
      echo "OK|${total_dollars}||admin"
      return
    fi
  fi
  # Fall back: validate key
  local key="${ANTHROPIC_ADMIN_KEY:-${ANTHROPIC_API_KEY}}"
  local status
  status="$(curl --silent --max-time 10 -o /dev/null -w "%{http_code}" \
    "https://api.anthropic.com/v1/models" \
    --header "anthropic-version: 2023-06-01" \
    --header "x-api-key: ${key}" 2>/dev/null)"
  if [[ "${status}" == "200" ]]; then
    echo "VALID|||"
  else
    echo "ERROR|HTTP ${status}||"
  fi
}

check_edenai() {
  # Get credits balance
  local credits_json spend_json credits spend
  credits_json="$(curl --silent --max-time 10 "https://api.edenai.run/v2/cost_management/credits/" \
    -H "Authorization: Bearer ${EDENAI_API_KEY}" 2>/dev/null)"
  if [[ -z "${credits_json}" ]]; then
    echo "ERROR|timeout||"
    return
  fi
  credits="$(json_field "${credits_json}" "credits")"
  if [[ -z "${credits}" ]]; then
    echo "ERROR|invalid key||"
    return
  fi
  # Get spend for current month
  local begin_date end_date
  begin_date="$(date +%Y-%m)-01"
  end_date="$(date +%Y-%m-%d)"
  spend_json="$(curl --silent --max-time 10 \
    "https://api.edenai.run/v2/cost_management/?begin=${begin_date}&end=${end_date}&step=3" \
    -H "Authorization: Bearer ${EDENAI_API_KEY}" 2>/dev/null)"
  spend="$(json_sum_total_cost "${spend_json}")"
  echo "OK|${spend:-0}|${credits}|"
}

#####################################################################
## DISPLAY HELPER
#####################################################################

show_provider() {
  local name="${1}" result="${2}" dashboard_url="${3}"
  local status spend limit detail
  IFS='|' read -r status spend limit detail <<< "${result}"

  case "${status}" in
    OK)
      sf_metric "dollarsign.circle" "${name} \$${spend}" "${name}: \$${spend}" "green"
      sf_detail_line "creditcard" "Spend: \$${spend}"
      if [[ -n "${limit}" ]] && [[ "${limit}" != "null" ]] && [[ "${limit}" != "0" ]]; then
        sf_detail_line "chart.bar" "Credits: \$${limit}"
      fi
      if [[ "${detail}" == "admin" ]]; then
        sf_detail_line "key.fill" "Via admin key (this month)"
      fi
      ;;
    VALID)
      sf_metric "checkmark.circle.fill" "${name}" "${name}: active" "green"
      sf_detail_line "key.fill" "Key valid (no spend API)"
      ;;
    ERROR)
      sf_metric "exclamationmark.triangle" "${name}" "${name}: ${spend:-error}" "orange"
      ;;
  esac
  menu_line "${name} Dashboard | href=${dashboard_url}"
}

#####################################################################
## PLUGIN OUTPUT
#####################################################################

plugin_output() {
  local has_any=false

  if [[ -n "${OPENROUTER_API_KEY}" ]]; then
    has_any=true
    show_provider "OpenRouter" "$(check_openrouter)" "https://openrouter.ai/activity"
  fi

  if [[ -n "${OPENAI_ADMIN_KEY}${OPENAI_API_KEY}" ]]; then
    has_any=true
    show_provider "OpenAI" "$(check_openai)" "https://platform.openai.com/usage"
  fi

  if [[ -n "${ANTHROPIC_ADMIN_KEY}${ANTHROPIC_API_KEY}" ]]; then
    has_any=true
    show_provider "Anthropic" "$(check_anthropic)" "https://console.anthropic.com/settings/usage"
  fi

  if [[ -n "${EDENAI_API_KEY}" ]]; then
    has_any=true
    show_provider "EdenAI" "$(check_edenai)" "https://app.edenai.run/admin/cost-management"
  fi

  if [[ "${has_any}" == false ]]; then
    sf_metric "key.fill" "No keys" "No API keys configured"
    detail_line "Add keys to .env or .apiusage.env"
  fi
}

swiftbar_run "$@"
