class_name SaveGameData
extends Resource

#-----------------------------------------------------------------------------
# RESOURCE MANAGER
#-----------------------------------------------------------------------------

@export var madra : float = 25.0
@export var gold : float = 0.0

#-----------------------------------------------------------------------------
# INVENTORY MANAGER
#-----------------------------------------------------------------------------

# Key is the item instance id, value is the item instance data
@export var inventory : InventoryData = InventoryData.new()

#-----------------------------------------------------------------------------
# CULTIVATION MANAGER
#-----------------------------------------------------------------------------

@export var core_density_xp : float = 0.0 
@export var core_density_level : float = 0.0
@export var current_advancement_stage : CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION

#-----------------------------------------------------------------------------
# UNLOCK MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_game_systems: Array[UnlockManager.GameSystem] = [UnlockManager.GameSystem.ZONE, UnlockManager.GameSystem.CYCLING]
@export var unlock_progression: UnlockProgressionData = UnlockProgressionData.new()

#-----------------------------------------------------------------------------
# EVENT MANAGER
#-----------------------------------------------------------------------------

@export var event_progression: EventProgressionData = EventProgressionData.new()

#-----------------------------------------------------------------------------
# ZONE MANAGER
#-----------------------------------------------------------------------------
@export var current_selected_zone_id: String = ""
@export var zone_progression_data: Dictionary[String, ZoneProgressionData] = {}


func get_zone_progression_data(zone_id: String) -> ZoneProgressionData:
	if zone_id in zone_progression_data:
		return zone_progression_data[zone_id]
	else:
		var new_zone_progression = ZoneProgressionData.new()
		new_zone_progression.zone_id = zone_id
		zone_progression_data[zone_id] = new_zone_progression
		return zone_progression_data[zone_id]

func increment_zone_progression_for_action(action_id: String, zone_id: String, quantity: int) -> int:
	if not zone_id in zone_progression_data:
		var new_zone_progression = ZoneProgressionData.new()
		new_zone_progression.zone_id = zone_id
		zone_progression_data[zone_id] = new_zone_progression
	
	zone_progression_data[zone_id].action_completion_count.set(action_id, zone_progression_data[zone_id].action_completion_count.get(action_id, 0) + quantity)
	return zone_progression_data[zone_id].action_completion_count[action_id]
	
#-----------------------------------------------------------------------------
# CURRENT STATE (Player's current equipment/configuration)
#-----------------------------------------------------------------------------

@export var current_cycling_technique_name: String = "Foundation Technique"

func _to_string() -> String:
	var zone_progression_data_str := ""
	if typeof(zone_progression_data) == TYPE_DICTIONARY:
		var progression_strings := []
		for zone_id in zone_progression_data.keys():
			var progression : ZoneProgressionData = zone_progression_data[zone_id]
			var progression_summary := ""
			if progression:
				progression_summary = "Completions: %s" % (str(progression.action_completion_count) if "action_completion_count" in progression else "N/A")
			else:
				progression_summary = "None"
			progression_strings.append("%s: [%s]" % [zone_id, progression_summary])
		zone_progression_data_str = "{%s}" % ", ".join(progression_strings)
	else:
		zone_progression_data_str = "N/A"

	return "SaveGameData(\n  Madra: %.2f\n  Gold: %.2f\n  CoreDensityXP: %.2f\n  CoreDensityLevel: %.2f\n  AdvancementStage: %s\n  UnlockedGameSystems: %s\n  UnlockProgression: %s\n  EventProgression: %s\n  SelectedZone: %s\n  ZoneProgressionData: %s\n  InventoryCount: %d\n  CurrentCyclingTechnique: %s\n)" % [
			madra,
			gold,
			core_density_xp,
			core_density_level,
			CultivationManager.get_advancement_stage_name(current_advancement_stage),
			str(unlocked_game_systems),
			str(unlock_progression),
			str(event_progression),
			current_selected_zone_id,
			zone_progression_data_str,
			inventory.items.size() if inventory and inventory.has_method("items") else 0,
			current_cycling_technique_name
		]


func _reset_state() -> void:
	# Resource Manager
	madra = 25.0
	gold = 0.0
	
	# Cultivation Manager
	core_density_xp = 0.0
	core_density_level = 0.0
	current_advancement_stage = CultivationManager.AdvancementStage.FOUNDATION

	# Unlock Manager, default to Zone and Cycling unlocked
	unlocked_game_systems = [UnlockManager.GameSystem.ZONE, UnlockManager.GameSystem.CYCLING]
	unlock_progression = UnlockProgressionData.new()
	
	# Event Manager
	event_progression = EventProgressionData.new()
	
	# Zone Manager
	zone_progression_data = {}
	current_selected_zone_id = ""
	
	# Inventory Manager
	inventory = InventoryData.new()
	
	# Current State
	current_cycling_technique_name = "Foundation Technique"
	
