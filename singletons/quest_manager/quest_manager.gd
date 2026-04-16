extends Node

## Tracks active and completed quests. Advances quest steps based on
## EventManager.event_triggered or UnlockConditionData evaluation. Fires
## completion effects when the last step advances.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal quest_started(quest_id: String)
signal quest_step_advanced(quest_id: String, new_step_index: int)
signal quest_completed(quest_id: String)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _live_save_data: SaveGameData = null
var _quest_catalog: QuestList = preload("res://resources/quests/quest_list.tres")
var _quests_by_id: Dictionary = {}  # String -> QuestData

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("QuestManager: Could not get save_game_data from PersistenceManager on ready!")
	if EventManager:
		EventManager.event_triggered.connect(_on_event_triggered)
	else:
		Log.critical("QuestManager: EventManager not available on ready!")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Starts a quest by id. No-op if already active or completed.
func start_quest(quest_id: String) -> void:
	push_error("QuestManager.start_quest not yet implemented")

## Returns true if the quest is currently in the active list.
func has_active_quest(quest_id: String) -> bool:
	if not _live_save_data:
		return false
	return _live_save_data.quest_progression.active_quests.has(quest_id)

## Returns true if the quest is in the completed list.
func has_completed_quest(quest_id: String) -> bool:
	if not _live_save_data:
		return false
	return quest_id in _live_save_data.quest_progression.completed_quest_ids

## Returns ids of all currently active quests in insertion order.
func get_active_quest_ids() -> Array[String]:
	var result: Array[String] = []
	if not _live_save_data:
		return result
	for quest_id: String in _live_save_data.quest_progression.active_quests.keys():
		result.append(quest_id)
	return result

## Returns ids of all completed quests.
func get_completed_quest_ids() -> Array[String]:
	var result: Array[String] = []
	if not _live_save_data:
		return result
	for quest_id: String in _live_save_data.quest_progression.completed_quest_ids:
		result.append(quest_id)
	return result

## Returns the current step index for an active quest, or -1 if not active.
func get_current_step_index(quest_id: String) -> int:
	if not _live_save_data:
		return -1
	return _live_save_data.quest_progression.active_quests.get(quest_id, -1)

## Returns the QuestData for a quest_id, or null if unknown.
func get_quest_data(quest_id: String) -> QuestData:
	return _quests_by_id.get(quest_id, null)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _build_catalog_index() -> void:
	_quests_by_id.clear()
	for quest: QuestData in _quest_catalog.quests:
		if quest and not quest.quest_id.is_empty():
			_quests_by_id[quest.quest_id] = quest

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data

func _on_event_triggered(_event_id: String) -> void:
	# Implemented in Task 5.
	pass
