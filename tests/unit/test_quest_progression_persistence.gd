extends GutTest

const TMP_PATH: String = "user://test_quest_progression.tres"

func after_each() -> void:
	if ResourceLoader.exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

func test_active_quests_round_trip() -> void:
	var data := SaveGameData.new()
	data.quest_progression.active_quests["quest_a"] = 2
	data.quest_progression.active_quests["quest_b"] = 0
	ResourceSaver.save(data, TMP_PATH)

	var loaded: SaveGameData = ResourceLoader.load(TMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.quest_progression.active_quests.get("quest_a", -1), 2)
	assert_eq(loaded.quest_progression.active_quests.get("quest_b", -1), 0)

func test_completed_quests_round_trip() -> void:
	var data := SaveGameData.new()
	data.quest_progression.completed_quest_ids = ["quest_x", "quest_y"]
	ResourceSaver.save(data, TMP_PATH)

	var loaded: SaveGameData = ResourceLoader.load(TMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.quest_progression.completed_quest_ids.size(), 2)
	assert_eq(loaded.quest_progression.completed_quest_ids[0], "quest_x")
	assert_eq(loaded.quest_progression.completed_quest_ids[1], "quest_y")

func test_reset_clears_quest_progression() -> void:
	var data := SaveGameData.new()
	data.quest_progression.active_quests["quest_a"] = 5
	data.quest_progression.completed_quest_ids = ["quest_x"]
	data.reset()
	assert_eq(data.quest_progression.active_quests.size(), 0,
		"reset should empty active_quests")
	assert_eq(data.quest_progression.completed_quest_ids.size(), 0,
		"reset should empty completed_quest_ids")
