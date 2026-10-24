extends GutTest

var _save_data: SaveGameData
var _test_quest: QuestData

## QuestManager's and EventManager's real state, given back after each test so
## later files see the real quest catalog and save.
var _saved_quest_save_data: SaveGameData = null
var _saved_quests_by_id: Dictionary[String, QuestData] = {}
var _saved_event_save_data: SaveGameData = null

func before_each() -> void:
	_saved_quest_save_data = QuestManager._live_save_data
	_saved_quests_by_id = QuestManager._quests_by_id
	_saved_event_save_data = EventManager.live_save_data
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
	QuestManager._live_save_data = _saved_quest_save_data
	QuestManager._quests_by_id = _saved_quests_by_id
	EventManager.live_save_data = _saved_event_save_data

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
