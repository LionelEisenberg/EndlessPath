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
signal condition_unlocked(condition_id: String)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@export var unlock_condition_list : UnlockConditionList = preload("res://resources/game_systems/unlocks/unlock_condition_list.tres")

var live_save_data: SaveGameData = null

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
		
		if live_save_data.unlock_progression == null:
			printerr("CRITICAL - UnlockManager: Could not get UnlockProgressionData from PersistenceManager!")
			live_save_data.unlock_progression = UnlockProgressionData.new()
	else:
		printerr("CRITICAL - UnlockManager: Could not get save_game_data from PersistenceManager on ready!")
		return
	
	# Connect to existing signals to check for unlock conditions
	_initialize_from_save()
	_connect_unlock_signals()

func _initialize_from_save() -> void:
	live_save_data = PersistenceManager.save_game_data
	game_systems_updated.emit(live_save_data.unlocked_game_systems)
	condition_unlocked.emit()

func _connect_unlock_signals() -> void:
	# Connect to EventManager signals
	if EventManager:
		EventManager.event_triggered.connect(_evaluate_all_conditions)
	else:
		printerr("CRITICAL - UnlockManager: EventManager is missing!")

	# Connect to CultivationManager signals
	if CultivationManager:
		CultivationManager.advancement_stage_changed.connect(_evaluate_all_conditions)
		CultivationManager.core_density_level_updated.connect(_evaluate_all_conditions)
	else:
		printerr("CRITICAL - UnlockManager: CultivationManager is missing!")
	
	# Connect to ResourceManager signals
	if ResourceManager:
		ResourceManager.madra_changed.connect(_evaluate_all_conditions)
		ResourceManager.gold_changed.connect(_evaluate_all_conditions)
	else:
		printerr("CRITICAL - UnlockManager: ResourceManager is missing!")

#-----------------------------------------------------------------------------
# PUBLIC UNLOCK MANAGEMENT FUNCTIONS
#-----------------------------------------------------------------------------

func are_unlock_conditions_met(unlock_conditions: Array[UnlockConditionData]) -> bool:
	for condition in unlock_conditions:
		if not is_condition_unlocked(condition.condition_id):
			return false
	return true

## Checks if a condition has already been achieved
func is_condition_unlocked(condition_id: String) -> bool:
	if live_save_data == null:
		return false
	return condition_id in live_save_data.unlock_progression.unlocked_condition_ids

## Returns the list of achieved condition IDs
func get_achieved_conditions() -> Array[String]:
	if live_save_data == null:
		return []
	return live_save_data.unlock_progression.unlocked_condition_ids

#-----------------------------------------------------------------------------
# PRIVATE UNLOCK CONDITION EVALUATION
#-----------------------------------------------------------------------------

## Called by any signal that changes game state.
func _evaluate_all_conditions(_args = null) -> void:
	if unlock_condition_list == null:
		printerr("UnlockManager: 'unlock_condition_list' is not set. Assign it in the editor.")
		return

	for condition in unlock_condition_list.list:
		if is_condition_unlocked(condition.condition_id):
			continue

		if condition.evaluate():
			_unlock_condition(condition.condition_id)

## Adds the condition to the progression data and emits the signal.
func _unlock_condition(condition_id: String) -> void:
	if not condition_id in live_save_data.unlock_progression.unlocked_condition_ids:
		live_save_data.unlock_progression.unlocked_condition_ids.append(condition_id)
		condition_unlocked.emit(condition_id)

		print("UnlockManager: Condition permanently unlocked: %s" % condition_id)

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
