# Persistence System

Last updated: 2026-10-24

## Overview

`PersistenceManager` (autoload #1) owns the game's single save object, a `SaveGameData` resource. It loads `user://save.tres` at boot and validates it. The `SaveTimer` node in `main_game.tscn` writes it back every 5 seconds. Every other manager holds a live reference to the same `SaveGameData` instance and reads and writes its own fields directly. There is no per-manager serialization step.

**Does progress persist between launches?** Yes. `reset_save_data` is `false` at `singletons/persistence_manager/persistence_manager.gd:5` (since commit `e4f47e0`, 2026-05-28), so the save loads unchanged on the next launch. The exceptions are:

| Situation | Result |
|-----------|--------|
| `reset_save_data` set to `true` in the script | The save is wiped on every boot. It was `true` from 2026-05-23 (`a0bc58d`) to 2026-05-28, and the flag has changed 7 times since it was added in Nov 2025 |
| `SaveGameData.verify()` fails (an unknown `current_selected_zone_id`) | The file is first copied to `save.invalid.<unix time>.tres`, then the whole save is reset and overwritten, with `Log.critical`. `migrate()` runs first, so an id listed in `ZONE_ID_MIGRATIONS` (Test Zone) moves instead |
| `save.tres` exists but does not load as a `SaveGameData` | The file is copied to `save.unreadable.<unix time>.tres` and left untouched. The session runs on a default save in memory, and `save_data()` refuses to write (`ERR_LOCKED`) until the game restarts. `Log.critical` names the copy |
| `ZoneManager` failed to load, so `verify()` cannot run | The loaded save is kept in memory but not checked, and saving is off for the session (`Log.critical`). Nothing is reset |
| The save predates the 2026-05-23/24 schema changes | Incompatible, with no migration. See [Versioning](#versioning) |
| The game quits less than 5 s after a change | That change is lost, because nothing saves on quit |

## Player Experience

- There is no save/load UI, no save slots, and no "New Game" option. Progress saves silently every 5 seconds and is restored on launch.
- Quitting mid-adventure loses the adventure: the map, position, vitals and timer. The Madra drained to start it, and any gold or loot already awarded, stay as they were at the last 5 s tick.
- To start over, a developer sets `reset_save_data = true` for one launch, or deletes `save.tres`.
- After pulling or merging new art, run `--headless --import` before running the game or the tests. Without it, an item `.tres` the save names can fail to load its new texture, which makes the whole save unreadable. PersistenceManager then keeps the file and turns saving off, so the run shows a fresh game, but nothing is lost: re-import and launch again.

## Architecture

```
PersistenceManager (autoload Node)          singletons/persistence_manager/persistence_manager.gd
  save_game_data: SaveGameData  ── same instance ──►  live_save_data / _live_save_data in 11 managers
  signal save_data_reset

MainGame (main_game.tscn)
  SaveTimer (Timer)                          scenes/main/main_game/save_timer.gd
    wait_time = 5.0, autostart = true, repeating
    timeout ──► PersistenceManager.save_data()
```

### Save file location

The save file is `user://save.tres`, in Godot's text-resource format, written by `ResourceSaver.save()`. The project does not set `application/config/use_custom_user_dir`, so `user://` is Godot's default per-project folder (on Windows, `%APPDATA%\Godot\app_userdata\EndlessPath\`). Editor runs, exported builds and headless GUT runs all share this folder. It also holds `logs-YYYY-MM-DD.log` (see [LOGGING.md](LOGGING.md)).

### Manager access pattern

Every manager that owns save state follows the same three steps:

1. In `_ready()`, it copies the `PersistenceManager.save_game_data` reference into `live_save_data` (or `_live_save_data`).
2. It connects `PersistenceManager.save_data_reset` to a handler that re-binds the reference. Some handlers also re-emit change signals (see [Reset](#reset)).
3. It mutates fields on the shared instance. The change reaches disk at the next `SaveTimer` tick.

Because `SaveGameData` is a `Resource`, a write by one manager is immediately visible to all the others.

## Data Model

### PersistenceManager

| Member | Type | Value / behaviour |
|--------|------|-------------------|
| `SAVE_PATH` | `const String` | `"user://save.tres"` |
| `reset_save_data` | `@export bool` | `false`. When `true`, `_ready()` calls `load_new_save_data()` on every boot. The autoload is a bare script, not a scene, so this can only be changed by editing the script default |
| `save_game_data` | `SaveGameData` | The live save shared by all managers |
| `save_path` | `String` | `SAVE_PATH`. Where the manager reads and writes. Only tests point it elsewhere |
| `_save_blocked` | `bool` | Set when the save could not be read or checked this session. `save_data()` then refuses to write |
| `save_data_reset` | signal | Emitted by `load_new_save_data()` after a reset |

| Function | Behaviour |
|----------|-----------|
| `boot()` | Called by `_ready()`: `load_data()`, `migrate()`, the `reset_save_data` reset, then `verify()` (see [Boot and load](#boot-and-load)). It stops after `load_data()` when the save could not be read |
| `load_data()` | If the file is missing, it creates `SaveGameData.new()`, saves it, and logs info. It then calls `ResourceLoader.load(save_path)`. If that does not return a `SaveGameData`, it copies the file aside as `<name>.unreadable.<unix time>.tres`, blocks saving for the session, and runs on `SaveGameData.new()` in memory (`Log.critical`) |
| `save_data() -> Error` | `ResourceSaver.save(save_game_data, save_path)`, or `ERR_LOCKED` without writing while saving is blocked |
| `is_save_blocked() -> bool` | True when the save on disk could not be read or checked this session |
| `load_new_save_data()` | Calls `save_game_data.reset()` (in place, so all references stay valid), then `save_data()` (`Log.critical` on error), then emits `save_data_reset` |

### SaveGameData fields and owners

`singletons/persistence_manager/save_game_data.gd` defines `class_name SaveGameData extends Resource`. Every field is `@export`. Each owner manager is documented in detail in the linked doc.

| Field | Type | Default | Owner | Details |
|-------|------|---------|-------|---------|
| `madra` | `float` | `25.0` | ResourceManager | [RESOURCES.md](RESOURCES.md) |
| `gold` | `float` | `0.0` | ResourceManager | [RESOURCES.md](RESOURCES.md) |
| `inventory` | `InventoryData` | `new()` | InventoryManager | [INVENTORY.md](../inventory/INVENTORY.md) |
| `character_attributes` | `CharacterAttributesData` | `new()` (all 10.0) | CharacterManager | [CHARACTER.md](CHARACTER.md) |
| `core_density_xp` | `float` | `0.0` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `core_density_level` | `float` | `0.0` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `current_advancement_stage` | `CultivationManager.AdvancementStage` | `FOUNDATION` | CultivationManager | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
| `core_density_milestones` | `Dictionary[int, int]` | `{}` | CultivationManager (`_pay_milestone()`, seeded in `_update_resources()`): stage → the highest milestone level already paid, so a level lost and regained pays no second path point. Missing on older saves. Cleared by `reset()` | [CULTIVATION.md](../cultivation/CULTIVATION.md) |
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

Apart from tests, each field is read and written only by its owning singleton. `DevPanel` changes state only through manager APIs.

### SaveGameData methods

| Method | Behaviour |
|--------|-----------|
| `get_zone_progression_data(zone_id) -> ZoneProgressionData` | Returns the zone's entry, creating and storing one on first access |
| `get_merchant_ledger(merchant_id) -> MerchantLedgerData` | Returns the merchant's ledger, creating and storing an empty one on first access |
| `increment_zone_progression_for_action(action_id, zone_id, quantity) -> int` | Adds `quantity` to `action_completion_count[action_id]` (creating the zone entry if needed) and returns the new total |
| `migrate()` | Moves `current_selected_zone_id` through `ZONE_ID_MIGRATIONS` (`{"TestZone": "SpiritValley"}`), so a save standing in the now hidden Test Zone moves to Spirit Valley. Runs after loading and before `verify()` |
| `verify() -> bool` | Returns `_verify_current_selected_zone_id()`: true if the id is `""` or `ZoneManager.has_zone(id)`. This is the only validation performed |
| `reset()` | Sets every field back to its default. The defaults are written out a second time here |
| `_to_string()` | Multi-line debug summary |

### Sub-resources

Each of these is embedded in `save.tres` as a `sub_resource`.

| Class | File | Fields | Owner |
|-------|------|--------|-------|
| `InventoryData` | `singletons/persistence_manager/inventory_data.gd` | `materials: Dictionary[MaterialDefinitionData, int]`; `equipment: Dictionary` (slot index → `ItemInstanceData`); `equipped_gear: Dictionary` (`EquipmentSlot` → `ItemInstanceData`, for MAIN_HAND/OFF_HAND/HEAD/ARMOR); `equipped_accessories: Dictionary` (0/1 → `ItemInstanceData`); `quest_items: Dictionary[ItemDefinitionData, int]`; `consumables: Dictionary[ConsumableDefinitionData, int]`; `equipped_consumables: Dictionary[int, ConsumableDefinitionData]` (hotbar 0–3); `unlocked_equipment_pages: int = 2`. Constants: `PAGE_ROWS = 6`, `PAGE_COLUMNS = 6`, `SLOTS_PER_PAGE = 36`; `equipment_capacity()`, `has_free_equipment_slot()` | InventoryManager |
| `CharacterAttributesData` | `scripts/resource_definitions/character/character_attributes_data.gd` | 8 `float` fields: `strength` … `willpower` | CharacterManager |
| `UnlockProgressionData` | `singletons/persistence_manager/unlock_progression_data.gd` | `unlocked_condition_ids: Array[String]` | UnlockManager |
| `EventProgressionData` | `singletons/persistence_manager/event_progression_data.gd` | `triggered_events: Array[String]` | EventManager |
| `QuestProgressionData` | `singletons/persistence_manager/quest_progression_data.gd` | `active_quests: Dictionary[String, int]` (quest_id → 0-based step index); `completed_quest_ids: Array[String]` | QuestManager |
| `ZoneProgressionData` | `singletons/persistence_manager/zone_progression_data.gd` | `zone_id: String`; `action_completion_count: Dictionary[String, int]`; `forage_active: bool`; `forage_start_time: float`; `training_tick_progress: Dictionary[String, int]`; `last_idle_action_id: String` (the idle action the zone resumes) | ZoneManager |
| `MerchantLedgerData` | `singletons/persistence_manager/merchant_ledger_data.gd` | `merchant_id: String`; `purchase_counts: Dictionary[String, int]` (`MerchantStockEntry.entry_id` → copies bought); `get_count()`, `add_purchase()` | MerchantManager |

Item definitions are not copied into the save. The keys of the `InventoryData` dictionaries and `ItemInstanceData.item_definition` are saved as `ext_resource` references to the item `.tres` files under `res://resources/items/`. `ItemInstanceData` itself (`item_definition`, `quantity`, `instance_id`, `metadata`) is embedded.

## Core Flows

### Boot and load

```
Godot instantiates all 17 autoloads (member initializers run), then adds them
to the tree in project.godot order, running each one's _ready():

 1. PersistenceManager._ready()
      boot()
        load_data()                      missing → create + save; unreadable → copy aside, block saving, stop
        save_game_data.migrate()         listed zone ids move before verify() (Test Zone → Spirit Valley)
        if reset_save_data:  load_new_save_data()
        if ZoneManager did not load:     block saving, stop (the save cannot be checked)
        if not save_game_data.verify():
            copy the file aside;  Log.critical("...invalid. Resetting to default.");  load_new_save_data()
 2–17. CultivationManager, EventManager, CharacterManager, UnlockManager, ResourceManager,
      ZoneManager, ActionManager, InventoryManager, Dialogic, DialogueManager, PlayerManager,
      LogManager, CyclingManager, AbilityManager, PathManager, QuestManager
      the 11 save-owning ones: grab the live reference, connect save_data_reset,
      emit or derive their initial state

main_game.tscn loads → MainGame._ready() (sets Log print level) → SaveTimer starts
```

- `verify()` runs before `ZoneManager._ready()`. It works only because `ZoneManager._all_zone_data` is a preloaded member default, which is set when the autoload is instantiated.
- If a reset happens during boot, the `save_data_reset` emission reaches no listeners, because the other managers have not connected yet. They read the reset data in their own `_ready()`.
- Some managers write first-run defaults into the save:
  - `ZoneManager.get_current_zone()` sets `current_selected_zone_id` to the first zone in `zone_data_list.tres` when it is empty.
  - `PathManager._restore_current_path()` sets `current_path_id = "pure_madra"` (`DEFAULT_PATH_ID`) when it is empty.
  - `AbilityManager._ensure_equipped_array_size()` pads `equipped_ability_ids` to 4 slots.
  - `ZoneManager._initialize_seen_actions()` marks every action available at that moment as seen and sets `seen_actions_initialized`, once per save.
  - `CyclingManager._initialize_seen_techniques()` marks every technique unlocked at that moment as seen and sets `seen_cycling_techniques_initialized`, once per save (again after a reset), so an older save shows no NEW seals.
  - `ActionManager` records the zone's `last_idle_action_id` whenever an idle action starts, including the one the load's `zone_changed` resumes.

### Auto-save

`SaveTimer.timeout` calls `PersistenceManager.save_data()`, which calls `ResourceSaver.save(save_game_data, "user://save.tres")`.

- The interval is **5 seconds**, set as `wait_time = 5.0` with `autostart = true` on the `SaveTimer` node (`scenes/main/main_game/main_game.tscn:332-333`). `save_timer.gd` only connects `timeout`, and no code changes `wait_time`. Older docs said Godot's 1 s default applied, but the 5 s value has been set since `f6bcc53` (PR #6, 2026-04-06).
- The whole file is written every 5 s on the main thread, straight to `save.tres` with no backup copy. While saving is blocked (an unreadable or unverifiable save at boot), each tick returns `ERR_LOCKED` and writes nothing.
- The returned `Error` is ignored on timer saves.
- There is no save on quit (no `NOTIFICATION_WM_CLOSE_REQUEST` handler) and no immediate save after important events.
- `SaveTimer` exists only in `main_game.tscn`. Running another scene directly loads the save but never writes it.

### Reset

Only two things trigger a reset, both during boot: `reset_save_data = true`, or a failed `verify()`. The dev panel has no reset button; its spec lists "Save wipe, force-save, reload" as deferred ([dev panel spec](../superpowers/specs/2026-04-20-dev-panel-design.md)).

`load_new_save_data()` calls `reset()`, saves, and emits `save_data_reset`. Each listener then does the following:

| Manager | Handler | Re-emits / extra work |
|---------|---------|-----------------------|
| ResourceManager | `_update_resources` | `madra_changed`, `gold_changed` |
| CultivationManager | `_update_resources` | `core_density_xp_updated`, `core_density_level_updated`, `advancement_stage_changed`. Before them it sets a level past the stage's cap to the cap with no XP (`Log.info`), then seeds a stage with no ledger entry from `floor(level / 10) × 10` |
| CharacterManager | `_update_resources` | `base_attribute_changed` for all 8 attributes |
| ZoneManager | `_initialize_from_save` | `zone_changed(get_current_zone())` |
| UnlockManager | `_initialize_from_save` | `condition_unlocked("")` |
| PathManager | `_on_save_data_reset` | Clears the tree and effects, then `_restore_current_path()`, which emits `path_set`, `effects_changed` and `points_changed` |
| QuestManager | `_on_save_data_reset` | `_prune_unknown_active_quests()` |
| AbilityManager | `_on_save_data_reset` | `_ensure_equipped_array_size()` |
| CyclingManager | `_on_save_data_reset` | Re-binds, then runs the seen-technique first-init pass |
| InventoryManager, EventManager | re-bind only | — |

### What is not saved

| State | Where it lives |
|-------|----------------|
| An in-progress adventure (map, tile, visited tiles, timer) | `AdventureView` / `AdventureTilemap` nodes |
| Player vitals (health, stamina, combat Madra) | `PlayerManager.vitals_manager`. These are re-initialized at each adventure start |
| The current action and its timers (cycling, foraging, training ticks in flight) | `ActionManager`, `CyclingTechnique` (the running cycle, with its snapshot and the last finished cycle's result on `CyclingManager`; the Auto toggle is `CyclingView`'s). Completed training ticks are saved in `training_tick_progress`, and each zone's `last_idle_action_id` is, so the load restarts that idle action (nothing accrues while the game is closed) |
| The log history (`LogManager`, 200 lines), the dev panel's position and unlock, the dev zone toggles | `LogManager`, scene nodes, `MainGame._dev_unlocked`, `ZoneManager` |
| Dialogic state | Not used. Nothing calls `Dialogic.Save` |

## Versioning

`SaveGameData` has no version field. The only migration code is `migrate()`, which moves listed zone ids before `verify()`. When a schema changes:

- An added field loads with its declared default. `CultivationManager._update_resources()` then repairs what the default cannot know: a save from before `core_density_milestones` gets the ledger seeded from its level (so no milestone pays twice), and a level past the stage's cap (Core Density was uncapped) loads at the cap with no XP (`cultivation_manager.gd:62-83`). Path points already earned stay.
- A field whose stored shape changes is not converted. Commit `1ce7ecd` (2026-05-23) replaced `CharacterAttributesData.attributes` (a dictionary) with 8 float fields. Its message says old saves "are incompatible and must be reset (no migration shim)", which is why `reset_save_data` was switched on that day.
- Enum values are stored as integers. Commit `0652b49` (2026-05-24) collapsed `EquipmentSlot.ACCESSORY_1`/`ACCESSORY_2` (4/5) into a single `ACCESSORY` (4) and moved equipped accessories into the new `equipped_accessories` dictionary. Accessories already saved in `equipped_gear` under keys 4 and 5 are not moved across.

The reverse direction is not covered: a save that has reached Copper, opened in a build from before the Tribulation, still hits the endless level-up loop (no Copper stage resource, so each level costs 0 XP). The loop guard only protects builds that have it.

Some managers tolerate stale ids in their own way, which partly makes up for the missing migrations:

- `QuestManager` drops active quests that are missing from the catalog.
- `AbilityManager` and `CyclingManager` skip unknown ids when resolving data, and `AbilityManager` pads the loadout to 4 slots.
- `PathManager` falls back to `pure_madra` only when `current_path_id` is empty.

## Integration Points

| System | Connection |
|--------|------------|
| All save-owning singletons (11) | Hold the live `SaveGameData` reference and connect `save_data_reset` |
| `ZoneManager` | `has_zone()` backs `SaveGameData.verify()`; it uses the `SaveGameData` zone helpers |
| `MainGame` / `SaveTimer` | The 5 s auto-save |
| `Log` | Boot diagnostics (`Log.info` / `Log.warn` / `Log.critical`) |
| Tests | 11 test files replace `PersistenceManager.save_game_data` with `SaveGameData.new()` and emit `save_data_reset`, and several more replace the inventory or a manager's `live_save_data`. None call `save_data()` |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/persistence_manager/persistence_manager.gd` | Load, verify, reset, save |
| `singletons/persistence_manager/save_game_data.gd` | Root save schema, zone helpers, `verify()`, `reset()` |
| `singletons/persistence_manager/inventory_data.gd` | Inventory sub-resource |
| `singletons/persistence_manager/zone_progression_data.gd` | Per-zone progression sub-resource |
| `singletons/persistence_manager/quest_progression_data.gd` | Quest sub-resource |
| `singletons/persistence_manager/unlock_progression_data.gd` | Unlock sub-resource |
| `singletons/persistence_manager/event_progression_data.gd` | Event sub-resource |
| `scripts/resource_definitions/character/character_attributes_data.gd` | Attribute sub-resource |
| `scenes/main/main_game/save_timer.gd` | Auto-save timer script (node in `main_game.tscn`) |
| `tests/unit/test_quest_progression_persistence.gd` | `QuestProgressionData` save/load round trip and `reset()` |
| `tests/unit/test_zone_progression_data.gd` | `ZoneProgressionData.training_tick_progress` and `last_idle_action_id` round trips |
| `tests/unit/test_save_migration.gd` | `migrate()` and an old save loading the zone view's new fields with their defaults |
| `tests/unit/test_persistence_manager.gd` | `boot()` / `load_data()` / `save_data()` on temporary paths: an unreadable save is kept, copied aside and never written; an invalid save is copied aside before its reset; an unverifiable save is not reset; `boot()` migrates the loaded save |
| `tests/unit/test_seen_actions.gd` | `seen_action_ids`, the once-per-save first-init pass and `mark_action_unseen()` (a technique unlock lights the cycling card) |
| `tests/unit/test_cycling_technique_data.gd`, `tests/unit/test_cycling_manager.gd` | The seen-technique fields: `reset()`, a save round trip, the first-init pass and its rerun on `save_data_reset` |
| `tests/unit/test_merchant_data.gd` | `merchant_ledgers` round trip, `reset()`, and an old save without the field |
| `tests/unit/test_cultivation_manager.gd` | `core_density_milestones`: a save round trip through `ResourceSaver` (the ledger is written, so a regained level pays nothing after a restart), `reset()`, the seed for an old save, and a save past the cap loading at it with its path points kept |
| `tests/unit/test_inventory_manager_restore.gd` | `InventoryManager.restore_*` against the live save (in memory only) |

## Work Remaining

### Bugs

- `[MEDIUM]` A failed `verify()` wipes the entire save. `PersistenceManager._ready()` calls `load_new_save_data()` when `current_selected_zone_id` names an unknown zone (for example, after a zone id is renamed without an entry in `SaveGameData.ZONE_ID_MIGRATIONS`). It should repair that one field to `""` instead.
- `[LOW]` An unreadable save is kept and copied aside, but the player is not told. The session silently runs on a default save with saving off; only the console and log file say why.

### Missing Functionality

- `[HIGH]` No save versioning, and no general migration. Schema changes have already broken saves twice (`1ce7ecd`, `0652b49`). This blocks giving builds to players whose saves must survive updates. `SaveGameData.migrate()` is the hook to grow: add a `save_version` field and per-version steps there (today it only moves listed zone ids).
- `[MEDIUM]` No save on quit. Saves happen only on the 5 s timer, so add a `NOTIFICATION_WM_CLOSE_REQUEST` handler that calls `save_data()`.
- `[MEDIUM]` No runtime reset or new-game path. A wipe needs a script edit (`reset_save_data`), which is easy to forget and ship (it was on for five days in May 2026). Add the deferred dev-panel "Save wipe / force-save / reload" actions, or a command-line flag, and keep the script default `false`.
- `[LOW]` In-progress adventures and action timers are not saved (see [What is not saved](#what-is-not-saved)). Quitting mid-adventure forfeits the Madra drained at its start.
- `[LOW]` There is a single fixed save slot (`SAVE_PATH` const).
- `[LOW]` Save errors on timer ticks are ignored. `save_timer.gd` connects `save_data` directly and drops the returned `Error`.

### Tech Debt

- `[MEDIUM]` Missing tests. `test_persistence_manager.gd` covers the boot path on temporary files, but nothing covers a full `SaveGameData` round trip (typed dictionaries keyed by resources in `InventoryData`, `equipped_accessories`, enum fields). Only the quest progression, `ZoneProgressionData` and merchant ledger round trips are tested.
- `[LOW]` Defaults are duplicated. Each field's default is declared on its `@export` and again in `SaveGameData.reset()`, and must also be added to `_to_string()`. `reset()` could copy from `SaveGameData.new()` instead.
- `[LOW]` `ZoneProgressionData.forage_active` and `forage_start_time` are saved but never read or written anywhere.
- `[LOW]` `verify()` depends on autoload timing. It runs before `ZoneManager._ready()` and relies on `_all_zone_data` being a preloaded member default. Moving that load into `_ready()` would make every save with a selected zone fail validation and get wiped.
- `[LOW]` `load_data()` has no early return after creating a new save, so it immediately reloads the file it just wrote.
- `[LOW]` The save is a `.tres` resource. Godot resource files can embed scripts, so a shared or edited save file could run code when loaded. Consider a data-only format before saves are exchanged between players.
- `[LOW]` Tests and the game share `user://`. GUT runs load the real `save.tres` through `PersistenceManager._ready()`, and would recreate it if it were missing or invalid. Several tests replace `PersistenceManager.save_game_data` without restoring it (for example `test_adventure_encounter.gd` and `test_award_path_point_effect_data.gd`).
- `[LOW]` `PersistenceManager` has no class doc comment, and its public functions have no `##` comments.
