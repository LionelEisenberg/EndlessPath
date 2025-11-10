extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

# Zone selection signals
signal zone_changed(zone_data: ZoneData)

# Zone unlock signals
signal zone_unlocked(zone_id: String)

# Action signals
signal action_unlocked(zone_id: String, action_id: String)
signal action_completed(zone_id: String, action_id: String)

# Forage signals
signal forage_started(zone_id: String)
signal forage_stopped(zone_id: String)

#-----------------------------------------------------------------------------
# VARIABLES
#-----------------------------------------------------------------------------

@export var zone_data_list: ZoneDataList = preload("res://resources/game_systems/zones/zone_data/zone_data_list.tres")

@export var live_save_data: SaveGameData = PersistenceManager.save_game_data

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
	else:
		printerr("CRITICAL - ZoneManager: Could not get save_game_data from PersistenceManager on ready!")
		return

func _initialize_from_save() -> void:
	pass

#-----------------------------------------------------------------------------
# CURRENT ZONE HANDLING
#-----------------------------------------------------------------------------

# Get current selected zone
func get_current_zone() -> ZoneData:
	"""Returns the ZoneData for the currently selected zone, or null if none selected"""
	if live_save_data.current_selected_zone_id == "":
		live_save_data.current_selected_zone_id = zone_data_list.list[0].zone_id
	return zone_data_list.get_zone_data_by_id(live_save_data.current_selected_zone_id)

# Set current selected zone
func set_current_zone(zone_data: ZoneData) -> void:
	"""Sets the current selected zone and updates SaveGameData. Emits zone_changed signal."""
	set_current_zone_by_id(zone_data.zone_id)

func set_current_zone_by_id(zone_id: String) -> void:
	"""Sets the current selected zone by zone_id. Emits zone_changed signal."""
	live_save_data.current_selected_zone_id = zone_id
	zone_changed.emit(zone_data_list.get_zone_data_by_id(zone_id))

#-----------------------------------------------------------------------------
# ZONE PROGRESS HANDLING
#-----------------------------------------------------------------------------

func get_zone_progression(zone_id: String) -> ZoneProgressionData:
	"""Returns ZoneProgressionData for the given zone, creating it if it doesn't exist"""
	return null

# Initialize progression data for a zone
func initialize_zone_progression(zone_id: String) -> void:
	"""Creates and initializes ZoneProgressionData for a zone with initial unlocked actions"""
	return

#-----------------------------------------------------------------------------
# ZONE DATA QUERYING
#-----------------------------------------------------------------------------

func get_zone_by_id(zone_id: String) -> ZoneData:
	"""Returns ZoneData for the given zone_id, or null if not found"""
	return zone_data_list.get_zone_data_by_id(zone_id)

func get_all_zones() -> Array[ZoneData]:
	"""Returns all zones from ZoneDataList"""
	return zone_data_list.list

func get_unlocked_zones() -> Array[ZoneData]:
	"""Returns all unlocked zones"""
	return []

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------
