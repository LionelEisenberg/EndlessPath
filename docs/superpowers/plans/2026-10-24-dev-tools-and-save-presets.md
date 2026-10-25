# Dev Tools, Save Presets and Save Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each task names the `godot-prompter:*` skills to invoke before writing its code (CLAUDE.md, GodotPrompter).

**Goal:** Reach any built story moment (Tribulation ready, Merchant open, Copper, …) with one click or one launch option, restart it with Ctrl+Shift+R, and never touch the user's real save while doing it. On the way, saves become versioned, safely written, backed up and locked to one writer, and the dev panel becomes a tabbed tool over all of it.

**Architecture:**
- **Save layer.** `PersistenceManager` plays one session per run: the user's save, an in-memory preset, or a `--save` file. Static helpers keep it focused: `LaunchOptions` (user args and the pin), `SaveFiles` (temp-file writes, backups), `SaveLock` (one writer per save). `SaveGameData` gains a version, migrations, `repair()` and `PlayStatsData`.
- **Preset layer.** `DevManager`, a new last autoload, builds presets and switches sessions. `DevCommands`, a static class beside it, is the one command API: each command calls a manager's public function. A preset is a `SavePresetData`: a point on the `StoryRouteData` plus `DevStepData` steps, or an embedded snapshot.
- **Panel layer.** `DevPanel` becomes a full-screen, mouse-ignoring root holding the panel body (a `TabContainer` of six tab sub-scenes) and a time-speed badge.
- **Rejected** (spec, Decisions): copied saves as the main preset form, a generic quest solver, a class per step kind, swapping the save under live views, restarting the process, JSON saves.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** [docs/superpowers/specs/2026-10-24-dev-tools-and-save-presets-design.md](../specs/2026-10-24-dev-tools-and-save-presets-design.md). Read it first: its Decisions, Save system, Presets, DevManager and Dev panel sections are the requirements, and this plan is how to build them.

## Global Constraints

- **Engine:** Godot 4.7.2 and GDScript only. Never modify `addons/`.
- **CLAUDE.md coding standards:**
  - every function has a return type;
  - public functions have no `_` and carry a `##` comment; private ones start with `_`;
  - class variables are typed;
  - node references use `%UniqueName`;
  - code is grouped under `#----` section headers;
  - no `print()`: use `Log` for diagnostics and `LogManager.log_message()` for lines the player reads.
- **UI lives in `.tscn` files.** Scripts set text, visibility and data. A dynamic list instances a row `.tscn` from code, the existing pattern (`quest_items_tab.gd:43`). No `Node.new()` UI, and no `add_theme_*_override()` in scripts.
- **No text is cut off.** No scene or script under `scenes/` may save `clip_text = true` or a non-zero `text_overrun_behavior`; `test_boards_never_trim_text.gd` scans them all. A Label that can run long has `autowrap_mode = 3` and a `custom_minimum_size.x`. Don't use `ItemList` or `Tree`: both trim by default, and a `TreeItem`'s wrapping can only be set from code.
- **The dev panel** is exempt from the lacquer look (STYLE_GUIDE.md, G11). It inherits `pixel_theme.tres` from `MainView`. Use its Label variants (`LabelSubheading`, `LabelBody`, `LabelBodySmall`) and no inline font sizes.
- **Saved enum numbers:** `DevStepData.Kind` values are stored as ints in `.tres` files. Append only; never insert.
- **Values from the spec:**
  - user save `user://save.tres`; backups in `user://backups/`, the newest 10 kept;
  - launch options `--preset=<id>`, `--save=<path>`, `--no-autosave`;
  - time speeds ×1, ×2, ×5, ×10;
  - Ctrl+Shift+D toggles the panel, Ctrl+Shift+R restarts the preset;
  - the route and the starting presets exactly as in Tasks 11 and 14; `merchant_open` has 700 gold; `empty_palm` goes in slot 3.
- **Values this plan sets:** `SaveGameData.CURRENT_VERSION = 1`; a save lock is stale after 60 s without a heartbeat or when its process is gone; the pin lives in `res://.dev_settings.cfg` (gitignored) in editor runs, `user://dev_settings.cfg` in exports.
- **Dev log line:** `[color=magenta][DEV][/color] <what happened>`, as today.
- **Tests** (docs/testing/TESTING.md):
  - Call the real autoloads, with their state swapped and restored in `after_each()`. No GUT doubles.
  - Managers `push_error` on unknown ids, and GUT fails a test on an unexpected one. Dev code checks ids first; a test that expects an error uses `assert_push_error`.
  - Persistence tests use bare `PersistenceManager` script instances pointed at temp paths (`_make_manager()` in `test_persistence_manager.gd`). Every new disk path (temp file, backups, lock) derives from the instance's `save_path`, `main_save_path` or `backup_dir`, never a hard-coded `user://` path, so no test touches the real folder.
  - Set `GODOT="/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe"`.
  - One file: `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/<dir>/<file>.gd -gexit`. GUT skips a script that doesn't parse with only a warning, so check that the file's tests actually ran.
  - The suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. Rerun a failure in one process (the runner prints the command) before investigating it.
  - A pass is exit code 0 with no failing tests.
- **Import:** after adding a script with a new `class_name`, run `"$GODOT" --headless --import` before the tests. Then run `git diff project.godot`: it must show only this plan's own edits. If the `[dialogic]` directory keys emptied, restore the file (CLAUDE.md).
- **Commits:**
  - Use conventional messages (`feat(save): …`), ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Stage files by name, with their generated `.gd.uid` files. Never stage `.godot/`.
  - Commit at the end of each task, on this feature branch. Never commit to `main`, and never merge.
  - Each stage ends at a PR boundary (Tasks 7, 15 and 23). The user decides whether to open the PRs.

## Review Focus

1. **Restart pressed from the panel's own button.** The switch is deferred, so the scene holding the button is freed only after its handler returns. Task 13, `test_play_preset_switches_on_the_next_frame`.
2. **Restart in the middle of a dialogue.** Dialogic's `timeline_ended` arrives a frame late. It must not stop the next session's action. Task 8, `test_cancel_mid_dialogue_leaves_the_next_action_running`.
3. **Restart during the boss hit-stop.** The freed tilemap never restores `Engine.time_scale`, so the switch does: it comes back to the dev speed, not 0.25. Task 13, `test_teardown_restores_the_time_scale`.
4. **A preset that fails mid-build, started from the user's save.** The session returns to the user's save, which still holds what it held. Task 13, `test_a_failed_build_returns_to_your_save_untouched`.
5. **Give equipment with a full grid.** The command refuses with "Equipment is full" instead of reporting a success the inventory silently dropped. Task 9, `test_award_equipment_with_a_full_grid_fails`.

## Calls this plan makes beyond the spec

The user has not seen these; flag them in the PRs.

1. **Commands live in a static `DevCommands` class** beside `DevManager`, which keeps sessions, building, time speed and panel state. The spec put the commands on `DevManager`.
2. **`DevStepData.apply()` returns "" or the reason**, not a bool, so a failed build names its step and why.
3. **A neutral `GameSpeed` util holds the base time scale.** Gameplay's hit-stop restores it without depending on the dev autoload, and its timer runs on real time: 0.15 s at any speed, as today at ×1.
4. **A built preset marks every available action and unlocked technique as seen**, like a save played to that point, so no NEW seals show.
5. **Migration v1 also moves accessories** from the legacy `equipped_gear` keys 4 and 5 into empty accessory slots.
6. **How the lock tells a live run from a dead one.** `OS.is_process_running()` can't see another process on Windows (verified on 4.7.2), so the lock checks with `tasklist`, or with `kill -0` elsewhere. This is what lets Stop then Play in the editor take the save straight back.
7. **The Trigger event picker and step validation use the events content listens to:** EVENT_TRIGGERED conditions in `unlock_condition_list.tres`, plus quest steps' `completion_event_id`.
8. **Travel is refused while anything but foraging or training runs.** `zone_changed` counts a completion and runs the success effects of whatever was running, an adventure included.
9. **Switches swap in a new save object and never reset in place.** That is what makes ActionManager's stale-save guard stop the running action without counting it.
10. **The panel handles both hotkeys in its own `_input()`.** Ctrl+Shift+D moves there from `MainGame`.
11. **Tabs are sub-scenes with one script each.** The zone-toggle test reaches its checkboxes through `%WorldTab`.
12. **A confirmation is a second click on the same button**, because the theme has no `Window` styles for a `ConfirmationDialog`.
13. **Dev commands pause play-stat recording while they run game code.** That covers Force-win, which now goes through the real death path.
14. **`UnlockManager.force_unlock_condition()` stays**, because 24 test call sites use it as a fixture. Only the panel control goes.
15. **Test runs have no main save.** `PersistenceManager.main_save_path` is empty under GUT, so no dev function can open the real save from a test.
16. **`AWARD_ITEM` targets the item's `res://` path.** `beat_9` has no `reached_when` marker, so the coverage test checks the stage directly.
17. **A snapshot preset's save is copied with `duplicate_deep(DEEP_DUPLICATE_INTERNAL)`**, instead of reloading the preset file with `CACHE_MODE_IGNORE`. The cached preset's embedded save is never mutated, and an unsaved preset works the same way.

## File Structure

| Path | | Responsibility |
|---|---|---|
| `scripts/utils/launch_options.gd` | new | `LaunchOptions`: user args after `--`, the pin, test-run detection |
| `scripts/utils/game_speed.gd` | new | `GameSpeed`: the base time scale |
| `singletons/persistence_manager/save_files.gd` | new | `SaveFiles`: temp-file writes, the temp fallback, copies aside, backups |
| `singletons/persistence_manager/save_lock.gd` | new | `SaveLock`: one writer per save |
| `singletons/persistence_manager/play_stats_data.gd` | new | `PlayStatsData`: playtime, first times, counts |
| `singletons/persistence_manager/persistence_manager.gd`, `save_game_data.gd` | changed | Sessions, boot, versions, migrations, repair |
| `singletons/dev_manager/dev_manager.gd` | new | `DevManager` autoload: sessions, presets, the route, time speed, panel state |
| `singletons/dev_manager/dev_commands.gd` | new | `DevCommands`: static commands over the managers' public APIs |
| `scripts/resource_definitions/dev/` | new | `DevStepData`, `StoryBeatData`, `StoryRouteData`, `SavePresetData` |
| `resources/dev/story_route.tres`, `resources/dev/save_presets/*.tres` | new | The route and the starting presets |
| `scenes/ui/dev_panel/` | changed | `DevPanel` shell, `tabs/*_tab.tscn`, `rows/dev_preset_row.tscn`, `rows/dev_action_row.tscn` |
| Ten managers, `main_game.gd`/`.tscn`, `adventure_view.gd`, `adventure_tilemap.gd`, `project.godot`, `.gitignore` | changed | Hooks, stats recording, the hit-stop, the autoload |

---

## Stage 1: Save safety and control

### Task 1: Launch options and test-run detection

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Create: `scripts/utils/launch_options.gd`
- Test: `tests/unit/test_launch_options.gd`

**Interfaces:**
- **Produces:**
  - `class_name LaunchOptions extends RefCounted`, with `var save_path: String = ""` and `var no_autosave: bool = false`. Task 12 adds the preset fields and the pin.
  - `static func parse(user_args: PackedStringArray) -> LaunchOptions`: reads `--save=<path>` and `--no-autosave`, and ignores anything else.
  - `static func current() -> LaunchOptions`: `parse(OS.get_cmdline_user_args())`, computed once and cached in a `static var`.
  - `static func is_test_run() -> bool`: true when an entry of `OS.get_cmdline_args()`, with `\` replaced by `/`, contains `addons/gut/`. Verified on 4.7.2: CLI runs carry `-s res://addons/gut/gut_cmdln.gd` (or `addons\gut\…` typed on Windows), and the editor panel's run carries `--scene res://addons/gut/gui/run_from_editor.tscn`. User args after `--` are not in that list.

- [ ] **Step 1: Write the failing tests.**
  - `test_no_args_gives_the_defaults`: `parse([])` has `save_path == ""` and `no_autosave == false`.
  - `test_save_option_sets_the_path`: `parse(["--save=user://dev/runs/a.tres"]).save_path == "user://dev/runs/a.tres"`.
  - `test_no_autosave_flag`: `parse(["--no-autosave"]).no_autosave == true`.
  - `test_unknown_args_are_ignored`: `parse(["--foo", "bar", "--save"])` gives the defaults (a `--save` without `=` is ignored).
  - `test_this_suite_is_a_test_run`: `LaunchOptions.is_test_run()` is true.
- [ ] **Step 2: Run the file.** Expected: FAIL (`LaunchOptions` is not declared).
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(save): parse launch options and detect test runs`

### Task 2: Temp-file writes, the temp fallback and backups

**Skills:** `godot-prompter:save-load`, `godot-prompter:godot-testing`

**Files:**
- Create: `singletons/persistence_manager/save_files.gd`
- Test: `tests/unit/test_save_files.gd`

**Interfaces:**
- **Produces:** `class_name SaveFiles extends RefCounted`, static helpers. Every path comes from the caller.
  - `static func temp_path_for(path: String) -> String`: `user://save.tres` gives `user://save.tmp.tres`. The temp keeps `.tres`, because `ResourceSaver.save()` picks its format from the extension and refuses an unknown one.
  - `static func write_atomically(resource: Resource, path: String) -> Error`: creates the parent folder, saves to the temp path, then `DirAccess.rename_absolute()` (globalized paths) over `path`. Returns the first error.
  - `static func load_save(path: String) -> SaveGameData`:
    - When `path` is missing but its temp file exists, it loads the temp, with `Log.warn`. This covers a crash inside Windows' rename, which deletes the target before it moves the temp.
    - It always loads with `ResourceLoader.CACHE_MODE_IGNORE`, never `CACHE_MODE_IGNORE_DEEP`: inventory dictionaries are keyed by the shared item resources.
    - Null when nothing loads as a `SaveGameData`.
  - `static func copy_aside(path: String, reason: String) -> String`: `PersistenceManager._copy_save_aside()` moved here unchanged (`<stem>.<reason>.<unix>.tres`, "" on failure).
  - `static func backup(path: String, backup_dir: String, keep: int) -> String`:
    - Copies `path` to `<backup_dir>/<stem>.<YYYYMMDD-HHMMSS>.tres`, adding `-2`, `-3`, … when a copy from the same second exists.
    - Then deletes that stem's oldest backups beyond `keep`. Other stems' backups are never touched.
    - Returns the copy's path, or "" when `path` doesn't exist or the copy fails.
  - `static func list_backups(path: String, backup_dir: String) -> PackedStringArray`: that stem's backups, newest first.

- [ ] **Step 1: Write the failing tests.** Temp root `user://__test_save_files/`, deleted recursively in `after_each()`.
  - `test_write_leaves_the_file_and_no_temp`.
  - `test_write_replaces_the_old_file`: write gold 1, then gold 2; loading gives 2.
  - `test_write_creates_missing_folders`: a path under `__test_save_files/a/b/`.
  - `test_load_falls_back_to_the_temp_file`: only `x.tmp.tres` exists, with gold 7. `load_save("…/x.tres")` has gold 7.
  - `test_load_ignores_the_cache`: two loads give different instances, and changing one leaves the other.
  - `test_load_of_a_missing_file_is_null`.
  - `test_backup_copies_with_a_timestamp`: the name matches `^save\.\d{8}-\d{6}(-\d+)?\.tres$` and the content is identical.
  - `test_backup_keeps_the_newest_of_its_own_stem`: 12 backups of `save` with `keep` 10, plus 2 of `other`, leave 10 and 2.
  - `test_list_backups_is_newest_first`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(save): write saves through a temp file and keep backups`

### Task 3: Save versions, migrations, repair and one set of defaults

**Skills:** `godot-prompter:save-load`, `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd` (the fields, `_to_string()` at 140-177, `verify()` at 184-185, `migrate()` at 189-193, `reset()` at 196-244)
- Test: `tests/unit/test_save_migration.gd`

**Interfaces:**
- **Produces:**
  - `const CURRENT_VERSION: int = 1`.
  - `@export var save_version: int = 0`, commented `## 0 means written before saves had versions. Never default this to CURRENT_VERSION: a loaded file sets only the keys it holds, so every old file would look current.`
  - `static func new_current() -> SaveGameData`: `new()` with `save_version = CURRENT_VERSION`.
  - `func is_from_newer_build() -> bool`: `save_version > CURRENT_VERSION`.
  - `func migrate() -> void`: does nothing for a newer save. Otherwise it runs `_migrate_to_v1()` when `save_version < 1` (later versions add `_migrate_to_vN()` the same way), then applies today's `ZONE_ID_MIGRATIONS` move on every load, then sets `save_version = CURRENT_VERSION`. The move runs on every load, not as a version step, so a save left on a hidden hex (the dev panel's hidden-zone toggle resets each launch) never stays stranded. This was ruled during execution and amends the spec's "Version 1 holds today's zone-id move".
  - `_migrate_to_v1()`: the legacy accessories. `inventory.equipped_gear` key 4 goes to `inventory.equipped_accessories[0]` and key 5 to `[1]`, each only when that accessory slot is empty. Otherwise the item stays and `Log.warn` names it.
  - `func repair() -> PackedStringArray`: when `_verify_current_selected_zone_id()` fails, sets `current_selected_zone_id = ""` and returns `["current_selected_zone_id"]`. Otherwise returns `[]`. `verify()` is unchanged.
  - `func reset() -> void`: copies every `PROPERTY_USAGE_STORAGE` entry of `get_script().get_script_property_list()` from a fresh `SaveGameData.new()`, so sub-resources are new instances, then sets `save_version = CURRENT_VERSION`. The hand-written field list goes.
  - `_to_string()` gains `SaveVersion`.

- [ ] **Step 1: Write the failing tests.**
  - `test_an_old_file_loads_as_unversioned`: `_load_hand_written_save()` of a save without `save_version` gives 0.
  - `test_migrate_stamps_the_current_version`.
  - `test_new_current_is_stamped`.
  - `test_a_newer_save_is_left_alone`: `save_version = CURRENT_VERSION + 1` and zone `TestZone`. After `migrate()` both are unchanged, and `is_from_newer_build()` is true.
  - `test_v1_moves_legacy_accessories`: `equipped_gear = {4: a, 5: b}` gives `equipped_accessories == {0: a, 1: b}`, and `equipped_gear` holds neither key.
  - `test_v1_keeps_an_occupied_accessory_slot`: accessory 0 holds x and gear 4 holds y; both stay.
  - `test_repair_clears_an_unknown_zone` and `test_repair_keeps_a_known_zone`.
  - `test_reset_matches_a_fresh_save`:
    - Set Madra 99, a milestone, a zone progression entry, an unlocked ability and a merchant ledger, then `reset()`.
    - Madra is 25.0, `core_density_milestones`, `zone_progression_data` and `merchant_ledgers` are `{}`, and `unlocked_ability_ids` is the default.
    - `inventory` is a new instance, and `save_version == CURRENT_VERSION`.
- [ ] **Step 2: Run the file.** Expected: the new tests FAIL; the existing seven still pass.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(save): version saves and repair instead of wiping`

### Task 4: PersistenceManager sessions, boot and test isolation

**Skills:** `godot-prompter:save-load`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/persistence_manager/persistence_manager.gd` (whole file), `scenes/main/main_game/save_timer.gd`
- Test: `tests/unit/test_persistence_manager.gd`, plus any test Step 7 finds

**Interfaces:**
- **Consumes:** Tasks 1-3.
- **Produces** (`PersistenceManager`):
  - Constants `SAVE_PATH := "user://save.tres"`, `BACKUP_DIR := "user://backups"`, `BACKUPS_KEPT := 10`.
  - `var save_path: String = SAVE_PATH`: where the session writes. "" is an in-memory session.
  - `var main_save_path: String = SAVE_PATH`: the user's own save ("Your save").
  - `var backup_dir: String = BACKUP_DIR`.
  - `var autosave_enabled: bool = true`.
  - `_ready()`:
    - Under `LaunchOptions.is_test_run()`: `main_save_path = ""`, `autosave_enabled = false`, then `use_save(SaveGameData.new_current(), "")`.
    - Otherwise `boot()`.
    - The detection lives here, not in `boot()`: the bare instances in `test_persistence_manager.gd` call `boot()` and must keep their own `save_path`.
  - `func boot(options: LaunchOptions = null) -> void`:
    - Null means `LaunchOptions.current()`.
    - `autosave_enabled = not options.no_autosave`. A non-empty `options.save_path` replaces `save_path`.
    - When `save_path == main_save_path`, it first runs `SaveFiles.backup(save_path, backup_dir, BACKUPS_KEPT)`.
    - Then `open_save_file(save_path)`.
  - `func open_save_file(path: String) -> void`: the one way a file becomes the session (at boot, and for Task 13's Back to my save). In order:
    1. `save_path = path`, and the block clears.
    2. Neither the file nor its temp exists: `save_game_data = SaveGameData.new_current()`, written at once.
    3. `SaveFiles.load_save(path)` is null: `SaveFiles.copy_aside(path, "unreadable")`, block with today's message, and run on an in-memory default.
    4. `is_from_newer_build()`: block with "written by a newer build (version N; this build knows M)" and keep the save in memory, unmigrated.
    5. Otherwise `migrate()`.
    6. `_can_verify()` is false: block with today's message.
    7. `repair()` is non-empty: `SaveFiles.copy_aside(path, "invalid")`, then `Log.warn` naming the repaired fields.
    8. Every path ends with `save_data_reset.emit()`. At boot it reaches no one; later it re-binds every manager.
  - `func use_save(save: SaveGameData, path: String) -> void`: swaps in a new save object (never a reset in place, so ActionManager's stale-save guard stops a running action without counting it), sets `save_path = path`, clears the block, emits `save_data_reset`.
  - `func save_data() -> Error`: `ERR_UNAVAILABLE` for an in-memory session, `ERR_LOCKED` while blocked. Otherwise it stamps `save_version = SaveGameData.CURRENT_VERSION`, then `SaveFiles.write_atomically(save_game_data, save_path)`.
  - `func autosave() -> void`: when `autosave_enabled` and `can_write()`, calls `save_data()`; `Log.error` on failure.
  - `func tick() -> void`: the `SaveTimer`'s 5 s tick. It calls `autosave()`; Task 5 adds the lock heartbeat.
  - `func can_write() -> bool`, `func is_in_memory() -> bool`, `func is_save_blocked() -> bool` (kept), `func get_block_reason() -> String`.
  - `func backup_main_save() -> String` and `func list_backups() -> PackedStringArray`, both of `main_save_path`.
  - `_notification(what)`: `NOTIFICATION_WM_CLOSE_REQUEST` calls `autosave()`.
  - Removed: `reset_save_data`, `load_new_save_data()`, `load_data()`, `_copy_save_aside()`.
  - `save_timer.gd`: `timeout.connect(PersistenceManager.tick)`.

- [ ] **Step 0: Record a baseline.** Run the suite before changing anything and keep the list of failing tests.
- [ ] **Step 1: Write the failing tests** in `test_persistence_manager.gd`. Keep the bare-instance pattern: `_make_manager()` also sets `main_save_path` to a different temp name and `backup_dir` to `user://__test_persistence_backups/`, which `after_each()` deletes.
  - Adapt `test_missing_save_is_created` to `boot()`; the saved file's `save_version` is 1. Move the unreadable tests from `load_data()` to `boot()` (their assertions stand). `test_unverifiable_save_is_not_reset` is unchanged.
  - Replace `test_invalid_save_is_copied_aside_before_its_reset` with `test_an_unknown_zone_is_repaired_not_wiped`: gold 42 stays, the zone is "", and there is one `.invalid.` copy holding the original text.
  - `test_a_newer_save_is_never_written`: a file with `save_version = 99` and gold 42 gives a block whose reason contains "newer". `save_data() == ERR_LOCKED`, the file's bytes are unchanged, and gold 42 is in memory.
  - `test_boot_backs_up_the_main_save`: with `main_save_path = save_path`, one backup holds the original bytes.
  - `test_boot_backs_up_nothing_for_another_file`.
  - `test_save_option_opens_that_file`: `options.save_path` set to temp B gives `save_path == B`, and B is created.
  - `test_no_autosave_turns_off_the_tick`: after changing gold, `tick()` leaves the file's gold unchanged.
  - `test_tick_autosaves`.
  - `test_close_request_autosaves`: after changing gold, `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` on the bare instance writes the new gold.
  - `test_in_memory_session_writes_nothing`: after `use_save(s, "")`, `save_data() == ERR_UNAVAILABLE`.
  - `test_use_save_swaps_and_re_binds`: `save_game_data` is `s`, and `save_data_reset` was emitted once.
  - `test_save_data_stamps_the_version`: a save object at version 0, once written, reloads at version 1.
  - `test_this_run_never_touches_the_real_save` (the autoload): `PersistenceManager.is_in_memory()`, `main_save_path == ""` and `not autosave_enabled`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Run the suite.** Each failure that is not in the baseline, once confirmed in one process, is a test that read state it never set up and used to get it from the developer's save.
  - Give that test its own setup with a pattern from TESTING.md "Patterns used in the suite": a fresh `SaveGameData` bound with `save_data_reset`, restored in `after_each()`. Never change production code for it.
  - Likely candidates: `test_boards_never_trim_text.gd` (it puts `goals_panel.tscn` and `now_strip.tscn` in the tree without a save), and the files that swap in a fresh save without restoring it, whose leaks hid such reliance.
- [ ] **Step 6: Run the suite.** Expected: only the baseline failures, if any.
- [ ] **Step 7: Commit.** `feat(save): choose the save per run and keep tests off the real save`

### Task 5: One writer per save

**Skills:** `godot-prompter:save-load`, `godot-prompter:godot-testing`

**Files:**
- Create: `singletons/persistence_manager/save_lock.gd`
- Modify: `singletons/persistence_manager/persistence_manager.gd` (`open_save_file`, `use_save`, `save_data`, `tick`, `_notification`)
- Test: `tests/unit/test_save_lock.gd`, `tests/unit/test_persistence_manager.gd`

**Interfaces:**
- **Produces:**
  - `class_name SaveLock extends RefCounted`:
    - `const STALE_AFTER_SECONDS: int = 60`.
    - `static func lock_path_for(save_path: String) -> String`: `save_path + ".lock"`.
    - `static func acquire(save_path: String) -> bool`: true, writing the lock, when there is no lock, a stale one or our own. False when another live run holds it.
    - `static func refresh(save_path: String) -> void`: rewrites the time when the lock is ours.
    - `static func release(save_path: String) -> void`: deletes the lock when it is ours.
    - `static func holder_pid(save_path: String) -> int`: 0 when there is no lock.
    - `static func is_process_alive(pid: int) -> bool`:
      - Our own pid is alive.
      - `OS.is_process_running()` only knows processes this one started (verified on 4.7.2: false for another live Godot process).
      - So on Windows it runs `tasklist /FI "PID eq <pid>" /NH /FO CSV` through `OS.execute()` and looks for `"<pid>"` in the output. That takes about 100 ms, and only when a save opens.
      - Elsewhere it runs `kill -0 <pid>` and checks for exit code 0.
    - The lock file holds two lines, `pid=<OS.get_process_id()>` and `time=<int(Time.get_unix_time_from_system())>`. A lock is live when its process is alive and its time is within `STALE_AFTER_SECONDS`.
  - `PersistenceManager`:
    - `open_save_file()` acquires the lock first. If it is refused, it blocks with "in use by another run (pid N)" and still loads the save into memory.
    - `use_save()` releases our lock on the old path and acquires one on a new non-empty path; a refusal blocks.
    - `save_data()` refreshes the lock after a write.
    - `tick()` refreshes it on every tick, even with autosave off. This is the heartbeat.
    - The close request releases it after the autosave.
    - An in-memory session holds no lock.

- [ ] **Step 1: Write the failing tests.** In `test_save_lock.gd`, the temp save path is `user://__test_save_lock_<name>.tres`, and `after_each()` deletes the locks.
  - `test_a_free_save_is_acquired`: the lock holds our pid.
  - `test_our_own_lock_is_acquired_again`.
  - `test_a_live_run_keeps_its_lock`:
    - Start a short-lived helper process with `OS.create_process()`: on Windows `cmd` with `["/c", "ping", "-n", "6", "127.0.0.1"]`, elsewhere `sleep` with `["5"]`.
    - Write a lock with its pid and the current time. `acquire()` is false.
    - `OS.kill()` the helper in `after_each()`.
  - `test_a_dead_process_lock_is_taken_over`: pid 999999 gives true.
  - `test_an_old_heartbeat_is_taken_over`: the helper's pid with the time 120 s ago gives true.
  - `test_release_leaves_another_runs_lock`.
  - `test_is_process_alive`: our own pid is alive, 999999 is not.
  - In `test_persistence_manager.gd`:
    - `test_a_save_in_use_by_another_run_runs_in_memory`: a live helper lock gives a block whose reason contains "in use". The file is unchanged, and `save_data() == ERR_LOCKED`.
    - `test_tick_refreshes_the_lock_even_without_autosave`.
    - `test_use_save_releases_the_old_lock`.
    - `test_close_request_releases_the_lock`: call `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` on the bare instance.
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run both files.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(save): let only one run write a save`

### Task 6: Play stats

**Skills:** `godot-prompter:save-load`, `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `singletons/persistence_manager/play_stats_data.gd`
- Modify:
  - `singletons/persistence_manager/save_game_data.gd`
  - `scenes/main/main_game/main_game.gd`
  - `singletons/event_manager/event_manager.gd` (`trigger_event` at 28-31)
  - `singletons/unlock_manager/unlock_manager.gd` (`_unlock_condition` at 94-99)
  - `singletons/cycling_manager/cycling_manager.gd` (`set_last_cycle_result` at 189-191)
  - `singletons/action_manager/action_manager.gd` (`confirm_adventure_start` at 296-298)
  - `scenes/adventure/adventure_view/adventure_view.gd` (`stop_adventure`'s outcome at 145-156)
  - `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` (`handle_combat_result` at 304-327)
  - `singletons/resource_manager/resource_manager.gd` (`add_gold` at 121-126)
- Test: `tests/unit/test_play_stats.gd`, `tests/unit/test_save_round_trip.gd`, `tests/integration/test_play_stats_recording.gd`, `tests/integration/test_adventure_end_flow.gd`

**Interfaces:**
- **Produces:**
  - `class_name PlayStatsData extends Resource`:
    - `@export var play_time: float = 0.0`: seconds of game time while the main scene runs, scaled by the dev time speed.
    - `@export var event_first_times: Dictionary[String, float] = {}` and `@export var condition_first_times: Dictionary[String, float] = {}`.
    - `@export` ints `cycles_finished`, `adventures_started`, `adventures_won`, `adventures_lost`, `adventures_timed_out`, `fights_won`, all 0, and `@export var gold_earned: float = 0.0`.
    - `@export var built_from_preset: String = ""`.
    - `var recording_paused: bool = false`, not saved, commented `## Set by DevCommands while a dev command runs game code, so dev actions never count as play.`
    - `func add_play_time(seconds: float) -> void`.
    - `func record_event(event_id: String) -> void` and `func record_condition(condition_id: String) -> void`: the first time only, at `play_time`. Nothing for "" or while paused.
    - `func first_time_of(id: String) -> float`: the event's time, else the condition's, else -1.0.
    - `func count_cycle_finished()`, `count_adventure_started()`, `count_adventure_won()`, `count_adventure_lost()`, `count_adventure_timed_out()`, `count_fight_won()` (each `-> void`) and `func add_gold_earned(amount: float) -> void`. Each does nothing while paused.
  - `SaveGameData`: `@export var stats: PlayStatsData = PlayStatsData.new()`.
  - Recording sites (each on the live save's `stats`):
    - `MainGame._process(delta)`: `add_play_time(delta)`.
    - `EventManager.trigger_event`: `record_event(event_id)` inside its first-time branch.
    - `UnlockManager._unlock_condition`: `record_condition(condition_id)` after the append.
    - `CyclingManager.set_last_cycle_result(result)`: `count_cycle_finished()` when `result != null`. The null from `clear_last_cycle_result()` is not a cycle.
    - `ActionManager.confirm_adventure_start`: `count_adventure_started()`. This is the real start; `adventure_start_requested` can repeat.
    - `AdventureView.stop_adventure`: a win counts `count_adventure_won()`, health at 0 `count_adventure_lost()`, a stopped timer `count_adventure_timed_out()`. A retreat counts nothing.
    - `AdventureTilemap.handle_combat_result(true, …)`: `count_fight_won()`, once per fight (`_on_enemy_health_changed` can re-emit at 0).
    - `ResourceManager.add_gold(amount)`: `add_gold_earned(amount)` when `amount > 0`. `set_gold` and `spend_gold` count nothing.

- [ ] **Step 1: Write the failing tests.**
  - Unit (`test_play_stats.gd`):
    - `test_record_event_keeps_the_first_time` and `test_record_condition`.
    - `test_nothing_is_recorded_while_paused`: events, conditions and every count.
    - `test_first_time_of_reads_events_then_conditions`.
    - `test_empty_ids_are_ignored`.
  - Integration (`test_play_stats_recording.gd`; a fresh save is bound per test and the original restored):
    - `test_a_new_event_records_its_time`: with `play_time` 12.5, triggering an event records 12.5.
    - `test_a_latched_condition_records_its_time`.
    - `test_add_gold_counts_as_earned_and_set_gold_does_not`.
    - `test_a_finished_cycle_counts_once`.
    - `test_confirming_an_adventure_counts_a_start`.
    - `test_a_new_save_has_empty_stats`.
  - In `test_adventure_end_flow.gd`, extend its two tests. The timeout gives `adventures_timed_out == 1`. The boss win gives `adventures_won == 1` and `fights_won == 1`.
  - `test_save_round_trip.gd`, `test_a_full_save_round_trips`. Nothing checked the whole save before (PERSISTENCE.md, Tech Debt).
    - Set every field to a non-default value: materials, quest items and consumables keyed by real item `.tres` files; an equipment instance in the grid; one in `equipped_gear` and one in `equipped_accessories`; an equipped consumable; stage Copper; a milestone; latched conditions, triggered events, an active quest at step 1 and a completed one; zone progression with training ticks and a last idle action; seen ids; techniques, abilities and path purchases; a merchant ledger; stats with counts and first times.
    - Write it with `SaveFiles.write_atomically()` and read it back with `SaveFiles.load_save()`.
    - A recursive digest of every stored property is equal before and after. The digest replaces an external resource by its `resource_path`, so item keys compare by file.
- [ ] **Step 2: Run the four files.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the four files.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(save): record play stats in the save`

### Task 7: Stage 1 docs and the full suite

**Skills:** none

**Files:**
- Modify: `docs/infrastructure/PERSISTENCE.md`, `docs/testing/TESTING.md`, `docs/tooling/DEV_TOOLS.md`, `CLAUDE.md`

- [ ] **Step 1: PERSISTENCE.md.**
  - Document:
    - sessions and the launch options (`--save`, `--no-autosave`);
    - boot: the backup, the temp fallback, newer saves, migrate, repair, the lock;
    - temp-file writes, backups, save on quit, `tick()`;
    - versioning, with the default trap and v1;
    - play stats: the fields, and which system records each.
  - Remove `reset_save_data` and the wipe.
  - Fix the drift the code map found: the autoload and save-owning manager counts the doc states, the `SaveTimer` line numbers, and the nonexistent `MainGame._dev_unlocked`.
  - Work Remaining: close the items this stage settles. These are the missing versioning, no save on quit, the wipe on an unknown zone, ignored timer errors, tests sharing `user://`, duplicated defaults and the `load_data()` reload. The runtime New game item stays open until Task 20.
- [ ] **Step 2: TESTING.md.** Test runs boot on an in-memory save, never read or write `user://save.tres`, and have no `main_save_path`. Remove the "loads the developer's real save" text and the shared-`user://` tech-debt item.
- [ ] **Step 3: DEV_TOOLS.md.** Other debug switches: the `reset_save_data` row goes, and the table points at PERSISTENCE.md for the launch options.
- [ ] **Step 4: CLAUDE.md.** Common Commands gains, under "Run the game from CLI", a line to run it on its own save file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --save=user://dev/runs/<name>.tres`.
- [ ] **Step 5: Run the suite.** Expected: PASS.
- [ ] **Step 6: Commit.** `docs(save): document save sessions, versions, backups and the lock`

Stage 1 ends here (PR boundary).

---

## Stage 2: Presets

### Task 8: Manager hooks for dev tools

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/ability_manager/ability_manager.gd`, `cycling_manager/cycling_manager.gd`, `quest_manager/quest_manager.gd`, `zone_manager/zone_manager.gd`, `event_manager/event_manager.gd`, `unlock_manager/unlock_manager.gd`, `log_manager/log_manager.gd`, `dialogue_manager/dialogue_manager.gd`, `player_manager/player_manager.gd`, `action_manager/action_manager.gd` (all under `singletons/`)
- Test: `tests/integration/test_dev_hooks.gd`

**Interfaces:**
- **Produces:**
  - `AbilityManager.get_all_abilities() -> Array[AbilityData]` and `has_ability(ability_id: String) -> bool`.
  - `CyclingManager.get_all_techniques() -> Array[CyclingTechniqueData]` and `has_technique(technique_id: String) -> bool`.
  - `QuestManager.get_all_quests() -> Array[QuestData]`, in catalog order.
  - `ZoneManager.are_demo_zones_visible() -> bool` and `are_hidden_zones_visible() -> bool`.
  - `EventManager.get_triggered_events() -> Array[String]` and `UnlockManager.get_unlocked_condition_ids() -> Array[String]`, both copies.
  - `LogManager.clear_history() -> void`: empties `_history` and emits nothing. The log board reads the history in its `_ready()`.
  - `DialogueManager.end_dialogue_now() -> void`: when a timeline runs, `Dialogic.end_timeline(true)` (which skips the ending) and clears `current_timeline_name`.
  - `PlayerManager.reset_vitals() -> void`: frees `vitals_manager` and creates a fresh one as `_ready()` does, so no run's values or regen survive.
  - `ActionManager.complete_without_playing(action_data: ZoneActionData, zone_id: String) -> void`:
    - Counts one completion in `zone_id`, then runs the success effects, in that order, like a played stop. Nothing starts or stops.
    - `_stop_executing_current_action()` uses the same two private helpers, `_count_completion(action, zone_id)` and `_run_completion_effects(action, successful)`, so the rule exists once.
  - `ActionManager.cancel_current_action() -> void`: stops the current action with no completion and no effects, and resumes nothing. In order:
    1. For a dialogue, it disconnects the one-shot `DialogueManager.dialogue_ended → stop_action` and calls `DialogueManager.end_dialogue_now()`. Dialogic's `timeline_ended` arrives a frame late and would otherwise stop the next action.
    2. It sets `_current_action_save = null`, so the stale-save guard skips counting and effects.
    3. It runs `_stop_executing_current_action()`, which emits the `stop_*` signal and resets the timer, then `clear_current_action()`.

- [ ] **Step 1: Write the failing tests.** Bind a fresh save per test. In `after_each()`, run `while ActionManager.get_current_action() != null: ActionManager.stop_action()`, then restore the original save.
  - `test_catalog_accessors_list_the_catalogs`:
    - The technique ids include `foundation_technique`, `smooth_flow` and `torrential_flow`.
    - The ability ids include `basic_strike`, `empty_palm`, `enforce` and `power_font`.
    - The quest ids include `q_fill_core`, `q_first_steps` and `q_reach_core_density_10`.
    - `has_*` is true for those and false for "nope", with no `push_error`.
  - `test_clear_history_empties_the_log`.
  - `test_triggered_events_and_conditions_are_copies`: changing the returned array changes nothing.
  - `test_complete_without_playing_counts_then_runs_effects`: NPC 1 in `SpiritValley` has a completion count of 1, event `celestial_intervener_dialogue_1` fired, `q_fill_core` is active, and nothing is running.
  - `test_cancel_stops_foraging_without_counting`:
    - Trigger `q_fill_core_completed`, `select_action(foraging)`, then cancel.
    - Nothing runs and the completion count is 0.
    - `action_timer.is_stopped()`, and its `timeout` has no connections.
  - `test_cancel_mid_dialogue_leaves_the_next_action_running` (Review Focus 2):
    - Trigger `q_fill_core_completed`, `select_action(NPC 1)`, cancel, then `select_action(foraging)`.
    - After `await wait_process_frames(3)`, foraging still runs.
    - NPC 1's count is 0, and event `celestial_intervener_dialogue_1` has not fired.
  - `test_reset_vitals_gives_a_fresh_vitals_manager`: a new instance, with `current_health == 0.0`.
  - `test_zone_visibility_getters`: set, read back, and reset to false.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file**, then the suite. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the manager hooks dev tools need`

### Task 9: DevCommands

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Create: `singletons/dev_manager/dev_commands.gd`
- Test: `tests/integration/test_dev_commands.gd`

**Interfaces:**
- **Consumes:** Task 8's hooks, and `PlayStatsData.recording_paused` (Task 6).
- **Produces:** `class_name DevCommands extends RefCounted`. Every command is static and returns "" on success, or the reason it refused. Each one:
  - checks ids itself before calling a manager;
  - sets `stats.recording_paused` for its own duration;
  - on success, logs `[color=magenta][DEV][/color] <what it did>` through `LogManager.log_message()`.

  | Command | Rule |
  |---|---|
  | `complete_action(action_id: String) -> String` | Looks in the current zone's `all_actions`. Returns "" with nothing done once it has reached `max_completions`. Refuses one missing from `get_available_actions()` ("<id> is not available now"). Then `ActionManager.complete_without_playing(action, zone_id)` |
  | `trigger_event(event_id: String) -> String` | Refuses an id not in `known_event_ids()`. Returns "" when the event has already fired |
  | `reach_core_density(level: int) -> String` | Targets `mini(level, get_core_density_cap())`. Repeatedly adds `get_xp_for_next_level()`, which always crosses exactly one level. Refuses when a level-up leaves the level unchanged (a stage with no cost). Returns "" at or above the target |
  | `set_madra(value: float) -> String`, `set_gold(value: float) -> String` | Refuse a negative value |
  | `add_path_points(amount: int) -> String` | |
  | `buy_path_node(node_id: String) -> String` | Returns "" once the node has been bought. Refuses a node missing from the current tree, a stage too low, or a missing prerequisite (named). Adds only the missing points (`point_cost − balance`), then `purchase_node()` |
  | `unlock_technique(id: String) -> String`, `equip_technique(id: String) -> String` | Refuse an unknown id. Equip also refuses a locked technique |
  | `unlock_ability(id: String) -> String`, `equip_ability(ability_id: String, slot: int) -> String` | `slot` is 1–4 and maps to index `slot − 1`. Refuses an unknown or locked ability, or any other slot |
  | `award_item(item_path: String, quantity: int) -> String` | Refuses a path that isn't an `ItemDefinitionData`, or a quantity below 1. Equipment needs `quantity` free grid slots, else "Equipment is full": the inventory would drop it and still log "Looted" |
  | `grant_equipment_page() -> String` | |
  | `add_attribute(attribute: CharacterAttributesData.AttributeType, amount: float) -> String` | |
  | `advance_stage() -> String` | Refuses when `has_next_stage()` is false |
  | `travel_to_zone(zone_id: String) -> String` | Refuses an id not in `get_all_zones()`. Refuses while anything but foraging or training runs |
  | `refill_vitals() -> String` | Refuses unless an adventure runs. Then `initialize_current_values(current_madra)`, which keeps the run's Madra |
  | `unlock_all_techniques() -> String`, `unlock_all_abilities() -> String` | Log how many were newly unlocked |
  | `known_event_ids() -> PackedStringArray` | Sorted and unique: the `target_value` of every EVENT_TRIGGERED condition in `UnlockManager.unlock_condition_list.list`, plus every quest step's `completion_event_id` |
  | `list_item_paths() -> PackedStringArray` | Every `.tres` under `res://resources/items/` that loads as an `ItemDefinitionData`, walked with `ResourceLoader.list_directory()` (subfolders end in `/`), sorted |

- [ ] **Step 1: Write the failing tests.** Bind a fresh save per test, stop actions, and restore the original afterwards.
  - Complete action:
    - `test_complete_action_runs_its_effects`.
    - `test_complete_action_skips_a_used_up_action`: called twice, the count is 1 and both return "".
    - `test_complete_action_refuses_an_unavailable_action`: NPC 2 on a fresh save gives a reason containing "not available".
  - Events: `test_trigger_event_refuses_an_unknown_id`, `test_trigger_event_twice_is_fine`.
  - Core Density:
    - `test_reach_core_density_pays_milestones`: on a fresh save, 20 gives level 20 and 2 path points.
    - `test_reach_core_density_stops_at_the_cap`: 150 gives 100.
  - Path nodes:
    - `test_buy_path_node_adds_only_missing_points`: from a balance of 0, `pure_core_awakening` is bought, the balance is 0, and `empty_palm` is unlocked.
    - `test_buy_path_node_skips_a_bought_node`.
    - `test_buy_path_node_names_a_missing_prerequisite`: `power_font` first.
  - Abilities:
    - `test_equip_ability_uses_slots_one_to_four`: slot 3 gives `get_ability_at_slot(2) == "empty_palm"`.
    - `test_equip_ability_refuses_slot_zero_and_five`.
  - Items:
    - `test_award_item_by_path`: Crude Scale ×3 gives a consumables count of 3.
    - `test_award_equipment_with_a_full_grid_fails` (Review Focus 5): with the grid filled, the reason is "Equipment is full", the grid is unchanged, and no "Looted" line was logged.
  - `test_advance_stage_refuses_at_copper`, `test_travel_refuses_during_cycling` and `test_refill_vitals_refuses_outside_a_run`.
  - `test_dev_commands_never_count_as_play`: triggering `aura_well_discovered` through the command leaves `event_first_times` empty, and `recording_paused` false afterwards.
  - `test_known_event_ids`: a content lock on exactly these eight: `celestial_intervener_dialogue_1`, `_2`, `_3` and `_4`, `q_fill_core_completed`, `q_first_steps_enemy_defeated`, `aura_well_discovered`, `merchant_discovered`.
  - `test_list_item_paths_finds_nested_items`: it holds `res://resources/items/consumables/crude_scale.tres` and `res://resources/items/equipment/spirit_valley/iron_shortsword.tres`, and every entry loads as an item.
  - `test_successful_commands_log_a_dev_line`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add dev commands over the managers' public APIs`

### Task 10: Step, beat, route and preset data

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `scripts/resource_definitions/dev/dev_step_data.gd`, `story_beat_data.gd`, `story_route_data.gd`, `save_preset_data.gd`
- Test: `tests/unit/test_dev_preset_data.gd`

**Interfaces:**
- **Consumes:** Task 9's commands.
- **Produces:**
  - `class_name DevStepData extends Resource`:
    - `enum Kind { COMPLETE_ACTION, TRIGGER_EVENT, REACH_CORE_DENSITY, SET_MADRA, SET_GOLD, BUY_PATH_NODE, UNLOCK_TECHNIQUE, EQUIP_TECHNIQUE, UNLOCK_ABILITY, EQUIP_ABILITY, AWARD_ITEM, ADVANCE_STAGE, TRAVEL }`, values 0–12.
    - `@export var kind: Kind`, `@export var target_id: String = ""` and `@export var amount: float = 0.0`.
    - `func apply() -> String`: the matching `DevCommands` call; `amount` becomes an int for levels, slots and quantities.
    - `func describe() -> String`: for example "Complete celestial_intervener_dialogue_1", "Set gold to 700", "Equip ability empty_palm in slot 3" and "Reach Core Density 100".
    - `func validate() -> PackedStringArray`: errors for an unknown action (`ZoneManager.get_action_by_id`), event (`DevCommands.known_event_ids()`), path node (the current tree), technique, ability, item path or zone; a level below 1; a slot outside 1–4; a quantity below 1; a negative Madra or gold value.
  - `class_name StoryBeatData extends Resource`: `beat_id`, `title`, `steps: Array[DevStepData]` and `reached_when: String`.
  - `class_name StoryRouteData extends Resource`:
    - Fields `beats: Array[StoryBeatData]`, `optional_quest_ids: Array[String]` and `excluded_action_ids: Array[String]`.
    - `func find_beat(beat_id: String) -> StoryBeatData`: null when unknown.
    - `func steps_through(beat_id: String) -> Array[DevStepData]`: every step of every beat up to and including it, in order. Empty for "".
    - `func validate() -> PackedStringArray`: duplicate or empty beat ids, unknown listed quests or actions, and each step's errors prefixed with its beat.
  - `class_name SavePresetData extends Resource`:
    - Fields `preset_id`, `title`, `description` (multiline), `story_through: String`, `steps: Array[DevStepData]` and `snapshot: SaveGameData`.
    - `func validate(route: StoryRouteData) -> PackedStringArray`: an empty id or title, an unknown `story_through`, step errors, or a snapshot from a newer build.

- [ ] **Step 1: Write the failing tests.**
  - `test_validate_catches_each_bad_step`, one assertion per rule above, and `test_a_good_step_validates`.
  - `test_describe_reads_plainly`: the four examples.
  - `test_apply_dispatches_to_the_command`: SET_GOLD 700 on a fresh save gives gold 700.
  - `test_the_kinds_the_route_does_not_use_apply`: the route and presets exercise the other kinds, so check these four. On a fresh save, UNLOCK_TECHNIQUE `torrential_flow`, UNLOCK_ABILITY `power_font`, AWARD_ITEM the Crude Scale's path ×2, and TRAVEL `SpiritValley` each return "" and have their effect.
  - `test_steps_through_includes_earlier_beats_in_order` and `test_steps_through_nothing`.
  - `test_route_validate_catches_duplicate_beats` and `test_preset_validate_catches_an_unknown_beat`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add step, beat, route and preset resources`

### Task 11: The story route and its coverage test

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `resources/dev/story_route.tres`
- Test: `tests/integration/test_story_route.gd`

**Interfaces:**
- **Consumes:** Task 10's classes.
- **Produces:** the route. `optional_quest_ids` and `excluded_action_ids` start empty. Every id was checked against the content.

  | `beat_id` | `title` | Steps (kind, target, amount) | `reached_when` |
  |---|---|---|---|
  | `beat_1` | Awakening | COMPLETE_ACTION `celestial_intervener_dialogue_1`; SET_MADRA 100; COMPLETE_ACTION `celestial_intervener_dialogue_2` | `q_fill_core_completed` |
  | `beat_2` | First Steps Out | TRIGGER_EVENT `q_first_steps_enemy_defeated`; COMPLETE_ACTION `celestial_intervener_dialogue_3`; BUY_PATH_NODE `pure_core_awakening`; EQUIP_TECHNIQUE `smooth_flow`; EQUIP_ABILITY `empty_palm` 3 | `celestial_intervener_dialogue_3` |
  | `beat_3a` | Aura Well | TRIGGER_EVENT `aura_well_discovered` | `aura_well_discovered` |
  | `beat_3b` | Merchant unlocked | REACH_CORE_DENSITY 10; COMPLETE_ACTION `celestial_intervener_dialogue_4`; TRIGGER_EVENT `merchant_discovered` | `merchant_discovered` |
  | `beat_9_ready` | Tribulation ready | REACH_CORE_DENSITY 100 | `core_density_full` |
  | `beat_9` | Copper | ADVANCE_STAGE | "" |

  Write it by hand, in the shape of `resources/quests/q_fill_core.tres`:
  - declare sub_resources before they are used;
  - a typed array names its script's ext_resource id, for example `steps = Array[ExtResource("2_step")]([SubResource("step_1"), SubResource("step_2")])`;
  - enums are ints;
  - reference scripts by `path=`. A `uid=` is optional (`scripts/tools/generate_uid.gd` prints fresh ones).

- [ ] **Step 1: Write the failing tests.** Bind a fresh save with `PersistenceManager.use_save(SaveGameData.new_current(), "")`, cancel actions, and restore the original afterwards.
  - `test_the_route_validates`: `validate()` is empty.
  - `test_the_route_covers_the_story`:
    - Apply every step in order, asserting each returns "".
    - Before the first step and after every step, record the available action ids across `ZoneManager.get_all_zones()`.
    - At the end:
      - every quest in `QuestManager.get_all_quests()` is completed, unless it is in `optional_quest_ids`;
      - every action of every listed zone was recorded available, unless it is in `excluded_action_ids`;
      - every NPC dialogue action with `max_completions > 0` is used up;
      - every non-empty `reached_when` holds (`has_event_triggered()` or `is_condition_unlocked()`);
      - the stage is Copper.
- [ ] **Step 2: Run the file.** Expected: FAIL (no route file).
- [ ] **Step 3: Write the route.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the Foundation story route`

### Task 12: DevManager builds a preset at launch

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:save-load`, `godot-prompter:scene-organization`, `godot-prompter:godot-testing`

**Files:**
- Create: `singletons/dev_manager/dev_manager.gd`
- Modify:
  - `project.godot`: add `DevManager="*res://singletons/dev_manager/dev_manager.gd"` after `MerchantManager`, as the last autoload.
  - `scripts/utils/launch_options.gd`.
  - `singletons/persistence_manager/persistence_manager.gd` (`boot`).
  - `.gitignore`: add `.dev_settings.cfg`.
- Test: `tests/unit/test_launch_options.gd`, `tests/unit/test_persistence_manager.gd`, `tests/integration/test_dev_manager_build.gd`

**Interfaces:**
- **Consumes:** Tasks 4, 9, 10 and 11.
- **Produces:**
  - `LaunchOptions`:
    - New fields `preset_id: String = ""` and `preset_from_pin: bool = false`.
    - `parse(user_args: PackedStringArray, pinned_preset_id: String = "")` reads `--preset=<id>`. When no `--preset` was given, it uses the pin and sets `preset_from_pin`.
    - `current()` passes `read_pin()`.
    - `static var pin_path_override: String = ""`, for tests only.
    - `static func pin_file_path() -> String`: the override when set. Otherwise `res://.dev_settings.cfg` when `OS.has_feature("editor")` (true for every run from the editor binary), else `user://dev_settings.cfg`.
    - `static func read_pin() -> String`: ConfigFile section `dev`, key `pinned_preset`.
    - `static func write_pin(preset_id: String) -> Error`: "" erases the key.
  - `PersistenceManager.boot()`: when `options.preset_id != ""`, it reads no file and takes no backup. It calls `use_save(SaveGameData.new_current(), options.save_path)`, and DevManager builds next.
  - `DevManager` (autoload, last):
    - `enum SessionKind { YOUR_SAVE, PRESET, FILE }` and `signal session_changed`.
    - Constants `ROUTE_PATH := "res://resources/dev/story_route.tres"`, `PRESET_DIR := "res://resources/dev/save_presets/"` and `EXPORT_PRESET_DIR := "user://dev/save_presets/"`.
    - `var preset_dir_override: String = ""`, for tests only. When set, it replaces both folders.
    - `func get_route() -> StoryRouteData`.
    - `func get_presets() -> Array[SavePresetData]`: every `.tres` in the preset folders that loads as a `SavePresetData`, sorted by title.
    - `func find_preset(preset_id: String) -> SavePresetData`.
    - `func get_session_kind() -> SessionKind` and `func get_session_preset() -> SavePresetData` (null outside a preset session).
    - `func build_preset(preset: SavePresetData, save_path: String = "") -> String`:
      1. The save is `preset.snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)` then `migrate()`, or else `SaveGameData.new_current()`. Its `stats.built_from_preset` is set to `preset.preset_id`.
      2. `PersistenceManager.use_save(save, save_path)`.
      3. Each step of `get_route().steps_through(preset.story_through)`, then of `preset.steps`, is applied. The first failure returns `"<describe()>: <reason>"`.
      4. It marks every available action in every zone seen (`ZoneManager.mark_action_seen()`) and every unlocked technique seen (`CyclingManager.mark_technique_seen()`).
      5. It returns "".
    - `_ready()`: does nothing under a test run. Otherwise it calls `start_from_launch_options(LaunchOptions.current())`.
    - `func start_from_launch_options(options: LaunchOptions) -> void`:
      - The kind is PRESET when `options.preset_id` is set, FILE when only `save_path` is, and YOUR_SAVE otherwise.
      - For a preset it calls `build_preset(find_preset(options.preset_id), options.save_path)` synchronously. Verified on 4.7.2: the main scene's `_ready()` runs after the last autoload's.
      - It then calls `LogManager.clear_history()` and logs one `[DEV]` line: "Started preset '<title>'", plus " (pinned)" when it came from the pin.
      - An unknown id or a failed build gets `Log.critical` with the reason, then `PersistenceManager.use_save(SaveGameData.new_current(), "")`. Never the user's save.

- [ ] **Step 1: Write the failing tests.**
  - Launch options:
    - `test_preset_option`.
    - `test_the_pin_starts_a_preset`: pinned "x" with no args gives `preset_id == "x"` and `preset_from_pin`.
    - `test_an_option_beats_the_pin`.
    - `test_write_and_read_the_pin` and `test_an_empty_pin_clears_it`, with `pin_path_override` pointing at a temp file.
  - Persistence: `test_boot_with_a_preset_reads_no_file`. A temp file with gold 42 is left alone: the session is in memory with the default gold, the file's bytes are unchanged, and there is no backup.
  - `test_dev_manager_build.gd`, using inline `SavePresetData` objects:
    - `test_build_applies_the_route_then_the_steps`: through `beat_3b` plus SET_GOLD 700 gives Core Density ≥ 10, the merchant available, and gold 700.
    - `test_a_built_save_records_its_preset_and_no_play`: `built_from_preset` is set, every count is 0, and the first times are empty.
    - `test_a_built_save_shows_no_new_seals`.
    - `test_a_failing_step_names_itself`: a lone COMPLETE_ACTION `celestial_intervener_dialogue_4` returns text containing that id and "not available".
    - `test_a_snapshot_is_copied_not_shared`: a snapshot with gold 5 is built, gold is set to 99, and building again gives gold 5.
    - `test_building_writes_nothing`: `PersistenceManager.is_in_memory()`.
    - `test_an_unknown_preset_falls_back_to_a_fresh_save_in_memory`:
      - Point `main_save_path` at a temp file holding gold 42.
      - `start_from_launch_options()` with `preset_id = "no_such_preset"` gives an in-memory session with the default gold.
      - The temp file is unchanged.
    - `test_a_restart_matches_a_launch` (boot equivalence):
      - Build a preset through `beat_3b`, write it to a temp file, load it with `SaveFiles.load_save()`, then `use_save(loaded, "")`.
      - A digest is equal before and after. It covers Core Density level and XP, the stage, Madra, gold, path points and purchases, active quests with their steps, completed quests, triggered events, latched conditions, available action ids, unlocked and equipped abilities and the technique, inventory counts by item, the current zone id and the current action id.
- [ ] **Step 2: Run the three files.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import` and check `git diff project.godot`.
- [ ] **Step 4: Run the three files**, then the suite. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): build a save preset at launch`

### Task 13: Switching sessions in game

**Skills:** `godot-prompter:scene-organization`, `godot-prompter:godot-testing`

**Files:**
- Create: `scripts/utils/game_speed.gd`
- Modify: `singletons/dev_manager/dev_manager.gd`
- Test: `tests/integration/test_dev_manager_sessions.gd`

**Interfaces:**
- **Consumes:** Tasks 4, 5, 8 and 12.
- **Produces:**
  - `class_name GameSpeed extends RefCounted`: `static var base_scale: float = 1.0` and `static func set_base_scale(scale: float) -> void`, which stores it and sets `Engine.time_scale`.
  - `DevManager`:
    - `signal session_switch_failed(reason: String)`.
    - `func play_preset(preset: SavePresetData) -> void`.
    - `func play_story_through(beat_id: String) -> void`: an unnamed preset with `preset_id` "story_through_<beat_id>", title "Story through <beat title>" and `story_through = beat_id`.
    - `func restart_preset() -> void`: does nothing outside a preset session. A restart keeps the session's `--save` path.
    - `func back_to_my_save() -> void`: `open_save_file(main_save_path)`.
    - `func new_game() -> void`: backs up the main save, then `use_save(SaveGameData.new_current(), main_save_path)` and `save_data()`.
    - `func keep_as_my_save() -> void`: refuses when another run holds the main save's lock. It backs up the main save, then `use_save(save_game_data.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL), main_save_path)` and `save_data()`.
    - `func restore_backup(backup_path: String) -> void`: backs up the main save, copies the backup over it, then `open_save_file(main_save_path)`.
    - Functions that need the main save refuse when `PersistenceManager.main_save_path` is empty. That is every test run, unless the test sets it.
  - Each switch is scheduled once with `call_deferred` and returns at once. A panel button's handler lives inside the scene the switch frees, and `SceneTree.unload_current_scene()` deletes that scene immediately. The deferred switch runs in this order:
    1. `PersistenceManager.autosave()`, so a session that writes a file keeps its last moments.
    2. Teardown:
       - `ActionManager.cancel_current_action()`;
       - `CyclingManager.end_cycle_session()` and `clear_last_cycle_result()`;
       - `PlayerManager.reset_vitals()`;
       - `Engine.time_scale = GameSpeed.base_scale`, because a boss hit-stop freed mid-way never restores it.
    3. When `get_tree().current_scene` is the main scene, it calls `get_tree().unload_current_scene()`. The main scene is the one whose `scene_file_path` equals `ResourceUID.ensure_path(ProjectSettings.get_setting("application/run/main_scene"))`. Under GUT the current scene is the runner, so nothing is unloaded or reloaded.
    4. The new session: a build, `open_save_file()`, or the New game, keep or restore steps.
       - A refusal or a failed build emits `session_switch_failed(reason)`, with `Log.error`.
       - The previous session then comes back the same way: Your save reopens from disk, a preset rebuilds, a file reopens.
       - If that fails too, an in-memory fresh save.
    5. `LogManager.clear_history()`, and one `[DEV]` line naming the new session.
    6. If step 3 unloaded the main scene, `change_scene_to_file()` loads it again. Then `session_changed.emit()`.

- [ ] **Step 1: Write the failing tests.**
  - Setup: tests that use a main save point `main_save_path` and `backup_dir` at temp paths and restore both. After each switch, `await wait_process_frames(2)`.
  - `test_play_preset_switches_on_the_next_frame` (Review Focus 1): right after `play_preset()` the kind and gold are unchanged; after the frames the kind is PRESET and gold is the preset's.
  - `test_restart_rebuilds_the_preset` and `test_restart_outside_a_preset_does_nothing`.
  - `test_switching_cancels_the_running_action_without_counting`.
  - `test_teardown_restores_the_time_scale` (Review Focus 3): `Engine.time_scale = 0.25`, then a switch, gives 1.0.
  - `test_the_log_starts_clean`: the history is one line containing the preset's title.
  - `test_back_to_my_save_reopens_it`: from a temp main save with gold 42, play a preset, then go back. Gold is 42 and the kind is YOUR_SAVE.
  - `test_a_failed_build_returns_to_your_save_untouched` (Review Focus 4): from the temp main save with gold 42, play a preset whose only step fails.
    - `session_switch_failed` is emitted with the step's text.
    - The kind is YOUR_SAVE, and gold is 42 both in memory and in the file.
  - `test_new_game_backs_up_first`: from gold 42, a new game gives gold 0 in memory and in the file, and one backup holds gold 42.
  - `test_keep_as_my_save_writes_the_session`: from a preset with gold 700, keep gives a main file with gold 700, the kind YOUR_SAVE, and a backup of the old main save.
  - `test_restore_backup_brings_it_back`.
  - `test_main_save_functions_refuse_without_a_main_save`: with `main_save_path` "", `back_to_my_save()` emits `session_switch_failed`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run `--import`.
- [ ] **Step 4: Run the file**, then the suite. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): switch between presets and your save in game`

### Task 14: Starting presets, save-as-preset and the pin

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `resources/dev/save_presets/fresh.tres`, `adventure_open.tres`, `path_open.tres`, `merchant_open.tres`, `tribulation_ready.tres`, `copper.tres`
- Modify: `singletons/dev_manager/dev_manager.gd`
- Test: `tests/integration/test_save_presets.gd`

**Interfaces:**
- **Produces:**
  - The presets. The spec fixes the ids, titles, beats and gold; the descriptions are this plan's copy.

    | `preset_id` | `title` | `story_through` | Steps | `description` |
    |---|---|---|---|---|
    | `fresh` | Fresh start | "" | — | A new game. |
    | `adventure_open` | Adventure open | `beat_1` | — | The Shallow Woods and foraging are open. The first fight is next. |
    | `path_open` | First keystone | `beat_2` | — | Pure Core Awakening bought; Smooth Flow and Empty Palm equipped. |
    | `merchant_open` | Merchant open | `beat_3b` | SET_GOLD 700 | The Traveling Merchant is in Spirit Valley, with gold for every piece. |
    | `tribulation_ready` | Tribulation ready | `beat_9_ready` | — | Every quest done and the core full. The Tribulation waits. |
    | `copper` | Copper | `beat_9` | — | The Tribulation passed. The first moments of Copper. |

  - `func save_as_preset(title: String, description: String) -> String`:
    - Refuses an empty title or an id that already exists.
    - The id is the title lowercased, with each run of characters outside `a-z0-9` turned into `_`, and `_` trimmed from both ends.
    - It writes a `SavePresetData` with `snapshot = save_game_data.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)`. A copy has no `resource_path`, so it embeds.
    - The file goes to `PRESET_DIR` in editor runs (`OS.has_feature("editor")`), else to `EXPORT_PRESET_DIR`, or to `preset_dir_override` when set, through `SaveFiles.write_atomically()`.
  - `func pin_preset(preset_id: String) -> Error` ("" unpins) and `func get_pinned_preset_id() -> String`, over `LaunchOptions.write_pin()` and `read_pin()`.

- [ ] **Step 1: Write the failing tests.**
  - `test_the_starting_presets_exist`: the six ids.
  - `test_every_preset_validates_and_builds`: for each of `get_presets()`, `validate(get_route())` is empty and `build_preset()` returns "".
  - `test_tribulation_ready_has_a_full_core`: Core Density 100, and `spirit_valley_tribulation` is available.
  - `test_copper_is_copper`: stage Copper, and the Tribulation is gone.
  - `test_merchant_open_has_the_merchant_and_700_gold`.
  - Save as preset (with `preset_dir_override` pointing at a temp folder):
    - `test_save_as_preset_round_trips`: with gold 321, the saved file loads as a preset with that title, and building it gives gold 321.
    - `test_save_as_preset_refuses_a_taken_id`.
    - `test_save_as_preset_slug`: "Weird State #2!" gives `weird_state_2`.
  - `test_pin_round_trips`, with `LaunchOptions.pin_path_override` pointing at a temp file.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Write the presets and implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the starting presets and save-as-preset`

### Task 15: Stage 2 docs and the full suite

**Skills:** none

**Files:**
- Modify: `docs/tooling/DEV_TOOLS.md`, `docs/infrastructure/PERSISTENCE.md`, `docs/testing/TESTING.md`, `docs/progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md`, `CLAUDE.md`

- [ ] **Step 1: DEV_TOOLS.md.** A Presets section: what a preset is, the route, how to add a preset, launching with `--preset`, the pin, the coverage rule, and tables of `DevManager`'s and `DevCommands`' public functions.
- [ ] **Step 2: PERSISTENCE.md.** The preset session row, and `--preset` in the launch options.
- [ ] **Step 3: TESTING.md.** New tests set up story state with `DevCommands`, the route or a preset instead of writing fields. Explain the coverage test's rule, and that DevManager never reloads a scene under GUT.
- [ ] **Step 4: QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md.** A new quest or zone action needs a route step, or a listing in the route's `optional_quest_ids` or `excluded_action_ids`.
- [ ] **Step 5: CLAUDE.md.**
  - Update the singleton counts it states: DevManager makes 18 managers, 19 autoloads with Dialogic.
  - Common Commands gains launching into a preset, `… main_game.tscn -- --preset=tribulation_ready`, and notes that an agent adds `--save=user://dev/runs/<name>.tres` to keep the run's file.
- [ ] **Step 6: Run the suite.** Expected: PASS.
- [ ] **Step 7: Commit.** `docs(dev): document presets, the story route and DevManager`

Stage 2 ends here (PR boundary).

---

## Stage 3: Dev panel

### Task 16: Time speed

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/dev_manager/dev_manager.gd`, `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` (`_play_boss_reveal`, lines 783-786)
- Test: `tests/integration/test_dev_manager_sessions.gd`, `tests/integration/test_adventure_map_render.gd`

**Interfaces:**
- **Consumes:** Task 13's `GameSpeed`.
- **Produces:**
  - `DevManager`: `const TIME_SPEEDS: Array[float] = [1.0, 2.0, 5.0, 10.0]`, `signal time_speed_changed(speed: float)`, `func set_time_speed(speed: float) -> void` (calls `GameSpeed.set_base_scale()`, then emits), and `func get_time_speed() -> float`.
  - The hit-stop: `Engine.time_scale = 0.25 * GameSpeed.base_scale`, restored to `GameSpeed.base_scale` by `get_tree().create_timer(0.15, true, false, true)`. That timer runs on real time, so the stop lasts 0.15 s at any speed, as it does today at ×1.

- [ ] **Step 1: Write the failing tests.**
  - `test_set_time_speed_scales_the_engine`: ×5 gives `Engine.time_scale == 5.0` and the signal. `after_each()` sets ×1.
  - In `test_adventure_map_render.gd`, `test_the_hit_stop_returns_to_the_dev_speed`: with base 2.0, the scale is 0.5 right after the reveal and 2.0 after 0.3 s of real time. Restore base 1.0. The existing hit-stop assertions (0.25, then 1.0) keep passing.
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both files.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add a time-speed control`

### Task 17: Force-win through the real death path

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.gd` (`force_win_combat`, lines 188-193), `singletons/dev_manager/dev_commands.gd`
- Test: `tests/integration/test_dev_adventure_commands.gd`

**Interfaces:**
- **Produces:**
  - `AdventureView.force_win_combat()`:
    - Takes `var enemy := combat.enemy_combatant`, and returns unless the fight is on, `is_instance_valid(enemy)`, and `enemy.vitals_manager.current_health > 0.0`.
    - Then `enemy.vitals_manager.apply_vitals_change(-enemy.vitals_manager.max_health)`. `AdventureCombat._on_enemy_health_changed()` pays the fight's gold and fires `q_first_steps_enemy_defeated`.
    - The health guard stops a second press from paying twice: the setter re-emits at 0.
  - `DevCommands.force_win_fight(view: AdventureView) -> String`: refuses when the view is null or no fight is on.
  - `DevCommands.exit_adventure(view: AdventureView, victory: bool) -> String`: refuses when no run is going.
  - Both pause stats recording.

- [ ] **Step 1: Write the failing tests.** Host a real AdventureView as `test_adventure_end_flow.gd:6-62` does:
  - `add_child_autofree()` the view, then `tile_set.emit_changed()`;
  - start the run with `ActionManager._set_current_action(action)` and `confirm_adventure_start(action, 50.0)`;
  - start a fight with `_current_combat_choice = choice` and `_on_start_combat(choice)`.

  Tests:
  - `test_force_win_pays_gold_and_fires_the_event`: the event fired, gold rose by the fight's reward, and `trigger_combat_end` was emitted once.
  - `test_force_win_twice_pays_once`.
  - `test_dev_force_win_is_not_play`: `fights_won` and `gold_earned` stay 0.
  - `test_refill_vitals_keeps_the_run_madra`.
  - `test_exit_as_victory_ends_the_run`: the adventure stopped, and `adventures_won` is 0.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file**, then `test_adventure_end_flow.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `fix(dev): force-win a fight through the enemy's death`

### Task 18: The panel shell and the World tab

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:scene-organization`, `godot-prompter:godot-testing`

**Files:**
- Rewrite: `scenes/ui/dev_panel/dev_panel.tscn` (with a real uid from `generate_uid.gd`), `scenes/ui/dev_panel/dev_panel.gd`
- Create: `scenes/ui/dev_panel/tabs/world_tab.tscn`, `world_tab.gd`
- Modify: `scenes/main/main_game/main_game.tscn` (the DevPanel instance), `scenes/main/main_game/main_game.gd`, `singletons/dev_manager/dev_manager.gd`
- Test: `tests/integration/test_dev_panel.gd`, `tests/integration/test_dev_panel_zone_toggles.gd`

**Interfaces:**
- **Consumes:** Tasks 9, 13 and 16.
- **Produces:**
  ```
  DevPanel (Control, full rect, mouse_filter Ignore)          dev_panel.gd, class DevPanel
  ├── Body (PanelContainer, %Body, mouse Stop, custom_minimum_size (560, 680))
  │   └── VBoxContainer
  │       ├── TitleBar (PanelContainer, %TitleBar)
  │       │   └── HBoxContainer: TitleLabel (Label, LabelSubheading, "Dev Panel"),
  │       │       Spacer (expand), SpeedOption (OptionButton, %SpeedOption: ×1 ×2 ×5 ×10),
  │       │       CloseButton (Button, %CloseButton, "×", flat)
  │       └── Tabs (TabContainer, %Tabs, vertical expand)
  │           └── World (world_tab.tscn instance, %WorldTab)
  └── SpeedBadge (Label, %SpeedBadge, LabelSubheading, top right, mouse Ignore, "×5", hidden at ×1)
  ```
  - When complete, the tab order is Saves, Player, Story, Items, Adventure, World. Tasks 19-22 add the others.
  - Every tab scene has the same layout:
    - a `ScrollContainer` root (horizontal off, vertical auto), then a `MarginContainer`, then a `VBoxContainer`;
    - section headers use `LabelSubheading` and field labels `LabelBody`;
    - long text uses `LabelBodySmall` with `autowrap_mode = 3` and `custom_minimum_size.x = 480`.
  - `class_name DevPanel extends Control`:
    - `@export var adventure_view: AdventureView`. `main_game.tscn` sets it to `../AdventureView`, and from Task 19 `_ready()` hands it to the Adventure tab.
    - `func toggle() -> void`, `func set_open(open: bool) -> void` and `func is_open() -> bool`.
    - `_ready()`:
      - restores the body's visibility, position and tab from `DevManager.panel_open`, `panel_position` and `panel_tab`;
      - sets the speed option and badge from `DevManager.get_time_speed()`;
      - connects `DevManager.time_speed_changed`.
    - Dragging the title bar moves `Body` and writes `DevManager.panel_position`. Tab changes write `panel_tab`, and opening or closing writes `panel_open`.
    - `_input()`: Ctrl+Shift+D toggles. This moves from `MainGame._input`, with the same raw key check, and marks the event handled.
  - `DevManager` gains `var panel_open: bool = false`, `var panel_position: Vector2 = Vector2(24, 24)` and `var panel_tab: int = 0`.
  - `main_game.tscn`:
    - The DevPanel instance keeps its path `MainView/DevPanel` and its place as MainView's last child (`test_tribulation_view_state.gd:316-319`).
    - It drops the offset overrides and `visible = false`, takes full-rect anchors, and sets `adventure_view`.
  - `main_game.gd`: `_input`, `_on_dev_hotkey` and `_dev_panel` go.
  - World tab (`world_tab.gd`):
    - `%TravelOption`: an OptionButton of `ZoneManager.get_all_zones()` names, with the ids as metadata.
    - `%TravelButton` calls `DevCommands.travel_to_zone()`. `%TravelStatus`, a wrapping Label, shows a refusal.
    - `%DemoZonesCheck` and `%HiddenZonesCheck` call `ZoneManager.set_*_visible()`. When the tab is built, they take their state from `are_*_visible()` through `set_pressed_no_signal()`.

- [ ] **Step 1: Write the failing tests.**
  - In `test_dev_panel.gd` (restore DevManager's panel fields, ×1 speed and the zone toggles in `after_each()`):
    - `test_toggle_opens_and_closes_the_body`.
    - `test_ctrl_shift_d_toggles`: send a synthesized `InputEventKey` (ctrl, shift, `KEY_D`) to `_input()`.
    - `test_open_state_position_and_tab_survive_a_rebuild`: free the panel and instance it again; the state is the same.
    - `test_speed_option_sets_the_speed`: selecting ×5 gives `DevManager.get_time_speed() == 5.0`.
    - `test_badge_shows_only_above_x1`.
    - `test_world_checkboxes_follow_zone_manager`: with hidden zones on, a rebuilt panel's check is pressed.
    - `test_travel_shows_a_refusal`.
  - In `test_dev_panel_zone_toggles.gd`: reach the checks through `_panel.get_node("%WorldTab").get_node("%DemoZonesCheck")`, and keep and restore the original save (TESTING.md's safe pattern).
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both files**, plus `test_boards_never_trim_text.gd` and `test_tribulation_view_state.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): rebuild the dev panel as tabs`

### Task 19: The Player and Adventure tabs

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/ui/dev_panel/tabs/player_tab.tscn`, `player_tab.gd`, `adventure_tab.tscn`, `adventure_tab.gd`
- Modify: `scenes/ui/dev_panel/dev_panel.tscn`
- Test: `tests/integration/test_dev_panel.gd`

**Interfaces:**
- **Consumes:** Tasks 9 and 17.
- **Produces:**
  - Player tab:
    - `%MadraSpin` with `%MadraSet` call `set_madra`; `%GoldSpin` with `%GoldSet` call `set_gold`.
    - `%LevelSpin` (0–100) with `%LevelReach` calls `reach_core_density`.
    - `%StageLabel` reads "Stage: Foundation · Core Density 42 / 100"; `%AdvanceStage` calls `advance_stage`.
    - `%PointsSpin` with `%PointsAdd` calls `add_path_points`.
    - `%AttributeOption` (the eight attributes), `%AttributeSpin` and `%AttributeAdd` call `add_attribute`.
    - `%TechniqueOption` (every technique) with `%TechniqueUnlock`, `%TechniqueEquip`, and `%UnlockAllTechniques`.
    - `%AbilityOption` (every ability), `%AbilitySlotSpin` (1–4), `%AbilityUnlock`, `%AbilityEquip`, and `%UnlockAllAbilities`.
    - `%PlayerStatus`, a wrapping Label, shows the last refusal and clears on a success.
  - Adventure tab:
    - `func set_adventure_view(view: AdventureView) -> void`, called by `DevPanel._ready()`.
    - With no run, it shows only `%NoRunLabel` ("No adventure running").
    - During a run it shows:
      - `%ForceWin`, only during a fight, calling `DevCommands.force_win_fight(view)`;
      - `%ExitVictory` and `%ExitDefeat`, calling `DevCommands.exit_adventure(view, true)` and `(view, false)`;
      - `%ShowWholeMap`, a CheckButton calling `view.set_show_whole_map()`, whose state comes from `view.adventure_tilemap.is_dev_reveal_all()`;
      - `%RefillVitals`, calling `DevCommands.refill_vitals()`;
      - `%AdventureStatus`, showing the last refusal.
    - It follows `ActionManager.start_adventure` and `stop_adventure`. The fight row polls `is_in_combat` in `_process()` while visible, as today.

- [ ] **Step 1: Write the failing tests.**
  - `test_player_tab_sets_gold`: a button press changes the gold.
  - `test_player_tab_reaches_a_level`.
  - `test_player_tab_shows_a_refusal`: equipping a locked ability puts the reason in the status label.
  - `test_adventure_tab_hides_without_a_run`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the Player and Adventure tabs`

### Task 20: The Saves tab and Ctrl+Shift+R

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/ui/dev_panel/tabs/saves_tab.tscn`, `saves_tab.gd`, `scenes/ui/dev_panel/rows/dev_preset_row.tscn`, `dev_preset_row.gd`
- Modify: `scenes/ui/dev_panel/dev_panel.tscn`, `dev_panel.gd`
- Test: `tests/integration/test_dev_panel_saves_tab.gd`

**Interfaces:**
- **Consumes:** Tasks 13 and 14.
- **Produces:**
  ```
  SavesTab
  ├── SessionLabel (wraps): "Preset: Tribulation ready · in memory, not saved" | "Your save · user://save.tres"
  │     | "File · <path>"; then why saving is off, if it is; then
  │     "Version 1 · Playtime 12:34 · Foundation, Core Density 42 / 100 · 120 gold"
  ├── BeatsLabel (wraps): one line per route beat, "Awakening — 2:41" or "Awakening — not reached"
  ├── HBox: RestartButton ("Restart preset (Ctrl+Shift+R)", disabled outside a preset),
  │         BackButton ("Back to my save", disabled in Your save)
  ├── "PRESETS": PresetList (VBoxContainer of dev_preset_row instances)
  ├── "SAVE THIS GAME AS A PRESET": TitleEdit (LineEdit), DescriptionEdit (LineEdit), SavePresetButton,
  │     SavePresetStatus (wraps)
  ├── "YOUR SAVE": NewGameButton, KeepButton ("Keep as my save", disabled in Your save), SaveNowButton,
  │     AutosaveCheck (PersistenceManager.autosave_enabled), BackupOption + RestoreButton, OpenFolderButton
  └── SavesStatus (wraps)
  ```
  - `dev_preset_row.tscn`:
    - An `HBoxContainer` holding a `VBoxContainer` (TitleLabel in `LabelBody`, wrapping; DescriptionLabel in `LabelBodySmall`, wrapping; PinnedLabel "Pinned · every launch starts here"), then PlayButton and PinButton ("Pin" or "Unpin").
    - `func set_preset(preset: SavePresetData, pinned: bool) -> void`, and signals `play_pressed(preset: SavePresetData)` and `pin_pressed(preset: SavePresetData)`.
  - New game and Restore need a second click within 3 s. The button reads "Click again to start a new game" or "Click again to restore" until then.
  - The tab refreshes on `DevManager.session_changed`, on `session_switch_failed` (which puts the reason in `SavesStatus`), and when shown. The playtime line refreshes once a second while visible.
  - `DevPanel._input()`: in a preset session, Ctrl+Shift+R calls `DevManager.restart_preset()` and marks the event handled. That also keeps `ability_slot_4`, plain R, from reaching `TechniqueDock`.
  - Open folder runs `OS.shell_open(ProjectSettings.globalize_path("user://"))`.
  - Save now calls `PersistenceManager.save_data()`. On an error, `SavesStatus` names it: in memory, saving off (with the block reason), or the write error.

- [ ] **Step 1: Write the failing tests.**
  - `test_every_preset_has_a_row`.
  - `test_play_on_a_row_plays_its_preset`: after the frames, the kind is PRESET.
  - `test_restart_is_disabled_outside_a_preset`.
  - `test_the_session_line_says_in_memory`.
  - `test_new_game_needs_a_second_click`.
  - `test_ctrl_shift_r_restarts_a_preset`.
  - `test_save_as_preset_shows_a_refusal`: an empty title.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the Saves tab and the restart key`

### Task 21: The Story tab

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/ui/dev_panel/tabs/story_tab.tscn`, `story_tab.gd`, `scenes/ui/dev_panel/rows/dev_action_row.tscn`, `dev_action_row.gd`
- Modify: `scenes/ui/dev_panel/dev_panel.tscn`
- Test: `tests/integration/test_dev_panel_story_tab.gd`

**Interfaces:**
- **Consumes:** Tasks 8, 9, 11 and 13.
- **Produces:**
  - Story tab:
    - `%JumpOption` lists the beats as "<title> (<beat_id>)"; `%JumpButton` calls `DevManager.play_story_through()`.
    - `%QuestsLabel` (wraps) shows each active quest as "<quest title> — step N: <step description>", then "Done: <titles>".
    - `%EventOption` lists `DevCommands.known_event_ids()`; `%TriggerButton` calls `trigger_event`.
    - "ACTIONS": `%ActionList`, a VBox of `dev_action_row` instances for the current zone's `all_actions`.
    - `%EventsLabel` (wraps) shows the triggered events and latched conditions, and `%StoryStatus` the last refusal.
  - `dev_action_row`:
    - NameLabel and StatusLabel (both wrap), and a CompleteButton enabled only when the action is available.
    - `func set_action(action: ZoneActionData, status: String, available: bool) -> void`, and signal `complete_pressed(action_id: String)`.
  - `story_tab.gd` has `static func action_status(action: ZoneActionData, zone_id: String) -> String`. It returns "Available", "Used up (n/n)", "Passed" (a passed Tribulation), or "Locked: needs <the condition ids not latched, comma-separated>".
  - The tab refreshes on `EventManager.event_triggered`, `UnlockManager.condition_unlocked`, QuestManager's signals, `ZoneManager.action_completed` and `zone_changed`, `DevManager.session_changed`, and when shown.

- [ ] **Step 1: Write the failing tests.**
  - `test_jump_plays_story_through_the_beat`.
  - `test_trigger_fires_the_event`.
  - `test_a_locked_action_names_its_conditions`: on a fresh save, NPC 2 reads "Locked: needs q_fill_core_madra_full".
  - `test_complete_on_a_row_completes_it`.
  - `test_quests_label_shows_the_current_step`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the Story tab`

### Task 22: The Items tab

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/ui/dev_panel/tabs/items_tab.tscn`, `items_tab.gd`
- Modify: `scenes/ui/dev_panel/dev_panel.tscn`
- Test: `tests/integration/test_dev_panel_items_tab.gd`

**Interfaces:**
- **Consumes:** Task 9.
- **Produces:**
  - `%ItemOption` lists `DevCommands.list_item_paths()`, showing each `item_name` with the path as metadata.
  - `%QuantitySpin` (1–99); `%GiveButton` calls `award_item`.
  - `%GrantPageButton` calls `grant_equipment_page`.
  - `%ItemsStatus` (wraps) shows a refusal.

- [ ] **Step 1: Write the failing tests.**
  - `test_give_awards_the_selected_item`.
  - `test_give_shows_why_it_failed`: a full grid.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(dev): add the Items tab`

### Task 23: Panel docs, the full suite and a hands-on pass

**Skills:** none

**Files:**
- Modify: `docs/tooling/DEV_TOOLS.md`, `docs/infrastructure/MAIN_VIEW.md`, `docs/UI_STYLING.md`, `docs/infrastructure/PERSISTENCE.md`

- [ ] **Step 1: DEV_TOOLS.md.**
  - Rewrite the Dev Panel section: the scene tree, each tab's controls, the hotkeys and time speed.
  - Remove the Force condition row and its caveat, the Force-Win bug, the spec's v2 list, the stale `MainGame._dev_unlocked`, and the tech-debt items this work fixed: the absolute path, the private catalog read, the placeholder uid and the unlock-all count.
- [ ] **Step 2: MAIN_VIEW.md** Keybindings, "Other inputs": Ctrl+Shift+D is now handled by `DevPanel._input()`. Add a row for Ctrl+Shift+R.
- [ ] **Step 3: UI_STYLING.md** Work Remaining: drop the dev panel title as the example of inline sizing.
- [ ] **Step 4: PERSISTENCE.md** Work Remaining: close the runtime New game item.
- [ ] **Step 5: Run the suite.** Expected: PASS.
- [ ] **Step 6: Commit.** `docs(dev): document the tabbed dev panel`
- [ ] **Step 7: Hand the user a hands-on pass.**
  - Launch with `-- --preset=tribulation_ready` and open the panel (Ctrl+Shift+D).
  - Play the Tribulation, press Ctrl+Shift+R, and check the game comes back at Core Density 100.
  - Go through each tab, set ×10 and check the badge, then go Back to my save.

Stage 3 ends here (PR boundary).
