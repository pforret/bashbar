#!/usr/bin/env bash
# <xbar.title>Disk Usage</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Show disk usage percentage for home directory</xbar.desc>

## TEMPLATE: create a new plugin by copying this file:
##   cp template.1h.sh myplugin.5m.sh
## Then update:
##   1. the filename — {name}.{refresh}.sh (e.g. weather.10m.sh)
##      refresh: 1s/10s/1m/5m/10m/1h/1d (or omit for manual only)
##   2. the metadata block above (title, version, desc)
##   3. the plugin_output() function with your own logic
## The source line below loads shared helpers from core.sh.
## See core.sh for available functions: color_for_pct, get_disk, get_memory, etc.

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## PLUGIN LOGIC — replace the body of this function
##
## Output functions from core.sh (see docs/SwiftBar/plugins.md for full reference):
##   metric "icon" "header" "menu text" "color"
##     — icon + header in menu bar, icon + menu text in dropdown (same icon for both)
##   menu_line "text"        — dropdown-only item (e.g. Refresh)
##   detail_line "text"      — indented sub-item in dropdown
##   swiftbar_flush          — call once at the end to print everything
#####################################################################

plugin_output() {
  local pct
  pct=$(get_disk)

  metric "💾" "${pct}%" "Disk usage: ${pct}%" "$(color_for_pct "${pct}")"
  detail_line "$(df -h "$HOME" | awk 'NR==2 {printf "Size: %s  Used: %s  Free: %s", $2, $3, $4}')"
  menu_line "Refresh | refresh=true"
  swiftbar_flush
}

swiftbar_run "$@"
