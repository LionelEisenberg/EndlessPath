class_name SaveGameData
extends Resource

enum AdvancementStage { FOUNDATION, COPPER, IRON, JADE, SILVER }

#-----------------------------------------------------------------------------
# RESOURCE MANAGER
#-----------------------------------------------------------------------------

@export var madra : float = 25.0
@export var gold : float = 0.0

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

#-----------------------------------------------------------------------------
# CURRENT STATE (Player's current equipment/configuration)
#-----------------------------------------------------------------------------

@export var current_cycling_technique_name: String = "Foundation Technique"

func _to_string() -> String:
	return "SaveGameData(Madra: %f, Gold: %f, CoreDensityXP: %f, CoreDensityLevel: %f, AdvancementStage: %s, UnlockedGameSystems: %s)" % [
		madra,
		gold,
		core_density_xp,
		core_density_level,
		CultivationManager.get_advancement_stage_name(current_advancement_stage),
		str(unlocked_game_systems)
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
	
	# Current State
	current_cycling_technique_name = "Foundation Technique"
