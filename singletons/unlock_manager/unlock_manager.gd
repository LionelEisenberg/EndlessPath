# UnlockManager.gd
# AUTOLOADED SINGLETON
extends Node

## The enum for all game systems
enum GameSystem {
	ZONE,
	CYCLING,
	SCRIPTING,
	ELIXIR_MAKING,
	SOULSMITHING,
	ADVENTURING
}

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal game_systems_updated(unlocked_game_systems: Array[GameSystem])
signal unlock_conditions_met(unlock_type: String, unlock_id: String)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@onready var unlock_condition_list : UnlockConditionList = preload("res://resources/game_systems/unlocks/unlock_condition_list.tres")

var live_save_data: SaveGameData = null

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
		_initialize_from_save()
	else:
		printerr("CRITICAL - UnlockManager: Could not get save_game_data from PersistenceManager on ready!")
	
	# Connect to existing signals to check for unlock conditions
	_connect_unlock_signals()

func _initialize_from_save() -> void:
	game_systems_updated.emit(live_save_data.unlocked_game_systems)

func _connect_unlock_signals() -> void:
	# Connect to CultivationManager signals
	if CultivationManager:
		CultivationManager.advancement_stage_changed.connect(_on_cultivation_stage_changed)
		CultivationManager.core_density_level_updated.connect(_on_cultivation_level_changed)
	else:
		printerr("CRITICAL - UnlockManager: CultivationManager is missing!")
	
	# Connect to ResourceManager signals
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
		ResourceManager.gold_changed.connect(_on_gold_changed)
	else:
		printerr("CRITICAL - UnlockManager: ResourceManager is missing!")

func _on_cultivation_stage_changed(stage) -> void:
	# Check cultivation stage conditions
	_check_cultivation_stage_conditions(stage)

func _on_cultivation_level_changed(xp: float, level: float) -> void:
	# Check cultivation level conditions
	_check_cultivation_level_conditions(xp, level)

func _on_madra_changed(amount: float) -> void:
	# Check resource amount conditions
	_check_resource_amount_conditions(ResourceManager.ResourceType.MADRA, amount)

func _on_gold_changed(amount: float) -> void:
	# Check resource amount conditions
	_check_resource_amount_conditions(ResourceManager.ResourceType.GOLD, amount)

#-----------------------------------------------------------------------------
# GAME SYSTEM UNLOCK FUNCTIONS
#-----------------------------------------------------------------------------

## The main function to unlock a new game system.
func unlock_game_system(system: GameSystem):
	if system not in live_save_data.unlocked_game_systems:
		live_save_data.unlocked_game_systems.append(system)
		game_systems_updated.emit(live_save_data.unlocked_game_systems)

## Returns the full list of unlocked game system enums.
func get_unlocked_game_systems() -> Array[GameSystem]:
	return live_save_data.unlocked_game_systems

## A public function for other nodes to check a game system's status.
func is_game_system_unlocked(system: GameSystem) -> bool:
	return system in live_save_data.unlocked_game_systems

#-----------------------------------------------------------------------------
# PUBLIC UNLOCK MANAGEMENT FUNCTIONS
#-----------------------------------------------------------------------------

func are_unlock_conditions_met(unlock_conditions: Array[UnlockConditionData]) -> bool:
	for condition in unlock_conditions:
		if not is_condition_achieved(condition.condition_id):
			return false
	return true


## Marks a condition as achieved in save data
func mark_condition_achieved(condition_id: String) -> void:
	if live_save_data == null:
		printerr("CRITICAL- UnlockManager: Cannot mark condition - live_save_data is null")
		return
	
	if condition_id not in live_save_data.achieved_unlock_conditions:
		live_save_data.achieved_unlock_conditions.append(condition_id)
	
	unlock_conditions_met.emit(condition_id)

## Checks if a condition has already been achieved
func is_condition_achieved(condition_id: String) -> bool:
	if live_save_data == null:
		return false
	return condition_id in live_save_data.achieved_unlock_conditions

## Returns the list of achieved condition IDs
func get_achieved_conditions() -> Array[String]:
	if live_save_data == null:
		return []
	return live_save_data.achieved_unlock_conditions

#-----------------------------------------------------------------------------
# PRIVATE UNLOCK CONDITION CHECKING
#-----------------------------------------------------------------------------

## Checks cultivation stage conditions when stage changes
func _check_cultivation_stage_conditions(stage: CultivationManager.AdvancementStage) -> void:
	for unlock_condition in _get_conditions_for_type(UnlockConditionData.ConditionType.CULTIVATION_STAGE):
		if _compare_values(stage, unlock_condition.target_value, unlock_condition.comparison_op):
			mark_condition_achieved(unlock_condition.condition_id)

## Checks cultivation level conditions when level changes
func _check_cultivation_level_conditions(_xp: float, _level: float) -> void:
	for unlock_condition in _get_conditions_for_type(UnlockConditionData.ConditionType.CULTIVATION_LEVEL):
		pass

## Checks resource amount conditions when resources change
func _check_resource_amount_conditions(resource_type: ResourceManager.ResourceType, amount: float) -> void:
	for unlock_condition in _get_conditions_for_type(UnlockConditionData.ConditionType.RESOURCE_AMOUNT):
		if resource_type == unlock_condition.optional_params.get("resource_type"):
			if _compare_values(amount, unlock_condition.target_value, unlock_condition.comparison_op):
				mark_condition_achieved(unlock_condition.condition_id)
		elif resource_type == unlock_condition.optional_params.get("resource_type"):
			if _compare_values(amount, unlock_condition.target_value, unlock_condition.comparison_op):
				mark_condition_achieved(unlock_condition.condition_id)
		else:
			printerr("CRITICAL - UnlockManager: Invalid resource type for condition: %s" % unlock_condition.condition_id)

#-----------------------------------------------------------------------------
# PRIVATE UTILITY FUNCTIONS
#-----------------------------------------------------------------------------

func _get_conditions_for_type(condition_type: UnlockConditionData.ConditionType) -> Array[UnlockConditionData]:
	return unlock_condition_list.list.filter(func(condition: UnlockConditionData): return condition.condition_type == condition_type)

# Compares current value (a) with target value (b) using the comparison operator (op)
func _compare_values(a: Variant, b: Variant, op: String) -> bool:
	match op:
		">=": return a >= b
		">":  return a > b
		"<=": return a <= b
		"<":  return a < b
		"==": return a == b
		"!=": return a != b
		_: return false
