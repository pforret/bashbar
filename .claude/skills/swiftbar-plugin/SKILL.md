---
name: swiftbar-plugin
description: Create new SwiftBar menu bar plugins for macOS using core.sh framework. Use when user asks to create, scaffold, or add a new plugin, menu bar item, or SwiftBar script. Covers plugin naming, core.sh output functions, SF Symbols, .env configuration, and the full SwiftBar plugin API.
---

# Create SwiftBar Plugin

## Workflow

1. Ask the user what the plugin should display and where data comes from
2. Choose a filename: `{name}.{refresh}.sh` (e.g., `weather.30m.sh`, `cpu.5m.sh`)
3. Read `core.sh` to verify current API (functions may have been added/changed)
4. Read `template.1h.sh` as the base scaffold
5. Create the plugin file using the structure below
6. `chmod +x` the new file
7. Test by running `./{name}.{refresh}.sh` directly
8. Optionally install with `./{name}.{refresh}.sh install`

## Refresh Intervals

`1s`, `10s`, `1m`, `5m`, `10m`, `30m`, `1h`, `3h`, `1d`

## Plugin Structure

```bash
#!/usr/bin/env bash
# <xbar.title>Plugin Title</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Peter Forret</xbar.author>
# <xbar.author.github>pforret</xbar.author.github>
# <xbar.desc>Short description</xbar.desc>
# <xbar.dependencies>comma,separated</xbar.dependencies>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

## .env config with defaults
MY_VAR="${MY_VAR:-default_value}"

## helper functions here

plugin_output() {
  ## collect data, then output using core.sh functions
}

swiftbar_run "$@"
```

## core.sh Output Functions

Use ONLY these functions for output. Never write raw `echo` or directly to `_swiftbar_headers`/`_swiftbar_dropdown`.

### Emoji-based (icon is an emoji string)

```bash
metric "icon" "header_text" "menu_text" "color"
# header: icon header_text | color=... dropdown=false
# menu:   ---\nicon menu_text | color=...
# color is optional, use CSS color names or hex

detail_line "text"
# indented sub-item: --text
```

### SF Symbol-based (icon is an SF Symbol name)

```bash
sf_metric "sfimage" "header_text" "menu_text" "sfcolor"
# header: header_text | sfimage=... sfcolor=... dropdown=false
# menu:   ---\n:sfimage: menu_text | sfcolor=...
# sfcolor is optional

sf_detail_line "sfimage" "text"
# indented sub-item with SF Symbol: --:sfimage: text
```

### Shared

```bash
menu_line "text"
# dropdown separator + text: ---\ntext
# supports SwiftBar params: menu_line "Open URL | href=https://..."

color_for_pct "value" "warn_threshold" "crit_threshold" "default_color"
# returns: "red" if >= crit (default 90), "orange" if >= warn (default 75), else default
```

`swiftbar_flush` and the Refresh button are handled automatically by `swiftbar_run`.

## .env Configuration

core.sh auto-loads `.env` files by plugin prefix (filename without interval/extension).
For a plugin `weather.30m.sh`, the prefix is `weather` and these files are checked:

1. `${SCRIPT_DIR}/.env` - shared across all plugins
2. `${SCRIPT_DIR}/.weather.env` - plugin-specific
3. `${PLUGIN_DIR}/.env` - shared in SwiftBar folder
4. `${PLUGIN_DIR}/.weather.env` - plugin-specific in SwiftBar folder

Always provide defaults: `MY_VAR="${MY_VAR:-default}"`

## SF Symbols Reference

Inline in dropdown text: `:symbol.name:` (e.g., `:thermometer.medium:`)
As menu bar icon: `sfimage=symbol.name` parameter (used by `sf_metric`)

Common symbols for plugins:
- System: `cpu`, `memorychip`, `internaldrive`, `network`, `wifi`, `battery.100`
- Weather: `sun.max.fill`, `cloud.fill`, `cloud.sun.fill`, `cloud.rain.fill`, `cloud.snow.fill`, `cloud.bolt.rain.fill`, `cloud.fog.fill`, `thermometer.medium`, `humidity.fill`, `wind`, `barometer`
- Status: `checkmark.circle.fill`, `exclamationmark.triangle.fill`, `xmark.circle.fill`
- Misc: `clock`, `calendar`, `bell.fill`, `envelope.fill`, `dollarsign.circle`, `arrow.down.circle`, `arrow.up.circle`, `gear`

Color with `sfcolor=`: CSS names (`red`, `orange`, `steelblue`, `green`) or hex (`#FF5733`).

## SwiftBar Line Parameters

Any output line can have `| param=value param2=value2` appended:

| Parameter   | Example                | Purpose                   |
|-------------|------------------------|---------------------------|
| `color`     | `color=red`            | Text color (CSS/hex)      |
| `sfimage`   | `sfimage=sun.max.fill` | SF Symbol as line icon    |
| `sfcolor`   | `sfcolor=orange`       | SF Symbol color           |
| `href`      | `href=https://...`     | Open URL on click         |
| `bash`      | `bash=/path/to/script` | Run script on click       |
| `terminal`  | `terminal=false`       | Run bash silently         |
| `refresh`   | `refresh=true`         | Re-run plugin on click    |
| `font`      | `font=Menlo`           | Custom font               |
| `size`      | `size=12`              | Font size                 |
| `dropdown`  | `dropdown=false`       | Header-only (no dropdown) |
| `alternate` | `alternate=true`       | Show on Option-click      |

## Rules

- All output through core.sh functions, never raw `echo` for SwiftBar output
- macOS-only commands are fine (`sysctl`, `defaults`, `pmset`, `vm_stat`, etc.)
- Quote all variables: `"${var}"`
- Use `curl --silent --max-time 10` for network calls with error handling
- Prefer `sf_metric`/`sf_detail_line` for new plugins (SF Symbols look native on macOS)
- Keep `plugin_output()` focused: helpers for data collection, output function for display
