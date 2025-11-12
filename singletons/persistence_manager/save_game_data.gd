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
@export var achieved_unlock_conditions: Array[String] = []  # Condition IDs that have been achieved

#-----------------------------------------------------------------------------
# ZONE MANAGER
#-----------------------------------------------------------------------------
@export var current_selected_zone_id: String = ""
@export var zone_progression_data: Dictionary[String, ZoneProgressionData] = {}


func get_zone_progression_data(zone_id: String) -> ZoneProgressionData:
	if zone_id in zone_progression_data:
		return zone_progression_data[zone_id]
	else:
		return ZoneProgressionData.new()

#-----------------------------------------------------------------------------
# CURRENT STATE (Player's current equipment/configuration)
#-----------------------------------------------------------------------------

@export var current_cycling_technique_name: String = "Foundation Technique"

func _to_string() -> String:
	return "SaveGameData(Madra: %f, Gold: %f, CoreDensityXP: %f, CoreDensityLevel: %f, AdvancementStage: %s, UnlockedGameSystems: %s, SelectedZone: %s)" % [
		madra,
		gold,
		core_density_xp,
		core_density_level,
		CultivationManager.get_advancement_stage_name(current_advancement_stage),
		str(unlocked_game_systems),
		current_selected_zone_id
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
	achieved_unlock_conditions = []
	
	# Zone Manager
	current_selected_zone_id = ""
	
	# Inventory Manager
	inventory = InventoryData.new()
	
	# Current State
	current_cycling_technique_name = "Foundation Technique"
	
