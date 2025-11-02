# ZoneManager Singleton - Role and API Specification

## Role Overview

The ZoneManager singleton serves as the central hub for all zone-related operations:
1. **Bridge between SaveGameData and ZoneTilemap/ZoneView**: Handles loading, saving, and syncing the current selected zone
2. **Zone Progression Management**: Manages ZoneProgressionData for each zone (unlocked actions, completed actions, forage state, etc.)
3. **Zone Unlock System**: Evaluates and tracks zone unlock conditions
4. **Action Management**: Handles action unlocking, completion tracking, and state queries

## Core Responsibilities

### 1. Current Zone Management
- Track current selected zone via SaveGameData
- Provide getter/setter for current zone
- Load/restore zone state on game start
- Emit signals when zone changes

### 2. Zone Progression Data Management
- Create and manage ZoneProgressionData instances per zone
- Store/retrieve progression data from SaveGameData
- Initialize progression data for new zones
- Track unlocked actions, completed actions, forage state per zone

### 3. Zone Unlock Evaluation
- Check if zones are unlocked (via UnlockManager integration)
- Track unlocked zones in SaveGameData
- Emit signals when zones unlock

### 4. Action Management
- Check if actions are unlocked for a zone
- Track action completions (one-time, multi-time)
- Get available/unlocked actions for a zone
- Handle action requirements validation

### 5. Forage Management
- Start/stop foraging for zones
- Track forage active state and start time
- Handle forage resource generation (future)

## API Specification

### Current Zone Management

```gdscript
# Get current selected zone
func get_current_zone() -> ZoneData:
    """Returns the ZoneData for the currently selected zone, or null if none selected"""

# Set current selected zone
func set_current_zone(zone_data: ZoneData) -> void:
    """Sets the current selected zone and updates SaveGameData. Emits zone_changed signal."""

func set_current_zone_by_id(zone_id: String) -> void:
    """Sets the current selected zone by zone_id. Emits zone_changed signal."""

# Load initial zone state
func load_saved_zone() -> ZoneData:
    """Loads the saved zone from SaveGameData and returns it, or null if not found"""
```

### Zone Progression Data Management

```gdscript
# Get progression data for a zone
func get_zone_progression(zone_id: String) -> ZoneProgressionData:
    """Returns ZoneProgressionData for the given zone, creating it if it doesn't exist"""

# Initialize progression data for a zone
func initialize_zone_progression(zone_id: String) -> void:
    """Creates and initializes ZoneProgressionData for a zone with initial unlocked actions"""

# Save progression data
func save_zone_progression(zone_id: String) -> void:
    """Saves the ZoneProgressionData for the given zone to SaveGameData"""
```

### Zone Unlock Management

```gdscript
# Check if zone is unlocked
func is_zone_unlocked(zone_id: String) -> bool:
    """Returns true if the zone is unlocked (checked against SaveGameData.unlocked_zones)"""

# Unlock a zone
func unlock_zone(zone_id: String) -> void:
    """Adds zone_id to unlocked_zones in SaveGameData and emits zone_unlocked signal"""

# Evaluate zone unlock conditions
func evaluate_zone_unlock(zone_data: ZoneData) -> bool:
    """Evaluates unlock conditions for a zone and unlocks it if conditions are met"""
```

### Action Management

```gdscript
# Get available actions for a zone
func get_available_actions(zone_id: String) -> Array[ZoneActionData]:
    """Returns all actions available in the zone"""

# Get unlocked actions for a zone
func get_unlocked_actions(zone_id: String) -> Array[ZoneActionData]:
    """Returns only the actions that are unlocked for the zone"""

# Check if action is unlocked
func is_action_unlocked(zone_id: String, action_id: String) -> bool:
    """Returns true if the action is unlocked for the zone"""

# Unlock an action
func unlock_action(zone_id: String, action_id: String) -> void:
    """Unlocks an action for a zone and emits action_unlocked signal"""

# Check if action is completed
func is_action_completed(zone_id: String, action_id: String) -> bool:
    """Returns true if the action has been completed (for one-time actions)"""

# Get action completion count
func get_action_completion_count(zone_id: String, action_id: String) -> int:
    """Returns how many times an action has been completed"""

# Complete an action
func complete_action(zone_id: String, action_id: String) -> void:
    """Marks an action as completed and emits action_completed signal"""
```

### Forage Management

```gdscript
# Check if foraging is active for a zone
func is_forage_active(zone_id: String) -> bool:
    """Returns true if foraging is currently active for the zone"""

# Start foraging for a zone
func start_forage(zone_id: String) -> void:
    """Starts foraging for a zone, sets forage_active and forage_start_time. Emits forage_started signal."""

# Stop foraging for a zone
func stop_forage(zone_id: String) -> void:
    """Stops foraging for a zone. Emits forage_stopped signal."""

# Get forage start time
func get_forage_start_time(zone_id: String) -> float:
    """Returns the timestamp when foraging started for the zone, or 0.0 if not active"""
```

### Zone Data Queries

```gdscript
# Get zone by ID
func get_zone_by_id(zone_id: String) -> ZoneData:
    """Returns ZoneData for the given zone_id, or null if not found"""

# Get all zones
func get_all_zones() -> Array[ZoneData]:
    """Returns all zones from ZoneDataList"""

# Get unlocked zones
func get_unlocked_zones() -> Array[ZoneData]:
    """Returns all unlocked zones"""
```

## Signals

```gdscript
# Zone selection signals
signal zone_changed(zone_data: ZoneData)
signal current_zone_set(zone_data: ZoneData)

# Zone unlock signals
signal zone_unlocked(zone_id: String)

# Action signals
signal action_unlocked(zone_id: String, action_id: String)
signal action_completed(zone_id: String, action_id: String)

# Forage signals
signal forage_started(zone_id: String)
signal forage_stopped(zone_id: String)
```

## SaveGameData Integration

The ZoneManager will manage the following fields in SaveGameData:

```gdscript
@export var current_selected_zone_id: String = ""
@export var unlocked_zones: Array[String] = []  # Needs to be added
@export var zone_progression: Dictionary = {}  # Needs to be added - key: zone_id, value: ZoneProgressionData (serialized)
```

## Initialization

On `_ready()`:
1. Load ZoneDataList resource
2. Load saved zone from SaveGameData
3. Initialize progression data for any zones that don't have it yet
4. Evaluate unlock conditions for all zones
5. Connect to UnlockManager signals (for future unlock evaluation)

## Dependencies

- **PersistenceManager**: Access to SaveGameData
- **UnlockManager**: Zone and action unlock condition evaluation
- **ZoneDataList**: Resource containing all zone definitions
- **ZoneProgressionData**: Resource for per-zone progression tracking

