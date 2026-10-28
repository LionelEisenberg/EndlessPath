# Testing

## Overview

EndlessPath uses **GUT 9.7.1** (`addons/gut/`, editor plugin enabled) for unit and integration tests. The test runner prints the suite's size and a run's results, so this doc does not keep them.

Tests run inside the full project, so every autoload is loaded before the first test. `PersistenceManager` knows it is in a test run (`LaunchOptions.is_test_run()` finds `addons/gut/` in the engine arguments, which the CLI command, `tests/run_tests.ps1` and the editor's GUT panel all have) and boots on an in-memory save: a fresh `SaveGameData` with no `save_path`, no `main_save_path` (it is `""`) and autosave off. A test run never reads or writes `user://save.tres` or `user://backups/`, whatever the developer's save holds. Tests swap in their own `SaveGameData` objects as the patterns below show, and the tests of `PersistenceManager` itself build their own instances on temporary files. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md#sessions-and-launch-options). `DevManager` knows it too: its `_ready()` builds no preset in a test run, and its switches never unload or reload a scene (see [Patterns](#patterns-used-in-the-suite)).

`tests/label_tests/label_testing_scene.tscn` is a visual reference scene, not a GUT test. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene).

## A Green Run

A run that passes still prints some noise:

- **GUT warning:** `Ignoring Inner Class TestRecordingEffect because it does not extend GutTest`. `tests/unit/test_quest_manager.gd` declares the helper `class TestRecordingEffect extends EffectData`. GUT treats inner classes whose names start with `Test` (its default inner-class prefix) as test classes. The warning is harmless.
- **Deprecation notices:** 30 lines of `[DEPRECATED]: wait_frames has been replaced with wait_physics_frames…`, from the `wait_frames()` calls in the book tests (`test_abilities_book.gd`, `test_book_frame.gd`, `test_character_book.gd`, `test_path_book.gd`).
- **Orphans:** all 24 are Dialogic subsystem nodes (`subsystem_*.gd`, Timers, one `AudioStreamPlayer`) created as a side effect of the `Dialogic` autoload. GUT reports them as "Outside Tests" under `res://tests/unit/test_ability_manager.gd`, the first script it runs.
- **Exit-time engine lines:** every headless run, a GUT run (one script or the suite) or a launch of the game, ends with ``WARNING: <N> ObjectDB instances were leaked at exit (run with `--verbose` for details).`` and `ERROR: <N> resources still in use at exit (run with --verbose for details).` They are baseline, not any test's doing: a single script prints them too, one that predates the dev tools included (`test_resource_manager.gd`, `test_idle_action_resolution.gd`).
- **Errors and logs printed by passing tests:**
  - `tests/unit/test_combat_effect_types.gd` and `tests/integration/test_power_font_buff_strip.gd` print `Node not found: %VitalsManager / %CombatEffectManager / %CombatBuffManager / %CombatAbilityManager`. They build `CombatantNode.new()` from the script and `add_child_autofree()` it before attaching manager children, so the `@onready %` lookups fail (the same lines also name `%CombatantVisual`). `tests/integration/test_empty_palm_interrupt.gd` uses the same construction.
  - `tests/unit/test_persistence_manager.gd` builds its own `PersistenceManager` instances on temporary files and prints what they log:
    - The engine's load errors for its unreadable fixture saves and its unreadable temp file: `Cannot open file 'res://__missing_for_test_persistence/missing_item.tres'`, `Failed loading resource`, `Parse Error: [ext_resource] referenced non-existent resource` and `Error loading resource`. The tests mark them as expected.
    - `CRITICAL: PersistenceManager: Saving is off for this session: <reason>`, once for each session that blocks saving. The reasons are: the file could not be loaded (the line names the `.unreadable.` copy), the managers `verify()` needs did not load, and a newer build wrote the save (`version 99; this build knows 1`).
    - `WARN: SaveFiles: … is missing, so its temp file … is loaded instead (a write was cut short)`, and `WARN: PersistenceManager: Repaired current_selected_zone_id in …` (with the `.invalid.` copy's path) and `… in memory only; … stays as the newer build wrote it`.
    - `INFO: PersistenceManager: No save at …, so a new one was written`, `INFO: SaveGameData: Moved the current zone from TestZone to SpiritValley`, and `INFO: PersistenceManager: This run does not play the main scene, so … is read into memory and never written`, twice, from the tests of a run of another scene.
  - `tests/unit/test_save_files.gd` prints one engine error, `Cannot save file 'user://__test_save_files/save.tmp.tres'.`, with its `at:` line and a GDScript backtrace (`test_a_failed_write_leaves_the_old_file_alone` marks it as expected), one `WARN` for loading a temp file: `SaveFiles: … is missing, so its temp file … is loaded instead (a write was cut short)`, and, from its tests that hold the save open while it is written (Windows only), `WARN: SaveFiles: Renaming … over … took N tries` twice and `WARN: SaveFiles: Could not rename … over … in 20 tries (error 1)` once.
  - `tests/unit/test_save_migration.gd` prints `WARN: SaveGameData: Accessory slot 0 is taken, so <item id> stays in equipped_gear slot 4` and `INFO: SaveGameData: Moved the current zone from TestZone to SpiritValley`.
  - The dev tools' tests print the `INFO` lines of the systems they drive, and some expected `ERROR` and `CRITICAL` lines, each with a backtrace (`Log.error` and `Log.critical` do not `push_error`, so the tests pass):
    - `tests/unit/test_dev_preset_data.gd` prints `INFO` lines of the save swap its `before_each()` and `after_each()` make (the `CharacterManager` "Updating resources from save data" and "Updated 8 attributes" pair, and the idle foraging action starting and stopping), and two unusual ones, from its apply tests: `CyclingManager: Unlocked technique 'torrential_flow'` and `AbilityManager: Unlocked ability 'power_font'`.
    - `tests/integration/test_dev_hooks.gd` prints only `INFO` lines: the routine `CharacterManager` pairs of its save swaps, foraging starting and stopping, the events, unlocks and quest starts its complete-without-playing tests set off (`TriggerEventEffectData: Triggering event: …`, `UnlockManager: Condition permanently unlocked: …`, `QuestManager: Started quest 'q_fill_core'`), the unlock of its own condition, and the NPC 1 dialogue in its cancel test (`DialogueManager: Starting timeline: celestial_intervener_introduction_1`, `DialogueManager: Timeline ended`, and `ActionManager: Dialogue completed, processing effects for: Talk to the [INTERVENER]`, which a cancel logs too, though nothing completes).
    - `tests/integration/test_dev_commands.gd` prints the `INFO` lines of the actions, unlocks and equips it drives, and one `ERROR: CultivationManager: Cannot level - level 1 of stage FOUNDATION costs no XP …` with a backtrace, from `test_reach_core_density_refuses_a_stage_with_no_cost`: the manager's own guard, listed again below under `test_cultivation_manager.gd`.
    - `tests/integration/test_story_route.gd` prints only `INFO` lines, those of what the route sets off as it plays the story on a fresh save: events firing (`TriggerEventEffectData: Triggering event: …`), conditions latching (`UnlockManager: Condition permanently unlocked: …`), quests starting, advancing and completing (`StartQuestEffectData`, `QuestManager`), foraging starting and stopping, the Path Point (`AwardPathPointEffectData: Awarding 1 path point(s)`), the Refugee Camp Map (`AwardItemEffectData: Awarding item: …`) and the technique and ability unlocks and equips. `test_save_presets.gd` prints only the same kind of lines, for each preset it builds.
    - `tests/integration/test_dev_manager_build.gd` prints those lines for each build, `INFO: SaveGameData: Moved the current zone from TestZone to SpiritValley` (an old snapshot standing in the hidden Test Zone is migrated), `WARN: DevManager: Repaired current_selected_zone_id in a copy of the snapshot of preset 'test_lost_zone_snapshot'; the preset file is left as it is`, and two `CRITICAL` lines with a backtrace: `DevManager: Could not start preset no_such_preset: no preset has that id. Playing a fresh game in memory instead`, and the same for `test_failing_launch`, naming its step (`Complete celestial_intervener_dialogue_4: … is not available now`).
    - `tests/integration/test_dev_manager_sessions.gd` prints the lines of the refusals and failed builds it provokes, besides the `INFO` lines of its builds:
      - the same `CRITICAL: DevManager: Could not start preset no_such_preset …`, from its launch test;
      - `ERROR: DevManager: Could not start preset 'Test test_failing': Complete celestial_intervener_dialogue_4: … is not available now` for each switch whose build fails, and `ERROR: DevManager: Could not bring back the session a switch left: This run has no main save. Playing a fresh game in memory instead` when the session such a switch left was the user's save, which a test run does not have;
      - the call-time refusals, `ERROR: DevManager: Could not go back to your save`, `… start a new game on your save`, `… keep this game as your save` and `… restore your save from <file>`, which end `This run has no main save`, plus `… restore your save from no_such_backup.tres: There is no backup at …` and `Could not start preset 'Story through no_such_beat': story_through no_such_beat is not a beat of the route`;
      - the failed backups: the engine error `Could not create directory: '…/__test_dev_manager_sessions_blocker/backups'.` with its `at:` line (the tests mark it as expected), `ERROR: SaveFiles: Could not make the backup folder … (error 20)` and `ERROR: DevManager: Could not keep this game as your save: Could not back up your save, so it was left as it was`, and the same for a new game and a restore;
      - the refusals of a second switch asked for while one is pending, which end `A session switch is already under way`: `ERROR: DevManager: Could not start preset 'Test test_second'`, `… keep this game as your save` (twice), `… start a new game on your save` and `… go back to your save`.
    - `tests/integration/test_dev_adventure_commands.gd` prints only `INFO` lines of the runs and fights it drives: adventures starting and stopping, combats starting and ending (`AdventureCombat: Enemy died`, `AdventureTilemap: Boss defeated! Adventure Successful.`) and `UnlockManager: Condition permanently unlocked: q_first_steps_enemy_defeated`.
    - `tests/integration/test_dev_panel.gd` prints `CRITICAL: PersistenceManager: Saving is off for this session: user://__test_dev_panel_newer.tres was written by a newer build (version 99; this build knows 1)` three times, each with a backtrace, from the tests of the save warning, which play that save to block saving. Apart from those, it, `test_dev_panel_zone_toggles.gd` and `test_dev_panel_items_tab.gd` print only `INFO` lines: the routine `CharacterManager` "Updating resources from save data" and "Updated 8 attributes" pair for each save swap, and what the tests drive (the cycling start and stop of the travel test, the technique and ability unlocks and equips, the Core Density milestone's unlock, and `AdventureView`, `AdventureTilemap` and `AdventureCombat` initializing for each adventure view the Adventure tab tests host).
    - `tests/integration/test_dev_panel_saves_tab.gd` prints the `INFO` lines of its builds and:
      - `CRITICAL: PersistenceManager: Saving is off for this session: user://__test_dev_panel_saves_tab_file.tres was written by a newer build (version 99; this build knows 1)`, twice, each with a backtrace: once for the session line that says why saving is off, once for Save now naming the same reason;
      - `ERROR: DevManager: Could not go back to your save: This run has no main save`, twice, from the tests of a refused switch;
      - `ERROR: DevManager: Could not start preset 'Failing': Complete celestial_intervener_dialogue_4: … is not available now` and `ERROR: DevManager: Could not bring back the session a switch left: This run has no main save. Playing a fresh game in memory instead`, from the test of a switch that fails midway;
      - the engine error `Cannot save file 'user://__test_dev_panel_saves_tab_file.tmp.tres'.` with its `at:` line and a GDScript backtrace, from the Save now write-error test, which marks it as expected.
    - `tests/integration/test_dev_panel_story_tab.gd` prints the `INFO` lines of what its tests drive (events firing, conditions latching, quests starting, advancing and completing, foraging starting and stopping, and the route's steps for the jump tests) and three `ERROR` lines, each with a backtrace: `DevManager: Could not start preset 'Story through Awakening': A session switch is already under way` (a second jump asked for while the first is pending), and, from the test of a switch that fails midway, `Could not start preset 'Failing': Complete celestial_intervener_dialogue_4: … is not available now` and `Could not bring back the session a switch left: This run has no main save. Playing a fresh game in memory instead`.
  - Any test that writes a save file can print `WARN: SaveFiles: Renaming … over … took N tries`, most often under the parallel runner's load: Windows refused the rename that ends the write once (an antivirus scan or the indexer holding the file just written), and the retry wrote it ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#writing-and-the-auto-save)). It shows up in `test_dev_manager_sessions.gd`, on no test in particular.
  - `test_save_round_trip.gd`, `test_launch_options.gd` and `test_play_stats.gd` print nothing. `test_play_stats_recording.gd` prints only the `INFO` lines of the systems it drives.
  - Expected negative-path logs:
    - `CyclingManager`, `QuestManager` and `PathManager` "unknown id 'nonexistent'"
    - `StartQuestEffectData` "empty quest_id"
    - `QuestManager` validation errors for `bad_quest` / `bad_quest2`
    - `AdventureMapGenerator` "critical-path check failed, regenerating (attempt 1..5)" and "filler quota combat exceeds available NoOp tiles (placed N of 500)", from the generator stress tests. Any test that starts a run on a randomly generated Shallow Woods map (`test_adventure_end_flow.gd`; `test_adventure_view_frame.gd` no longer does, as it plays every run on a fixed map) can print the same two warnings ("filler quota amorphous_spirit_encounter exceeds available NoOp tiles (placed N of 4)"), a different number of times on each run. It can also fail, rarely: about two maps in five need a second try, and now and then all five tries fail (in two runs of `test_adventure_view_frame.gd`, before it played on fixed maps, 14 of 36 maps needed a second try and one failed all five, so `test_adventure_end_flow.gd` is still exposed). That map ends in `push_error("AdventureMapGenerator: exhausted regeneration attempts, returning best-effort map")`, which GUT counts as an unexpected error, so the test it lands in fails and the next run is usually green. `test_adventure_map_generator.gd` expects the same error once and consumes it with `assert_push_error`
    - `HexagonalTileMapLayer: TileMapLayer is not in the right position, it won't look right!`: about 300 `WARN` lines under `test_adventure_map_generator.gd`, which instances the hex layer scene for its maths only
    - `ExpeditionPage: 'Many' has more than 3 choices; the rest are not shown` (a `Log.warn`), from `test_extra_choices_beyond_the_third_are_left_out`
    - `CombatAbilityManager: Player: Ability Basic Strike is on cooldown` (twice), `Not enough resources for Basic Strike` and `Cannot use ability while casting`, from the technique dock's refusal tests. A press the dock refuses asks `can_cast_ability_instance()` first, and that logs its reason with `Log.warn` (the tests check the player's log stays silent)
    - `AdventureTilemap: Choice ignored …` (`Log.info`), from the pick-guard tests
    - `InventoryManager: swap_accessory_slots called with empty from_index`, with a backtrace, from `test_swap_accessory_slots_empty_source_changes_nothing` (`Log.error` does not `push_error`, so the test passes)
    - `CultivationManager: Cannot level - level 1 of stage FOUNDATION costs no XP (a free level or a missing stage resource)` (each with a backtrace), from `test_a_free_level_does_not_level` and `test_no_stage_resource_does_not_level` in `test_cultivation_manager.gd`, and from `test_reach_core_density_refuses_a_stage_with_no_cost` in `test_dev_commands.gd`: the guard against a loop that cannot end (`Log.error` does not `push_error`, so the tests pass)
    - `CultivationManager: Core Density N is past the stage's cap of 100. Loaded at the cap, with no XP` (three `INFO` lines, one per file that loads an over-cap save): 130 from `test_a_save_past_the_cap_loads_at_the_cap` in `test_cultivation_manager.gd`, 140 from `test_cultivator_plate.gd` and 120 from `test_goals_panel.gd`

## Running Tests

### First run in a fresh checkout

GUT's `class_name`s (`GutTest` and others) are only registered after the project has been imported once. Without a `.godot/` cache, import first:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import
git diff project.godot            # should print nothing
```

Run the same import after pulling or merging new art, before the suite or the game. Neither a scene run nor the `-s` test command imports anything. A scene run on a checkout that has not imported the new art can fail to load an item `.tres` the real save names. A run of the main scene then keeps `save.tres` untouched, copies it to `save.unreadable.<time>.tres` and turns saving off for that run; a run of another scene, which only reads the save into memory, plays a new game in memory and copies nothing, so the file stays as it is (see [PERSISTENCE.md](../infrastructure/PERSISTENCE.md)). Either way the run itself sees a default save. The suite never loads the real save.

> **Fixed 2026-10-19:** In a fresh checkout this import used to rewrite the `[dialogic]` section of `project.godot`, emptying `directories/dch_directory` and `directories/dtl_directory` and dropping the registered characters and timeline. Dialogic's editor panel pruned every entry whose `.dch`/`.dtl` loader wasn't registered yet. A local patch in `addons/dialogic/Core/DialogicResourceUtil.gd` now prunes only files that are really missing (see the addon exceptions in `CLAUDE.md`). If `git diff project.godot` ever shows those keys emptied again, the patch was probably lost in a Dialogic upgrade. Running the test command by itself does not modify `project.godot`.

### Parallel runner

`tests/run_tests.ps1` runs the suite in several headless Godot processes at once, 6 by default, and prints one result. From the project root, in any shell:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1
```

| Option | Default | Effect |
|--------|---------|--------|
| `-Processes N` | `6` | How many Godot processes run at once (1-32) |
| `-Godot <path>` | the Godot 4.7.2 console build in `C:\Program Files (x86)\Godot\` | The Godot console executable |

- It takes the test scripts from `.gutconfig.json`'s `dirs` and splits them into groups of about equal time, longest first, using each script's time from the last run. Each group runs with a copy of `.gutconfig.json` that lists its scripts in place of the `dirs`, so every other GUT setting still applies.
- The times are saved after each run in `gut_test_times.json` in the repository's shared git folder (`git rev-parse --git-common-dir`), so every worktree on the machine starts from them. A script with no time yet counts as the median; with no times at all the groups are about equal in size, and the first run is slower.
- Each process's config, output (`process_N.log`), errors (`process_N.errors.log`) and JUnit file go to `.godot/test_runs/`, replaced every run.
- It prints a line as each process finishes, then either `All N tests passed` or each failing test with its message, the processes' log paths, and the one-process command that confirms the failing files.
- It also fails the run when a test script runs no tests. GUT treats a test script that does not parse as one that does not extend `GutTest`: it prints a warning, skips the script, and still reports `All tests passed!` with exit code 0, so in one process the only signs are one script fewer and one more warning.
- Exit code `0` when every test passes, `1` when a test fails or a script runs no tests, `2` when the run cannot start (no Godot at `-Godot`, a checkout that has not been imported, no test scripts).
- Several processes make the machine busy, and a test that depends on how long frames take can fail under load (see the real-time waits under [Tech Debt](#tech-debt)). Each process also runs its scripts in another order than one process does, so a test that depends on what an earlier script left behind can fail in one and not the other (see "Inject manager state directly" under [Patterns](#patterns-used-in-the-suite)). Confirm a failure in one process before acting on it. Ctrl+C ends the Godot processes still running.

### One process

From the project root, the whole suite:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

- Use the `_console.exe` build so output reaches the terminal.
- `-gdir` repeats what `.gutconfig.json` already sets. GUT loads `res://.gutconfig.json` by default; `-gconfig=` disables that.
- To run one file, pass `-gconfig=` with `-gtest`. Without it, the config still adds both test directories and every script runs:

  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_resource_manager.gd -gexit
  ```

- Exit code is `0` when every test passes and `1` when any fails. In headless mode GUT quits on its own, but keep `-gexit` for clarity.

Useful GUT 9.7 flags (from `addons/gut/cli/gut_cli.gd`):

| Flag | Example | Effect |
|------|---------|--------|
| `-gtest` | `-gconfig= -gtest=res://tests/unit/test_path_manager.gd` | Run specific script(s). Pass `-gconfig=` too: otherwise `.gutconfig.json` still adds both test directories and the whole suite runs |
| `-gselect` | `-gselect=inventory` | Run scripts whose filename contains the text |
| `-gunit_test_name` | `-gunit_test_name=equip` | Run only tests whose name contains the text |
| `-ginner_class` | `-ginner_class=Foo` | Run only matching inner test classes |
| `-glog` | `-glog=3` | Log level 0 to 3 (config default 2) |
| `-gjunit_xml_file` | `-gjunit_xml_file=user://results.xml` | Export JUnit XML |
| `-gfailure_error_types` | | Which error types fail a test. Default `engine, gut, push_error`. |
| `-gh` | | Print all options |

### In the editor

The enabled GUT plugin adds a GUT bottom panel. It can run all tests, a single script, or the test at the cursor.

## Configuration

`.gutconfig.json` (project root):

| Key | Value |
|-----|-------|
| `dirs` | `["res://tests/unit/", "res://tests/integration/"]` |
| `prefix` / `suffix` | `test_` / `.gd` |
| `should_maximize` | `false` |
| `compact_mode` | `true` |
| `opacity` | `100` |
| `font_size` | `20` |
| `log_level` | `2` |

`tests/label_tests/` is not in `dirs`, so GUT never collects it.

## Directory Layout

```
tests/
├── unit/                         one system, resource or manager per file (plus `counting_effect.gd`, a shared fake GUT does not collect)
├── integration/                  content flows and scene-level UI behaviour (plus `adventure_map_fixture.gd`, a shared helper GUT does not collect)
├── helpers/                      shared helpers with a `class_name`, which GUT does not collect (`PageBounds`: the inventory's two page rects, and text drawn off them or at another scale)
├── run_tests.ps1                 the parallel runner
└── label_tests/
    ├── label_testing_scene.tscn  visual Label-variant reference (run with F6)
    └── label_testing_scene.gd
```

## Writing Tests

### Conventions

- File name `test_<system>.gd` (unit) or `test_<flow>.gd` (integration). Every file `extends GutTest`.
- Test functions are `func test_<behaviour>() -> void:`. Helpers are private (`_make_equipment()`, `_create_test_technique()`).
- Most files open with a `##` comment saying what they cover, and group tests under `#----` section headers.
- Write tests whenever you add logic to a singleton, resource class or combat formula (see `CLAUDE.md`).
- A new test that needs the game at a story moment sets it up with `DevCommands`, the story route or a preset, not by writing save fields (see "Story state from the dev commands, the route or a preset" below).

### Patterns used in the suite

| Pattern | Example | Notes |
|---------|---------|-------|
| Fresh save per test | `_save_data = SaveGameData.new()` in `before_each()` | The most common setup |
| Swap one manager's save, restore it after | `test_award_attribute_effect_data.gd`, `test_zone_progression_data.gd`, `test_training_flow.gd`, `test_inventory_manager.gd` | Keep the original in a field and put it back in `after_each()`. This is the safe pattern. |
| Bind several managers to one test save, restore them all after | `test_resource_manager.gd`, `tests/integration/test_adventure_flow.gd` | Swap every manager the code under test reaches, including the ones that react to its signals (`UnlockManager`, `EventManager`, `QuestManager`). Both also swap `CultivationManager.advancement_stage_resources` for a stub stage, so the caps are the stub's, not the shipped stage's |
| Swap the global save and re-bind all managers | `PersistenceManager.save_game_data = SaveGameData.new()` then `PersistenceManager.save_data_reset.emit()` (`test_unlock_condition_item_owned.gd`; `test_change_vitals_effect_data.gd`, `test_cultivation_manager.gd`, `test_character_manager.gd` and `test_adventure_combat_victory_event.gd` also restore) | Handlers run in autoload order, so `CultivationManager` re-evaluates unlocks before `EventManager` re-binds |
| Inject manager state directly | `CyclingManager._live_save_data`, `CyclingManager._techniques_by_id`, `QuestManager._quests_by_id`, `PathManager._all_trees`, `EventManager.live_save_data` | Keep the original in a field in `before_each()` and put it back in `after_each()`, as `test_quest_manager.gd`, `test_start_quest_effect_data.gd` and `test_cycling_manager.gd` do. A state nulled or left behind leaks into every later file, and into different files in each process of the parallel runner: until 2026-10-23 the two quest files nulled `EventManager.live_save_data`, which printed 18 `event_progression on Nil` errors in a one-process run and once failed a test in the runner |
| Test-only hook in production code | `PathManager._test_stage_override`; `TribulationView.clock_usec`; `DevManager.preset_dir_override`; `LaunchOptions.pin_path_override` | `PathManager.is_stage_reached()` checks the first one first. `clock_usec` is a `Callable` that defaults to `Time.get_ticks_usec` and that `test_tribulation_view.gd` and `test_tribulation_view_state.gd` replace with a test clock, so a run is stepped by exact microseconds without waiting (every judgement and timed effect reads it). `preset_dir_override` is the one folder `DevManager` reads presets from and saves them to, in place of the repository's and the export folder, and `pin_path_override` the pin file `LaunchOptions` reads and writes in place of the checkout's: a test that saves a preset or a pin sets them to a temp path and puts them back |
| Mutate the run's save in place | `PersistenceManager.save_game_data.inventory = InventoryData.new()` (inventory integration tests) | Changes only in-memory state, but the save is the one in-memory save every test in the process shares, so the rest of it stays as earlier tests left it |
| Story state from the dev commands, the route or a preset | `DevCommands.complete_action("celestial_intervener_dialogue_1")`, `DevCommands.reach_core_density(100)`, `DevManager.build_preset(preset)` (`test_dev_commands.gd`, `test_story_route.gd`, `test_save_presets.gd`, `test_dev_manager_build.gd`) | A test that needs the game at a story moment sets it up through these, not by writing save fields. They go through the managers' own rules (the quest chain, the unlocks, the Core Density milestones), so the test starts where play would, and content that moves a step breaks the route's test instead of every test that wrote its own fields. A command returns `""` or the reason it refused, so assert it. Bind a fresh save first (`PersistenceManager.use_save(SaveGameData.new_current(), "")`) and give the original back, and cancel the running action before and after (`ActionManager.cancel_current_action()`: the route makes foraging start on its own). A test that builds through the route also sets what other files swap in stubs of, since a step reads it: PathManager's current tree (after binding the save, which drops it) with `_test_stage_override` at -1, AbilityManager's index, QuestManager's catalog and index, and the real Foundation and Copper stages as `CultivationManager.advancement_stage_resources`. `test_story_route.gd` shows how: it sets the real ones in `before_each()`, and gives the tree, the override and the stages back in `after_each()` |
| Instance a scene | `const X := preload("res://...tscn")`, `X.instantiate()`, `add_child_autofree(node)`, then `await get_tree().process_frame` before reading `@onready` nodes | |
| Step the clock by hand | Timers: hold `ActionManager.action_timer` (`paused = true`) and emit its `timeout` for each tick or haul (`_tick()` in `test_training_flow.gd`, `_finish_haul()` in `test_zone_map_render.gd`), or hold it partway through (`_hold_haul_at()` there, `_hold_action_timer_at()` in `test_zone_panel.gd`); let a one-shot timer run out by stopping it and emitting `timeout` (`_run_out_preview_delay()` in `test_zone_travel.gd`). Tweens: `custom_step()` every running tween in `get_tree().get_processed_tweens()` a 60 FPS frame at a time, as a frame does (`_step_tweens()` in `test_zone_travel.gd`, `_run_tweens()` in `test_zone_panel.gd` and `test_lacquer_pieces.gd`), or one paused tween (`_run()` in `test_zone_map_render.gd`, on the map's `_idle_motion_tween`). `_process` and `_physics_process`: take the node off the frame clock (`set_process(false)`, `set_physics_process(false)`) and run it with `simulate()` (`_advance_floater()` in `test_map_markers.gd`, the character's walk in `_step_frame()` in `test_zone_travel.gd`) | A test that waits real seconds is slow, and if its checks depend on how long frames take it fails on a loaded machine: a floater placed a frame before its rise crossed a 2 px step, fewer ticks than the wait allows. `start(time_left)` then putting the interval back as `wait_time` holds a timer partway through. Release a held timer in `after_each()`: `ActionManager` is an autoload, so a paused timer would stop every later tick and haul. A stepped frame runs the physics step before the tweens, as the tree does. Frame awaits that only let nodes lay out or place themselves stay. The adventure tests (`_step_frame()`, `_wait_for_hop()` in `test_adventure_map_render.gd` and its three neighbours) also catch a hop's end inside the stepping loop (`movement_completed`), have the camera follow each stepped frame with `Camera2D.force_update_scroll()` (the tree's transform update, which a hover laid at a walk's end reads), and step a `_process` shake with `simulate()` on its own node (the coin, the expedition page). A `SceneTreeTimer` cannot be stepped: the boss reveal's hit-stop runs out in real time (`_wait_out_the_hit_stop()`, 0.15 s) before the push is stepped, and a check that time has slowed reads before any real frame runs |
| A view state without the main scene | `test_merchant_view_state.gd`: `MainView.new()` that never enters the tree, a hand-built `state_stack`, and `merchant_view` / `grey_background` assigned directly. `test_tribulation_view_state.gd` does the same with a real `TribulationView` and plain Controls for the log, Goals board and dock | Call the state's signal handlers (`_on_start_merchant()`, `_on_stop_merchant()`, `_on_close_finished()`, `_on_start_tribulation()`) instead of emitting `ActionManager` signals, since the state is never in the tree to connect them. `test_tribulation_flow.gd` does add the state to the tree, so its `_ready()` connects, and drives it through the real `ActionManager`. The `MainView._unhandled_input()` routing to the state is not tested: the tests call `handle_input()` |
| Zone view fixture | `PersistenceManager.save_game_data = SaveGameData.new()`, then `PersistenceManager.save_data_reset.emit()`; end with `while ActionManager.get_current_action() != null: ActionManager.stop_action()` (`test_idle_action_resolution.gd`, `test_zone_panel.gd`, `test_zone_travel.gd`) | Every action, card and map test starts from a fresh save and stops what it started, so no idle tick timer leaks into the next test. Never add `main_game.tscn` to the tree: it starts the whole game inside the test (the tests that read it only instance it). Its `SaveTimer` is harmless in a test run, since the session is in memory and a tick writes nothing |
| Pointer tests over a map or a board | `_hosted_map()` in `test_zone_travel.gd` puts the map in a `CanvasLayer` above GUT's output window (layer 128); `test_vitals_plate.gd`, `test_expedition_page.gd`, `test_technique_dock.gd` and `test_adventure_view_frame.gd` host their boards the same way, `test_adventure_map_zoom.gd` hosts the real `AdventureView` so (it pushes the wheel into the viewport as a press and a release), and `test_tribulation_flow.gd` hosts a zone card and the open `TribulationView` on one layer and pushes a left click at the card's centre, to show the board stops it | In the full run GUT's window covers the screen and would take the pointer the hover tests move. A test that moves the real pointer puts it back at window point (0, 0) in `after_each()`, or the zone map's hover tests fail later in the run |
| An adventure map without the generator | `tests/integration/adventure_map_fixture.gd` (no `test_` prefix, so GUT does not run it), preloaded as `AdventureMapFixture`: a six-tile map with a fight, a rest site and a boss, and `AdventureTilemap.start_adventure_on_map(action, encounters)` | Used by the tilemap, render, marker, zoom and view tests. Every run in `test_adventure_view_frame.gd` (and in `test_adventure_map_zoom.gd`) starts through `_start_run()`, which hands the tilemap a `FixedMapGenerator` (see Fakes) that returns `_map` (the fixture, or the map a test sets) before the run starts, so no random map is generated and nothing can fail its critical-path check. `start_adventure_on_map()` does not clear the visited and revealed sets, so a test that plays a second map on a tilemap that already ran stops it first, as a run's end does |
| Stepped motion | Shakes and animated glyphs run in `_process` from an elapsed counter through `MapGlyph.shake_offset_at()` (or a static function of elapsed time); a test drives them with GUT's `simulate()` or calls the static | A tween sampled against the wall clock is flaky: it lags a timer by up to a frame, and a keyframe edge can sit 12 ms away |
| Timer-driven flows | Hold the timer and emit its `timeout` for each tick (`_tick()` in `test_training_flow.gd`; see "Step the clock by hand"). A test that has to run a real `Timer` waits for what it does, with a generous timeout (`await wait_until(func() -> bool: return _tick_signal_count >= 3, 2.0)`), never a fixed `create_timer()` window counted in ticks | A `Timer` fires at most once a frame, so when frames run longer than its `wait_time` it falls behind the clock and a fixed window catches too few ticks on a busy machine. `--fixed-fps 10` on the suite command plays a busy machine |
| A rule walked over scenes | `test_boards_never_trim_text.gd` instances each scene of a list (`BOARD_SCENES`), finds every `Label` in it and asserts on it; a second test reads those scene files for the same keys, and a third checks the labels that can run long wrap by word. The rule also holds for the whole game: two tests read every `.tscn` and every `.gd` under `res://scenes` (`DirAccess`, line by line) for a trimming overrun behaviour or `clip_text`, and fail for a file that is not on the allowlist `KNOWN_TRIMMERS`, and for a listed file that no longer trims, so the list is exact and only shrinks; a last test pins what the walk takes for trimming | A new board joins `BOARD_SCENES`, and needs no test of its own for the rule. Its own test file checks that it grows with its text. A file that has been swept for wrapping comes off `KNOWN_TRIMMERS` in the same commit, or the second test fails. `clip_contents` on a container is not scanned |
| Real physics picking | `_press_at()` in `test_cycling_technique.gd`: `await wait_physics_frames(2)`, `push_input(event, true)` (local coordinates), then `await wait_physics_frames(2)` | The headless root window is 64 px square, so a `push_input` without the local flag is scaled and misses. An `Area2D`'s broadphase entry updates at the physics step, so an event pushed in the first physics iteration after the area was created or moved can miss |
| Parsed input actions | A test that parses an `InputEventAction` releases it in `after_each()` (`Input.action_release(&"ui_cancel")`) | Otherwise `Input.is_action_pressed()` stays true for every later test |
| Queued frees before the orphan count | `await _await_queued_frees()` (one `wait_process_frames(1)`) at the end of a test whose code takes nodes out of the tree and queue-frees them: a technique switch, a technique list rebuild, a hidden cycling board (`test_cycling_technique.gd`, `test_cycling_view.gd`, `test_zone_panel.gd`) | GUT counts a test's orphans before the frame that frees them ends, so without the wait the run prints a per-test orphan list |
| Scenes with hex map layers | Nothing extra: after `add_child_autofree()`, the scene's hex layers convert cube↔map coordinates and find paths (`test_hexagon_tile_map_layer.gd` reads a layer at once, before any frame) | A hex layer runs the addon's own set-up (the conversions, the neighbour directions and, with pathfinding on, the A* graph) in its `_ready()`, whenever it is built. Some older tests still call `tile_set.emit_changed()` on one of the scene's layers after adding it, a workaround the layer no longer needs: the call is harmless, and a new test leaves it out |
| Signals | `watch_signals(obj)` with `assert_signal_emitted`, `assert_signal_emitted_with_parameters`, `assert_signal_emit_count`, `assert_signal_not_emitted` | |
| Expected errors | `assert_push_error("unknown technique_id")` | GUT 9.7 fails a test on unexpected engine errors and `push_error` by default, so negative-path tests must consume their `push_error` |
| Fakes | `CountingEffect` (`tests/unit/counting_effect.gd`), an `EffectData` that counts its `process()` calls, which the consumable tests preload; `FakeGreyBackground` extends `GreyBackground` and shows and hides at once (`test_merchant_view_state.gd`); `FakeCoveringState` stands in for a second overlay that hides the HUD boards (`test_view_state_hud_positions.gd`); `FixedMapGenerator` extends `AdventureMapGenerator` and returns the map it was given (`test_adventure_view_frame.gd` and `test_adventure_map_zoom.gd`, installed by `_start_run()`) | Don't start inner class names with `Test` |
| Temporary files | `user://test_*.tres` / `user://__test_*.tres`, removed with `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` | `test_quest_progression_persistence.gd`, `test_zone_progression_data.gd` |
| `PersistenceManager` on temporary files | `_make_manager()` in `test_persistence_manager.gd`: `PersistenceManagerScript.new()` (never the autoload) with `save_path`, `main_save_path` and `backup_dir` pointed at temp files, then `boot(LaunchOptions.new())`. `test_save_files.gd` keeps its files under `user://__test_*` the same way | Every path the code derives (the temp file, the copies aside, the backups) comes from those three, never from a hard-coded `user://` path, so no test touches the real folder. `LaunchOptions.new()` makes the boot ignore whatever options this GUT run was started with. Two managers pointed at one temp save stand in for two windows of one checkout on its save |
| `DevManager` under GUT | `test_dev_manager_sessions.gd`, `test_dev_manager_build.gd` | `DevManager._ready()` builds nothing in a test run, so a test calls `start_from_launch_options()` with its own `LaunchOptions`, `build_preset()` or a switch. A switch runs on the next frame (`await wait_process_frames(2)`), and it never unloads or reloads a scene under GUT: it frees the main scene only when that is the current scene, and the runner is. A second switch asked for before the first has run is refused (`DevManager.SWITCH_UNDER_WAY`), so a test that needs two lets a frame pass between them. A switch that needs the user's save refuses unless the test points `PersistenceManager.main_save_path` and `backup_dir` at temp files (a test run has no main save). Opening that temp main save backs it up into the temp folder, as a launch does, so `_start_on_temp_main_save()` empties the folder again and each test counts only the backups its own switches take. A switch puts autosave back to the run's launch value, which is off in a test run; a test that needs it on sets `PersistenceManager._autosave_at_launch`. Put back whatever the test changed: those two paths, autosave and its launch value, `DevManager`'s session, the player's log (`LogManager`) and the time scale (`GameSpeed.set_base_scale(1.0)`). A test that saves a preset sets `DevManager.preset_dir_override` to a temp folder first, because a GUT run from the editor binary would otherwise write into `res://resources/dev/save_presets/` |
| The route's coverage test | `test_story_route.gd` | Plays the route on a fresh save and fails for story content the route neither reaches nor lists as left out: a quest not completed, a zone action never available, a capped NPC dialogue not used up, a beat whose `reached_when` did not fire. The rule is in [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#the-story-route) and its authoring side in [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md). A step of a kind the test has no check for fails it, so a route step's effect is always asserted: a new kind in the route needs its check added |
| Content lock | Loads shipped `.tres` and asserts on field values | `test_crude_scale_tres.gd`, `test_path_tree_resource_loading.gd`, `test_foundation_tribulation_data.gd` (the Tribulation, the Copper stage and the action's wiring). `test_tribulation_run.gd` plays a `duplicate(true)` of the shipped trial with exact times, so the data and the judge are checked together |

The suite never uses GUT doubles, stubs or partial doubles (`double()`, `stub()`, `partial_double()`).

### Avoid mirror tests

A mirror test re-implements the production logic inside the test and asserts against that copy. The method itself is never called, so the test passes whatever production does. None are left: every suite calls the code it tests.

New tests should call the real method on the autoload, with its state swapped as above. Keep the original reference and put it back in `after_each()`; never set an autoload's state to `null`.

## Coverage Gaps

A test file's name says which system or flow it checks (`tests/unit/test_<system>*.gd`, `tests/integration/test_<flow>*.gd`), and its opening `##` comment says what it covers, so search by name to find an area's tests. This table lists only what the tests do not reach. Change a row when you close a gap or find one; it does not list the tests themselves, which every PR adds to.

| Area | Not covered |
|------|-------------|
| PersistenceManager / SaveGameData | The autoload's own boot on a real launch (the tests boot bare instances, and the one autoload test reads the GUT-run branch), and its check of which scene runs (the tests hand `boot()` the answer); a real window close (the tests send `NOTIFICATION_WM_CLOSE_REQUEST` themselves); `SaveTimer`'s connection to `autosave()` |
| ResourceManager | The known bugs in [RESOURCES.md](../infrastructure/RESOURCES.md#bugs): `set_madra()` ignoring the cap; the 0 cap when the stage has no resource (a gain adds nothing) |
| CultivationManager | The missing `SILVER` entry in `PATH_POINTS_PER_STAGE` ([CULTIVATION.md](../cultivation/CULTIVATION.md)); the order of `advance_to_next_stage()`'s log line and signals |
| Tribulation | Pixels: what the stage's draw handlers paint (the colours, the Echo swap and the draw order) was checked once against an oracle in a scratch renderer, not by a test; the live `MainView._unhandled_input()` route and the real keyboard (the playtest checks Space and Escape) |
| CharacterManager | The `PlayerManager` / `VitalsManager` refresh on `base_attribute_changed` |
| Inventory UI | Closing `InventoryView`: no test closes the book, so its trash flush on close runs only as `TrashSlot.flush_to_inventory()` called directly |
| Items generator | The writer, `scripts/tools/items_md_to_resources.gd` |
| Combat | `SimpleEnemyAI`, `VitalsManager` regen, the `CharacterManager.get_gold_multiplier()` factor (a stub returning 1.0, so the tests cannot tell it from missing) |
| Adventure | The rest of `AdventureView` (death, result building), `AdventureEndCard` |
| Adventure map | Pixel placement against the mock (checked by movie captures, not tests) |
| Adventure frame | Hovering a technique slot or a buff socket inside the real `AdventureView` (their pointer tests host the boards on a canvas layer); pixel placement (captures) |
| AbilityManager | Dragging abilities onto loadout slots |
| Cycling | Content integrity (unique technique ids, path-node unlock ids matching the catalog); pixel placement (checked by captures, not tests) |
| PathManager | Buying a node from the book |
| QuestManager | `QuestToast`; the Beat 1 → Beat 2 → Beat 3 chain played as the game plays it (the story route plays it through dev commands, which run each step's effects without the clicks, timers and screens between them; only Beat 3b has an integration test of its own); a data check that every authored `completion_event_id` has a producer |
| Effects | `TriggerEventEffectData`, `AwardResourceEffectData` apart from its `quiet` flag, `AwardItemEffectData`, `AwardLootTableEffectData`, `ChangeVitalsEffectData.process()` and `describe()` |
| UnlockManager / conditions | `CULTIVATION_STAGE`, `ZONE_UNLOCKED`, `ADVENTURE_COMPLETED` and `ATTRIBUTE_VALUE` have no direct tests. `CULTIVATION_LEVEL` is tested only through the Beat 3b and Tribulation flows. The evaluation sweep itself, and comparison operators other than `>=` |
| ZoneManager / training | `max_completions` filtering in `get_available_actions()` |
| ActionManager | `FORAGE` loot awarding; the Dialogic timeline itself (the tests emit `dialogue_ended`) |
| Zone view panels | Pixel placement against the mock (checked by movie captures, not tests) |
| Zone map | `ZoneTransition`'s per-pellet arithmetic and its camera reset |
| MerchantManager / shop | The real `GreyBackground` fade and Escape routing through `MainView` (checked in play) |
| EventManager | No dedicated tests: `trigger_event()` runs inside the quest, encounter and content tests, but its contract with `has_event_triggered()` is not tested on its own |
| DialogueManager, PlayerManager, `Log` | No tests of their own. The dev hooks test `DialogueManager.end_dialogue_now()` (through a cancelled dialogue action) and `PlayerManager.reset_vitals()`; `start_timeline()`, the vitals' wiring and `Log` are not tested |
| UI shell | `MainView` push/pop/change semantics, `GreyBackground`'s fade-in ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)); the call to the cabinet hand-off from `MainView._ready()` (the helper is tested; the call is checked in a headless run of the real scene); `MainView._unhandled_input()` routing a key to `TribulationViewState` (the tests call `handle_input()`) |
| Dev tools | Map Preview, the UID tool and the dev panel's Open save folder button ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)). The Adventure tab is tested on a run set up by hand (a view with an action set), not on a real one; the commands behind it are tested on a real run. Switching sessions is tested only under GUT, where no scene is freed or loaded, so reloading the main scene, and a switch mid-dialogue or mid-adventure in a running game, are not tested. `DevManager._ready()` builds nothing under GUT, so a launch with `--preset` or a pin runs only through `start_from_launch_options()`. "Save this game as a preset" is tested into a temp folder: its write into the repository's folder from an editor run, and into the export folder, are not (a test reads which folder an editor run would pick) |
| Loot | `LootTable` rolls (no test references `LootTable`) |

## Key Files

| File | Purpose |
|------|---------|
| `.gutconfig.json` | GUT defaults (directories, prefix, log level) |
| `addons/gut/` | GUT 9.7.1 (read-only third-party code) |
| `addons/gut/gut_cmdln.gd` | CLI entry point |
| `tests/run_tests.ps1` | Parallel runner: the suite in several Godot processes, one result ([Parallel runner](#parallel-runner)) |
| `tests/unit/`, `tests/integration/` | Test scripts |
| `tests/label_tests/label_testing_scene.tscn` | Visual Label-variant reference |
| `docs/testing/TEST_SUITE_PROMPT.md` | Historical one-shot prompt that created the suite (2026-04-10, commit `2f6d5bf`) |

## Work Remaining

### Missing Functionality

- `[MEDIUM]` Little coverage of the UI shell's core. `MainView.remove_state()`, `MerchantViewState`, the book states' close paths, `GreyBackground.hide_with_panel()` and the HUD board placement and hiding are tested, but not the `MainView` push/pop/change semantics. `ActionManager`'s forage loot awarding is untested.
- `[MEDIUM]` No tests for `AdventureEndCard`, `AdventureView.stop_adventure()`'s result building and death path, `SimpleEnemyAI` or `LootTable`.
- `[LOW]` No CI. The suite only runs locally.

### Tech Debt

- `[MEDIUM]` Tests build `CombatantNode.new()` and add it to the tree before its manager children exist, which prints `Node not found: %VitalsManager ...`. Affects `tests/unit/test_combat_effect_types.gd`, `tests/integration/test_power_font_buff_strip.gd` and `tests/integration/test_empty_palm_interrupt.gd`. Instance the combatant scene, or add the managers before `add_child_autofree()`.
- `[LOW]` Rename `TestRecordingEffect` in `tests/unit/test_quest_manager.gd`, for example to `RecordingEffect`, to clear the GUT inner-class warning.
- `[LOW]` 24 Dialogic orphans per run come from the `Dialogic` autoload. GUT attributes them to `test_ability_manager.gd`.
- `[LOW]` `test_pagination_bar.gd` and `test_trash_slot_flow.gd` still print per-test orphan lists (page buttons, item instances). The pagination bar's come from the same remove-then-queue-free pattern, so a frame's wait at the end of each test, as the cycling and chest tests do, would likely clear them; the trash flow's were not looked into.
- `[LOW]` A few adventure waits stay real on purpose: the boss reveal's hit-stop (0.15 s in each push test, 0.3 s in `test_boss_reveal_keeps_the_hit_stop`, which tests it), the 24 real frames of `test_coins_keep_up_with_a_camera_a_tween_moves` (it tests the frame's own order: tweens after `_process`, the coins placed again before drawing), and the 0.01 s opening cooldown in `test_adventure_view_frame.gd`'s `_cast_the_first_technique()`. `test_adventure_map_zoom.gd` still waits real frames for the wheel's zoom; its zoom ease could be stepped as `_zoom_to()` in `test_adventure_map_render.gd` does.
- `[LOW]` The book tests still wait real seconds for the book's AnimationPlayers (open, close, page turns) and its bookmark slide: `test_book_frame.gd`, and through it `test_character_book.gd`, `test_path_book.gd` and `test_abilities_book.gd`. Stepping them needs `AnimationPlayer.advance()` with the players' `callback_mode_process` set to manual, not the tween and timer stepping above. A few short real-time waits remain in `test_zone_map_render.gd` (the foraging wander and the walk, 1.2 s in all), `test_grey_background.gd`, `test_zone_action_cards.gd`, `test_book_view_state.gd` and `test_adventure_end_flow.gd`. `test_cycling_technique.gd` already steps its clock by hand; its time is physics frames for real picking.
- `[LOW]` The book tests call GUT's deprecated `wait_frames()`, which prints 30 deprecation notices per run. GUT suggests `wait_physics_frames()` or `wait_process_frames()`.
- `[LOW]` The setup of a test that builds through the route (the real path tree, stage override, ability index, quest catalog and stages) is repeated in `test_story_route.gd`, `test_save_presets.gd`, `test_dev_manager_build.gd` and `test_dev_manager_sessions.gd`, and `test_save_presets.gd` and `test_dev_manager_build.gd` each carry their own `_is_available()` and `_inventory_counts()`. There is no shared fixture module.
- `[LOW]` `PathManager._test_stage_override` is a test hook in production code.
- `[LOW]` Several tests replace `PersistenceManager.save_game_data` with a fresh `SaveGameData` and never put the original back, for example `test_adventure_encounter.gd` and `test_award_path_point_effect_data.gd`. The next script in the process starts on their save, not the run's own. Keep the original in a field and restore it in `after_each()`, as the files in the patterns table do.
- `[LOW]` A headless `--import` in a fresh checkout empties `[dialogic] directories/*` in `project.godot` (see [the gotcha](#first-run-in-a-fresh-checkout)).
