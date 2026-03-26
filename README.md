# SwiftPlugins

A collection of [SwiftBar](https://github.com/swiftbar/SwiftBar) plugins written in Bash.

SwiftBar lets you add custom items to the macOS menu bar using simple scripts. This repo provides a shared framework (`core.sh`) and several ready-to-use plugins.

## Plugins

| Plugin           | Refresh | Description                                        |
|------------------|---------|----------------------------------------------------|
| `template.1h.sh` | 1 hour  | Disk usage - use as starting point for new plugins |
| `memory.5m.sh`   | 5 min   | RAM usage with detailed breakdown                  |
| `vitals.5m.sh`   | 5 min   | Cycles between disk, RAM, CPU, network and battery |

## Install / Uninstall

Each plugin can install itself into your SwiftBar Plugin Folder via a symlink:

```bash
./vitals.5m.sh install     # symlink into SwiftBar Plugin Folder
./vitals.5m.sh uninstall   # remove the symlink
./vitals.5m.sh help        # show usage
```

The Plugin Folder is detected automatically from SwiftBar's preferences.

## Creating a new plugin

1. Copy the template:
   ```bash
   cp template.1h.sh myplugin.5m.sh
   chmod +x myplugin.5m.sh
   ```
2. Edit `myplugin.5m.sh`:
   - Update the filename: `{name}.{refresh}.sh` (e.g. `weather.10m.sh`)
   - Update the metadata block (`xbar.title`, `xbar.desc`, etc.)
   - Replace the `plugin_output()` function with your own logic
3. Install it:
   ```bash
   ./myplugin.5m.sh install
   ```

## Architecture

```
core.sh            # Shared framework (output helpers, install/uninstall, dispatch)
template.1h.sh     # Template plugin - copy this to start a new plugin
memory.5m.sh       # RAM usage plugin
vitals.5m.sh       # System vitals plugin
```

### core.sh

Provides the SwiftBar output API and plugin management. Each plugin sources it with:

```bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"
```

This resolves symlinks, so plugins work correctly when installed via `./plugin.sh install`.

#### Output functions

| Function | Purpose |
|----------|---------|
| `metric "icon" "header" "menu text" "color"` | Cycling menu bar item + dropdown entry (icon shared) |
| `menu_line "text"` | Dropdown-only item with separator (e.g. Refresh) |
| `detail_line "text"` | Indented sub-item in dropdown |
| `swiftbar_flush` | Print all buffered output (call once at end) |

Output is buffered so that all header lines appear before dropdown content, regardless of call order. This lets you group data collection and output per metric.

#### Management

| Function | Purpose |
|----------|---------|
| `swiftbar_run "$@"` | Dispatch: `install`, `uninstall`, `help`, or run `plugin_output()` |

### Plugin structure

A minimal plugin looks like this:

```bash
#!/usr/bin/env bash
# <xbar.title>My Plugin</xbar.title>
# <xbar.desc>Does something useful</xbar.desc>

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
source "${SCRIPT_DIR}/core.sh"

plugin_output() {
  metric "🔧" "42" "My metric: 42" "green"
  detail_line "Some detail here"
  menu_line "Refresh | refresh=true"
  swiftbar_flush
}

swiftbar_run "$@"
```

## Requirements

- macOS
- [SwiftBar](https://github.com/swiftbar/SwiftBar)
- Bash
