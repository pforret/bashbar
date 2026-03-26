#!/usr/bin/env bash
## SwiftBar plugin core library
## Source this file at the top of each plugin script:
##   SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
##   source "${SCRIPT_DIR}/core.sh"

#####################################################################
## ENV LOADING
##
## Loads .env files in order (later files override earlier ones):
##   1. ${SCRIPT_DIR}/.env              — shared secrets for all plugins
##   2. ${SCRIPT_DIR}/.${prefix}.env    — plugin-specific secrets
##   3. ${PLUGIN_DIR}/.env              — shared secrets in SwiftBar folder
##   4. ${PLUGIN_DIR}/.${prefix}.env    — plugin-specific in SwiftBar folder
##
## The prefix is the plugin name without refresh interval and extension,
## e.g. "check_api" from "check_api.1h.sh".
#####################################################################

_swiftbar_load_env() {
  local script_dir="${1}"
  local prefix
  prefix="$(basename "$0")"
  prefix="${prefix%%.*}"

  local plugin_dir
  plugin_dir="${SWIFTBAR_PLUGINS_PATH:-$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)}"

  # 1. shared .env from installation folder
  [[ -f "${script_dir}/.env" ]] && source "${script_dir}/.env"
  # 2. plugin-specific .env from installation folder
  [[ -f "${script_dir}/.${prefix}.env" ]] && source "${script_dir}/.${prefix}.env"
  # 3. shared .env from SwiftBar plugin folder
  if [[ -n "${plugin_dir}" ]] && [[ -d "${plugin_dir}" ]] && [[ "${plugin_dir}" != "${script_dir}" ]]; then
    [[ -f "${plugin_dir}/.env" ]] && source "${plugin_dir}/.env"
    # 4. plugin-specific .env from SwiftBar plugin folder
    [[ -f "${plugin_dir}/.${prefix}.env" ]] && source "${plugin_dir}/.${prefix}.env"
  fi
}

_swiftbar_load_env "${SCRIPT_DIR}"

#####################################################################
## HELPER FUNCTIONS
#####################################################################

color_for_pct() {
  local pct="${1}" warn="${2:-75}" crit="${3:-90}" default="${4:-white}"
  if [[ "${pct}" -ge "${crit}" ]]; then echo "red"
  elif [[ "${pct}" -ge "${warn}" ]]; then echo "orange"
  else echo "${default}"
  fi
}

#####################################################################
## OUTPUT FUNCTIONS — build SwiftBar-formatted lines
##
## All output is buffered so you can group data collection and output
## per metric. Call swiftbar_flush at the end to print everything.
##
## metric "💾" "28%" "Disk: 28%" "green"
##   → adds cycling header line:  💾 28% | color=green dropdown=false
##   → adds dropdown menu line:   ---\n💾 Disk: 28% | color=green
##   icon is shared between header and dropdown
##
## sf_metric "sun.max.fill" "22°C" "Weather: 22°C Sunny" "orange"
##   → like metric but uses SF Symbol via sfimage= and sfcolor=
##   → header:  22°C | sfimage=sun.max.fill sfcolor=orange dropdown=false
##   → menu:    ---\n:sun.max.fill: Weather: 22°C Sunny | sfcolor=orange
##
## detail_line "Size: 1.8Ti  Used: 501Gi"
##   → indented sub-item in the dropdown (prefixed with --)
##
## sf_detail_line "thermometer.medium" "Temperature: 22°C"
##   → indented sub-item with inline SF Symbol: --:thermometer.medium: Temperature: 22°C
##
## swiftbar_flush
##   → prints all header lines, then all dropdown lines
#####################################################################

_swiftbar_headers=""
_swiftbar_dropdown=""

metric() {
  local icon="${1}" header_text="${2}" menu_text="${3}" color="${4:-}"
  if [[ -n "${color}" ]]; then
    _swiftbar_headers+="${icon} ${header_text} | color=${color} dropdown=false"$'\n'
    _swiftbar_dropdown+="---"$'\n'"${icon} ${menu_text} | color=${color}"$'\n'
  else
    _swiftbar_headers+="${icon} ${header_text} | dropdown=false"$'\n'
    _swiftbar_dropdown+="---"$'\n'"${icon} ${menu_text}"$'\n'
  fi
}

sf_metric() {
  local sfimage="${1}" header_text="${2}" menu_text="${3}" sfcolor="${4:-}"
  if [[ -n "${sfcolor}" ]]; then
    _swiftbar_headers+="${header_text} | sfimage=${sfimage} sfcolor=${sfcolor} dropdown=false"$'\n'
    _swiftbar_dropdown+="---"$'\n'":${sfimage}: ${menu_text} | sfcolor=${sfcolor}"$'\n'
  else
    _swiftbar_headers+="${header_text} | sfimage=${sfimage} dropdown=false"$'\n'
    _swiftbar_dropdown+="---"$'\n'":${sfimage}: ${menu_text}"$'\n'
  fi
}

menu_line() {
  local text="${1}"
  _swiftbar_dropdown+="---"$'\n'"${text}"$'\n'
}

detail_line() {
  local text="${1}"
  _swiftbar_dropdown+="--${text}"$'\n'
}

sf_detail_line() {
  local sfimage="${1}" text="${2}"
  _swiftbar_dropdown+="--:${sfimage}: ${text}"$'\n'
}

swiftbar_flush() {
  printf "%s" "${_swiftbar_headers}"
  printf "%s" "${_swiftbar_dropdown}"
}

#####################################################################
## SWIFTBAR INSTALL / UNINSTALL / HELP
#####################################################################

swiftbar_plugin_dir() {
  local plugin_dir
  plugin_dir="${SWIFTBAR_PLUGINS_PATH:-$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null)}"
  if [[ -z "${plugin_dir}" ]]; then
    echo "Error: could not detect SwiftBar Plugin Folder" >&2
    echo "Is SwiftBar installed?" >&2
    exit 1
  fi
  if [[ ! -d "${plugin_dir}" ]]; then
    echo "Error: plugin folder '${plugin_dir}' does not exist" >&2
    exit 1
  fi
  echo "${plugin_dir}"
}

swiftbar_install() {
  local script_path plugin_dir dest
  script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  plugin_dir="$(swiftbar_plugin_dir)"
  dest="${plugin_dir}/$(basename "$0")"

  if [[ -L "${dest}" ]] && [[ "$(readlink "${dest}")" == "${script_path}" ]]; then
    echo "Already installed: ${dest}"
  elif [[ -e "${dest}" ]]; then
    echo "Error: '${dest}' already exists (not a symlink to this script)" >&2
    echo "Remove it first if you want to reinstall." >&2
    exit 1
  else
    ln -s "${script_path}" "${dest}"
    echo "Installed: ${dest} -> ${script_path}"
  fi
}

swiftbar_uninstall() {
  local script_path plugin_dir dest
  script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  plugin_dir="$(swiftbar_plugin_dir)"
  dest="${plugin_dir}/$(basename "$0")"

  if [[ -L "${dest}" ]] && [[ "$(readlink "${dest}")" == "${script_path}" ]]; then
    rm "${dest}"
    echo "Uninstalled: removed ${dest}"
  elif [[ -e "${dest}" ]]; then
    echo "Error: '${dest}' exists but is not a symlink to this script" >&2
    echo "Remove it manually if needed." >&2
    exit 1
  else
    echo "Not installed: ${dest} does not exist"
  fi
}

swiftbar_help() {
  local script_name
  script_name="$(basename "$0")"
  echo "Usage: ${script_name} [command]"
  echo ""
  echo "Commands:"
  echo "  (none)      Run the plugin (SwiftBar output)"
  echo "  install     Symlink this script into the SwiftBar Plugin Folder"
  echo "  uninstall   Remove the symlink from the SwiftBar Plugin Folder"
  echo "  help        Show this help message"
}

#####################################################################
## MAIN DISPATCH — call from each plugin script:
##   swiftbar_run "$@"
#####################################################################

swiftbar_run() {
  case "${1:-}" in
    install)        swiftbar_install ;;
    uninstall)      swiftbar_uninstall ;;
    help|--help|-h) swiftbar_help ;;
    *)              plugin_output
                    menu_line "Refresh | refresh=true"
                    swiftbar_flush ;;
  esac
}
