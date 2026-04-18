extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

# Zone selection signals
signal zone_changed(zone_data: ZoneData)

# Zone Action Completed signals
signal action_completed

#-----------------------------------------------------------------------------
# VARIABLES
#-----------------------------------------------------------------------------

@export var _all_zone_data: ZoneDataList = preload("res://resources/zones/zone_data_list.tres")

var live_save_data: SaveGameData = PersistenceManager.save_game_data

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
	else:
		Log.critical("ZoneManager: Could not get save_game_data from PersistenceManager on ready!")
		return

func _initialize_from_save() -> void:
	live_save_data = PersistenceManager.save_game_data
	zone_changed.emit(get_current_zone())

#-----------------------------------------------------------------------------
# CURRENT ZONE HANDLING
#-----------------------------------------------------------------------------

## Returns the ZoneData for the currently selected zone, or null if none selected.
func get_current_zone() -> ZoneData:
	if live_save_data.current_selected_zone_id == "":
		live_save_data.current_selected_zone_id = _all_zone_data.list[0].zone_id
	return _all_zone_data.get_zone_data_by_id(live_save_data.current_selected_zone_id)

## Sets the current selected zone and updates SaveGameData. Emits zone_changed signal.
func set_current_zone(zone_data: ZoneData) -> void:
	set_current_zone_by_id(zone_data.zone_id)

## Sets the current selected zone by zone_id. Emits zone_changed signal.
func set_current_zone_by_id(zone_id: String) -> void:
	live_save_data.current_selected_zone_id = zone_id
	zone_changed.emit(_all_zone_data.get_zone_data_by_id(zone_id))

## 
func has_zone(zone_id: String) -> bool:
	return _all_zone_data.get_zone_data_by_id(zone_id) != null

#-----------------------------------------------------------------------------
# ZONE PROGRESS HANDLING
#-----------------------------------------------------------------------------

## Returns ZoneProgressionData for the given zone, creating it if it doesn't exist.
func get_zone_progression(zone_id: String = get_current_zone().zone_id) -> ZoneProgressionData:
	return live_save_data.get_zone_progression_data(zone_id)

## Increments the completion count for the given action in the ZoneProgressionData.
func increment_zone_progression_for_action(action_id: String, zone_id: String = get_current_zone().zone_id, quantity = 1) -> void:
	var _num_completions_for_action = live_save_data.increment_zone_progression_for_action(action_id, zone_id, quantity)
	var action: ZoneActionData = get_action_by_id(action_id)
	if action == null:
		return
	if action.max_completions != 0 and _num_completions_for_action >= action.max_completions:
		action_completed.emit(action_id)

## Returns accumulated training ticks for the given action in the given zone (0 if unseen).
func get_training_ticks(action_id: String, zone_id: String = get_current_zone().zone_id) -> int:
	return get_zone_progression(zone_id).training_tick_progress.get(action_id, 0)

## Adds `amount` ticks to the action's training progress and returns the new total.
func increment_training_ticks(action_id: String, zone_id: String = get_current_zone().zone_id, amount: int = 1) -> int:
	var zp: ZoneProgressionData = get_zone_progression(zone_id)
	var new_total: int = zp.training_tick_progress.get(action_id, 0) + amount
	zp.training_tick_progress[action_id] = new_total
	return new_total

#-----------------------------------------------------------------------------
# ACTION PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Returns a list of actions that are both unlocked and not completed for the given zone.
## Checks action unlock_conditions and compares max_completions with action_completion_count.
func get_available_actions(zone_id: String = get_current_zone().zone_id) -> Array[ZoneActionData]:
	var zone_data = get_zone_by_id(zone_id)
	if zone_data == null:
		Log.error("ZoneManager: Zone not found: %s" % zone_id)
		return []
	
	# Check if zone itself is unlocked
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		return []
	
	# Get zone progression data
	var zone_progression = get_zone_progression(zone_id)
	
	# Filter actions that are unlocked and not completed
	var available_actions: Array[ZoneActionData] = []
	
	for action in zone_data.all_actions:
		# Check if action is unlocked
		if not UnlockManager.are_unlock_conditions_met(action.unlock_conditions):
			continue
		
		# Check if action is not completed
		var completion_count = zone_progression.action_completion_count.get(action.action_id, 0)
		
		# If max_completions == 0, action is unlimited (always available)
		# Otherwise, check if completion_count < max_completions
		if action.max_completions == 0 or completion_count < action.max_completions:
			available_actions.append(action)
	
	return available_actions

## Returns the action_data for a given action_id
func get_action_by_id(action_id: String) -> ZoneActionData:
	for zone in _all_zone_data.list:
		for action in zone.all_actions:
			if action.action_id == action_id:
				return action
	return null

#-----------------------------------------------------------------------------
# ZONE DATA QUERYING
#-----------------------------------------------------------------------------

## Returns ZoneData for the given zone_id, or null if not found.
func get_zone_by_id(zone_id: String) -> ZoneData:
	return _all_zone_data.get_zone_data_by_id(zone_id)

## Returns all zones from ZoneDataList.
func get_all_zones() -> Array[ZoneData]:
	return _all_zone_data.list

## Returns all unlocked zones.
func get_unlocked_zones() -> Array[ZoneData]:
	return []

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------
