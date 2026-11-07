# Start no idle action when a run ends (#141)

Playtest polish issue #141, tracked in #85. Lionel's note: "Don't automatic forage spring forest when exiting combat." Built against `main` at 7d586171 (#137 merged).

## Decided before the canvas

Lionel's answer, recorded on the issue: after a run nothing starts, whatever ran before it, for every way a run ends (boss win, lost fight, the clock, the dev exits). An unlock after a run starts nothing. No "Resumed …" line. A click on an idle card starts it as today. Load keeps its rule: arriving in the zone starts its last idle action, and the run leaves that saved id as it is.

## Mock-up answers

Canvas: [After a run](https://claude.ai/artifact/LUw7VANrj6HYBRgS7bZjRm), approved by Lionel 2026-11-07. Recorded on #141.

1. **The Now tray after a run** reads "Nothing running", the line a zone with no idle action already reads. No new copy.
2. **Any action the player starts ends the quiet.** The talk, Riverbank Training, cycling, the shop or the Tribulation each end it; while one runs the tray reads "<idle action> · paused" again, and its end resumes the idle action as today. Arriving in the zone ends it too.

## Shape

- `ActionManager`:
  - `_idle_held: bool`, in memory only. `stop_action()` sets it when the stopped action is an adventure, before the action clears, so `current_action_changed(null)` listeners already read it; it then resumes nothing.
  - `select_action()` clears it for any action, once the action passes the Tribulation check (answer 2).
  - `_on_zone_changed()` clears it before it stops and resolves, so the load, travel and a save reset work as before.
  - `_on_condition_unlocked()` starts nothing while held.
  - `is_idle_held() -> bool`, public, for the Now tray.
  - `resolve_idle_action()`, `is_idle_action()` and the log words stay as they are (#150 rewrites the words).
- `NowStrip._update_empty_line()`: while `ActionManager.is_idle_held()`, "Nothing running" (`NOTHING_RUNNING`) instead of "<idle action> · paused". The scene does not change. The tray refreshes on `current_action_changed` and `condition_unlocked` as today; the hold is set before the clear, so the first refresh reads it.
- No save change: no field, no version step. `ZoneProgressionData.last_idle_action_id` keeps its meaning.

## Tests

- `test_idle_action_resolution.gd`: the session-stop table loses its adventure rows; a new "After a run" section: a run's end starts nothing (won, lost, from foraging or the Aura Well, no timer, no Madra rate, no Resumed line); the last idle id is kept; the hold is set when the tray hears the clear; an unlock after a run starts nothing (with and without an idle action before the run); picking an idle action starts it and ends the hold; a session after a run resumes the idle action when it ends (answer 2); a second run holds again; load and a save reset after a run start the last idle action.
- `test_adventure_end_flow.gd`: every way a run ends (boss win, lost fight, the clock, the dev exits) leaves nothing running, from foraging.
- `test_zone_panel.gd`: the empty tray after a run reads the approved line.
- Comments in `test_adventure_map_zoom.gd`, `test_adventure_view_frame.gd`, `test_dev_adventure_commands.gd` and `test_adventure_end_flow.gd` no longer say a run's end resumes the idle action.

## Checks in the game

The issue's Done when list, on `-- --save=user://dev/runs/no-idle-after-run.tres` and the presets it names.
