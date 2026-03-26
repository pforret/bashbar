#!/usr/bin/env bash
# <xbar.title>System Vitals</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Cycle between disk, RAM, CPU, network usage and battery level</xbar.desc>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## HELPERS
#####################################################################

color_for_pct() {
  local pct="${1}"
  if [[ "${pct}" -ge 90 ]]; then echo "red"
  elif [[ "${pct}" -ge 75 ]]; then echo "orange"
  else echo "green"
  fi
}

battery_color() {
  local pct="${1}"
  if [[ "${pct}" -le 10 ]]; then echo "red"
  elif [[ "${pct}" -le 25 ]]; then echo "orange"
  else echo "green"
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
## DATA COLLECTION
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
## PLUGIN OUTPUT
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
