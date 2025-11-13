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

@export var advancement_stage_resources: Array[AdvancementStageResource] = [
	preload("res://resources/game_systems/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres")
]

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
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		printerr("CRITICAL - CultivationManager: live_save_data is null in _update_resources!")
		return
	
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	advancement_stage_changed.emit(live_save_data.current_advancement_stage)

#-----------------------------------------------------------------------------
# PUBLIC LOGIC FUNCTIONS
#-----------------------------------------------------------------------------
## Add XP to core density and handle level progression.
func add_core_density_xp(amount: float):
	if live_save_data == null:
		printerr("CultivationManager: Cannot add XP - live_save_data is null")
		return
	
	# Add XP to current amount
	live_save_data.core_density_xp += amount
	
	# Check for level progression
	var xp_needed_for_next_level = get_xp_for_next_level()
	
	# Level up if we have enough XP
	while live_save_data.core_density_xp >= xp_needed_for_next_level:
		# Level up
		live_save_data.core_density_level += 1
		live_save_data.core_density_xp -= xp_needed_for_next_level
		
		# Emit level up signal
		core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
		
		# Get XP needed for next level
		xp_needed_for_next_level = get_xp_for_next_level()
	
	# Always emit XP updated signal for UI updates
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)

func attempt_breakthrough():
	return

func get_xp_for_next_level() -> float:
	if live_save_data == null:
		return 0.0
	var cur_level = live_save_data.core_density_level + 1
	var res = _get_current_stage_resource()
	return res.get_xp_for_level(cur_level) if res else 0.0

func get_core_density_xp() -> float:
	if live_save_data == null:
		return 0.0
	return live_save_data.core_density_xp

func get_core_density_level() -> float:
	if live_save_data == null:
		return 0.0
	return live_save_data.core_density_level

func get_current_advancement_stage() -> AdvancementStage:
	if live_save_data == null:
		return AdvancementStage.FOUNDATION
	return live_save_data.current_advancement_stage

func get_current_advancement_stage_name() -> String:
	var res = _get_current_stage_resource()
	return res.stage_name if res else "Unknown"

func get_advancement_stage_name(stage: AdvancementStage) -> String:
	for res in advancement_stage_resources:
		if res.stage_id == stage:
			return res.stage_name
	return "Unknown"

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

func _get_stage_resource(stage: AdvancementStage) -> AdvancementStageResource:
	for i in range(advancement_stage_resources.size()):
		if advancement_stage_resources[i].stage_id == stage:
			return advancement_stage_resources[i]
	return null

func _get_current_stage_resource() -> AdvancementStageResource:
	if live_save_data == null:
		return null
	var stage : AdvancementStage = live_save_data.current_advancement_stage
	return _get_stage_resource(stage)
