#!/usr/bin/env bash
## SwiftBar plugin core library
## Source this file at the top of each plugin script:
##   SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
##   source "${SCRIPT_DIR}/core.sh"

#####################################################################
## HELPER FUNCTIONS — reusable across plugins
#####################################################################

color_for_pct() {
  local pct="${1}"
  if [[ "${pct}" -ge 90 ]]; then
    echo "red"
  elif [[ "${pct}" -ge 75 ]]; then
    echo "orange"
  else
    echo "green"
  fi
}

battery_color() {
  local pct="${1}"
  if [[ "${pct}" -le 10 ]]; then
    echo "red"
  elif [[ "${pct}" -le 25 ]]; then
    echo "orange"
  else
    echo "green"
  fi
}

format_bytes_per_sec() {
  local bps="${1}"
  if [[ "${bps}" -ge 1073741824 ]]; then
    awk "BEGIN {printf \"%.1f GB/s\", ${bps}/1073741824}"
  elif [[ "${bps}" -ge 1048576 ]]; then
    awk "BEGIN {printf \"%.1f MB/s\", ${bps}/1048576}"
  elif [[ "${bps}" -ge 1024 ]]; then
    awk "BEGIN {printf \"%.1f KB/s\", ${bps}/1024}"
  else
    echo "${bps} B/s"
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
## detail_line "Size: 1.8Ti  Used: 501Gi"
##   → indented sub-item in the dropdown (prefixed with --)
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

menu_line() {
  local text="${1}"
  _swiftbar_dropdown+="---"$'\n'"${text}"$'\n'
}

detail_line() {
  local text="${1}"
  _swiftbar_dropdown+="--${text}"$'\n'
}

swiftbar_flush() {
  printf "%s" "${_swiftbar_headers}"
  printf "%s" "${_swiftbar_dropdown}"
}


#####################################################################
## DATA COLLECTION FUNCTIONS
#####################################################################

get_disk() {
  df "$HOME" | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

get_memory() {
  local page_size total_bytes active wired used_mb total_mb
  page_size=$(vm_stat | awk '/page size of/{print $8}')
  total_bytes=$(sysctl -n hw.memsize)
  total_mb=$((total_bytes / 1024 / 1024))
  active=$(vm_stat | awk '/Pages active/{gsub(/\./,"",$3); print $3}')
  wired=$(vm_stat | awk '/Pages wired/{gsub(/\./,"",$4); print $4}')
  used_mb=$(( (active + wired) * page_size / 1024 / 1024 ))
  echo "$((used_mb * 100 / total_mb))"
}

get_cpu() {
  local idle
  idle=$(top -l 1 -n 0 | awk '/CPU usage/{gsub(/%/,"",$7); print $7}')
  awk "BEGIN {printf \"%.0f\", 100 - ${idle}}"
}

get_battery() {
  pmset -g batt | awk '/-InternalBattery/{gsub(/;/,""); print $3+0}'
}

get_network() {
  local iface="en0"
  local in1 out1 in2 out2
  read -r in1 out1 <<< "$(netstat -ib | awk -v iface="${iface}" '$1==iface && $3~/<Link#/{print $7, $10; exit}')"
  sleep 2
  read -r in2 out2 <<< "$(netstat -ib | awk -v iface="${iface}" '$1==iface && $3~/<Link#/{print $7, $10; exit}')"
  echo "$(( (in2 - in1) / 2 )) $(( (out2 - out1) / 2 ))"
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
    *)              plugin_output ;;
  esac
}
