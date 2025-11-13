extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

# Zone selection signals
signal zone_changed(zone_data: ZoneData)

#-----------------------------------------------------------------------------
# VARIABLES
#-----------------------------------------------------------------------------

@export var _all_zone_data: ZoneDataList = preload("res://resources/game_systems/zones/zone_data_list.tres")

var live_save_data: SaveGameData = PersistenceManager.save_game_data

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(func(): live_save_data = PersistenceManager.save_game_data)
	else:
		printerr("CRITICAL - ZoneManager: Could not get save_game_data from PersistenceManager on ready!")
		return

func _initialize_from_save() -> void:
	pass

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

#-----------------------------------------------------------------------------
# ZONE PROGRESS HANDLING
#-----------------------------------------------------------------------------

## Returns ZoneProgressionData for the given zone, creating it if it doesn't exist.
func get_zone_progression(zone_id: String) -> ZoneProgressionData:
	return live_save_data.get_zone_progression_data(zone_id)

## Creates and initializes ZoneProgressionData for a zone with initial unlocked actions.
func initialize_zone_progression(_zone_id: String) -> void:
	return

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
