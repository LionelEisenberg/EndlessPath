# Breakthrough and Tribulation

> **Status:** built (PR #62), and not yet played through by the user. The design is [2026-10-23-tribulation-breath-of-the-core-design.md](../superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md), with a [playable prototype](../superpowers/mockups/tribulation-breath-of-the-core-prototype.html). The [plan](../superpowers/plans/2026-10-23-tribulation-breath-of-the-core.md) ends with an "As built (2026-10-24)" section that lists where the build differs from the plan's text. Core Density caps at 100 in Foundation, a pass moves the player to a thin Copper stage, and every number below is a starting value kept in data (see [CULTIVATION.md](CULTIVATION.md)).

## How it plays

- **The reveal.** Core Density stops at 100 in Foundation, and XP earned there is lost. The level-up that reaches 100 writes "Your core is full. The Tribulation waits in Spirit Valley." to the log. "The Tribulation" then appears among Spirit Valley's Cultivate actions with a NEW seal, and stays. The Goals board's milestone reads "Face the Tribulation".
- **The card.** Below 100 it shows a core rod and "Core 95 / 100" with the tag TRIAL, and a click shakes the row and logs "Your core must be full to face the Tribulation (95 / 100)." At 100 it shows "About 38 s" with "failure costs 5 levels" in its right column, both in brass, a steady brass frame and the tag ENTER.
- **Opening.** A click on a ready card opens a lacquer board in the map gap (952 px wide at (484, 24)), with no grey backdrop: the camera pushes in on the cultivator and the board grows out of them while the dock steps down and the Goals board and the log step off the left edge ([Board transitions](../infrastructure/MAIN_VIEW.md#board-transitions)). The map takes no input while the board is up. Closing plays it backwards. The intro panel shows the rules line ("4 cracks end the trial and cost 5 levels of Core Density."), **Begin** and **Not yet**. Space or a click on the board begins the run. A click anywhere else on the intro does nothing and reaches nothing beneath, so a double click on the card cannot skip the rules. **Not yet** and Escape close the board with nothing changed.
- **The trial: Breath of the Core.** About 38 seconds and 25 beats:
  - An aura sphere breathes in (faint, a dashed tan ring) and out (bright, a solid Madra-blue ring) around the core. The player presses Space or clicks as the bright, shrinking sphere crosses a brass ring.
  - Five phases get harder: Steady breath (6 × 1.7 s), Heartbeat (an irregular rhythm), Echo (two spheres, 0.6 s apart, the closest beats about 0.3 s apart), Quickening (faster and faster, Madra streaming into the core) and the last breath, which ends in a hold while the aura pours into the core.
  - A press within ±70 ms of a beat is PERFECT and within ±140 ms GOOD. A press up to 0.30 s early is an early miss, a beat nobody pressed is a late miss, and farther presses are ignored. Letting go of the hold more than 0.05 s early is a miss too. Every miss is a crack, and 4 cracks fail the trial on the spot.
  - Each press is judged when it arrives, on a clock read from `Time.get_ticks_usec()`, so judging does not follow the frame rate.
- **Feedback.** A hit pops its word ("Perfect", "Good", "Perfect · hold", "Held") and flashes the ring, and Madra pellets fly off it. A crack pops "Miss" with "Too early" or "Too late" ("The breath escapes you" on the last beat, "Released too early"), lights a crack pip and shakes the board (the full shake for the crack that fails it). The core steps up through four sizes with the hits and shows its cracks. The hold fills a brass arc in 24 whole steps. Only the newest word shows.
- **No escape mid-trial.** Once it starts, Escape does nothing and there is no close button. Losing window focus does not pause it: beats pass as misses, and a hold in progress ends as an early release.
- **The result** is applied the moment the run ends, before the panel shows, so closing the game on the panel cannot dodge the penalty after the next autosave (within 5 s; nothing saves on quit). The panel shows the grade (Flawless for 0 cracks, Clean for 1, Scraped through for 2 to 3, and Failed after a failure; cosmetic only), the counts ("24 perfect · 1 good · 0 missed") and **Continue**, which stops the action and resumes the zone's idle action.
  - **Pass:** "Breakthrough" and "Your core condenses into Copper." The stage becomes Copper, Core Density restarts at 0 on Copper's own curve and Madra cap, the log reads "You break through to Copper.", the card goes away at once, and the Goals milestone reads "Copper reached". The core on the board turns brass.
  - **Fail:** "Your core cracks" and "Core Density falls from 100 to 95." The core loses 5 levels (a starting value) and the path points stay. The card stays, showing "Core 95 / 100", until the player cycles back to 100. The board's core turns spent. Levels regained pay no second path point.
- **Later stages** reuse the mini-game, each with its own `TribulationData` (harder timings, different crack limits and penalties).

## Where the code lives

| Piece | File | Notes |
|---|---|---|
| The cap, the pass and the failure | `singletons/cultivation_manager/cultivation_manager.gd` | `add_core_density_xp()` `:88-149`, `lose_core_density_levels()` `:153-161`, `advance_to_next_stage()` `:167-183`, the milestone payout `:248-257`. The stage data: `resources/cycling/advancement_stages/` (Foundation's `next_stage` is Copper) |
| The data | `scripts/resource_definitions/tribulation/tribulation_data.gd`, `tribulation_phase_data.gd`; `resources/tribulation/foundation_tribulation.tres` | Every timing, window, penalty and line of copy. `get_early_reach()` `:146`, `get_rules_line()` `:150`, `get_fail_line()` `:154` |
| The judge | `scripts/tribulation/tribulation_run.gd` (`TribulationRun`, a `RefCounted`) | No nodes. Builds the beat schedule in `_init()` `:181`, then `press()` `:195`, `release()` `:224`, `advance()` `:239`, `is_failed()` `:249`, `is_finished()` `:258`, `grade()` `:263`, and the drawing queries `spheres_at()` `:325`, `hold_progress()` `:335` |
| The action | `scripts/resource_definitions/zones/zone_action_data/tribulation_action_data/tribulation_action_data.gd`; `resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres`; `resources/unlocks/core_density_full.tres` | `ActionType.TRIBULATION` is 7. `is_passed()` `:29` (the stage is at or past the target; `ZoneManager.get_available_actions()` drops the card, `zone_manager.gd:227-230`) and `can_attempt()` `:38` (the stage before the target, with a full core) |
| The gate and the signals | `singletons/action_manager/action_manager.gd` | The refusal in `select_action()` `:130-135`, before anything stops; `start_tribulation` and `stop_tribulation` `:37-38`; the handlers `:357` and `:409`. TRIBULATION is not an idle action, so stopping it resumes the zone's idle action |
| The card | `scenes/zones/zone_action_button/presenters/tribulation_presenter.gd` and `.tscn`; `scripts/utils/zone_action_groups.gd` | The Core row and the ready line (`setup()` `:26`), the gate (`can_activate()` `:45`) and the refusal's shake and log (`on_activation_rejected()` `:49`). Group Cultivate, tag TRIAL |
| The board | `scenes/tribulation/tribulation_view.gd` (`TribulationView`) and `.tscn` | Judges input and applies the result: `setup()` `:255`, `begin()` `:283`, `handle_press_event()` `:330`, `_gui_input()` `:239`, the run's end `:480`. Emits `finished(passed)`. `halt()` stops it and keeps it drawn for the close; `get_board_rect()` frames the transition |
| The stage | `scenes/tribulation/tribulation_stage.gd` (`TribulationStage`) | Draws the spheres and the hold arc per 2 px cell from the band rule the ring art uses: `show_frame()` `:137`, `band_runs()` `:97` |
| The state | `scenes/tribulation/tribulation_view_state.gd`; `MainView.open_board()` / `close_board()` (`scenes/ui/main_view/main_view.gd`); the two nodes in `scenes/main/main_game/main_game.tscn` | Pushed by `start_tribulation`. `stop_tribulation` halts the board and closes it, and the state removes itself when the close ends. Escape turns the trial down from the intro. See [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#tribulation-board) |
| The input | `project.godot` `tribulation_press` (`:144`): Space and the left mouse button | Every button on the board sets `focus_mode = FOCUS_NONE`, so Space never presses one |
| The art | `assets/ui/lacquer/tribulation/` (board, ring, core and pip strips), `assets/ui/lacquer/lacquer_rod_core_{empty,full}_ai.png`, `assets/styleboxes/lacquer/trib_board9.tres` | All `_ai`. Drawn by `docs/superpowers/mockups/tribulation-lacquer/gen/kit_tribulation.py` |

Tests: `tests/unit/test_tribulation_*.gd` and `tests/integration/test_tribulation_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Open

- **The numbers are starting values** (the windows, the 38 s length, 4 cracks, the 5-level penalty). They need playtesting: aim for 2 to 3 passes in five first attempts, and mashing Space through a run must fail. The spec's test plan has the adjustments.
- **The Core Density curve is not retuned.** It sets when level 100 arrives and how heavy 5 levels feel.
- **Copy is placeholder,** there is no sound, and Copper unlocks nothing yet.
- **No map teaser** for Zone 2 in v1. A zone shows UNCHARTED whenever its chart condition is unmet, before the unlock condition is read, so a teaser needs a rule change or new veil art.
- **Closing the game mid-trial** applies nothing, so it remains a way out of a failing run.

## What it replaced

Two earlier designs conflicted. On 2026-10-23 the user replaced both with a simpler one:

- **This document's 2025 design:** a Breakthrough tile on adventure maps at Core Density 100, then a mouse-tracking Tribulation built on the cycling technique, with no failure penalty.
- **[FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md) Beats 7–9:** a Tribulation Guardian boss, then an Advancement Zone holding the Tribulation Site.

The user wanted the trial to start from the base as a plain zone action, a mini-game that isn't cycling, and a real penalty. The old text of this document is in git history (for example at `05c437e`).

## Related

- [CULTIVATION.md](CULTIVATION.md): Core Density, stages and the stage resources
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md#beat-9-the-tribulation-implemented): Beat 9 in the Foundation spine
- [ZONES.md](../zones/ZONES.md): the card, the action type and the gate
- [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#tribulation-board): the board's state and what it turns off; [Board transitions](../infrastructure/MAIN_VIEW.md#board-transitions): how it opens and closes
