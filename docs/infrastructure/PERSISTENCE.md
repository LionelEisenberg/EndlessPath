# Persistence System

## Overview

`PersistenceManager` (the first autoload) owns the run's save, a `SaveGameData` resource, and the file it is written to. Every other manager holds a live reference to the same `SaveGameData` instance and reads and writes its own fields directly. There is no per-manager serialization step. The `SaveTimer` node in `main_game.tscn` calls `PersistenceManager.tick()` every 5 seconds, and the window's close request saves once more.

A run plays one **session**: the user's own save (`user://save.tres`), another file chosen with `--save=<path>`, a preset that `DevManager` builds on a fresh save (in memory, or in the `--save` file), or a save in memory that nothing writes (every GUT run). Every write goes through a temp file, one run at a time writes a save, and a save that cannot be read, checked or safely written is never replaced. See [Sessions and launch options](#sessions-and-launch-options).

**Does progress persist between launches?** Yes. The save is written every 5 seconds while the main scene runs, and when the window closes, and it loads unchanged on the next launch. The exceptions are:

| Situation | Result |
|-----------|--------|
| The process is killed (the editor's Stop button, a crash) | The changes since the last 5 s tick are lost: only the tick and the close request write |
| The run was launched with `--no-autosave`, or is a GUT run | The tick and the close write nothing. A GUT run also has no file to write |
| The run plays a preset: `--preset`, a pinned preset on a plain launch, or one played in game | The save is a fresh one the preset is built on, in memory. The user's save is not read and nothing is written, unless `--save` names a file. See [Sessions and launch options](#sessions-and-launch-options) |
| `save.tres` exists but does not load as a `SaveGameData` | The file is copied to `save.unreadable.<unix time>.tres` and left untouched. The session runs on a new save in memory, and saving is blocked until the game restarts. `Log.critical` names the copy |
| `ZoneManager` failed to load, so the save cannot be checked | The save is migrated but kept unchecked, and saving is blocked for the session (`Log.critical`). Nothing is repaired |
| A newer build wrote the save | It is played as loaded, unmigrated, with saving blocked (`Log.critical`): writing it back would drop what this build does not know |
| Another live run holds the save's lock | The save loads, but saving is blocked (`in use by another run`), and no boot backup is taken |
| The save names a zone the game no longer has | `repair()` puts `current_selected_zone_id` back to `""` (the first zone), after the file is copied to `save.invalid.<unix time>.tres`. The rest of the save stays. A zone listed in `ZONE_ID_MIGRATIONS` (Test Zone) moves to its listed zone (Spirit Valley) instead |
| The save was written before saves had versions | `migrate()` brings it up to the current version when it loads. See [Versioning](#versioning) |
| The save predates the 2026-05-23 attributes change | Its attributes come back as defaults: no migration step converts them. See [Versioning](#versioning) |

## Player Experience

- A player sees no save/load screen, no save slots and no "New Game" option: progress saves silently every 5 seconds and when the window closes, and is restored on launch. The dev panel's Saves tab can start a new game, restore a backup and switch sessions ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#saves)).
- Quitting mid-adventure loses the adventure: the map, position, vitals and timer. The Madra drained to start it, and any gold or loot already awarded, stay as they were when the window closed (or at the last 5 s tick, when the process is killed).
- To start over, press New game on my save in the dev panel's Saves tab (it backs `save.tres` up first), or delete `save.tres`, or play another file with `--save=`: a path with no file starts a new save. `--preset=fresh` plays a new game that leaves `save.tres` alone.
- Each launch on `save.tres` first copies it to `user://backups/`, and the newest 10 copies are kept. To go back to one, pick it in the dev panel's Saves tab and press Restore, or copy it over `save.tres` with the game closed.
- After pulling or merging new art, run `--headless --import` before running the game or the tests. Without it, an item `.tres` the save names can fail to load its new texture, which makes the whole save unreadable. PersistenceManager then keeps the file and turns saving off, so the run shows a fresh game, but nothing is lost: re-import and launch again.

## Architecture

```
LaunchOptions (RefCounted)                   scripts/utils/launch_options.gd
  --save=<path>, --preset=<id>, --no-autosave, the checkout's pinned preset, is_test_run()

PersistenceManager (autoload Node)           singletons/persistence_manager/persistence_manager.gd
  save_game_data: SaveGameData  ── same instance ──►  live_save_data / _live_save_data in the save-owning managers
  signal save_data_reset
  SaveFiles (statics)                        singletons/persistence_manager/save_files.gd: temp-file writes, loads, copies, backups
  SaveLock (statics)                         singletons/persistence_manager/save_lock.gd: one writer per save

DevManager (the last autoload)               singletons/dev_manager/dev_manager.gd
  builds a preset on the fresh save a preset launch binds, and switches sessions in game (DEV_TOOLS.md)

MainGame (main_game.tscn)
  _process(delta) ──► save_game_data.stats.add_play_time(delta)
  SaveTimer (Timer)                          scenes/main/main_game/save_timer.gd
    wait_time = 5.0, autostart = true, repeating
    timeout ──► PersistenceManager.tick()
```

### Sessions and launch options

`LaunchOptions` reads the user arguments after `--` on the command line (`OS.get_cmdline_user_args()`) and the checkout's pinned preset. `LaunchOptions.current()` parses them once; `parse()` takes any list and a pinned preset id, so a test can feed it both. Anything else after `--`, and a `--save` or `--preset` with no `=`, is ignored. An option given twice keeps its last value.

| Option | Effect |
|--------|--------|
| `--preset=<id>` | Start a preset session: a fresh save that `DevManager` builds the preset on, instead of the user's save. It lives in memory unless `--save` is given too. See [Launching into a preset](../tooling/DEV_TOOLS.md#launching-into-a-preset) |
| `--save=<path>` | Play and write that file instead of `user://save.tres`. A path with no file starts a new save there. With `--preset`, the built session is written there |
| `--no-autosave` | The `SaveTimer`'s tick and the window's close write nothing. `save_data()` still writes when something calls it, and the save lock still holds |

A preset pinned for the checkout stands in for `--preset` on a **plain** launch, one with neither `--preset` nor `--save`. [The pin](../tooling/DEV_TOOLS.md#the-pin) has the rule in full.

A run plays one session:

| Session | Chosen by | `save_path` | Lock | Boot backup | Written |
|---------|-----------|-------------|------|-------------|---------|
| The user's own save | No `--save`, no `--preset`, no pinned preset | `user://save.tres`, which is also `main_save_path` | Yes | Yes | By the tick and the close |
| A file | `--save=<path>`, no `--preset` | The path | Yes | No | By the tick and the close |
| A preset | `--preset=<id>`, or a pinned preset on a plain launch; `DevManager` in game | `""`, or the `--save` path when a launch gave one | Only with `--save` | Only when the `--save` path is `main_save_path` | Only with `--save`, by the tick and the close |
| In memory | A GUT run | `""` | No | No | Never: `save_data()` returns `ERR_UNAVAILABLE` |

A preset session reads no file. `boot()` binds a fresh `SaveGameData.new_current()` to the `--save` path (`""` for none), and `DevManager` builds the preset on it in its own `_ready()`, once every other autoload is ready. A preset written over the user's own save (`--preset=<id> --save=user://save.tres`) is backed up first, under the lock, as a launch on that save is, so a preset never overwrites the user's save without a backup; it still reads nothing from it. How a preset is built, what happens when it does not build, and how `DevManager` switches sessions in game are in [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#save-presets).

A GUT run is detected by `LaunchOptions.is_test_run()`: `addons/gut/` appears in the engine arguments (the CLI's `-s addons/gut/gut_cmdln.gd`, and the editor panel's `--scene res://addons/gut/gui/run_from_editor.tscn`). The user arguments are not engine arguments, so a `--save=` path cannot make a normal launch look like one. `PersistenceManager._ready()` boots a GUT run on `SaveGameData.new_current()` in memory, with `main_save_path` set to `""` (no main save to open or back up) and `autosave_enabled` false. No test run reads or writes `user://save.tres`, its lock or `user://backups/`.

Any run of the project that is not a GUT run (the main scene, any other scene, a headless `-s` script) plays the user's real save unless it passes `--save=` or `--preset=`, or a preset is pinned for the checkout: it backs the save up at boot and takes its lock, and a run with a window saves it and gives up the lock when the window closes. The command for a run on its own file is in `CLAUDE.md`.

### Save file location

The user's own save is `user://save.tres`, in Godot's text-resource format, written by `ResourceSaver.save()`. The project does not set `application/config/use_custom_user_dir`, so `user://` is Godot's default per-project folder (on Windows, `%APPDATA%\Godot\app_userdata\EndlessPath\`). It also holds `logs-YYYY-MM-DD.log` (see [LOGGING.md](LOGGING.md)).

The files below sit next to the save the session plays, named from its path (shown for `user://save.tres`):

| File | What it is |
|------|------------|
| `user://save.tmp.tres` | The temp file each write goes through. It keeps the extension because `ResourceSaver` picks the file format from it |
| `user://save.tres.lock` | The save's lock: `pid=` and `time=` lines. See [The save lock](#the-save-lock) |
| `user://save.unreadable.<unix time>.tres` | A save that would not load, copied aside. The original is never touched |
| `user://save.invalid.<unix time>.tres` | The file as it was before `repair()` fixed it |
| `user://backups/save.<YYYYMMDD-HHMMSS>[-N].tres` | A boot backup of the user's own save. The time is UTC, and `-2`, `-3`, ... number copies made in the same second. The newest 10 of each stem are kept, and other files in the folder are never touched |

### Manager access pattern

Every manager that owns save state follows the same three steps:

1. In `_ready()`, it copies the `PersistenceManager.save_game_data` reference into `live_save_data` (or `_live_save_data`).
2. It connects `PersistenceManager.save_data_reset` to a handler that re-binds the reference. Some handlers also re-emit change signals (see [Switching the save](#switching-the-save)).
3. It mutates fields on the shared instance. The change reaches disk at the next autosave.

Because `SaveGameData` is a `Resource`, a write by one manager is immediately visible to all the others.

## Data Model

### PersistenceManager

| Member | Type | Value / behaviour |
|--------|------|-------------------|
| `SAVE_PATH` | `const String` | `"user://save.tres"`, the user's own save |
| `BACKUP_DIR` | `const String` | `"user://backups"`, where the main save's backups go |
| `BACKUPS_KEPT` | `const int` | `10` |
| `save_game_data` | `SaveGameData` | The live save shared by all managers |
| `save_path` | `String` | Where the session writes. `""` is a session in memory. It starts as `SAVE_PATH`; `--save=` replaces it, and a preset session sets it to the `--save` path, or `""` |
| `main_save_path` | `String` | The user's own save, `SAVE_PATH`. `""` in a GUT run, which has none. A session on it is backed up at boot |
| `backup_dir` | `String` | Where the main save's backups go. `BACKUP_DIR` |
| `autosave_enabled` | `bool` | False after `--no-autosave` and in a GUT run: the tick and the close then write nothing |
| `save_data_reset` | signal | Emitted when a save becomes the session's, so every manager re-binds. At boot it reaches no one |

| Function | Behaviour |
|----------|-----------|
| `boot(options)` | Starts the run's session from its launch options (`null` reads `LaunchOptions.current()`): sets `autosave_enabled` and `save_path`, backs the main save up when the session is on it, then calls `open_save_file()`. With a preset (`options.preset_id`) it reads no file: it backs the main save up only when the `--save` path is the main save, then calls `use_save()` with a fresh save and that path (`""` for none), and `DevManager` builds the preset on it next. `_ready()` calls it, except in a GUT run |
| `open_save_file(path)` | Makes the file at `path` the session: the one way a file becomes it. Clears any block, moves the lock to `path`, loads the save as [Boot and load](#boot-and-load) says, and ends with `save_data_reset` |
| `use_save(save, path)` | Makes the `SaveGameData` object `save` the session's save, written to `path` (`""` keeps it in memory), then emits `save_data_reset`. Any block clears, and the lock moves to `path` |
| `save_data() -> Error` | Stamps `save_version`, then writes the save to `save_path` through a temp file. `ERR_UNAVAILABLE` for a session in memory, `ERR_LOCKED` while saving is blocked or once the lock's heartbeat finds the lock lost, writing nothing; otherwise what `SaveFiles.write_atomically()` returns |
| `autosave()` | Calls `save_data()` when `autosave_enabled` and `can_write()`, and logs a failed write with `Log.error` |
| `tick()` | The `SaveTimer`'s 5 s call: the lock's heartbeat (which beats with autosave off too), then `autosave()` |
| `can_write() -> bool` | True when the session has a file and saving is not blocked |
| `is_in_memory() -> bool` | True when `save_path` is `""` |
| `is_save_blocked() -> bool` | True when the save could not be read or checked, a newer build wrote it, or another run holds its lock or took it over. Nothing writes it until another save becomes the session's |
| `get_block_reason() -> String` | Why saving is blocked, or `""` |
| `backup_main_save() -> String` | Copies the main save into `backup_dir` and keeps its newest `BACKUPS_KEPT`. Returns the copy's path, or `""` when there is no main save file or the copy failed. `DevManager` calls it before a switch writes the user's save |
| `list_backups() -> PackedStringArray` | The main save's backups in `backup_dir`, newest first. The dev panel's Saves tab lists them |

### Helper classes

`SaveFiles` and `SaveLock` hold statics only, and take every path from the caller, so a test can point any of it at a temp folder.

| Class | File | Public functions |
|-------|------|------------------|
| `LaunchOptions` | `scripts/utils/launch_options.gd` | `parse(user_args, pinned_preset_id = "")` (returns an object with `save_path`, empty when `--save` was not given, `preset_id`, empty for no preset, `preset_from_pin` and `no_autosave`), `current()` (this process's own, parsed once, with the checkout's pin), `is_test_run()`, and the pin: `pin_file_path()`, `read_pin()`, `write_pin(preset_id)`. The static `pin_path_override` points the pin at another file, for tests only |
| `SaveFiles` | `singletons/persistence_manager/save_files.gd` | `temp_path_for(path)`, `write_atomically(resource, path)`, `write_bytes_atomically(bytes, path)` (the same temp-file write for raw bytes: it puts a copy of a save file in place of another, byte for byte), `load_save(path)`, `copy_aside(path, reason)`, `backup(path, backup_dir, keep)`, `list_backups(path, backup_dir)` |
| `SaveLock` | `singletons/persistence_manager/save_lock.gd` | `lock_path_for(save_path)`, `acquire(save_path)`, `refresh(save_path)`, `release(save_path)`, `holder_pid(save_path)`, `is_process_alive(pid)`. `STALE_AFTER_SECONDS` is 60 |

### SaveGameData fields and owners

`singletons/persistence_manager/save_game_data.gd` defines `class_name SaveGameData extends Resource`. Every field is `@export`. Each owner manager is documented in detail in the linked doc.

| Field | Type | Default | Owner | Details |
|-------|------|---------|-------|---------|
| `save_version` | `int` | `0` | PersistenceManager (every write stamps it) and `migrate()`. `0` means written before saves had versions | [Versioning](#versioning) |
| `madra` | `float` | `25.0` | ResourceManager | [RESOURCES.md](RESOURCES.md) |
| `gold` | `float` | `0.0` | ResourceManager | [RESOURCES.md](RESOURCES.md) |
| `inventory` | `InventoryData` | `new()` | InventoryManager | [INVENTORY.md](../inventory/INVENTORY.md) |
| `character_attributes` | `CharacterAttributesData` | `new()` (all 10.0) | CharacterManager | [CHARACTER.md](CHARACTER.md) |
| `core_density_xp` | `float` | `0.0` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `core_density_level` | `float` | `0.0` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `current_advancement_stage` | `CultivationManager.AdvancementStage` | `FOUNDATION` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `core_density_milestones` | `Dictionary[int, int]` | `{}` | CultivationManager (written when a milestone pays, seeded on load and on a save switch): stage → the highest milestone level already paid, so a level lost and regained pays no second path point. Missing on older saves. Cleared by `reset()` | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `unlock_progression` | `UnlockProgressionData` | `new()` | UnlockManager | [UNLOCKS.md](UNLOCKS.md) |
| `event_progression` | `EventProgressionData` | `new()` | EventManager | [EVENTS.md](EVENTS.md) |
| `quest_progression` | `QuestProgressionData` | `new()` | QuestManager | [QUESTS.md](../progression/QUESTS.md) |
| `current_selected_zone_id` | `String` | `""` | ZoneManager | [ZONES.md](../zones/ZONES.md) |
| `zone_progression_data` | `Dictionary[String, ZoneProgressionData]` | `{}` | ZoneManager (through the `SaveGameData` helpers) | [ZONES.md](../zones/ZONES.md) |
| `seen_action_ids` | `Array[String]` | `[]` | ZoneManager (`mark_action_seen()`, `mark_action_unseen()`); an available action not in it shows NEW. A technique unlock takes the cycling actions' ids out again | [ZONES.md](../zones/ZONES.md) |
| `seen_actions_initialized` | `bool` | `false` | ZoneManager: set once its first-init pass has marked every action available at that moment as seen | [ZONES.md](../zones/ZONES.md) |
| `unlocked_cycling_technique_ids` | `Array[String]` | `["foundation_technique"]` | CyclingManager | [CYCLING.md](../cycling/CYCLING.md) |
| `equipped_cycling_technique_id` | `String` | `"foundation_technique"` | CyclingManager | [CYCLING.md](../cycling/CYCLING.md) |
| `seen_cycling_technique_ids` | `Array[String]` | `[]` | CyclingManager (`mark_technique_seen()`); an unlocked technique that is neither in it nor equipped shows NEW on its drawer. Cleared by `reset()` | [CYCLING.md](../cycling/CYCLING.md) |
| `seen_cycling_techniques_initialized` | `bool` | `false` | CyclingManager: set once its first-init pass has marked every technique unlocked at that moment as seen. Cleared by `reset()` | [CYCLING.md](../cycling/CYCLING.md) |
| `unlocked_ability_ids` | `Array[String]` | `["basic_strike", "enforce"]` | AbilityManager | [ABILITIES.md](../abilities/ABILITIES.md) |
| `equipped_ability_ids` | `Array[String]` | `["basic_strike", "enforce", "", ""]` | AbilityManager | [ABILITIES.md](../abilities/ABILITIES.md) |
| `current_path_id` | `String` | `""` | PathManager | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `path_node_purchases` | `Dictionary[String, int]` | `{}` | PathManager | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `path_points` | `int` | `0` | PathManager | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `merchant_ledgers` | `Dictionary[String, MerchantLedgerData]` | `{}` | MerchantManager (through `get_merchant_ledger()`) | [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented) |
| `stats` | `PlayStatsData` | `new()` | The systems that record it | [Play stats](#play-stats) |

Apart from tests, each field is read and written only by its owning singleton, except `stats`, which several systems record into. The dev tools change state only through manager APIs (`DevCommands`). The one exception is `DevManager`, which makes the saves it plays: it sets `stats.built_from_preset` on the save it builds, and `save_as_preset()` copies the whole save.

### SaveGameData methods

| Method | Behaviour |
|--------|-----------|
| `new_current() -> SaveGameData` (static) | A new save stamped with `CURRENT_VERSION`, for a game that starts fresh. A plain `SaveGameData.new()` is version 0, the number an old file loads with |
| `is_from_newer_build() -> bool` | True when `save_version` is above `CURRENT_VERSION`: this build must neither migrate nor write such a save |
| `migrate()` | Brings a save written by an older build up to `CURRENT_VERSION` and stamps it. Does nothing to a newer one. See [Versioning](#versioning) |
| `verify() -> bool` | True if `current_selected_zone_id` is `""` or `ZoneManager.has_zone(id)`. This is the only validation performed. `PersistenceManager` calls `repair()`, which makes the same check, so nothing in the game calls `verify()` |
| `repair() -> PackedStringArray` | Fixes what `verify()` would reject, in place, and returns the names of the fields it changed (empty when there was nothing to fix). An unknown current zone goes back to `""`, which means the first zone in the list |
| `reset()` | Sets every stored field back to the default a fresh `SaveGameData.new()` declares, in place, so the managers holding the object keep a valid reference, then stamps `CURRENT_VERSION`. Defaults are declared once, on the fields, so a new field resets without being added here, and every sub-resource is a new object. Nothing in the game calls it today |
| `get_zone_progression_data(zone_id) -> ZoneProgressionData` | Returns the zone's entry, creating and storing one on first access |
| `get_merchant_ledger(merchant_id) -> MerchantLedgerData` | Returns the merchant's ledger, creating and storing an empty one on first access |
| `increment_zone_progression_for_action(action_id, zone_id, quantity) -> int` | Adds `quantity` to `action_completion_count[action_id]` (creating the zone entry if needed) and returns the new total |
| `_to_string()` | Multi-line debug summary |

### Sub-resources

Each of these is embedded in `save.tres` as a `sub_resource`.

| Class | File | Fields | Owner |
|-------|------|--------|-------|
| `InventoryData` | `singletons/persistence_manager/inventory_data.gd` | `materials: Dictionary[MaterialDefinitionData, int]`; `equipment: Dictionary` (slot index → `ItemInstanceData`); `equipped_gear: Dictionary` (`EquipmentSlot` → `ItemInstanceData`, for MAIN_HAND/OFF_HAND/HEAD/ARMOR); `equipped_accessories: Dictionary` (0/1 → `ItemInstanceData`); `quest_items: Dictionary[ItemDefinitionData, int]`; `consumables: Dictionary[ConsumableDefinitionData, int]`; `equipped_consumables: Dictionary[int, ConsumableDefinitionData]` (hotbar 0–3); `unlocked_equipment_pages: int = 2`. Constants: `PAGE_ROWS = 6`, `PAGE_COLUMNS = 6`, `SLOTS_PER_PAGE = 36`; `equipment_capacity()`, `free_equipment_slots()`, `has_free_equipment_slot()` | InventoryManager |
| `CharacterAttributesData` | `scripts/resource_definitions/character/character_attributes_data.gd` | 8 `float` fields: `strength` … `willpower` | CharacterManager |
| `UnlockProgressionData` | `singletons/persistence_manager/unlock_progression_data.gd` | `unlocked_condition_ids: Array[String]` | UnlockManager |
| `EventProgressionData` | `singletons/persistence_manager/event_progression_data.gd` | `triggered_events: Array[String]` | EventManager |
| `QuestProgressionData` | `singletons/persistence_manager/quest_progression_data.gd` | `active_quests: Dictionary[String, int]` (quest_id → 0-based step index); `completed_quest_ids: Array[String]` | QuestManager |
| `ZoneProgressionData` | `singletons/persistence_manager/zone_progression_data.gd` | `zone_id: String`; `action_completion_count: Dictionary[String, int]`; `forage_active: bool`; `forage_start_time: float`; `training_tick_progress: Dictionary[String, int]`; `last_idle_action_id: String` (the idle action the zone resumes) | ZoneManager |
| `MerchantLedgerData` | `singletons/persistence_manager/merchant_ledger_data.gd` | `merchant_id: String`; `purchase_counts: Dictionary[String, int]` (`MerchantStockEntry.entry_id` → copies bought); `get_count()`, `add_purchase()` | MerchantManager |
| `PlayStatsData` | `singletons/persistence_manager/play_stats_data.gd` | Playtime, first times and counts (see [Play stats](#play-stats)) | The systems that record each |

Item definitions are not copied into the save. The keys of the `InventoryData` dictionaries and `ItemInstanceData.item_definition` are saved as `ext_resource` references to the item `.tres` files under `res://resources/items/`. `ItemInstanceData` itself (`item_definition`, `quantity`, `instance_id`, `metadata`) is embedded.

## Core Flows

### Boot and load

```
Godot instantiates every autoload (member initializers run), then adds them
to the tree in project.godot order, running each one's _ready():

 1. PersistenceManager._ready()
      GUT run:    use_save(SaveGameData.new_current(), "")     a save in memory; nothing below runs
      otherwise:  boot()
        autosave_enabled = not --no-autosave;  save_path = --save=<path> when given
        --preset=<id> or a pinned preset:  (back the main save up first when the --save path is the main save)
                                           use_save(SaveGameData.new_current(), the --save path or "")
                                           no file is read; open_save_file() and the rest of this step do not run
        a session on the main save:  take its lock, then back it up (no backup when another run holds the lock)
        open_save_file(save_path)
          move the lock to save_path      another live run holds it → saving blocked, the save still loads
          no save and no temp file        a new save, written at once
          the file will not load          copied aside as .unreadable., saving blocked, a new save in memory
          a newer build wrote the save    saving blocked, never migrated or written; repaired in memory only
          any other save                  migrate(); then repair() (the file is copied aside as .invalid. first
                                          when it changes something), or saving blocked if ZoneManager is missing
          save_data_reset                 reaches no one yet
 2. The other autoloads, in order. The ones that own save state (the Owner column under Data Model)
      grab the live reference, connect save_data_reset, and emit or derive their initial state
 3. DevManager._ready(), the last autoload (nothing in a GUT run)
      a preset launch: builds the preset on the save step 1 bound, then clears the player's log

main_game.tscn loads → MainGame._ready() (sets Log print level) → SaveTimer starts
```

The order inside `open_save_file()`:

- **The lock comes first.** The lock on the save the session leaves is released and the one on `path` is taken. Another live run holding it blocks saving (`in use by another run (pid N)`). The save still loads below, so the session plays it, but nothing clears that block: the file is never written.
- **No save and no temp file there:** a new save (`SaveGameData.new_current()`), written at once, with an `INFO` line.
- **The file that `load_save()` reads fails to load as a `SaveGameData`.** That is the save, or its temp file when the save is missing. It is copied aside as `<name>.unreadable.<unix time>.<extension>` and left as it was, and the session runs on `SaveGameData.new_current()` in memory with saving blocked. `Log.critical` names the copy.
- **A save from a newer build** (`is_from_newer_build()`): saving blocked, never migrated and never written, so nothing is copied aside. When `ZoneManager` is there, `repair()` still runs on the object in memory, so the session never stands in a zone this build does not know. The file stays as the newer build wrote it.
- **Any other save:** `migrate()` first, then the check. When `ZoneManager` did not load (a stale import cache can do that) the save cannot be checked, and saving is blocked. Otherwise `repair()` fixes an unknown zone id and, when it changed something, the file as it was is copied aside as `<name>.invalid.<unix time>.<extension>` and a `Log.warn` names it. The repaired save is written at the next autosave.
- **Every block is logged with `Log.critical`** and keeps its reason, which `get_block_reason()` returns. Only a new session (`open_save_file()` or `use_save()`) clears a block.
- **The boot backup** is the main save as the last run left it, copied to `user://backups/` before anything can write it. The session's lock is taken first, and another live run holding it means no backup: that save is the other run's live state, and enough launches locked out of it would rotate the first run's start-of-session backup out of the newest 10. When only the temp file a cut-short write left is there, that file may be the only copy of the save, so it is the one backed up, under its own stem (`save.tmp.<stamp>.tres`), which `list_backups()` does not list.

Also at boot:

- The zone check (`repair()`'s, the same as `verify()`'s) runs before `ZoneManager._ready()`. It works only because `ZoneManager._all_zone_data` is a preloaded member default, which is set when the autoload is instantiated.
- `open_save_file()` ends with `save_data_reset`, which reaches no listeners at boot, because the other managers have not connected yet. They read the loaded save in their own `_ready()`.
- Some managers write first-run defaults into the save:
  - `ZoneManager.get_current_zone()` sets `current_selected_zone_id` to the first zone in `zone_data_list.tres` when it is empty.
  - `PathManager` sets `current_path_id = "pure_madra"` (`DEFAULT_PATH_ID`) when it is empty.
  - `AbilityManager` pads `equipped_ability_ids` to 4 slots.
  - `ZoneManager` marks every action available at that moment as seen and sets `seen_actions_initialized`, once per save.
  - `CyclingManager` marks every technique unlocked at that moment as seen and sets `seen_cycling_techniques_initialized`, once per save (again after a save switch), so an older save shows no NEW seals.
  - `ActionManager` records the zone's `last_idle_action_id` whenever an idle action starts, including the one the load's `zone_changed` resumes.

### Writing and the auto-save

`save_data()` stamps `save_version = CURRENT_VERSION` and calls `SaveFiles.write_atomically()`. That makes the save's folder, saves to the temp file (`user://save.tmp.tres`), then renames the temp over the save, so a failed save leaves the old file as it was, and a crash mid-write never leaves half a save. Windows deletes the old file before it moves the temp in, so a crash inside that rename can leave only the temp, whole. `SaveFiles.load_save()` loads the temp when the save is missing (with a `Log.warn`), and never reads a temp next to a save that exists, since a crash while saving it can leave it half-written.

`load_save()` always ignores the resource cache (`CACHE_MODE_IGNORE`), so every call reads the file again and returns its own object. It is never `CACHE_MODE_IGNORE_DEEP`: the inventory's dictionaries are keyed by the item resources the whole game shares, and a deep reload would key them by copies that no lookup finds.

- `SaveTimer.timeout` calls `PersistenceManager.tick()` every **5 seconds**, set as `wait_time = 5.0` with `autostart = true` on the `SaveTimer` node in `main_game.tscn`. `save_timer.gd` only connects `timeout`, and no code changes `wait_time`.
- `tick()` beats the lock's heartbeat, then calls `autosave()`, which writes only when `autosave_enabled` and `can_write()`. A failed write is logged with `Log.error`, and the next tick tries again.
- The whole file is written every 5 s on the main thread. While saving is blocked (an unreadable, newer, unverifiable or locked-out save), each write returns `ERR_LOCKED` and writes nothing.
- **Save on quit.** `NOTIFICATION_WM_CLOSE_REQUEST` calls `autosave()` and then releases the lock, so a normal close of a session that can write loses nothing. It writes nothing under `--no-autosave`. The editor's Stop button kills the process without a close request, so it still loses up to 5 s.
- There is no immediate save after important events.
- `SaveTimer` exists only in `main_game.tscn`. A run of any other scene has no tick: it never autosaves on a timer and never refreshes its lock, but it still saves when its window closes.

### The save lock

One run at a time writes a save. A session on a file holds that save's lock, `<save>.lock`. The file has two lines: `pid=` (the holder's process id) and `time=` (the unix time of its last heartbeat).

- **Live or stale.** A lock is live when its process is alive and its time is within `SaveLock.STALE_AFTER_SECONDS` (60 s). The process check asks the OS, `tasklist` on Windows (about 100 ms, so it runs only for a recent lock) and `kill -0` elsewhere, because `OS.is_process_running()` only knows the processes this one started. A stale lock (its run crashed, was killed or hung) is taken over by the next run.
- **Taking it.** `acquire()` succeeds when there is no lock, the lock is stale, or it is already this run's. `PersistenceManager` takes it when a session starts on a file (before the boot backup, for the main save) and moves it when the session moves to another file. A refused session plays its save with saving blocked. A lock file that cannot be written is logged by `SaveLock` but still counts as taken, so the session finds its lock missing at its first write or tick and blocks (`its lock file is gone`).
- **The heartbeat** moves `time=` to now, in `tick()` (also under `--no-autosave`) and at the start of every `save_data()`. The tick comes from the `SaveTimer`, which runs only while `main_game.tscn` does: a run of any other scene takes the lock at boot and never refreshes it, so after 60 s another run may take it over.
- **Losing it.** A session whose lock another run took over (a different pid is in the file), or whose lock file is gone, finds out at its next tick or write. It blocks with `taken over by another run (pid N)` or `(its lock file is gone)` and writes nothing from then on.
- **Giving it up.** The close request releases the lock after its last write. `release()` deletes only a lock that holds this run's pid, so a run never deletes another run's lock.
- **Advisory only.** Two runs that open one save within the same few milliseconds can both win it.

### Switching the save

A save becomes the session's through `open_save_file()` (boot, and any later switch to a file) or `use_save()` (a `SaveGameData` object and the path it writes to). Apart from boot, only `DevManager` calls them: it builds a preset at launch and switches sessions in game ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#switching-sessions)). Both end by emitting `save_data_reset`, and each listener re-binds to `PersistenceManager.save_game_data` and does the following:

| Manager | Re-emits / extra work |
|---------|-----------------------|
| ResourceManager | `madra_changed`, `gold_changed` |
| CultivationManager | `core_density_xp_updated`, `core_density_level_updated`, `advancement_stage_changed`. Before them it sets a level past the stage's cap to the cap with no XP (`Log.info`), then seeds a stage with no ledger entry from `floor(level / 10) × 10` |
| CharacterManager | `base_attribute_changed` for all 8 attributes |
| ZoneManager | `zone_changed(get_current_zone())` |
| UnlockManager | `condition_unlocked("")` |
| PathManager | Clears the tree and effects, then restores the current path, which emits `path_set`, `effects_changed` and `points_changed` |
| QuestManager | Drops active quests that are missing from the catalog |
| AbilityManager | Pads `equipped_ability_ids` to 4 slots |
| CyclingManager | Re-binds, then runs the seen-technique first-init pass |
| InventoryManager, EventManager | Re-bind only |

`use_save()` swaps the new object in and never resets the old one in place. `ActionManager` remembers the save its current action started under, so stopping that action after a swap counts no completion and runs no effect in the new save.

### What is not saved

| State | Where it lives |
|-------|----------------|
| An in-progress adventure (map, tile, visited tiles, timer) | `AdventureView` / `AdventureTilemap` nodes |
| Player vitals (health, stamina, combat Madra) | `PlayerManager.vitals_manager`. These are re-initialized at each adventure start |
| The current action and its timers (cycling, foraging, training ticks in flight) | `ActionManager`, `CyclingTechnique` (the running cycle, with its snapshot and the last finished cycle's result on `CyclingManager`; the Auto toggle is `CyclingView`'s). Completed training ticks are saved in `training_tick_progress`, and each zone's `last_idle_action_id` is, so the load restarts that idle action (nothing accrues while the game is closed) |
| The log history (`LogManager`, 200 lines), the dev zone toggles | `LogManager`, `ZoneManager` |
| The dev panel's open state, place and tab, and the time speed | `DevManager` (`panel_open`, `panel_position`, `panel_tab`) and `GameSpeed` (`base_scale`). They outlast a session switch, which loads the main scene again, but not a relaunch |
| Which session is running, why saving is blocked, and the lock | `PersistenceManager` (`save_path`, `is_save_blocked()`, `get_block_reason()`) and the lock file. `DevManager` keeps what the session plays (`get_session_kind()`, `get_session_preset()`); a save names its preset only in `stats.built_from_preset` |
| `PlayStatsData.recording_paused` | The `PlayStatsData` instance: a plain `var`, not an `@export` |
| Dialogic state | Not used. Nothing calls `Dialogic.Save` |

## Versioning

`SaveGameData.CURRENT_VERSION` is 1, the save format this build writes. `save_version` is the version a save was written at. Every write stamps it (`save_data()`), and so do a new save (`new_current()`), `reset()` and `migrate()`.

**The default trap.** `save_version` defaults to 0, which means "written before saves had versions", and must never default to `CURRENT_VERSION`. Godot builds a loaded resource with `new()` and then sets only the keys the file holds, so a default of `CURRENT_VERSION` would make every old file look current and skip its migration. A fresh game gets the current version from `SaveGameData.new_current()`, not from `new()`.

`PersistenceManager` calls `migrate()` on every save it loads (a `--save` file included) except one from a newer build, after the load and before the check. `migrate()` itself does the following:

1. A save from a newer build (`save_version` above `CURRENT_VERSION`) is left alone: no step runs and the version is not stamped. `PersistenceManager` never gets that far with one: it plays the save with saving blocked.
2. The version steps, each run once for a save older than its version. Version 1 moves the accessories an old save keeps in `inventory.equipped_gear` under keys 4 and 5 (the old `ACCESSORY_1` and `ACCESSORY_2`) into slots 0 and 1 of `equipped_accessories`, in that order. A slot that is already taken keeps its item, and the old accessory stays in `equipped_gear`, named in a `Log.warn`.
3. The hidden-zone move: `current_selected_zone_id` goes through `ZONE_ID_MIGRATIONS` (`{"TestZone": "SpiritValley"}`), so a save standing in the now hidden Test Zone moves to Spirit Valley. It is not a version step: it runs on every load, whatever the save's version, because the dev panel can walk a save into Test Zone and its toggle resets on the next launch.
4. It stamps `CURRENT_VERSION`.

A schema change bumps `CURRENT_VERSION`, adds a version step, and adds an `if save_version < N` line to `migrate()`. When a schema changes without a step:

- An added field loads with its declared default. `CultivationManager` then repairs, when it reads the save, what the default cannot know: a save from before `core_density_milestones` gets the ledger seeded from its level (so no milestone pays twice), and a level past the stage's cap (Core Density was uncapped) loads at the cap with no XP. Path points already earned stay.
- A field whose stored shape changes is not converted. Commit `1ce7ecd` (2026-05-23) replaced `CharacterAttributesData.attributes` (a dictionary) with 8 float fields, and no step converts it: such a save loads with its attributes at their defaults. Its message says old saves "are incompatible and must be reset (no migration shim)".
- Enum values are stored as integers. Commit `0652b49` (2026-05-24) collapsed `EquipmentSlot.ACCESSORY_1`/`ACCESSORY_2` (4/5) into a single `ACCESSORY` (4) and moved equipped accessories into the new `equipped_accessories` dictionary. Version step 1 moves the accessories a save still holds in `equipped_gear`.

A build that has `save_version` plays a newer save with saving blocked instead of writing over it. A build from before saves had versions cannot tell: a save that has reached Copper, opened in a build from before the Tribulation, still hits the endless level-up loop (no Copper stage resource, so each level costs 0 XP). The loop guard only protects builds that have it.

Some managers tolerate stale ids in their own way, which covers what no migration step does:

- `QuestManager` drops active quests that are missing from the catalog.
- `AbilityManager` and `CyclingManager` skip unknown ids when resolving data, and `AbilityManager` pads the loadout to 4 slots.
- `PathManager` falls back to `pure_madra` only when `current_path_id` is empty.

## Play stats

`SaveGameData.stats` is a `PlayStatsData` sub-resource that records how the save has been played. Each figure is recorded by the system that owns the moment, through the `record_*`, `count_*` and `add_*` functions on the live save's stats.

| Field | What it holds | Recorded by |
|-------|---------------|-------------|
| `play_time` | Seconds of game time while `main_game.tscn` runs, scaled by `Engine.time_scale`, so a dev time speed ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#time-speed)) of ×10 counts ten times as fast | `MainGame._process()` (`add_play_time()`) |
| `event_first_times` | Event id → the `play_time` at which it first fired. A repeat keeps the first time | `EventManager.trigger_event()`, in its first-time branch |
| `condition_first_times` | Unlock condition id → the `play_time` at which it first latched. A repeat keeps the first time. An empty id is skipped: `UnlockManager` announces `""` on every save switch | `UnlockManager`, when a condition first unlocks |
| `cycles_finished` | Cycles that ran to their end | `CyclingManager.set_last_cycle_result()`, which the cycling board calls when a cycle ends. A null result is no cycle |
| `adventures_started` | Adventures started, counted when the run begins, after the Madra drain | `ActionManager.confirm_adventure_start()`: the real start, since the request (`adventure_start_requested`) can repeat |
| `adventures_won`, `adventures_lost`, `adventures_timed_out` | Adventures that ended in a win (the boss fell), with the player's Health at 0, or when the run's time ran out | `AdventureView.stop_adventure()`, only while a run is on (`is_adventure_running()`). A retreat counts nothing, and neither does a stop before the run starts (the Madra drain) |
| `fights_won` | Fights won, boss fights included, each counted once | `AdventureTilemap.handle_combat_result()`, while the fight's choice is still pending: `AdventureCombat` can report a win again, and the repeat finds the choice cleared |
| `gold_earned` | Gold earned: every positive amount added, never a set, a spend or a take-away | `ResourceManager.add_gold()` |
| `built_from_preset` | The id of the preset the save was built from, `""` for real play, so a preset's stats are never read as a playtest's | `DevManager.build_preset()` |

`first_time_of(id)` returns the `play_time` at which the event with that id first fired, else the one at which the condition with that id first latched, else `-1.0`.

`recording_paused` is a flag for code that runs game logic on the player's behalf, which must not count as play (a dev command, say). Each `DevCommands` command sets it for the game code it runs and puts it back as it found it, and `DevManager.build_preset()` sets it for the whole build of a preset. It is a plain `var`, so it is never saved. While it is true the `record_*`, `count_*` and `add_gold_earned()` functions record nothing. `add_play_time()` ignores it: time passes whatever a command does.

`SaveGameData.reset()` hands back a new, empty `PlayStatsData`.

## Integration Points

| System | Connection |
|--------|------------|
| All save-owning singletons | Hold the live `SaveGameData` reference and connect `save_data_reset` |
| `ZoneManager` | `has_zone()` backs the zone check of `SaveGameData.verify()` and `repair()`; it uses the `SaveGameData` zone helpers |
| `ActionManager` | Remembers the save its current action started under (see [Switching the save](#switching-the-save)); counts an adventure start in the play stats |
| `MainGame` / `SaveTimer` | `SaveTimer` calls `PersistenceManager.tick()` every 5 s; `MainGame._process()` adds each frame to the playtime |
| The play stats recorders | `EventManager`, `UnlockManager`, `CyclingManager`, `AdventureView`, `AdventureTilemap` and `ResourceManager` (see [Play stats](#play-stats)) |
| `DevManager` | Builds a preset session (`use_save()` on a save it makes), switches sessions in game (`open_save_file()`, `use_save()`, `autosave()`, `backup_main_save()`, `save_data()`), copies the session's save into a snapshot preset and sets `stats.built_from_preset`. See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#devmanager) |
| `Log` | Boot diagnostics (`Log.info` / `Log.warn` / `Log.error` / `Log.critical`) |
| Tests | A GUT run plays a save in memory, so no test reads or writes the real save. Test files replace `PersistenceManager.save_game_data` with `SaveGameData.new()` and emit `save_data_reset`, and several more replace the inventory or a manager's `live_save_data`. The `PersistenceManager` tests build their own instances on temporary files ([TESTING.md](../testing/TESTING.md)) |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/persistence_manager/persistence_manager.gd` | Sessions, load, repair, write, backups, the lock |
| `singletons/persistence_manager/save_files.gd` | Temp-file writes, loads, copies aside, backups |
| `singletons/persistence_manager/save_lock.gd` | One writer per save |
| `scripts/utils/launch_options.gd` | Launch options, the pin and test-run detection |
| `singletons/persistence_manager/save_game_data.gd` | Root save schema, version, `migrate()`, `repair()`, `verify()`, `reset()`, zone helpers |
| `singletons/persistence_manager/play_stats_data.gd` | Play stats sub-resource |
| `singletons/persistence_manager/inventory_data.gd` | Inventory sub-resource |
| `singletons/persistence_manager/zone_progression_data.gd` | Per-zone progression sub-resource |
| `singletons/persistence_manager/quest_progression_data.gd` | Quest sub-resource |
| `singletons/persistence_manager/unlock_progression_data.gd` | Unlock sub-resource |
| `singletons/persistence_manager/event_progression_data.gd` | Event sub-resource |
| `scripts/resource_definitions/character/character_attributes_data.gd` | Attribute sub-resource |
| `scenes/main/main_game/save_timer.gd` | The 5 s tick (node in `main_game.tscn`) |

Tests: `tests/unit/test_persistence_manager.gd` and `tests/unit/test_save_migration.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[LOW]` Saving that is off is silent to the player. An unreadable save, a save from a newer build, and a save another run holds the lock on (or took over) all run with saving blocked, and only the console, the log file and the dev panel's Saves tab say why (`Log.critical`, and the tab's session line). `get_block_reason()` returns it, but no screen a player sees shows it.

### Missing Functionality

- `[LOW]` In-progress adventures and action timers are not saved (see [What is not saved](#what-is-not-saved)). Quitting mid-adventure forfeits the Madra drained at its start.
- `[LOW]` A player has one save, the user's own `user://save.tres`. Another file is reachable only through `--save=`.
- `[LOW]` The lock's heartbeat runs only in `main_game.tscn`, the one scene with a `SaveTimer`. A run of any other scene holds its lock for 60 s at most. After that another run may take the save over, and the first run then blocks itself and writes nothing when its window closes.

### Tech Debt

- `[LOW]` `ZoneProgressionData.forage_active` and `forage_start_time` are saved but the game never reads or writes them.
- `[LOW]` The zone check depends on autoload timing. `repair()` makes it before `ZoneManager._ready()` and relies on `_all_zone_data` being a preloaded member default. Moving that load into `_ready()` would make every save with a selected zone fail the check, and `repair()` would send each one back to the first zone.
- `[LOW]` `boot()` recognises the main save by comparing path strings, so a `--save` that names the same file another way (`user://./save.tres`, or its absolute path) is a plain file session: no boot backup, and a lock file under another name.
- `[LOW]` The save is a `.tres` resource. Godot resource files can embed scripts, so a shared or edited save file could run code when loaded. Consider a data-only format before saves are exchanged between players.
