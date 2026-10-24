extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

# Zone selection signals
signal zone_changed(zone_data: ZoneData)

# Zone Action Completed signals
## Emitted when a limited action (max_completions > 0) reaches its limit.
signal action_completed(action_id: String)

## Emitted when the set of zones the map shows changes (dev toggles for the
## demo zones and the hidden zones).
signal map_zones_changed()

## Emitted when something asks the zone panel to scroll to and flash an
## action's card, e.g. a map popover's "Show me ›".
signal action_focus_requested(action_id: String)

#-----------------------------------------------------------------------------
# ENUMS AND CONSTANTS
#-----------------------------------------------------------------------------

## How the overworld map draws a zone. See get_zone_map_state().
enum ZoneMapState { CURRENT, OPEN, LOCKED, UNCHARTED }

## Dev-only zones that show the locked and uncharted map states. They are loaded
## on demand by set_demo_zones_visible() and never enter zone_data_list.tres,
## so a save can never stand in one.
const DEMO_ZONE_PATHS: Array[String] = [
	"res://resources/zones/dev/advancement_zone_demo.tres",
	"res://resources/zones/dev/uncharted_zone_demo.tres",
]

#-----------------------------------------------------------------------------
# VARIABLES
#-----------------------------------------------------------------------------

@export var _all_zone_data: ZoneDataList = preload("res://resources/zones/zone_data_list.tres")

var live_save_data: SaveGameData = PersistenceManager.save_game_data

var _demo_zones_visible: bool = false
var _hidden_zones_visible: bool = false
var _demo_zones: Array[ZoneData] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
		CyclingManager.technique_unlocked.connect(_on_technique_unlocked)
	else:
		Log.critical("ZoneManager: Could not get save_game_data from PersistenceManager on ready!")
		return
	_initialize_seen_actions()

func _initialize_from_save() -> void:
	live_save_data = PersistenceManager.save_game_data
	_initialize_seen_actions()
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

## Returns the id of the idle action last started in the zone, or "" if none.
func get_last_idle_action_id(zone_id: String) -> String:
	return get_zone_progression(zone_id).last_idle_action_id

## Records the idle action last started in the zone, so the zone can resume it.
func set_last_idle_action_id(zone_id: String, action_id: String) -> void:
	get_zone_progression(zone_id).last_idle_action_id = action_id

#-----------------------------------------------------------------------------
# MAP STATE
#-----------------------------------------------------------------------------

## Returns the zones the overworld map shows, in zone list order. Zones with
## hidden_on_map are skipped unless hidden zones are shown; the demo zones
## come last when they are shown.
func get_map_zones() -> Array[ZoneData]:
	var zones: Array[ZoneData] = []
	for zone: ZoneData in _all_zone_data.list:
		if zone.hidden_on_map and not _hidden_zones_visible:
			continue
		zones.append(zone)
	if _demo_zones_visible:
		zones.append_array(_get_demo_zones())
	return zones

## Returns how the map draws the zone: UNCHARTED while its chart conditions
## are unmet, LOCKED while its unlock conditions are unmet, CURRENT for the
## zone the player stands in, OPEN otherwise.
func get_zone_map_state(zone_data: ZoneData) -> ZoneMapState:
	if not is_zone_charted(zone_data):
		return ZoneMapState.UNCHARTED
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		return ZoneMapState.LOCKED
	var current_zone: ZoneData = get_current_zone()
	if current_zone != null and zone_data.zone_id == current_zone.zone_id:
		return ZoneMapState.CURRENT
	return ZoneMapState.OPEN

## Returns true when every chart condition of the zone is met (or it has none).
func is_zone_charted(zone_data: ZoneData) -> bool:
	return UnlockManager.are_unlock_conditions_met(zone_data.chart_conditions)

## DEV: shows or hides the two demo zones (locked and uncharted) on the map.
## Emits map_zones_changed when the setting changes.
func set_demo_zones_visible(visible: bool) -> void:
	if visible == _demo_zones_visible:
		return
	_demo_zones_visible = visible
	map_zones_changed.emit()

## DEV: shows or hides zones marked hidden_on_map (Test Zone) on the map.
## Emits map_zones_changed when the setting changes.
func set_hidden_zones_visible(visible: bool) -> void:
	if visible == _hidden_zones_visible:
		return
	_hidden_zones_visible = visible
	map_zones_changed.emit()

## Asks the zone panel to scroll to the action's card and flash it.
func request_action_focus(action_id: String) -> void:
	action_focus_requested.emit(action_id)

#-----------------------------------------------------------------------------
# SEEN ACTIONS
#-----------------------------------------------------------------------------

## Records that the player has seen the action, which clears its NEW tag.
func mark_action_seen(action_id: String) -> void:
	if action_id == "" or live_save_data.seen_action_ids.has(action_id):
		return
	live_save_data.seen_action_ids.append(action_id)

## Forgets that the player has seen the action, which lights its NEW tag again.
func mark_action_unseen(action_id: String) -> void:
	live_save_data.seen_action_ids.erase(action_id)

## Returns true when the player has seen the action (no NEW tag).
func is_action_seen(action_id: String) -> bool:
	return live_save_data.seen_action_ids.has(action_id)

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

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Loads the demo zones on first use.
func _get_demo_zones() -> Array[ZoneData]:
	if _demo_zones.is_empty():
		for path: String in DEMO_ZONE_PATHS:
			var zone: ZoneData = load(path) as ZoneData
			if zone == null:
				Log.error("ZoneManager: Could not load demo zone %s" % path)
				continue
			_demo_zones.append(zone)
	return _demo_zones

## On a save's first initialisation, marks every action available at that
## moment as seen, so only actions unlocked later show the NEW tag.
func _initialize_seen_actions() -> void:
	if live_save_data == null or live_save_data.seen_actions_initialized:
		return
	for zone: ZoneData in _all_zone_data.list:
		for action: ZoneActionData in get_available_actions(zone.zone_id):
			mark_action_seen(action.action_id)
	live_save_data.seen_actions_initialized = true

## A technique unlocking gives cycling something new, so every cycling action
## shows its NEW tag again until the player hovers its card or opens cycling.
func _on_technique_unlocked(_technique: CyclingTechniqueData) -> void:
	for zone: ZoneData in _all_zone_data.list:
		for action: ZoneActionData in zone.all_actions:
			if action.action_type == ZoneActionData.ActionType.CYCLING:
				mark_action_unseen(action.action_id)
