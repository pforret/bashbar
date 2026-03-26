#!/usr/bin/env bash
# <xbar.title>System Vitals</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Cycle between disk, RAM, CPU, network usage and battery level</xbar.desc>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## PLUGIN LOGIC
#####################################################################

plugin_output() {

  ## Disk
  local disk_pct
  disk_pct=$(get_disk)
  metric "💾" "${disk_pct}%" "Disk: ${disk_pct}%" "$(color_for_pct "${disk_pct}")"
  detail_line "$(df -h "$HOME" | awk 'NR==2 {printf "Size: %s  Used: %s  Free: %s", $2, $3, $4}')"

  ## Memory
  local mem_pct page_size active wired inactive free_p
  mem_pct=$(get_memory)
  page_size=$(vm_stat | awk '/page size of/{print $8}')
  active=$(vm_stat | awk '/Pages active/{gsub(/\./,"",$3); print $3}')
  wired=$(vm_stat | awk '/Pages wired/{gsub(/\./,"",$4); print $4}')
  inactive=$(vm_stat | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')
  free_p=$(vm_stat | awk '/Pages free/{gsub(/\./,"",$3); print $3}')
  metric "🐏" "${mem_pct}%" "Memory: ${mem_pct}%" "$(color_for_pct "${mem_pct}")"
  detail_line "$(printf "Active: %d MB  Wired: %d MB" "$((active * page_size / 1024 / 1024))" "$((wired * page_size / 1024 / 1024))")"
  detail_line "$(printf "Inactive: %d MB  Free: %d MB" "$((inactive * page_size / 1024 / 1024))" "$((free_p * page_size / 1024 / 1024))")"

  ## Network (samples for 2s, so run before CPU which also takes ~1s)
  local net_in_bps net_out_bps net_in_fmt net_out_fmt
  read -r net_in_bps net_out_bps <<< "$(get_network)"
  net_in_fmt=$(format_bytes_per_sec "${net_in_bps}")
  net_out_fmt=$(format_bytes_per_sec "${net_out_bps}")
  metric "🌐" "↓${net_in_fmt} ↑${net_out_fmt}" "Network: ↓${net_in_fmt}  ↑${net_out_fmt}"
  detail_line "Interface: en0"
  detail_line "Download: ${net_in_fmt}"
  detail_line "Upload:   ${net_out_fmt}"

  ## CPU
  local cpu_pct
  cpu_pct=$(get_cpu)
  metric "🖥" "${cpu_pct}%" "CPU: ${cpu_pct}%" "$(color_for_pct "${cpu_pct}")"
  detail_line "$(top -l 1 -n 0 | awk '/CPU usage/{printf "User: %s  Sys: %s  Idle: %s", $3, $5, $7}')"

  ## Battery (only shown if present)
  local bat_pct
  bat_pct=$(get_battery)
  if [[ -n "${bat_pct}" ]] && [[ "${bat_pct}" -gt 0 ]]; then
    local bat_state
    bat_state=$(pmset -g batt | awk '/-InternalBattery/{gsub(/;/,""); print $4}')
    metric "🔋" "${bat_pct}%" "Battery: ${bat_pct}% (${bat_state})" "$(battery_color "${bat_pct}")"
  fi

  ## Footer
  menu_line "Refresh | refresh=true"

  swiftbar_flush
}

swiftbar_run "$@"
