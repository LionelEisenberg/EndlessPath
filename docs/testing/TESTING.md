# Testing
Last updated: 2026-10-23

## Overview

EndlessPath uses **GUT 9.7.1** (`addons/gut/`, editor plugin enabled) for unit and integration tests.

| Suite | Directory | Scripts | Tests |
|-------|-----------|---------|-------|
| Unit | `tests/unit/` | 78 | 807 |
| Integration | `tests/integration/` | 45 | 825 |
| **Total** | | **123** | **1632** |

Tests run inside the full project, so all 18 autoloads are loaded before the first test. `PersistenceManager._ready()` loads the developer's real `user://save.tres`, and creates it if it is missing. Tests then swap in fresh `SaveGameData` objects in memory. No test calls `PersistenceManager.save_data()` and the autosave `SaveTimer` lives only in `main_game.tscn`, so a test run does not write the save file.

`tests/label_tests/label_testing_scene.tscn` is a visual reference scene, not a GUT test. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene).

## Current Suite Status

Run on 2026-10-23, on `feat/adventure-view-styleguide-1fc223` after the adventure view's map and frame rework (PR 1 of the lacquer rework, not merged) and its pre-merge touch-up, with the command from `CLAUDE.md`.

| Item | Result |
|------|--------|
| Engine | Godot v4.7.2.stable.official.ed1daf0bf |
| GUT | 9.7.1 |
| Scripts / tests | 123 / 1632 |
| Passing / failing / pending or risky | 1632 / 0 / 0 |
| Asserts | 9188 on this run. The count varies between runs: for example, `test_adventure_map_generator.gd` asserts once per element of a randomly generated map. |
| Orphans | 24 |
| GUT warnings | 1 |
| GUT deprecation notices | 30 |
| Exit code | 0 |
| Wall time | About 152 s on this run (GUT's `Time` line). The zone and adventure scene tests await real frames and timers (walks at about a second a hop, tweens, the 150 ms popover delay) |

Known noise in a green run:

- **GUT warning:** `Ignoring Inner Class TestRecordingEffect because it does not extend GutTest`. `tests/unit/test_quest_manager.gd` declares the helper `class TestRecordingEffect extends EffectData`. GUT treats inner classes whose names start with `Test` (its default inner-class prefix) as test classes. The warning is harmless.
- **Deprecation notices:** 30 lines of `[DEPRECATED]: wait_frames has been replaced with wait_physics_frames…`, from the `wait_frames()` calls in the book tests (`test_abilities_book.gd`, `test_book_frame.gd`, `test_character_book.gd`, `test_path_book.gd`).
- **Orphans:** all 24 are Dialogic subsystem nodes (`subsystem_*.gd`, Timers, one `AudioStreamPlayer`) created as a side effect of the `Dialogic` autoload. GUT reports them as "Outside Tests" under `res://tests/unit/test_ability_manager.gd`, the first script it runs.
- **Errors printed by passing tests:**
  - 18 copies of `SCRIPT ERROR: Invalid access to property or key 'event_progression' on a base object of type 'Nil'` at `event_manager.gd:35` (`has_event_triggered`): 10 under `tests/unit/test_quiet_madra.gd` and 8 under `tests/unit/test_unlock_condition_item_owned.gd`. The chain is `unlock_condition_data.gd evaluate()` ← `unlock_manager.gd _evaluate_all_conditions()` ← `cultivation_manager.gd _update_resources()` ← a `before_each()` that emits `PersistenceManager.save_data_reset`.
    - Likely cause, from reading the code: `tests/unit/test_quest_manager.gd` and `tests/unit/test_start_quest_effect_data.gd` set `EventManager.live_save_data = null` in `after_each()`, and both run earlier in alphabetical order. On `save_data_reset`, `CultivationManager`'s handler (autoload 2) runs before `EventManager`'s re-bind lambda (autoload 3). It emits `core_density_level_updated` and `advancement_stage_changed`, and each one evaluates the `EVENT_TRIGGERED` conditions against the null save. `test_quiet_madra.gd` now sorts between those files and `test_unlock_condition_item_owned.gd`, so it takes the first share of the errors.
  - `tests/unit/test_combat_effect_types.gd` and `tests/integration/test_power_font_buff_strip.gd` print `Node not found: %VitalsManager / %CombatEffectManager / %CombatBuffManager / %CombatAbilityManager`. They build `CombatantNode.new()` from the script and `add_child_autofree()` it before attaching manager children, so the `@onready %` lookups fail (the same lines also name `%CombatantVisual`). `tests/integration/test_empty_palm_interrupt.gd` uses the same construction.
  - `tests/unit/test_persistence_manager.gd` prints the engine's load errors for its unreadable fixture save (`Cannot open file 'res://__missing_for_test_persistence/missing_item.tres'`, `Parse Error: [ext_resource] referenced non-existent resource`) and `PersistenceManager`'s CRITICAL lines. The tests mark the engine errors as expected.
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

## Running Tests

### First run in a fresh checkout

GUT's `class_name`s (`GutTest` and others) are only registered after the project has been imported once. Without a `.godot/` cache, import first:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import
git diff project.godot            # should print nothing
```

Run the same import after pulling or merging new art, before the suite or the game. Neither a scene run nor the `-s` test command imports anything, so an item `.tres` the real save names can fail to load its new texture. `PersistenceManager` then keeps `save.tres` untouched, copies it to `save.unreadable.<time>.tres` and turns saving off for that run (see [PERSISTENCE.md](../infrastructure/PERSISTENCE.md)), but the run itself sees a default save.

> **Fixed 2026-10-19:** In a fresh checkout this import used to rewrite the `[dialogic]` section of `project.godot`, emptying `directories/dch_directory` and `directories/dtl_directory` and dropping the registered characters and timeline. Dialogic's editor panel pruned every entry whose `.dch`/`.dtl` loader wasn't registered yet. A local patch in `addons/dialogic/Core/DialogicResourceUtil.gd` now prunes only files that are really missing (see the addon exceptions in `CLAUDE.md`). If `git diff project.godot` ever shows those keys emptied again, the patch was probably lost in a Dialogic upgrade. Running the test command by itself does not modify `project.godot`.

### Command line

From the project root:

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
├── unit/                         78 scripts: one system, resource or manager per file
├── integration/                  45 scripts: content flows and scene-level UI behaviour (plus `adventure_map_fixture.gd`, a shared helper GUT does not collect)
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

### Patterns used in the suite

| Pattern | Example | Notes |
|---------|---------|-------|
| Fresh save per test | `_save_data = SaveGameData.new()` in `before_each()` | `SaveGameData.new()` appears in 59 files |
| Swap one manager's save, restore it after | `test_award_attribute_effect_data.gd`, `test_zone_progression_data.gd`, `test_training_flow.gd`, `test_inventory_manager.gd` | Keep the original in a field and put it back in `after_each()`. This is the safe pattern. |
| Bind several managers to one test save, restore them all after | `test_resource_manager.gd`, `tests/integration/test_adventure_flow.gd` | Swap every manager the code under test reaches, including the ones that react to its signals (`UnlockManager`, `EventManager`, `QuestManager`). Both also swap `CultivationManager.advancement_stage_resources` for a stub stage, so the caps don't depend on the developer's save |
| Swap the global save and re-bind all managers | `PersistenceManager.save_game_data = SaveGameData.new()` then `PersistenceManager.save_data_reset.emit()` (`test_unlock_condition_item_owned.gd`; `test_change_vitals_effect_data.gd`, `test_cultivation_manager.gd`, `test_character_manager.gd` and `test_adventure_combat_victory_event.gd` also restore) | Handlers run in autoload order, so `CultivationManager` re-evaluates unlocks before `EventManager` re-binds |
| Inject manager state directly | `CyclingManager._live_save_data`, `CyclingManager._techniques_by_id`, `QuestManager._quests_by_id`, `PathManager._all_trees`, `EventManager.live_save_data` | Some files null these in `after_each()` instead of restoring them, which leaks into later files. Nulling `EventManager.live_save_data` is behind the `event_progression on Nil` errors described above. |
| Test-only hook in production code | `PathManager._test_stage_override` | The only one. `PathManager._is_stage_reached()` checks it first. |
| Mutate the loaded save in place | `PersistenceManager.save_game_data.inventory = InventoryData.new()` (inventory integration tests) | Changes only in-memory state, but the rest of the developer's save stays loaded |
| Instance a scene | `const X := preload("res://...tscn")`, `X.instantiate()`, `add_child_autofree(node)`, then `await get_tree().process_frame` before reading `@onready` nodes | 80 `await get_tree().process_frame` calls across 26 files |
| A view state without the main scene | `test_merchant_view_state.gd`: `MainView.new()` that never enters the tree, a hand-built `state_stack`, and `merchant_view` / `grey_background` assigned directly | Call the state's signal handlers (`_on_start_merchant()`, `_on_stop_merchant()`, `_on_close_finished()`) instead of emitting `ActionManager` signals, since the state is never in the tree to connect them |
| Zone view fixture | `PersistenceManager.save_game_data = SaveGameData.new()`, then `PersistenceManager.save_data_reset.emit()`; end with `while ActionManager.get_current_action() != null: ActionManager.stop_action()` (`test_idle_action_resolution.gd`, `test_zone_panel.gd`, `test_zone_travel.gd`) | Every action, card and map test starts from a fresh save and stops what it started, so no idle tick timer leaks into the next test. Never instance `main_game.tscn`: its `SaveTimer` writes the real save |
| Pointer tests over a map or a board | `_hosted_map()` in `test_zone_travel.gd` puts the map in a `CanvasLayer` above GUT's output window (layer 128); `test_vitals_plate.gd`, `test_expedition_page.gd`, `test_technique_dock.gd` and `test_adventure_view_frame.gd` host their boards the same way | In the full run GUT's window covers the screen and would take the pointer the hover tests move. A test that moves the real pointer puts it back at window point (0, 0) in `after_each()`, or the zone map's hover tests fail later in the run |
| An adventure map without the generator | `tests/integration/adventure_map_fixture.gd` (no `test_` prefix, so GUT does not run it), preloaded as `AdventureMapFixture`: a six-tile map with a fight, a rest site and a boss, and `AdventureTilemap.start_adventure_on_map(action, encounters)` | Used by the tilemap, render, marker and view tests. Every run in `test_adventure_view_frame.gd` starts through `_start_run()`, which hands the tilemap a `FixedMapGenerator` (see Fakes) that returns `_map` (the fixture, or the map a test sets) before the run starts, so no random map is generated and nothing can fail its critical-path check. `start_adventure_on_map()` does not clear the visited and revealed sets, so a test that plays a second map on a tilemap that already ran stops it first, as a run's end does |
| Stepped motion | Shakes and animated glyphs run in `_process` from an elapsed counter through `MapGlyph.shake_offset_at()` (or a static function of elapsed time); a test drives them with GUT's `simulate()` or calls the static | A tween sampled against the wall clock is flaky: it lags a timer by up to a frame, and a keyframe edge can sit 12 ms away |
| Real physics picking | `_press_at()` in `test_cycling_technique.gd`: `await wait_physics_frames(2)`, `push_input(event, true)` (local coordinates), then `await wait_physics_frames(2)` | The headless root window is 64 px square, so a `push_input` without the local flag is scaled and misses. An `Area2D`'s broadphase entry updates at the physics step, so an event pushed in the first physics iteration after the area was created or moved can miss |
| Parsed input actions | A test that parses an `InputEventAction` releases it in `after_each()` (`Input.action_release(&"ui_cancel")`) | Otherwise `Input.is_action_pressed()` stays true for every later test |
| Queued frees before the orphan count | `await _await_queued_frees()` (one `wait_process_frames(1)`) at the end of a test whose code takes nodes out of the tree and queue-frees them: a technique switch, a technique list rebuild, a hidden cycling board (`test_cycling_technique.gd`, `test_cycling_view.gd`, `test_zone_panel.gd`) | GUT counts a test's orphans before the frame that frees them ends, so without the wait the run prints a per-test orphan list |
| Scenes with hex map layers | After `add_child_autofree()`, call `tile_set.emit_changed()` on one of the scene's layers (`test_adventure_end_flow.gd`, `test_adventure_view_frame.gd`, `test_adventure_map_render.gd`, `test_zone_map_render.gd`) | The project's hex layer script skips the addon's `_ready()`. A layer built after the shared tileset's first `changed` therefore has no cube↔map conversion, and `cube_to_map()` errors. See [ADVENTURING.md](../adventuring/ADVENTURING.md) Tech Debt. |
| Signals | `watch_signals(obj)` with `assert_signal_emitted`, `assert_signal_emitted_with_parameters`, `assert_signal_emit_count`, `assert_signal_not_emitted` | 41 files |
| Expected errors | `assert_push_error("unknown technique_id")` | GUT 9.7 fails a test on unexpected engine errors and `push_error` by default, so negative-path tests must consume their `push_error` (7 files, 14 uses) |
| Fakes | Inner classes extending `EffectData`, such as `CountingEffect` (in 2 files); `FakeGreyBackground` extends `GreyBackground` and shows and hides at once (`test_merchant_view_state.gd`); `FakeCoveringState` stands in for a second overlay that hides the HUD boards (`test_view_state_hud_positions.gd`); `FixedMapGenerator` extends `AdventureMapGenerator` and returns the map it was given (`test_adventure_view_frame.gd`, installed by `_start_run()`) | Don't start inner class names with `Test` |
| Temporary files | `user://test_*.tres` / `user://__test_*.tres`, removed with `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` | `test_quest_progression_persistence.gd`, `test_zone_progression_data.gd`, `test_dev_password_modal.gd` |
| Content lock | Loads shipped `.tres` and asserts on field values | `test_crude_scale_tres.gd`, `test_path_tree_resource_loading.gd` |

The suite never uses GUT doubles, stubs or partial doubles (`double()`, `stub()`, `partial_double()`).

### Avoid mirror tests

A mirror test re-implements the production logic inside the test and asserts against that copy. The method itself is never called, so the test passes whatever production does. None are left: every suite calls the code it tests.

New tests should call the real method on the autoload, with its state swapped as above. Keep the original reference and put it back in `after_each()`; never set an autoload's state to `null`.

## Coverage Map

| Area | Test files (test count) | Exercised | Not covered |
|------|-------------------------|-----------|-------------|
| PersistenceManager / SaveGameData | `test_quest_progression_persistence` (3), `test_zone_progression_data` (8), `test_save_migration` (7), `test_seen_actions` (9), `test_persistence_manager` (9) | `ResourceSaver`/`ResourceLoader` round-trips of quest and zone progression (`last_idle_action_id` included); `migrate()` (Test Zone → Spirit Valley); an old save loading the new fields' defaults; the seen-action record, `mark_action_unseen()` and a technique unlock lighting the cycling card (the seen-technique fields are under Cycling); `boot()`/`load_data()`/`save_data()` on a fresh PersistenceManager pointed at temporary files (an unreadable save kept, copied aside and never written; an invalid save copied aside before its reset; an unverifiable save not reset; the loaded save migrated) | `reset()` field by field, `reset_save_data` |
| ResourceManager | `test_resource_manager` (39), `test_adventure_flow` (10), `test_quiet_madra` (16) | Madra add/spend/set with stage-cap clamping, gold, `award_resource()`, signals and log lines, the quiet-award and capped-add log rules, the amount `add_madra()` returns, adventure capacity/budget/threshold and `can_start_adventure()`, capacity with an equipment Foundation bonus; `set_madra()` via `test_quest_manager` and the Madra trickle via `test_training_flow` | The known bugs in [RESOURCES.md](../infrastructure/RESOURCES.md#bugs): the 0 cap when the stage has no resource, `set_madra()` ignoring the cap |
| CultivationManager | `test_cultivation_manager` (28), `test_cultivation_getters` (4) | The real `add_core_density_xp()` loop (carry-over, multi-level gains), its signals, path-point milestones per stage, stage names, `AdvancementStageResource.get_xp_for_level()`; `get_max_madra()`; `BREAKTHROUGH_LEVEL` pinned to 100 | The infinite loop when the stage has no resource, and the missing `SILVER` entry in `PATH_POINTS_PER_STAGE` ([CULTIVATION.md](../cultivation/CULTIVATION.md)) |
| CharacterManager | `test_character_manager` (28), `test_character_attributes_data` (3), `test_award_attribute_effect_data` (3), `test_change_vitals_effect_data` (6), `test_character_book` (15) | Attribute data; the real `get_total_attributes_data()` with gear, both accessory slots, stacking and negative bonuses; equip/unequip; `add_base_attribute()` and its signal; the Character book | The `PlayerManager` / `VitalsManager` refresh on `base_attribute_changed` |
| InventoryManager / InventoryData | `test_inventory_manager` (34), `_consumables` (14), `_consumable_hotbar` (7), `_pages` (3), `_restore` (4), `test_inventory_data_pagination` (4) | Equip (including the swap with an occupied slot and the accessory slots), unequip, unequip to a grid slot, accessory swap, `move_equipment()`, awards of equipment, materials and quest items, `has_item`, consumables, hotbar, pages, restore | |
| Inventory UI | `test_equipment_grid_pagination` (4), `test_equipment_drag_paging` (2), `test_equipment_filter` (4), `test_pagination_bar` (4), `test_sort_sub_banner` (2), `test_tab_banner_title` (2), `test_trash_slot_flow` (8), `test_item_detail_card` (2), `test_consumables_tab_hotbar_equip` (3), `test_journal_tab_render` (1) | Scene-level behaviour of tabs, grid, pagination, trash, detail card | `InventoryView` book open/close, materials tab |
| Items | `test_equipment` (25), `test_consumable_definition_data` (7), `test_crude_scale_tres` (6), `test_quest_item_definition_data` (2), `test_item_definition_data` (5) | Definitions, tooltips, shipped Crude Scale values, `mini_icon` and its fallback | |
| Items generator | `test_items_md_parser` (21) | `ItemsMdParser` | Writer `scripts/tools/items_md_to_resources.gd` |
| Combat | `test_combat_damage` (29), `test_combat_effect_data` (4), `test_combat_effect_types` (3), `test_combat_buff_manager_stacking` (7), `test_combat_buff_manager_strip` (4), `test_combat_ability_instance_cancel` (6), `test_empty_palm_interrupt` (2), `test_power_font_buff_strip` (2), `test_adventure_combat_victory_event` (2), `test_fight_rules` (10), `test_buff_effect_describe` (4) | Damage formula, scaling parts, effect routing, buffs, cast cancel; the real `AdventureCombat` scene firing the victory event on a win and not on a loss; `VitalsManager.max_health_for()` (Body × 10) and `AdventureCombat.gold_reward_for()` with every factor, and that a real fight pays by it; `BuffEffectData.describe()` | `SimpleEnemyAI`, `VitalsManager` regen, the `CharacterManager.get_gold_multiplier()` factor (a stub returning 1.0, so the tests cannot tell it from missing) |
| Adventure | `test_adventure_map_generator` (9), `test_adventure_data` (9), `test_adventure_encounter` (5), `test_encounter_choice` (7), `test_encounter_quota` (2), `test_encounter_icon_config` (10), `test_hex_forest_atlas` (10), `test_adventure_result_data` (12), `test_adventure_combat_count` (12), `test_adventure_end_flow` (2) | Generator, validation, eligibility, icon config, result defaults, `AdventureTilemap.get_total_combat_count()`; the real `AdventureView` end flow for a timeout and a boss win | The rest of `AdventureView` (death, result building), `AdventureEndCard` |
| Adventure map | `test_adventure_tilemap_events` (21), `test_adventure_map_render` (19), `test_adventure_map_markers` (21), `test_adventure_route` (3), `test_encounter_coin` (17), `test_adventure_kit_assets` (5) | `AdventureTilemap`'s arrivals, refusals (Stamina and a waiting choice, at the click and partway), resolutions and summaries, the map getters, the pick guard, stopping mid-walk (also mid-hop into an unvisited tile: no arrival, boss reveal or hit-stop); the zoom-1 map (camera, fog tiers and reach, veil and forest sources, rims, the route on hover and while walking, the 2x character on even px, the boss reveal's hit-stop and camera push); the coin layer (a coin per seen tile and state, the current tile's rise, following the camera, the dev reveal round trip, shakes, animated glyphs); the route dots; the imported textures (sizes, the 2x grid, the veil atlas) | Pixel placement against the mock (checked by movie captures, not tests) |
| Adventure frame | `test_vitals_plate` (39), `test_adventure_chest` (27), `test_run_clock` (3), `test_expedition_page` (105), `test_technique_dock` (31), `test_technique_slot_math` (8), `test_adventure_view_frame` (21) | The cabinet (figures, orbs, buff sockets and tooltip with its even height, the Stamina shake), the chest (title, clock painted when its timer is bound, hugging its page), the expedition page (Here tray states, drawers, Run ledger, long texts), the dock (slot states, the sweep's 24 steps, the cast tray, refused and accepted presses, keys only in a fight, the tooltip), and the real `AdventureView`'s wiring (the map's news reaching the boards, presses that stop at the boards, the map's hover going when the pointer leaves it and laid again when a walk ends (a Stamina stop included, and nothing while a choice waits), the fight's binding, the run's figures, a second run after a messy end) | Hovering a technique slot or a buff socket inside the real `AdventureView` (their pointer tests host the boards on a canvas layer); pixel placement (captures) |
| AbilityManager | `test_ability_manager` (18), `test_path_manager`, `test_abilities_book` (26) | Unlock/equip/loadout; the Abilities book's filter, rows, quick equip and details | Dragging abilities onto loadout slots |
| Cycling | `test_cycling_manager` (39), `test_cycling_rules` (7), `test_cycling_groove` (15), `test_cycling_technique_data` (4), `test_cycling_art` (17), `test_cycling_rate` (3), `test_cycling_technique` (85), `test_cycling_view` (71), `test_technique_drawer` (25), `test_path_manager` | Unlock, equip and catalog; the seen techniques and their first-init pass; the session snapshot and `madra_rate_changed`; the last cycle's result and its reset; the tiers, XP, pellet counts and result lines; the groove raster, its trail and its sweep; the icons and the seen-technique save fields; the art's sizes and palettes, the breathing sizes and the unbroken rings; `ActionManager`'s cycling rate; the ball's play (Madra steps at 30, 60 and 144 FPS, every step of a tracked 8 s cycle at 60, 120 and 144 FPS and at uneven frames, the Madra a cycle counts, the rate window, the breath, zones, scoring by a press on the ball, the cursor's reach out to the tracking ring's edge for tracking, presses and the hand cursor, Auto, a frame hitch and one through the cycle's end, the session owned by the technique that started it, the path scale, real physics picking); the board (status line, the result handed to `CyclingManager` and one log line, no result line of its own, the figure's size and place, pellets, floaters, Auto, show, hide (the pellets in flight freed) and close, presses through the board, its text wrapping with the figure and footer pushed down and the board grown, still on screen); the technique drawers (NEW cleared when the pointer leaves or on a press, long names and detail lines wrapping while the drawer grows) | Content integrity (unique technique ids, path-node unlock ids matching the catalog); pixel placement (checked by captures, not tests) |
| PathManager | `test_path_manager` (25), `test_award_path_point_effect_data` (4), `test_path_tree_resource_loading` (3), `test_path_book` (18) | Purchases, prerequisites, effects, shipped Pure Madra tree; the Path book's stage chapters, node and path details, benefits and points badge | Buying a node from the book |
| QuestManager | `test_quest_manager` (25), `test_start_quest_effect_data` (2), `test_quest_progression_persistence` (3), `test_beat_3b_merchant_unlock` (1), `test_goals_panel` (26) | Start/advance/complete, validation, persistence; the Goals board's quest row and figures | `QuestToast` |
| UnlockManager / conditions | `test_unlock_manager` (3), `test_unlock_condition_item_owned` (2), `test_aura_well_discovery_unlock` (2), `test_beat_3b_merchant_unlock` (1), `test_unlock_condition_progress` (6) | `force_unlock_condition()`; `EVENT_TRIGGERED`, `ITEM_OWNED`, `RESOURCE_AMOUNT` conditions; `CULTIVATION_LEVEL` indirectly through the Beat 3b flow (`q_reach_cd_10`); `is_measurable()` and the current / target getters | `CULTIVATION_STAGE`, `ZONE_UNLOCKED`, `ADVENTURE_COMPLETED`, `ATTRIBUTE_VALUE` have no direct tests |
| ZoneManager / training | `test_zone_progression_data` (8), `test_zone_map_state` (18), `test_seen_actions` (9), `test_training_action_data` (18), `test_training_action_helpers` (7), `test_training_flow` (1), `test_aura_well_discovery_unlock` (2), `test_zone_action_groups` (7) | Training ticks/levels and helpers, action availability, map zones and the four map states, the dev zone toggles, per-zone last idle action, seen actions, groups and mode tags | `max_completions` filtering in `get_available_actions()` |
| ActionManager | `test_idle_action_resolution` (35), `test_training_flow` (1), `test_adventure_end_flow` (2), `test_merchant_shop_flow` (35) | Idle-action resolution and resumes after cycling, adventures (win and loss), dialogue and the merchant; travel and its log lines; save resets; the auto-start on a first idle unlock; completions counted in the zone and save an action started in; the adventure Madra check before anything stops; `TRAIN_STATS`; `MERCHANT` start/stop | `FORAGE` loot awarding; the Dialogic timeline itself (the tests emit `dialogue_ended`) |
| Zone view panels | `test_cultivator_plate` (29), `test_goals_panel` (26), `test_zone_panel` (83), `test_zone_action_cards` (49), `test_lacquer_pieces` (33) | The cabinet's values, the fills it hands the orb shaders, its core and bead strip frames and its gold row, the Goals board and its cords, the zone chest (Now strip with its empty tray and the cycle tray, groups, scrolling, rail, lore, sizing, the techniques mode, the last cycle's line under the Now tray and a long one wrapping, the chest growing with a drawer), every card presenter and state, the lacquer theme's variants and line pitch, the strip rect, rod, frame overlay and text helpers | Pixel placement against the mock (checked by movie captures, not tests) |
| Zone map | `test_zone_map_math` (15), `test_zone_map_render` (33), `test_map_markers` (46), `test_map_popover_state` (18), `test_zone_travel` (49), `test_zone_walk_steps` (1), `test_character_walk_steps` (6), `test_camera_clamp_controller` (5), `test_madra_pellet` (9), `test_zone_transition` (3) | Framing and the camera clamp at every zoom, fog tiers and coverage, hex states, plates, glyphs, routes, ring and floaters, hover (also after the camera moves under a still pointer), popovers and who hears Esc, travel on arrival and walks cut short, whole-px walk steps, drain pellets; the drain's lookups in `main_game.tscn` and one whole drain into a confirmed adventure | `ZoneTransition`'s per-pellet arithmetic and its camera reset |
| MerchantManager / shop | `test_merchant_manager` (14), `test_merchant_data` (12), `test_spirit_valley_merchant_stock` (8), `test_spirit_valley_merchant_theme` (5), `test_merchant_view_state` (9), `test_merchant_shop_flow` (most of 35) | Purchase rules (sold out, gold, equipment space, item class vs `item_type`), per-merchant ledgers, their save round trip and debug string, the shipped stock and theme entries (including a panel opaque enough to hide the HUD under it, and an atmosphere mask that matches its corners), `MerchantView` rows (including "Equipment full" and broken stock data), buying, Buy without keyboard focus, Leave, the zone theme, the title's `LabelTitle` inheritance, the mock's header and footer padding with a panel that fits its rows, an atmosphere that fills the panel inside its border, Leave beside the title with the gold in the footer, a greeting that wraps at the header's width in smaller text, the gold preview while Buy is hovered, a closed shop skipping refreshes, and `MerchantViewState`'s push and close paths, including hiding and restoring the log and Goals boards | The real `GreyBackground` fade and Escape routing through `MainView` (checked in play) |
| EventManager | None dedicated | `trigger_event()` used inside quest, encounter and content tests | `trigger_event()`/`has_event_triggered()` contract |
| LogManager / log board | `test_log_manager_history` (5), `test_log_board` (33) | The bounded history; the five-line board (order, growth, tones and fading, cream haul lines, BBCode stripping, ellipsis); the full log (L, Escape, `toggle_window()`, trimming, rail caps, closing when hidden, closed and kept shut under a menu book) | |
| DialogueManager, PlayerManager, `Log` | None | | All |
| UI shell | `test_merchant_view_state` (9), `test_view_state_hud_positions` (15), `test_cycling_mode` (12), `test_main_game_layout` (2), `test_dock` (12), `test_book_view_state` (12), `test_grey_background` (5), `test_book_frame` (22), `test_book_style_data` (7), `test_tab_switcher` (5) | `MainView.remove_state()` and `MerchantViewState` on a `MainView` that never enters the tree; where each view state puts the Goals and log boards (the adventure leaves them in place), the shop hiding and restoring them (a `FakeCoveringState` is the second holder), and cycling and the menu books leaving them showing; cycling mode (the chest, dock and map turned over and back, the map taking no clicks, the full log blocked, a second `start_cycling` pushing once, the cabinet handed to the `CyclingView`, the unique names in `main_game.tscn`); the zone furniture's places in `main_game.tscn`, also after an editor save; `GreyBackground`'s fade-out and backdrop click; the menu books' shared close routes; the dock's buttons, notifications and parsed actions; `BookFrame` signals, chrome and palette; the books' side tabs | `MainView` push/pop/change semantics, `GreyBackground`'s fade-in ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)); the call to the cabinet hand-off from `MainView._ready()` (the helper is tested; the call is checked in a headless run of the real scene) |
| Dev tools | `test_dev_password_modal` (5), `test_unlock_manager` (3), `test_dev_panel_zone_toggles` (4) | `DevPasswordModal.check_password()`, `force_unlock_condition()`, the two Zones toggles | Other dev panel actions, Ctrl+Shift+D gate, Map Preview, UID tool ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |
| Loot | None | | `LootTable` rolls (no test references `LootTable`) |

## Key Files

| File | Purpose |
|------|---------|
| `.gutconfig.json` | GUT defaults (directories, prefix, log level) |
| `addons/gut/` | GUT 9.7.1 (read-only third-party code) |
| `addons/gut/gut_cmdln.gd` | CLI entry point |
| `tests/unit/`, `tests/integration/` | Test scripts |
| `tests/label_tests/label_testing_scene.tscn` | Visual Label-variant reference |
| `docs/testing/TEST_SUITE_PROMPT.md` | Historical one-shot prompt that created the suite (2026-04-10, commit `2f6d5bf`) |

## Work Remaining

### Missing Functionality

- `[MEDIUM]` Little coverage of the UI shell's core. `MainView.remove_state()`, `MerchantViewState`, the book states' close paths, `GreyBackground.hide_with_panel()` and the HUD board placement and hiding are tested, but not the `MainView` push/pop/change semantics. `ActionManager`'s forage loot awarding is untested.
- `[LOW]` `SaveGameData.reset()` and the `reset_save_data` flag are untested. The `PersistenceManager` boot path is covered by `test_persistence_manager.gd`.
- `[MEDIUM]` No tests for `AdventureEndCard`, `AdventureView.stop_adventure()`'s result building and death path, `SimpleEnemyAI` or `LootTable`.
- `[LOW]` Dev panel actions and the Ctrl+Shift+D gate are untested; the spec's planned `test_dev_panel_actions.gd` was never written.
- `[LOW]` No CI. The suite only runs locally.

### Tech Debt

- `[MEDIUM]` Test-order leak. `after_each()` in `tests/unit/test_quest_manager.gd` and `tests/unit/test_start_quest_effect_data.gd` sets `EventManager.live_save_data = null` (and nulls `QuestManager` state) instead of restoring the original. That is the likely source of the 18 `event_progression on Nil` errors printed under `tests/unit/test_quiet_madra.gd` and `tests/unit/test_unlock_condition_item_owned.gd`. Fix by saving and restoring the original reference.
- `[MEDIUM]` Tests build `CombatantNode.new()` and add it to the tree before its manager children exist, which prints `Node not found: %VitalsManager ...`. Affects `tests/unit/test_combat_effect_types.gd`, `tests/integration/test_power_font_buff_strip.gd` and `tests/integration/test_empty_palm_interrupt.gd`. Instance the combatant scene, or add the managers before `add_child_autofree()`.
- `[LOW]` Rename `TestRecordingEffect` in `tests/unit/test_quest_manager.gd`, for example to `RecordingEffect`, to clear the GUT inner-class warning.
- `[LOW]` 24 Dialogic orphans per run come from the `Dialogic` autoload. GUT attributes them to `test_ability_manager.gd`.
- `[LOW]` `test_pagination_bar.gd` (3 tests) and `test_trash_slot_flow.gd` (5 tests) still print per-test orphan lists (page buttons, item instances). The pagination bar's come from the same remove-then-queue-free pattern, so a frame's wait at the end of each test, as the cycling and chest tests do, would likely clear them; the trash flow's were not looked into.
- `[LOW]` The book tests call GUT's deprecated `wait_frames()`, which prints 30 deprecation notices per run. GUT suggests `wait_physics_frames()` or `wait_process_frames()`.
- `[LOW]` `CountingEffect` is duplicated in `test_consumable_definition_data.gd` and `test_inventory_manager_consumables.gd`, and there is no shared helper module.
- `[LOW]` `PathManager._test_stage_override` is a test hook in production code.
- `[LOW]` `tests/unit/test_path_manager.gd` swaps in a one-entry `AbilityManager._abilities_by_id` and never gives it back. It now restores `CyclingManager`'s index and save, as `test_cycling_manager.gd` does, and `test_fresh_save_cycling_card_wraps` rebuilds the real technique catalog for itself.
- `[LOW]` `tests/unit/test_dev_password_modal.gd` is indented with spaces, and its `const DevPasswordModal = preload(...)` shadows the global class name.
- `[LOW]` A headless `--import` in a fresh checkout empties `[dialogic] directories/*` in `project.godot` (see [the gotcha](#first-run-in-a-fresh-checkout)).
