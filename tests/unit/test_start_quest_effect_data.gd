extends GutTest

var _save_data: SaveGameData
var _test_quest: QuestData

func before_each() -> void:
	_save_data = SaveGameData.new()
	var step := QuestStepData.new()
	step.step_id = "s1"
	step.completion_event_id = "test_event"
	_test_quest = QuestData.new()
	_test_quest.quest_id = "test_quest"
	_test_quest.quest_name = "Test Quest"
	_test_quest.steps = [step] as Array[QuestStepData]
	QuestManager._live_save_data = _save_data
	QuestManager._quests_by_id = {"test_quest": _test_quest}
	EventManager.live_save_data = _save_data

func after_each() -> void:
	QuestManager._live_save_data = null
	QuestManager._quests_by_id = {}
	EventManager.live_save_data = null

func test_process_starts_the_quest() -> void:
	var effect := StartQuestEffectData.new()
	effect.quest_id = "test_quest"
	effect.process()
	assert_true(QuestManager.has_active_quest("test_quest"),
		"process() should call QuestManager.start_quest and add to active list")

func test_process_with_empty_quest_id_pushes_error() -> void:
	var effect := StartQuestEffectData.new()
	effect.quest_id = ""
	effect.process()
	assert_push_error("empty quest_id")
