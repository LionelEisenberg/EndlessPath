# Testing
Last updated: 2026-10-19

## Overview

EndlessPath uses **GUT 9.7.1** (`addons/gut/`, editor plugin enabled) for unit and integration tests.

| Suite | Directory | Scripts | Tests |
|-------|-----------|---------|-------|
| Unit | `tests/unit/` | 44 | 476 |
| Integration | `tests/integration/` | 18 | 62 |
| **Total** | | **62** | **538** |

Tests run inside the full project, so all 17 autoloads are loaded before the first test. `PersistenceManager._ready()` loads the developer's real `user://save.tres`, and creates it if it is missing. Tests then swap in fresh `SaveGameData` objects in memory. No test calls `PersistenceManager.save_data()` and the autosave `SaveTimer` lives only in `main_game.tscn`, so a test run does not write the save file.

`tests/label_tests/label_testing_scene.tscn` is a visual reference scene, not a GUT test. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene).

## Current Suite Status

Run on 2026-10-19, after the trash-slot and adventure end-flow fixes and the Godot 4.7 upgrade, with the command from `CLAUDE.md`.

| Item | Result |
|------|--------|
| Engine | Godot v4.7.2.stable.official.ed1daf0bf |
| GUT | 9.7.1 |
| Scripts / tests | 62 / 538 |
| Passing / failing / pending or risky | 538 / 0 / 0 |
| Asserts | 1966 on this run. The count varies between runs because `test_adventure_map_generator.gd` asserts once per element of a randomly generated map. |
| Orphans | 24 |
| GUT warnings | 1 |
| Exit code | 0 |
| Wall time | About 6 to 7 s |

Known noise in a green run:

- **GUT warning:** `Ignoring Inner Class TestRecordingEffect because it does not extend GutTest`. `tests/unit/test_quest_manager.gd` declares the helper `class TestRecordingEffect extends EffectData`. GUT treats inner classes whose names start with `Test` (its default inner-class prefix) as test classes. The warning is harmless.
- **Orphans:** all 24 are Dialogic subsystem nodes (`subsystem_*.gd`, Timers, one `AudioStreamPlayer`) created as a side effect of the `Dialogic` autoload. GUT reports them as "Outside Tests" under `res://tests/unit/test_ability_manager.gd`, the first script it runs.
- **Errors printed by passing tests:**
  - `tests/unit/test_unlock_condition_item_owned.gd` prints 10 copies of `SCRIPT ERROR: Invalid access to property or key 'event_progression' on a base object of type 'Nil'` at `event_manager.gd:35` (`has_event_triggered`). The chain is `unlock_condition_data.gd:47 evaluate()` ← `unlock_manager.gd:96 _evaluate_all_conditions()` ← `cultivation_manager.gd:62 _update_resources()` ← the test's `before_each()` (line 9), which emits `PersistenceManager.save_data_reset`.
    - Likely cause, from reading the code: `tests/unit/test_quest_manager.gd` and `tests/unit/test_start_quest_effect_data.gd` set `EventManager.live_save_data = null` in `after_each()`, and both run earlier in alphabetical order. On `save_data_reset`, `CultivationManager`'s handler (autoload 2) runs before `EventManager`'s re-bind lambda (autoload 3). It emits `core_density_level_updated` and `advancement_stage_changed`, and each one evaluates the 5 `EVENT_TRIGGERED` conditions against the null save, giving 2 × 5 = 10 errors.
  - `tests/unit/test_combat_effect_types.gd` and `tests/integration/test_power_font_buff_strip.gd` print `Node not found: %VitalsManager / %CombatEffectManager / %CombatBuffManager / %CombatAbilityManager`. They build `CombatantNode.new()` from the script and `add_child_autofree()` it before attaching manager children, so the `@onready %` lookups fail. `tests/integration/test_empty_palm_interrupt.gd` uses the same construction.
  - Expected negative-path logs:
    - `CyclingManager`, `QuestManager` and `PathManager` "unknown id 'nonexistent'"
    - `StartQuestEffectData` "empty quest_id"
    - `QuestManager` validation errors for `bad_quest` / `bad_quest2`
    - `AdventureMapGenerator` "critical-path check failed, regenerating (attempt 1..5)" and "filler quota combat exceeds available NoOp tiles (placed 5 of 500)", from the generator stress tests

## Running Tests

### First run in a fresh checkout

GUT's `class_name`s (`GutTest` and others) are only registered after the project has been imported once. Without a `.godot/` cache, import first:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import
git diff project.godot            # should print nothing
```

> **Fixed 2026-10-19:** In a fresh checkout this import used to rewrite the `[dialogic]` section of `project.godot`, emptying `directories/dch_directory` and `directories/dtl_directory` and dropping the registered characters and timeline. Dialogic's editor panel pruned every entry whose `.dch`/`.dtl` loader wasn't registered yet. A local patch in `addons/dialogic/Core/DialogicResourceUtil.gd` now prunes only files that are really missing (see the addon exceptions in `CLAUDE.md`). If `git diff project.godot` ever shows those keys emptied again, the patch was probably lost in a Dialogic upgrade. Running the test command by itself does not modify `project.godot`.

### Command line

From the project root:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

- Use the `_console.exe` build so output reaches the terminal.
- `-gdir` repeats what `.gutconfig.json` already sets. GUT loads `res://.gutconfig.json` by default; `-gconfig=` disables that.
- Exit code is `0` when every test passes and `1` when any fails. In headless mode GUT quits on its own, but keep `-gexit` for clarity.

Useful GUT 9.7 flags (from `addons/gut/cli/gut_cli.gd`):

| Flag | Example | Effect |
|------|---------|--------|
| `-gtest` | `-gtest=res://tests/unit/test_path_manager.gd` | Run specific script(s) |
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
├── unit/                         44 scripts: one system, resource or manager per file
├── integration/                  17 scripts: content flows and scene-level UI behaviour
├── label_tests/
│   ├── label_testing_scene.tscn  visual Label-variant reference (run with F6)
│   └── label_testing_scene.gd
└── label_testing_scene.gd.uid    orphan .uid left over from before the scene moved
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
| Fresh save per test | `_save_data = SaveGameData.new()` in `before_each()` | `SaveGameData.new()` appears in 25 files |
| Swap one manager's save, restore it after | `test_award_attribute_effect_data.gd`, `test_zone_progression_data.gd`, `test_training_flow.gd` | Keep the original in a field and put it back in `after_each()`. This is the safe pattern. |
| Swap the global save and re-bind all managers | `PersistenceManager.save_game_data = SaveGameData.new()` then `PersistenceManager.save_data_reset.emit()` (`test_unlock_condition_item_owned.gd`; `test_change_vitals_effect_data.gd` also restores) | Handlers run in autoload order, so `CultivationManager` re-evaluates unlocks before `EventManager` re-binds |
| Inject manager state directly | `CyclingManager._live_save_data`, `CyclingManager._techniques_by_id`, `QuestManager._quests_by_id`, `PathManager._all_trees`, `EventManager.live_save_data` | Some files null these in `after_each()` instead of restoring them, which leaks into later files. Nulling `EventManager.live_save_data` is behind the `event_progression on Nil` errors described above. |
| Test-only hook in production code | `PathManager._test_stage_override` | The only one. `PathManager._is_stage_reached()` checks it first. |
| Mutate the loaded save in place | `PersistenceManager.save_game_data.inventory = InventoryData.new()` (inventory integration tests) | Changes only in-memory state, but the rest of the developer's save stays loaded |
| Instance a scene | `const X := preload("res://...tscn")`, `X.instantiate()`, `add_child_autofree(node)`, then `await get_tree().process_frame` before reading `@onready` nodes | 40 `await get_tree().process_frame` calls across 11 files |
| Scenes with hex map layers | After `add_child_autofree()`, call `tile_set.emit_changed()` on one of the scene's layers (`test_adventure_end_flow.gd`) | The project's hex layer script skips the addon's `_ready()`. A layer built after the shared tileset's first `changed` therefore has no cube↔map conversion, and `cube_to_map()` errors. See [ADVENTURING.md](../adventuring/ADVENTURING.md) Tech Debt. |
| Signals | `watch_signals(obj)` with `assert_signal_emitted`, `assert_signal_emitted_with_parameters`, `assert_signal_emit_count`, `assert_signal_not_emitted` | 14 files |
| Expected errors | `assert_push_error("unknown technique_id")` | GUT 9.7 fails a test on unexpected engine errors and `push_error` by default, so negative-path tests must consume their `push_error` (7 files, 14 uses) |
| Fakes | Inner classes extending `EffectData`, such as `CountingEffect` (in 2 files) | Don't start inner class names with `Test` |
| Temporary files | `user://test_*.tres` / `user://__test_*.tres`, removed with `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` | `test_quest_progression_persistence.gd`, `test_zone_progression_data.gd`, `test_dev_password_modal.gd` |
| Content lock | Loads shipped `.tres` and asserts on field values | `test_crude_scale_tres.gd`, `test_path_tree_resource_loading.gd` |

The suite never uses GUT doubles, stubs or partial doubles (`double()`, `stub()`, `partial_double()`).

### Avoid mirror tests

Several older files re-implement the production logic inside the test and assert against that copy, so the singleton method itself is never called:

| File | Mirrored logic |
|------|----------------|
| `tests/unit/test_resource_manager.gd` (37 tests) | Madra/gold arithmetic inline on `SaveGameData`. `_create_manager()` is defined but never called. Real calls are only to `AdvancementStageResource.get_max_madra()`. |
| `tests/unit/test_cultivation_manager.gd` (25) | `_simulate_add_xp()` re-implements `CultivationManager.add_core_density_xp()` |
| `tests/unit/test_character_manager.gd` (23) | `_calculate_equipment_bonus()` re-implements `_get_equipment_bonuses()` and ignores `equipped_accessories`. The `CharacterAttributesData` getter tests are real. |
| `tests/integration/test_adventure_flow.gd` (17) | Uses capacity `50 + Foundation * 10`. The real `ResourceManager.get_adventure_madra_capacity()` returns `CharacterAttributesData.get_max_madra()` = `foundation * 10`. |
| `tests/unit/test_adventure_combat_count.gd` (12) | `_count_combats()` re-implements `AdventureTilemap.get_total_combat_count()` |
| `tests/unit/test_inventory_manager.gd` | The `test_swap_accessory_slots_*` tests simulate `swap_accessory_slots()`. `test_inventory_max_50_slots` uses a 50-slot helper, while `InventoryData` pages by `SLOTS_PER_PAGE`. |

New tests should call the real method on the autoload, with its state swapped as above.

## Coverage Map

| Area | Test files (test count) | Exercised | Not covered |
|------|-------------------------|-----------|-------------|
| PersistenceManager / SaveGameData | `test_quest_progression_persistence` (3), `test_zone_progression_data` (7) | `ResourceSaver`/`ResourceLoader` round-trips of quest and zone progression | `load_data()`, `save_data()`, `verify()`, `reset()`, `reset_save_data` |
| ResourceManager | `test_resource_manager` (37, mirror), `test_adventure_flow` (17, mirror) | Indirect only: `set_madra()` via `test_quest_manager`, Madra trickle via `test_training_flow` | `add_madra`/`spend_madra` clamping, adventure capacity/budget/threshold, signals |
| CultivationManager | `test_cultivation_manager` (25, mirror) | `AdvancementStageResource.get_xp_for_level()` | The `add_core_density_xp()` level-up loop and path point awards |
| CharacterManager | `test_character_manager` (23), `test_character_attributes_data` (3), `test_award_attribute_effect_data` (3), `test_change_vitals_effect_data` (6) | Attribute data, `get_total_attributes_data()` through effects | Real `_get_equipment_bonuses()`, including accessories |
| InventoryManager / InventoryData | `test_inventory_manager` (33), `_consumables` (14), `_consumable_hotbar` (7), `_pages` (3), `_restore` (4), `test_inventory_data_pagination` (4) | Equip/unequip/move/award/`has_item`, consumables, hotbar, pages, restore | Accessory swap (mirror) |
| Inventory UI | `test_equipment_grid_pagination` (4), `test_equipment_drag_paging` (2), `test_equipment_filter` (4), `test_pagination_bar` (4), `test_sort_sub_banner` (2), `test_tab_banner_title` (2), `test_trash_slot_flow` (8), `test_item_detail_card` (2), `test_consumables_tab_hotbar_equip` (3), `test_journal_tab_render` (1) | Scene-level behaviour of tabs, grid, pagination, trash, detail card | `InventoryView` book open/close, materials tab |
| Items | `test_equipment` (25), `test_consumable_definition_data` (7), `test_crude_scale_tres` (6), `test_quest_item_definition_data` (2) | Definitions, tooltips, shipped Crude Scale values | |
| Items generator | `test_items_md_parser` (21) | `ItemsMdParser` | Writer `scripts/tools/items_md_to_resources.gd` |
| Combat | `test_combat_damage` (29), `test_combat_effect_types` (3), `test_combat_buff_manager_stacking` (7), `test_combat_buff_manager_strip` (4), `test_combat_ability_instance_cancel` (6), `test_empty_palm_interrupt` (2), `test_power_font_buff_strip` (2), `test_adventure_combat_victory_event` (2) | Damage formula, effect routing, buffs, cast cancel, victory event | `SimpleEnemyAI`, `VitalsManager` regen, gold reward |
| Adventure | `test_adventure_map_generator` (9), `test_adventure_data` (9), `test_adventure_encounter` (5), `test_encounter_choice` (7), `test_encounter_quota` (2), `test_encounter_icon_config` (10), `test_hex_forest_atlas` (4), `test_adventure_result_data` (12), `test_adventure_combat_count` (12, mirror), `test_adventure_end_flow` (2) | Generator, validation, eligibility, icon config, result defaults; the real `AdventureView` end flow for a timeout and a boss win | `AdventureTilemap` (movement, fog, path preview), the rest of `AdventureView` (death, result building), `AdventureEndCard` |
| AbilityManager | `test_ability_manager` (18), `test_path_manager` | Unlock/equip/loadout | `AbilitiesView` UI |
| CyclingManager | `test_cycling_manager` (20), `test_path_manager` | Unlock/equip/catalog | Cycling mini-game (`CyclingTechnique`, `CyclingView`) |
| PathManager | `test_path_manager` (25), `test_award_path_point_effect_data` (4), `test_path_tree_resource_loading` (3) | Purchases, prerequisites, effects, shipped Pure Madra tree | `PathTreeView` UI |
| QuestManager | `test_quest_manager` (25), `test_start_quest_effect_data` (2), `test_quest_progression_persistence` (3), `test_beat_3b_merchant_unlock` (1) | Start/advance/complete, validation, persistence | `QuestWindow`, `QuestToast` |
| UnlockManager / conditions | `test_unlock_manager` (3), `test_unlock_condition_item_owned` (2), `test_aura_well_discovery_unlock` (2), `test_beat_3b_merchant_unlock` (1) | `force_unlock_condition()`; `EVENT_TRIGGERED`, `ITEM_OWNED`, `RESOURCE_AMOUNT` conditions; `CULTIVATION_LEVEL` only indirectly through the Beat 3b flow (`q_reach_cd_10`) | `CULTIVATION_STAGE`, `ZONE_UNLOCKED`, `ADVENTURE_COMPLETED`, `ATTRIBUTE_VALUE` have no direct tests |
| ZoneManager / training | `test_zone_progression_data` (7), `test_training_action_data` (18), `test_training_flow` (1), `test_aura_well_discovery_unlock` (2) | Training ticks/levels, action availability | Zone selection, `ZoneTilemap`, zone action presenters, `ZoneTransition` |
| ActionManager | `test_training_flow` (1), `test_adventure_end_flow` (2) | `TRAIN_STATS`; adventure `confirm_adventure_start()` and `stop_action()` | `FORAGE`, `CYCLING`, `NPC_DIALOGUE` and `MERCHANT` dispatch; the adventure Madra check in `_execute_adventure_action()` |
| EventManager | None dedicated | `trigger_event()` used inside quest, encounter and content tests | `trigger_event()`/`has_event_triggered()` contract |
| DialogueManager, PlayerManager, LogManager, `Log` | None | | All |
| UI shell | None | | `MainView` stack, all 8 view states, `GreyBackground`, `Toolbar`, `SystemMenuButton` ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)) |
| Dev tools | `test_dev_password_modal` (5), `test_unlock_manager` (3) | `DevPasswordModal.check_password()`, `force_unlock_condition()` | Dev panel actions, Ctrl+Shift+D gate, Map Preview, UID tool ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |
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

### Bugs

- `[MEDIUM]` `tests/integration/test_adventure_flow.gd` asserts against a stale capacity formula, `50 + Foundation * 10`. The real one is `foundation * 10` via `CharacterAttributesData.get_max_madra()`. The test passes only because it never calls `ResourceManager`.

### Missing Functionality

- `[HIGH]` The core singletons have no real-method tests. `ResourceManager`, `CultivationManager` and `CharacterManager._get_equipment_bonuses()` are covered by mirror tests that never call the singleton (see [Avoid mirror tests](#avoid-mirror-tests)). `CLAUDE.md` lists all three as must-test systems.
- `[MEDIUM]` No tests for the UI shell (`MainView` stack semantics, view states, `GreyBackground`) or for `ActionManager` dispatch beyond `TRAIN_STATS`.
- `[MEDIUM]` No tests for `PersistenceManager` load/save/verify/reset or for `SaveGameData.verify()`/`reset()`.
- `[MEDIUM]` No tests for adventure runtime (`AdventureTilemap`, `AdventureView.stop_adventure()` result building, `AdventureEndCard`), `SimpleEnemyAI` or `LootTable`.
- `[LOW]` Dev panel actions and the Ctrl+Shift+D gate are untested; the spec's planned `test_dev_panel_actions.gd` was never written.
- `[LOW]` No CI. The suite only runs locally.

### Tech Debt

- `[MEDIUM]` Test-order leak. `after_each()` in `tests/unit/test_quest_manager.gd` and `tests/unit/test_start_quest_effect_data.gd` sets `EventManager.live_save_data = null` (and nulls `QuestManager` state) instead of restoring the original. That is the likely source of the 10 `event_progression on Nil` errors printed by `tests/unit/test_unlock_condition_item_owned.gd`. Fix by saving and restoring the original reference.
- `[MEDIUM]` Tests build `CombatantNode.new()` and add it to the tree before its manager children exist, which prints `Node not found: %VitalsManager ...`. Affects `tests/unit/test_combat_effect_types.gd`, `tests/integration/test_power_font_buff_strip.gd` and `tests/integration/test_empty_palm_interrupt.gd`. Instance the combatant scene, or add the managers before `add_child_autofree()`.
- `[LOW]` Rename `TestRecordingEffect` in `tests/unit/test_quest_manager.gd`, for example to `RecordingEffect`, to clear the GUT inner-class warning.
- `[LOW]` 24 Dialogic orphans per run come from the `Dialogic` autoload. GUT attributes them to `test_ability_manager.gd`.
- `[LOW]` Remove the mirror helpers: `_create_manager()` (unused) in `test_resource_manager.gd`, `_simulate_add_xp()`, `_calculate_equipment_bonus()`, `_count_combats()`, `_add_to_first_slot()` (hard-codes 50 slots).
- `[LOW]` `CountingEffect` is duplicated in `test_consumable_definition_data.gd` and `test_inventory_manager_consumables.gd`, and there is no shared helper module.
- `[LOW]` `PathManager._test_stage_override` is a test hook in production code.
- `[LOW]` Orphan `tests/label_testing_scene.gd.uid` sits at the `tests/` root.
- `[LOW]` `tests/unit/test_dev_password_modal.gd` is indented with spaces, and its `const DevPasswordModal = preload(...)` shadows the global class name.
- `[LOW]` A headless `--import` in a fresh checkout empties `[dialogic] directories/*` in `project.godot` (see [the gotcha](#first-run-in-a-fresh-checkout)).
