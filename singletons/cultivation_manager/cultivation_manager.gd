# CultivationManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal core_density_xp_updated(xp: float, level: float)
signal core_density_level_updated(xp: float, level: float)
signal advancement_stage_changed(new_stage: AdvancementStage)

#-----------------------------------------------------------------------------
# ENUMS & CONSTANTS
#-----------------------------------------------------------------------------
enum AdvancementStage { 
	FOUNDATION,
	COPPER,
	IRON,
	JADE,
	SILVER
}

static var ADVANCEMENT_STAGE_NAMES = {
	AdvancementStage.FOUNDATION: "Foundation",
	AdvancementStage.COPPER: "Copper",
	AdvancementStage.IRON: "Iron",
	AdvancementStage.JADE: "Jade",
	AdvancementStage.SILVER: "Silver"
}

const CORE_DENSITY_BASE_XP = 10
const CORE_DENSITY_CURVE_FACTOR = 1.05

#-----------------------------------------------------------------------------
# PLAYER DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		printerr("CRITICAL - CultivationManager: Could not get save_game_data from PersistenceManager on ready!")

func _update_resources() -> void:
	if live_save_data == null:
		printerr("CRITICAL - CultivationManager: live_save_data is null in _update_resources!")
		return
	
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	advancement_stage_changed.emit(live_save_data.current_advancement_stage)

#-----------------------------------------------------------------------------
# PUBLIC LOGIC FUNCTIONS
#-----------------------------------------------------------------------------
func add_core_density_xp(amount: float):
	return

func attempt_breakthrough():
	return

func get_xp_for_next_level() -> float:
	return 0.0

func get_current_advancement_stage_name() -> String:
	return get_advancement_stage_name(live_save_data.current_advancement_stage)

func get_advancement_stage_name(stage: AdvancementStage) -> String:
	return ADVANCEMENT_STAGE_NAMES[stage]
