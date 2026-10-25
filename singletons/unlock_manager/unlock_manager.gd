# UnlockManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal condition_unlocked(condition_id: String)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@export var unlock_condition_list : UnlockConditionList = preload("res://resources/unlocks/unlock_condition_list.tres")

var live_save_data: SaveGameData = null

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
		
		if live_save_data.unlock_progression == null:
			Log.critical("UnlockManager: Could not get UnlockProgressionData from PersistenceManager!")
			live_save_data.unlock_progression = UnlockProgressionData.new()
	else:
		Log.critical("UnlockManager: Could not get save_game_data from PersistenceManager on ready!")
		return
	
	# Connect to existing signals to check for unlock conditions
	_initialize_from_save()
	_connect_unlock_signals()

func _initialize_from_save() -> void:
	live_save_data = PersistenceManager.save_game_data
	condition_unlocked.emit("")

func _connect_unlock_signals() -> void:
	# Connect to EventManager signals
	if EventManager:
		EventManager.event_triggered.connect(_evaluate_all_conditions.unbind(1))
	else:
		Log.critical("UnlockManager: EventManager is missing!")

	# Connect to CultivationManager signals
	if CultivationManager:
		CultivationManager.advancement_stage_changed.connect(_evaluate_all_conditions.unbind(1))
		CultivationManager.core_density_level_updated.connect(_evaluate_all_conditions.unbind(2))
	else:
		Log.critical("UnlockManager: CultivationManager is missing!")
	
	# Connect to ResourceManager signals
	if ResourceManager:
		ResourceManager.madra_changed.connect(_evaluate_all_conditions.unbind(1))
		ResourceManager.gold_changed.connect(_evaluate_all_conditions.unbind(1))
	else:
		Log.critical("UnlockManager: ResourceManager is missing!")

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

## Returns the ids of every condition latched in the live save, in the order
## they latched. A copy: changing it leaves the save as it is.
func get_unlocked_condition_ids() -> Array[String]:
	if live_save_data == null:
		return []
	return live_save_data.unlock_progression.unlocked_condition_ids.duplicate()

#-----------------------------------------------------------------------------
# PRIVATE UNLOCK CONDITION EVALUATION
#-----------------------------------------------------------------------------

## Called by any signal that changes game state.
func _evaluate_all_conditions() -> void:
	if unlock_condition_list == null:
		Log.error("UnlockManager: 'unlock_condition_list' is not set. Assign it in the editor.")
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
		live_save_data.stats.record_condition(condition_id)
		condition_unlocked.emit(condition_id)

		Log.info("UnlockManager: Condition permanently unlocked: %s" % condition_id)

## DEV-only: force-unlock a condition by id. Idempotent.
## Used by the dev panel; do not call from gameplay code.
func force_unlock_condition(condition_id: String) -> void:
	_unlock_condition(condition_id)
