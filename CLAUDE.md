# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

bashbar is a collection of [SwiftBar](https://github.com/swiftbar/SwiftBar) plugins written in Bash for macOS menu bar. Plugins are executable `.sh` scripts that output SwiftBar-formatted text.

## Architecture

- **`core.sh`** — Shared framework sourced by all plugins. Provides:
  - Buffered output system (`metric`, `menu_line`, `detail_line`, `swiftbar_flush`) that separates header lines (cycling menu bar items) from dropdown content
  - `color_for_pct` helper for threshold-based coloring (warn=75/orange, crit=90/red)
  - `.env` file loading chain (4 locations, later overrides earlier)
  - Install/uninstall management via symlinks into SwiftBar Plugin Folder
  - `swiftbar_run "$@"` dispatcher handling `install`, `uninstall`, `help`, or running `plugin_output()`

- **Plugin scripts** (`*.{refresh}.sh`) — Each plugin sources `core.sh`, defines a `plugin_output()` function, and calls `swiftbar_run "$@"`. The filename encodes refresh interval (e.g., `5m` = every 5 minutes, `1h` = every hour).

- **`docs/`** — MkDocs Material site (`mkdocs.yml`). `docs/SwiftBar/plugins.md` contains the full SwiftBar Plugin API reference.

## Key Conventions

- Plugins resolve symlinks to find `core.sh`: `SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"`
- All output goes through the buffered functions — never raw `echo` for SwiftBar output
- Metadata block uses xbar-compatible format: `# <xbar.title>...</xbar.title>`
- Plugin prefix (name without interval/extension, e.g., `vitals` from `vitals.5m.sh`) is used for `.env` file lookup
- Version tracked in `VERSION.md` (currently 0.1.2)

## Creating a New Plugin

```bash
cp template.1h.sh myplugin.5m.sh
chmod +x myplugin.5m.sh
# Edit plugin_output() function, update metadata block
./myplugin.5m.sh install   # symlink into SwiftBar Plugin Folder
```

## Testing

No test framework. Test plugins manually by running them directly:

```bash
./vitals.5m.sh          # run plugin output
./vitals.5m.sh install  # install to SwiftBar
./vitals.5m.sh help     # show usage
```

Plugins use macOS-specific commands (`vm_stat`, `sysctl`, `pmset`, `top`, `netstat`, `defaults`), so they only work on macOS.
