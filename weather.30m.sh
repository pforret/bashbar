#!/usr/bin/env bash
# <xbar.title>Weather</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Show current weather using wttr.in with SF Symbols</xbar.desc>
# <xbar.dependencies>curl</xbar.dependencies>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

#####################################################################
## CONFIGURATION via .env
##
## Set WEATHER_CITY in .env or .weather.env:
##   WEATHER_CITY="Brussels"
##   WEATHER_UNIT="m"   # m=metric, u=USCS/imperial, M=metric+mph
#####################################################################

WEATHER_CITY="${WEATHER_CITY:-Brussels}"
WEATHER_UNIT="${WEATHER_UNIT:-m}"

#####################################################################
## MAP WEATHER CONDITION TO SF SYMBOL
#####################################################################

weather_sfimage() {
  local condition="${1,,}" # lowercase
  case "${condition}" in
    *thunder*)        echo "cloud.bolt.rain.fill" ;;
    *heavy*rain*)     echo "cloud.heavyrain.fill" ;;
    *rain*|*drizzle*|*shower*) echo "cloud.rain.fill" ;;
    *sleet*|*ice*)    echo "cloud.sleet.fill" ;;
    *blizzard*|*heavy*snow*) echo "cloud.snow.fill" ;;
    *snow*|*flurries*) echo "cloud.snow.fill" ;;
    *fog*|*mist*|*haze*) echo "cloud.fog.fill" ;;
    *overcast*)       echo "smoke.fill" ;;
    *cloudy*|*cloud*) echo "cloud.sun.fill" ;;
    *sunny*|*clear*)  echo "sun.max.fill" ;;
    *)                echo "cloud.fill" ;;
  esac
}

weather_sfcolor() {
  local condition="${1,,}"
  case "${condition}" in
    *thunder*)          echo "purple" ;;
    *rain*|*drizzle*|*shower*) echo "steelblue" ;;
    *snow*|*sleet*|*blizzard*) echo "lightblue" ;;
    *sunny*|*clear*)    echo "orange" ;;
    *)                  echo "gray" ;;
  esac
}

#####################################################################
## FETCH WEATHER DATA
#####################################################################

fetch_weather() {
  # wttr.in custom format: %C=condition, %t=temp, %h=humidity, %w=wind, %l=location, %p=precip, %P=pressure
  curl --silent --max-time 10 "wttr.in/${WEATHER_CITY}?format=%C|%l:+%c+%t|%h|%w|%l|%p|%P&${WEATHER_UNIT}" 2>/dev/null
  # Example output:
  # Small hail/snow pallets shower, snow shower|brussels: ❄️   +6°C|56%|↘21km/h|brussels|0.0mm|1020hPa
  # Partly cloudy|paris: ⛅  +9°C|43%|↓21km/h|paris|0.0mm|1020hPa
  # Sunny|+17°C|29%|↙9km/h|madrid|0.0mm|1016hPa
  # Overcast|+10°C|37%|↘12km/h|london|0.0mm|1022hPa
  # Partly cloudy|+6°C|75%|←16km/h|vancouver|0.0mm|1033hPa
  # Clear|newyork: ☀️   +27°C|74%|←6km/h|newyork|0.0mm|1011hPa
}

#####################################################################
## PLUGIN OUTPUT
#####################################################################

plugin_output() {
  local raw
  raw="$(fetch_weather)"

  if [[ -z "${raw}" ]] || [[ "${raw}" == *"Unknown"* ]] || [[ "${raw}" == *"Sorry"* ]]; then
    sf_metric "exclamationmark.icloud" "N/A" "Weather unavailable for ${WEATHER_CITY}"
    return
  fi

  # Parse pipe-separated values
  local condition temp humidity wind location precip pressure
  IFS='|' read -r condition temp humidity wind location precip pressure <<< "${raw}"

  # Clean up: temp often has leading space and + sign
  temp="${temp## }"
  condition="${condition## }"
  location="${location## }"

  local sfimage sfcolor
  sfimage="$(weather_sfimage "${condition}")"
  sfcolor="$(weather_sfcolor "${condition}")"

  # Header: SF Symbol + temperature cycling in menu bar
  # Dropdown: location + all weather details
  sf_metric "${sfimage}" "${temp}" "${location}" "${sfcolor}"
  sf_detail_line "thermometer.medium" "${temp}  ${condition}"
  sf_detail_line "humidity.fill" "Humidity: ${humidity}"
  sf_detail_line "wind" "Wind: ${wind}"
  sf_detail_line "drop.fill" "Precip: ${precip}"
  sf_detail_line "barometer" "Pressure: ${pressure}"
  menu_line "Open wttr.in | href=https://wttr.in/${WEATHER_CITY}"
  menu_line "Open forecast | href=https://wttr.in/${WEATHER_CITY}?format=v2"
}

swiftbar_run "$@"
