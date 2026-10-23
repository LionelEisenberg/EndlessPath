# Logging

Last updated: 2026-10-22

## Overview

The game has two separate logging channels, and neither feeds the other:

| Channel | Where | Audience | Output |
|---------|-------|----------|--------|
| `Log` | `scripts/utils/log.gd` (`class_name Log extends Logger`, static API) | Developers | Console (`print_rich`, coloured by level) and the file `user://logs-YYYY-MM-DD.log`. It also captures engine errors, warnings and `print()` output into that file |
| `LogManager` | `singletons/log_manager/log_manager.gd` (autoload) | Players | The `message_logged` signal, which the in-game `LogWindow` renders as BBCode |

`Log` lines never appear in the `LogWindow`, and `LogManager` messages are never written to the log file.

## When to Use Which

| Situation | Call |
|-----------|------|
| Diagnostics, state transitions, unexpected data, failures | `Log.info()` / `Log.warn()` / `Log.error()` / `Log.critical()` |
| Something the player should read (rewards, combat events, rejections) | `LogManager.log_message("[color=…]…[/color]")` |
| Both | Call both. For example, `AdventureView.start_adventure()` calls `Log.info` and `LogManager.log_message` |
| Never in game code | Bare `print()`. Only the headless CLI tools in `scripts/tools/` (`extends SceneTree`) still use it |

Usage in `singletons/`, `scenes/` and `scripts/`: 254 `Log.*` calls (115 `info`, 30 `warn`, 74 `error`, 35 `critical`, 0 `debug`) and 29 `LogManager.log_message` calls across 9 files.

## Log Utility

### Levels

| `Log.Event` | Value | Console colour | Flushes file | Appends GDScript backtrace |
|-------------|-------|----------------|--------------|----------------------------|
| `INFO` | 0 | `lime_green` | — | — |
| `DEBUG` | 1 | `purple` | — | — |
| `WARN` | 2 | `gold` | — | — |
| `ERROR` | 3 | `tomato` | Yes | Yes |
| `CRITICAL` | 4 | `crimson` | Yes | Yes |
| `FORCE_FLUSH` | 5 | never printed | Yes | — |

### API

| Function | Behaviour |
|----------|-----------|
| `Log.info(msg)`, `Log.debug(msg)`, `Log.warn(msg)`, `Log.error(msg)`, `Log.critical(msg)` | Format the message as `[HH:MM:SS] LEVEL: message`, append it to the file, and print it to the console if the level is at or above the print level. `error` and `critical` append the GDScript backtrace from `Engine.capture_script_backtraces()` |
| `Log.force_flush()` | Flush the file buffer |
| `Log.set_print_level(level)` / `Log.get_print_level()` | Set or get the minimum console level. The default is `INFO`, and `FORCE_FLUSH` is coerced to `CRITICAL` with a warning |

### File output and engine capture

- The first time the `Log` class loads, `_static_init()` opens `user://logs-<YYYY-MM-DD>.log` with `FileAccess.WRITE` and registers `OS.add_logger(Log.new())`. The folder is the same per-project user directory as the save (see [PERSISTENCE.md](PERSISTENCE.md#save-file-location)).
- Writes are buffered and guarded by a mutex. The file is flushed every 10 lines (`_MAX_BUFFER_SIZE`) and immediately on ERROR, CRITICAL or FORCE_FLUSH.
- Because `Log` is an engine `Logger`, it also records two kinds of output to the file:
  - `_log_error()` records engine and script errors and warnings, with `file:line @ function()` and a backtrace for errors.
  - `_log_message()` records `print()` / `printerr()` output. It skips lines that start with `[lang=tlh]`, which is the marker `_print_event()` wraps around Log's own console output, so those lines are not written twice.
- If the file cannot be opened (`_is_valid == false`), every `Log.*` call returns immediately, so console output is lost too.

### Console output and configuration

- `_print_event()` sends `[lang=tlh][b][color=<level colour>]<first line>[/color][/b]…[/lang]` to `print_rich` with `call_deferred`, so the line appears at idle time.
- `MainGame` exports `log_print_level: Log.Event` and calls `Log.set_print_level()` in its `_ready()`. The script default is `DEBUG`, but `main_game.tscn` sets it to `0` (`INFO`).
- Autoload `_ready()` output, and every test run, uses the class default `INFO`.
- `INFO` (0) sorts numerically below `DEBUG` (1). So a print level of `INFO` prints everything, while `DEBUG` would hide INFO lines and still show DEBUG lines.

## LogManager

| Member | Behaviour |
|--------|-----------|
| `signal message_logged(bbcode_message: String)` | Emitted by `log_message()` |
| `log_message(bbcode: String)` | Emits `message_logged`. No levels, no buffering, no history |

## LogWindow

`scenes/ui/log_window/log_window.tscn` / `log_window.gd` (`class_name LogWindow extends PanelContainer`). It is instanced in `main_game.tscn` as `MainView/LogWindow` (`%LogWindow`), with offset (736, 781), minimum size 400×217, and `z_index` 1.

```
LogWindow (PanelContainer, StyleBoxEmpty, mouse_filter IGNORE)
  VBoxContainer
    TitleBar % (PanelContainer, assets/styleboxes/ui/log_titlebar.tres)
      HBoxContainer → TitleLabel "Log" (LabelHeading, 20 px), Spacer, CollapseButton % ("▼" / "▲", flat)
    ContentPanel % (PanelContainer, assets/styleboxes/ui/log_window.tres, min height 180, clip_contents)
      RichTextLabel % (bbcode_enabled, scroll_following, 18 px)
```

- It starts collapsed, with only the title bar showing. `CollapseButton` shows and hides `ContentPanel` through `toggle_collapse()`.
- Dragging the title bar with the left mouse button moves the window anywhere.
- Each `message_logged` appends `bbcode + "\n"`. The history is never trimmed or cleared.
- It sits below `GreyBackground` (z 2), so modal views cover it.

## BBCode Conventions

Callers format their own strings as single lines, and the window adds the newline.

| Markup | Meaning | Examples (source) |
|--------|---------|-------------------|
| `[color=cyan]` | Madra, adventure lifecycle, consumables, combat interrupts and strips | `Gained %d Madra` (ResourceManager), `Adventure Started: %s` / `Adventure Ended` (AdventureView), consumable `Obtained %dx %s` (InventoryManager), `cast was interrupted!` / `buffs were stripped!` (CombatEffectManager) |
| `[color=gold]` | Gold | `Gained %d Gold`, `Spent %d Gold` (ResourceManager) |
| `[color=red]` | Failure or loss | `Not enough Madra! Need %.0f, have %.0f` (ActionManager, AdventurePresenter), `Combat Defeat...` (AdventureView), `took %d Damage` (CombatEffectManager), `Discarded %s` (TrashSlot) |
| `[color=green]` | Success or healing | `Combat Victory!` (AdventureView), `healed for %d Health` (CombatEffectManager) |
| `[color=orange]` | Encounter choice | `Encounter: %s` (AdventureView) |
| `[color=light_gray]` | Material loot | `Looted %dx %s` (InventoryManager) |
| `[color=purple]` | Equipment loot | `Looted %dx %s` (InventoryManager) |
| `[color=yellow]` | Quest items, NPC flavour | quest-item `Obtained %dx %s` (InventoryManager), the merchant line (ActionManager) |
| `[color=magenta][DEV][/color]` prefix | Dev panel actions | `Set Madra to %d`, `Force-won current combat` (DevPanel) |
| `[b]name[/b]` | Combatant name | `[b]%s[/b] took …` (CombatEffectManager) |

## Integration Points

| System | Connection |
|--------|------------|
| `MainGame` | Sets the console print level from `log_print_level` |
| `LogWindow` | The only listener of `message_logged` |
| ResourceManager, InventoryManager, ActionManager, AdventureView, CombatEffectManager, AdventurePresenter, TrashSlot, ZoneViewBackground, DevPanel | Send player-facing messages through `LogManager.log_message()` |
| Every singleton and most scenes | Developer diagnostics through `Log.*` |
| Godot engine | `Log` is registered with `OS.add_logger()` and receives engine errors and `print()` output |

## Key Files

| File | Purpose |
|------|---------|
| `scripts/utils/log.gd` | `Log` levels, console and file output, engine logger |
| `singletons/log_manager/log_manager.gd` | Player-facing log signal bus |
| `scenes/ui/log_window/log_window.tscn` / `.gd` | In-game draggable, collapsible log |
| `scenes/main/main_game/main_game.gd` | `log_print_level` export, `Log.set_print_level()` |

## Work Remaining

### Bugs

- `[MEDIUM]` Madra log spam. `ResourceManager.add_madra()` logs every award of 1.0 or more. Cycling with Smooth Flow or Torrential Flow therefore writes about 12 lines a second to the `LogWindow` (see [RESOURCES.md](RESOURCES.md#bugs)).
- `[LOW]` Each launch, and each GUT run, opens the same-day log with `FileAccess.WRITE`, which truncates that day's earlier logs.
- `[LOW]` Console output depends on the log file. If `user://` isn't writable, every `Log.*` call returns before printing.

### Missing Functionality

- `[LOW]` `LogWindow` has no history cap, timestamps, filtering, or clear button. `RichTextLabel.append_text()` grows without limit over a session, which is made worse by the Madra spam.
- `[LOW]` `LogManager` keeps no history. Messages emitted before `LogWindow._ready()` are dropped. No current caller logs that early.
- `[LOW]` No log rotation. One `logs-YYYY-MM-DD.log` per day accumulates in `user://`.

### Tech Debt

- `[LOW]` The `Log.Event` order puts `INFO` (0) below `DEBUG` (1), the reverse of the usual severity order. `MainGame`'s script default (`DEBUG`) would hide INFO lines, and only the scene override to `INFO` avoids that.
- `[LOW]` A developer error goes to the player log. `ZoneViewBackground` reports `Failed to load layer %s` through `LogManager` instead of `Log.error`.
- `[LOW]` There is heavy `Log.info` in hot paths. `CombatEffectData.calculate_value()` logs at least 3 lines per call (plus one per non-zero scaling term), and `calculate_damage()` adds defense lines on top. This includes calls made when `AbilityStatsDisplay` renders stats, and all of it reaches the console at the `INFO` print level.
- `[LOW]` There are no tests for `Log`, `LogManager` or `LogWindow`.
