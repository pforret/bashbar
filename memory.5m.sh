#!/usr/bin/env bash
# <xbar.title>RAM Usage</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Show RAM memory usage percentage</xbar.desc>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## PLUGIN LOGIC
#####################################################################

plugin_output() {
  local page_size total_bytes total_mb
  page_size=$(vm_stat | awk '/page size of/{print $8}')
  total_bytes=$(sysctl -n hw.memsize)
  total_mb=$((total_bytes / 1024 / 1024))

  local free active inactive speculative wired
  free=$(vm_stat | awk '/Pages free/{gsub(/\./,"",$3); print $3}')
  active=$(vm_stat | awk '/Pages active/{gsub(/\./,"",$3); print $3}')
  inactive=$(vm_stat | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')
  speculative=$(vm_stat | awk '/Pages speculative/{gsub(/\./,"",$3); print $3}')
  wired=$(vm_stat | awk '/Pages wired/{gsub(/\./,"",$4); print $4}')

  local used_pages used_mb free_mb pct
  used_pages=$((active + wired))
  used_mb=$((used_pages * page_size / 1024 / 1024))
  free_mb=$((total_mb - used_mb))
  pct=$((used_mb * 100 / total_mb))

  metric "🐏" "${pct}%" "RAM usage: ${pct}%" "$(color_for_pct "${pct}")"
  detail_line "$(printf "Total:  %5d MB" "${total_mb}")"
  detail_line "$(printf "Used:   %5d MB (active + wired)" "${used_mb}")"
  detail_line "$(printf "Free:   %5d MB" "${free_mb}")"
  menu_line "Breakdown"
  detail_line "$(printf "Active:      %5d MB" "$((active * page_size / 1024 / 1024))")"
  detail_line "$(printf "Wired:       %5d MB" "$((wired * page_size / 1024 / 1024))")"
  detail_line "$(printf "Inactive:    %5d MB" "$((inactive * page_size / 1024 / 1024))")"
  detail_line "$(printf "Free:        %5d MB" "$((free * page_size / 1024 / 1024))")"
  detail_line "$(printf "Speculative: %5d MB" "$((speculative * page_size / 1024 / 1024))")"
}

swiftbar_run "$@"
