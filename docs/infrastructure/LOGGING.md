# Logging

Last updated: 2026-10-23

## Overview

The game has two separate logging channels, and neither feeds the other:

| Channel | Where | Audience | Output |
|---------|-------|----------|--------|
| `Log` | `scripts/utils/log.gd` (`class_name Log extends Logger`, static API) | Developers | Console (`print_rich`, coloured by level) and the file `user://logs-YYYY-MM-DD.log`. It also captures engine errors, warnings and `print()` output into that file |
| `LogManager` | `singletons/log_manager/log_manager.gd` (autoload) | Players | The `message_logged` signal and a bounded history, which the in-game `LogWindow` shows as the five-line log board and the full log |

`Log` lines never appear in the `LogWindow`, and `LogManager` messages are never written to the log file.

## When to Use Which

| Situation | Call |
|-----------|------|
| Diagnostics, state transitions, unexpected data, failures | `Log.info()` / `Log.warn()` / `Log.error()` / `Log.critical()` |
| Something the player should read (rewards, combat events, rejections) | `LogManager.log_message("[color=…]…[/color]")` |
| Both | Call both. For example, `AdventureView.start_adventure()` calls `Log.info` and `LogManager.log_message` |
| Never in game code | Bare `print()`. Only the headless CLI tools in `scripts/tools/` (`extends SceneTree`) still use it |

Usage in `singletons/`, `scenes/` and `scripts/` (counted 2026-10-18, before the zone view rebuild): 254 `Log.*` calls (115 `info`, 30 `warn`, 74 `error`, 35 `critical`, 0 `debug`) and 29 `LogManager.log_message` calls across 9 files.

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
| `signal visibility_toggled()` | Emitted by `toggle_window()`. `LogWindow` responds by opening or closing the full log |
| `const HISTORY_LIMIT: int = 200` | The most messages `get_history()` keeps |
| `log_message(bbcode: String)` | Appends to the history (dropping the oldest past `HISTORY_LIMIT`), then emits `message_logged`. No levels, no buffering |
| `get_history() -> Array[String]` | A copy of the kept messages, oldest first. `LogWindow` reads it in `_ready()`, so lines logged before it existed still show |
| `toggle_window()` | Emits `visibility_toggled`: opens or closes the full log, like L. Only tests call it today |

## LogWindow

`scenes/ui/log_window/log_window.tscn` / `log_window.gd` (`class_name LogWindow extends Control`), the lacquer log board (kit §5.3 and §0). It is instanced in `main_game.tscn` as `MainView/LogWindow` (`%LogWindow`), `z_index` 1, `mouse_filter` IGNORE, `theme = lacquer_theme.tres`. The root is the log's 440x204 slot: `ZoneViewState` puts it at (24, 852), and `AdventureViewState` leaves it there.

```
LogWindow (Control, the 440x204 slot)
  Board % (Control)                    the five-line board, on the slot's bottom edge (its top edge when the slot is in the upper half)
    BoardTexture % (TextureRect)       lacquer_log1_ai … lacquer_log5_ai, one per line count
    TitleLabel "Log" (LabelLacquerPanelTitle), HintLabel "Full log · L" (LabelLacquerDetail)
    Line4 … Line0 %                    LineBullet<n> (10x10 inlaid bullet) + LineLabel<n> (LabelLacquerDetail, 384 px, ellipsis)
  FullBoard % (Control, 440x560)       hidden by default
    FullBoardTexture (Panel)           StyleBoxTexture 9-slice of lacquer_log5_ai
    FullTitleLabel "Log", FullHintLabel "Close · L"
    FullLogText % (RichTextLabel, RichTextLacquerLog, 406x468: 18 whole 26 px lines)
```

- **Board.** Shows the newest 5 lines from `get_history()`, newest at the bottom, with their BBCode stripped (`plain_text()`). It is 74 + 26 px per line tall (the one-line board, empty, before anything is logged) and grows upward one line at a time from screen y 1056.
- **Tones.** `tone_for(bbcode)` reads the first `[color]` tag: orange-to-yellow hues (gold, yellow, orange) are BRASS, cyan-to-blue are MADRA, green, lime and the light neutrals (white, `light_gray`: value 0.8 and up) are CREAM, and anything else (red, magenta, gray, silver, no colour) is TAN. So a material haul (`light_gray`) is cream, as kit §5.3 asks; the cyan "Adventure Started" / "Adventure Ended" lines read Madra blue, a known difference from the kit's tan system lines. Lines fade by colour steps, never by opacity: ages 0 and 1 keep their tone, age 2 is tan, ages 3 and 4 are dim (`#94806A`), and each bullet takes the same colour.
- **Full log.** L (`toggle_log`), Escape while it is open, or `LogManager.toggle_window()` toggle it. It shows every kept line in its tone, without fading, newest at the bottom, scrolling in whole lines. Each entry is a one-row table (an 18 px bullet cell, then the text), so a wrapped line hangs under its own text. New lines append while it is open, and the oldest go past `HISTORY_LIMIT`. The rail's end caps are lit only when the text can scroll that way (kit §4.4). It never opens while the log is hidden, and hiding the log closes it. A menu book or the cycling board closes it and keeps it shut while it is open (`set_full_log_blocked()`, called through `MainViewState._block_full_log()` by `BookViewState` and `CyclingViewState`): the log ignores L and Escape then, so Escape closes the book or the board.
- **Visibility.** It sits below `GreyBackground` (z 2). The merchant shop hides it (`MainView.hide_hud_boards()`), and it comes back as it was when the shop closes. The menu books leave it showing, dimmed under their backdrop, and cycling leaves it showing beside its board. See [MAIN_VIEW.md](MAIN_VIEW.md#hud-boards).

## BBCode Conventions

Callers format their own strings as single lines. The board strips the tags and colours each line by its first `[color]` (see [LogWindow](#logwindow)); the full log does the same.

| Markup | Meaning | Examples (source) |
|--------|---------|-------------------|
| `[color=cyan]` | Madra, adventure lifecycle, consumables, combat interrupts and strips | `Gained %d Madra` (ResourceManager), `Adventure Started: %s` / `Adventure Ended` (AdventureView), consumable `Obtained %dx %s` (InventoryManager), `cast was interrupted!` / `buffs were stripped!` (CombatEffectManager), `Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP` (CyclingView, one per finished cycle) |
| `[color=gold]` | Gold | `Gained %d Gold`, `Spent %d Gold` (ResourceManager) |
| `[color=red]` | Failure or loss | `Not enough Madra! Need %.0f, have %.0f` (AdventurePresenter), `Combat Defeat...` (AdventureView), `took %d Damage` (CombatEffectManager), `Discarded %s` (TrashSlot) |
| `[color=green]` | Success or healing | `Combat Victory!` (AdventureView), `healed for %d Health` (CombatEffectManager) |
| `[color=orange]` | Encounter choice | `Encounter: %s` (AdventureView) |
| `[color=light_gray]` | Material loot | `Looted %dx %s` (InventoryManager) |
| `[color=purple]` | Equipment loot | `Looted %dx %s` (InventoryManager) |
| `[color=yellow]` | Quest items | quest-item `Obtained %dx %s` (InventoryManager) |
| No colour (tan) | Idle action resumes | `Resumed %s`, `Travelled to %s · resumed %s`, `Travelled to %s`, `Started %s` (ActionManager) |
| `[color=magenta][DEV][/color]` prefix | Dev panel actions | `Set Madra to %d`, `Force-won current combat` (DevPanel) |
| `[b]name[/b]` | Combatant name | `[b]%s[/b] took …` (CombatEffectManager) |

## Integration Points

| System | Connection |
|--------|------------|
| `MainGame` | Sets the console print level from `log_print_level` |
| `LogWindow` | The only listener of `message_logged` and `visibility_toggled`; reads `get_history()` |
| `MainView` / view states | `ZoneViewState` places the log slot (the adventure leaves it there); the merchant shop hides it, and a menu book or cycling blocks the full log ([MAIN_VIEW.md](MAIN_VIEW.md#hud-boards)) |
| ResourceManager, InventoryManager, ActionManager, AdventureView, CyclingView, CombatEffectManager, AdventurePresenter, TrashSlot, ZoneViewBackground, DevPanel | Send player-facing messages through `LogManager.log_message()` |
| Every singleton and most scenes | Developer diagnostics through `Log.*` |
| Godot engine | `Log` is registered with `OS.add_logger()` and receives engine errors and `print()` output |

## Key Files

| File | Purpose |
|------|---------|
| `scripts/utils/log.gd` | `Log` levels, console and file output, engine logger |
| `singletons/log_manager/log_manager.gd` | Player-facing log signal bus and history |
| `scenes/ui/log_window/log_window.tscn` / `.gd` | Lacquer log board and full log |
| `scenes/main/main_game/main_game.gd` | `log_print_level` export, `Log.set_print_level()` |

## Work Remaining

### Bugs

- `[LOW]` Each launch, and each GUT run, opens the same-day log with `FileAccess.WRITE`, which truncates that day's earlier logs.
- `[LOW]` Console output depends on the log file. If `user://` isn't writable, every `Log.*` call returns before printing.

### Missing Functionality

- `[LOW]` The log has no timestamps, filtering, or clear button, and the history keeps only the last 200 messages.
- `[LOW]` No log rotation. One `logs-YYYY-MM-DD.log` per day accumulates in `user://`.

### Tech Debt

- `[LOW]` The `Log.Event` order puts `INFO` (0) below `DEBUG` (1), the reverse of the usual severity order. `MainGame`'s script default (`DEBUG`) would hide INFO lines, and only the scene override to `INFO` avoids that.
- `[LOW]` `LogManager.toggle_window()` has no caller outside the tests, and the names `toggle_window` and `visibility_toggled` are misleading: they open the full log, they don't show or hide the log.
- `[LOW]` A developer error goes to the player log. `ZoneViewBackground` reports `Failed to load layer %s` through `LogManager` instead of `Log.error`.
- `[LOW]` There is heavy `Log.info` in hot paths. `CombatEffectData.calculate_value()` logs at least 3 lines per call (plus one per non-zero scaling term), and `calculate_damage()` adds defense lines on top. This includes the damage previews: the Abilities book's details card calls `calculate_value()` for its figure, and the technique tooltip's damage line does through `AbilityRow.format_damage()` (neither reaches `calculate_damage()`). All of it reaches the console at the `INFO` print level.
- `[LOW]` There are no tests for `Log`. `LogManager`'s history (`test_log_manager_history.gd`) and the log board and full log (`test_log_board.gd`) are tested.
