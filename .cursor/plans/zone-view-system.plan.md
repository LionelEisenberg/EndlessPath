<!-- 4883b336-cf3d-4ebf-b29d-164f45218edd 011e8458-5393-41bd-964c-9e80f42e50e6 -->
# Zone View System - Implementation Plan

## Architecture Overview

The Zone system integrates with existing managers through a signal-based architecture. UnlockManager listens to game events (cultivation changes, boss defeats, dialogue completion) and evaluates unlock conditions, emitting signals that ZoneManager handles to unlock zones and actions.

---

## Key Clarifications

**Visual Representation**: Grid of clickable hexagonal sprites

**Unlock System**: Zones unlock via cultivation stage, dialogue/story events, or boss defeats

**Forage**: Per-zone (each zone can have foraging active independently)

**Merchants**: Fixed inventories (dynamic refresh deferred)

---

## 1. Zone Resource Structure

### `ZoneData` (extends Resource)

**Location**: `resources/game_systems/zones/zone_data.gd`

**Properties**:

- `zone_name: String` - Display name
- `zone_id: String` - Unique identifier
- `description: String` - Zone lore/description
- `icon: Texture2D` - Hexagonal zone sprite
- `zone_tier: int` - Difficulty/tier level
- `unlock_conditions: Array[UnlockConditionData]` - Conditions to unlock this zone
- `available_actions: Array[ZoneActionData]` - All possible actions in this zone
- `initial_unlocked_actions: Array[String]` - Action IDs available from start
- `forage_resources: Array[ForageResourceData]` - Resources available for foraging

**Note**: ZoneEvents are NOT separate from actions. Story events are handled as `ZoneActionData` with `action_type = ZONE_EVENT`. This keeps the system unified - all clickable interactions are actions.

---

## 2. Action System

### `ZoneActionData` (extends Resource)

**Base action resource**:

- `action_id: String` - Unique identifier
- `action_name: String` - Display name
- `action_type: ActionType` (enum)
- `description: String`
- `icon: Texture2D`
- `unlock_conditions: Array[UnlockConditionData]`
- `requirements: Dictionary` - Cost/requirements (madra, gold, items)
- `is_one_time: bool` - If true, action completes and can't be repeated
- `is_completed: bool` - Runtime flag (not saved in resource, tracked in progression)

### ActionType Enum

```gdscript
enum ActionType {
    FORAGE,
    DUNGEON,
    NPC_DIALOGUE,
    MERCHANT,
    TRAIN_STATS,
    CYCLING_ROOM,
    ZONE_EVENT,  # Story/scripted events
    QUEST_GIVER
}
```

### Specific Action Sub-Resources

**`ForageActionData`** (extends ZoneActionData):

- `forage_resources: Array[ForageResourceData]` - What can be gathered
- `madra_cost_per_second: float`

**`DungeonActionData`** (extends ZoneActionData):

- `dungeon_id: String` - References dungeon resource
- `difficulty_level: int`

**`NPCActionData`** (extends ZoneActionData):

- `npc_id: String`
- `dialogue_tree_path: String` - Path to dialogue resource
- `on_complete_event_id: String` - Event to trigger after dialogue

**`MerchantActionData`** (extends ZoneActionData):

- `merchant_id: String`
- `trade_items: Array[TradeItemData]` - What they sell
- `accepts_madra: bool`
- `accepts_gold: bool`

**`TrainStatsActionData`** (extends ZoneActionData):

- `stat_type: String` (e.g., "STRENGTH", "AGILITY")
- `cost_per_training: Dictionary` - madra/gold cost
- `stat_gain_per_training: float`

---

## 3. Item & Forage System

### `ItemDefinitionData` (extends Resource)

**Location**: `resources/game_systems/items/item_definition_data.gd`

**Properties**:

- `item_id: String` - Unique identifier
- `item_name: String` - Display name
- `description: String`
- `icon: Texture2D`
- `item_type: ItemType` - (MATERIAL, CONSUMABLE, EQUIPMENT, QUEST_ITEM)
- `stack_size: int` - Max stack size (0 = infinite)
- `base_value: float` - Base gold value

### `ForageResourceData` (extends Resource)

**Location**: `resources/game_systems/zones/forage_resource_data.gd`

**Properties**:

- `item_definition: ItemDefinitionData` - References the item
- `generation_rate: float` - Items per second
- `drop_chance: float` - 0.0 to 1.0 (for random forage)

---

## 4. Unlock Condition System

### `UnlockConditionData` (extends Resource)

**Location**: `resources/game_systems/unlocks/unlock_condition_data.gd`

**Properties**:

- `condition_type: ConditionType` (enum)
- `target_value: Variant` - What to check against
- `comparison_op: String` - ">=", "==", "<=", etc.
- `optional_params: Dictionary` - Type-specific params

### ConditionType Enum

```gdscript
enum ConditionType {
    CULTIVATION_STAGE,     # Check advancement stage
    CULTIVATION_LEVEL,     # Check core density level
    ZONE_UNLOCKED,        # Check if zone is unlocked
    ADVENTURE_COMPLETED,   # Check dungeon/adventure completion
    EVENT_TRIGGERED,       # Check if event occurred
    ITEM_OWNED,           # Check inventory for item
    RESOURCE_AMOUNT,      # Check resource quantity (madra/gold)
    STAT_VALUE,           # Check adventure stat value
    GAME_SYSTEM_UNLOCKED  # Check if system is unlocked
}
```

**Method**: `evaluate() -> bool` - Evaluates condition against current game state via manager queries

---

## 5. UnlockManager Integration

**Signal Flow Architecture**:

1. **UnlockManager listens to**:

   - `CultivationManager.advancement_stage_changed`
   - `CultivationManager.core_density_level_updated`
   - `DialogueManager.dialogue_completed` (future)
   - `AdventureManager.boss_defeated` (future)
   - `ResourceManager.madra_changed / gold_changed`

2. **UnlockManager emits**:

   - `unlock_conditions_met(unlock_type: String, unlock_id: String)` - Generic unlock signal

3. **ZoneManager listens to**:

   - `UnlockManager.unlock_conditions_met` - Checks if any zones/actions should unlock
   - Evaluates all pending unlock conditions when triggered

**Updated UnlockManager additions**:

```gdscript
signal unlock_conditions_met(unlock_type: String, unlock_id: String)

func check_unlock_conditions():
    # Called when any game state changes
    # Emits unlock_conditions_met for various unlock types
    pass
```

---

## 6. Zone Progression Tracking

### `ZoneProgressionData` (extends Resource)

**Location**: `resources/game_systems/zones/zone_progression_data.gd`

**Properties**:

- `zone_id: String`
- `unlocked_actions: Array[String]` - Action IDs
- `completed_actions: Array[String]` - Completed one-time action IDs
- `forage_active: bool`
- `forage_start_time: float`
- `stat_training_count: Dictionary[String, int]` - Stat to training count
- `merchant_interactions: int`

### SaveGameData Additions

**New exports**:

```gdscript
@export var unlocked_zones: Array[String] = []
@export var current_zone_id: String = ""
@export var zone_progression: Dictionary = {}  # Serialized ZoneProgressionData
@export var completed_events: Array[String] = []  # Global event tracking
```

---

## 7. Zone Manager Singleton

**Location**: `singletons/zone_manager/zone_manager.gd`

**Responsibilities**:

- Load zone list from `ZoneListData` resource
- Evaluate unlock conditions for zones and actions
- Track zone progression via SaveGameData
- Handle forage resource generation
- Emit signals for zone/action unlocks and completions

**Key Signals**:

```gdscript
signal zone_unlocked(zone_id: String)
signal action_unlocked(zone_id: String, action_id: String)
signal action_completed(zone_id: String, action_id: String)
signal forage_started(zone_id: String)
signal forage_stopped(zone_id: String)
```

**Key API**:

```gdscript
func is_zone_unlocked(zone_id: String) -> bool
func unlock_zone(zone_id: String) -> void
func get_available_actions(zone_id: String) -> Array[ZoneActionData]
func is_action_unlocked(zone_id: String, action_id: String) -> bool
func is_action_completed(zone_id: String, action_id: String) -> bool
func complete_action(zone_id: String, action_id: String) -> void
func start_forage(zone_id: String) -> void
func stop_forage(zone_id: String) -> void
```

---

## 8. Zone View UI Structure

**Main Components**:

1. **ZoneHexGrid** (`scenes/game_systems/zones/zone_hex_grid.gd` + `.tscn`)

   - Grid container of hexagonal zone sprites
   - Click to select zone
   - Visual states: locked/unlocked/current

2. **ZoneInfoPanel** (`scenes/game_systems/zones/zone_info_panel.gd` + `.tscn`)

   - Displays selected zone info
   - Shows available actions as buttons
   - Forage status indicator

3. **ZoneActionButton** (`scenes/game_systems/zones/zone_action_button.gd` + `.tscn`)

   - Reusable button for actions
   - Shows icon, name, lock status
   - Disabled if locked or completed (one-time)

4. **ZoneView** (`scenes/game_systems/zones/zone_view.gd` + `.tscn`)

   - Main container for hex grid + info panel
   - Handles navigation between zones

---

## 9. Implementation Files

### Resources:

- `resources/game_systems/zones/zone_data.gd`
- `resources/game_systems/zones/zone_action_data.gd` (base)
- `resources/game_systems/zones/forage_action_data.gd`
- `resources/game_systems/zones/dungeon_action_data.gd`
- `resources/game_systems/zones/npc_action_data.gd`
- `resources/game_systems/zones/merchant_action_data.gd`
- `resources/game_systems/zones/train_stats_action_data.gd`
- `resources/game_systems/zones/forage_resource_data.gd`
- `resources/game_systems/zones/zone_list_data.gd`
- `resources/game_systems/zones/zone_progression_data.gd`
- `resources/game_systems/unlocks/unlock_condition_data.gd`
- `resources/game_systems/items/item_definition_data.gd`
- `resources/game_systems/items/trade_item_data.gd`

### Managers:

- `singletons/zone_manager/zone_manager.gd`
- Update `singletons/unlock_manager/unlock_manager.gd` with new signals

### Scenes:

- `scenes/game_systems/zones/zone_view.gd` + `.tscn`
- `scenes/game_systems/zones/zone_hex_grid.gd` + `.tscn`
- `scenes/game_systems/zones/zone_info_panel.gd` + `.tscn`
- `scenes/game_systems/zones/zone_action_button.gd` + `.tscn`

### Save Data:

- Update `singletons/persistence_manager/save_game_data.gd` with zone fields

---

## 10. Implementation Order

1. **Phase 1**: Core resources (ZoneData, ZoneActionData, UnlockConditionData, ItemDefinitionData)
2. **Phase 2**: Update UnlockManager with signal architecture
3. **Phase 3**: ZoneManager singleton and unlock evaluation
4. **Phase 4**: Save data integration (zone progression, completed actions)
5. **Phase 5**: Basic Zone View UI (hex grid + info panel)
6. **Phase 6**: Action button system with lock/unlock/complete states
7. **Phase 7**: Forage action implementation (idle resource generation)
8. **Phase 8**: Other action types (NPC, Merchant, Dungeon placeholders)

### To-dos

- [x] Create ItemDefinitionData resource system for items and materials
- [x] Create UnlockConditionData resource with evaluation logic
- [x] Create ZoneActionData base resource and action type sub-resources
- [x] Create ZoneData resource with actions and unlock conditions
- [x] Create ZoneProgressionData for tracking per-zone state
- [x] Update UnlockManager with signal architecture for unlock evaluation
- [ ] Create ZoneManager singleton for zone/action management
- [ ] Add zone progression and unlocked zones to SaveGameData
- [ ] Create ZoneHexGrid UI with clickable hexagonal sprites
- [ ] Create ZoneActionButton reusable component with lock/unlock/complete states
- [ ] Create ZoneInfoPanel to display zone details and action buttons
- [ ] Create ZoneView main scene integrating hex grid and info panel
- [ ] Implement forage action with idle resource generation per zone