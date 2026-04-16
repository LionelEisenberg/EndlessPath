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
## After adding to the active list, performs a retroactive pass to skip
## any steps whose completion criteria were already satisfied before start.
func start_quest(quest_id: String) -> void:
	if not _live_save_data:
		return
	if not _quests_by_id.has(quest_id):
		push_error("QuestManager: unknown quest_id '%s'" % quest_id)
		return
	if has_active_quest(quest_id):
		return
	if has_completed_quest(quest_id):
		return
	_live_save_data.quest_progression.active_quests[quest_id] = 0
	Log.info("QuestManager: Started quest '%s'" % quest_id)
	quest_started.emit(quest_id)
	_retroactive_advance(quest_id)

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

func _on_event_triggered(event_id: String) -> void:
	# Iterate over a copy since advancement may complete a quest and mutate active_quests.
	var active_ids: Array[String] = get_active_quest_ids()
	for quest_id: String in active_ids:
		_try_advance_step(quest_id, event_id)

## Advances the current step of `quest_id` if its completion criteria are met.
## `triggering_event_id` is the event that just fired (empty for non-event triggers).
func _try_advance_step(quest_id: String, triggering_event_id: String) -> void:
	var quest: QuestData = _quests_by_id.get(quest_id)
	if quest == null:
		return
	var step_index: int = _live_save_data.quest_progression.active_quests.get(quest_id, -1)
	if step_index < 0 or step_index >= quest.steps.size():
		return
	var step: QuestStepData = quest.steps[step_index]
	if not _is_step_satisfied(step, triggering_event_id):
		return
	_advance_step(quest_id)

## Returns true if the step's completion criterion is met right now.
## For event-based steps, `triggering_event_id` must match. For condition-based
## steps, evaluates all conditions against current state.
func _is_step_satisfied(step: QuestStepData, triggering_event_id: String) -> bool:
	if not step.completion_event_id.is_empty():
		return step.completion_event_id == triggering_event_id
	if step.completion_conditions.is_empty():
		# No criteria at all — auto-advance (load-time validation logs an error).
		return true
	for cond: UnlockConditionData in step.completion_conditions:
		if not cond.evaluate():
			return false
	return true

## Walks a freshly-started quest forward through any already-satisfied steps.
## For event-based steps, checks `EventManager.has_event_triggered`. For
## condition-based steps, re-evaluates conditions. Stops at first unsatisfied
## step or when the quest completes.
func _retroactive_advance(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	while _live_save_data.quest_progression.active_quests.has(quest_id):
		var step_index: int = _live_save_data.quest_progression.active_quests[quest_id]
		if step_index >= quest.steps.size():
			break
		var step: QuestStepData = quest.steps[step_index]
		if not _is_step_retroactively_satisfied(step):
			break
		_advance_step(quest_id)

## Returns true if the step should be treated as already done at start time.
func _is_step_retroactively_satisfied(step: QuestStepData) -> bool:
	if not step.completion_event_id.is_empty():
		return EventManager != null and EventManager.has_event_triggered(step.completion_event_id)
	if step.completion_conditions.is_empty():
		return true
	for cond: UnlockConditionData in step.completion_conditions:
		if not cond.evaluate():
			return false
	return true

## Moves the quest forward one step. If it was on the last step, the quest
## completes (implemented in Task 8). Emits quest_step_advanced otherwise.
func _advance_step(quest_id: String) -> void:
	var quest: QuestData = _quests_by_id[quest_id]
	var new_index: int = _live_save_data.quest_progression.active_quests[quest_id] + 1
	if new_index >= quest.steps.size():
		# Completion logic added in Task 8 — for now, remove from active to
		# satisfy Task 5's multi-quest test.
		_live_save_data.quest_progression.active_quests.erase(quest_id)
		return
	_live_save_data.quest_progression.active_quests[quest_id] = new_index
	Log.info("QuestManager: Quest '%s' advanced to step %d" % [quest_id, new_index])
	quest_step_advanced.emit(quest_id, new_index)
