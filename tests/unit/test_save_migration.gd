extends GutTest

## Unit tests for SaveGameData.migrate() and the save fields added for the
## map-first zone view. A save written before those fields existed must load
## with their defaults, and a save standing in the hidden Test Zone must move
## to Spirit Valley before verify() runs.

const TMP_OLD_SAVE_PATH: String = "user://__test_old_save_migration.tres"

func after_each() -> void:
	if FileAccess.file_exists(TMP_OLD_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_OLD_SAVE_PATH))

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _load_hand_written_save(text: String) -> SaveGameData:
	var file := FileAccess.open(TMP_OLD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return ResourceLoader.load(TMP_OLD_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData

#-----------------------------------------------------------------------------
# ZONE ID MIGRATION
#-----------------------------------------------------------------------------

func test_test_zone_save_moves_to_spirit_valley() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "TestZone"
	data.migrate()
	assert_eq(data.current_selected_zone_id, "SpiritValley")

func test_other_zone_is_unchanged() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "SpiritValley"
	data.migrate()
	assert_eq(data.current_selected_zone_id, "SpiritValley")

func test_empty_zone_is_unchanged() -> void:
	var data := SaveGameData.new()
	data.migrate()
	assert_eq(data.current_selected_zone_id, "", "an empty id still means 'the first zone in the list'")

func test_migrated_test_zone_save_still_verifies() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "TestZone"
	data.migrate()
	assert_true(data.verify(), "a migrated save must never be wiped by verify()")

#-----------------------------------------------------------------------------
# OLD SAVES
#-----------------------------------------------------------------------------

func test_old_save_loads_new_field_defaults() -> void:
	var loaded := _load_hand_written_save("""[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
gold = 42.0
""")
	assert_not_null(loaded)
	assert_eq(loaded.gold, 42.0)
	assert_eq(loaded.seen_action_ids, [] as Array[String], "a save from before the NEW tag has seen nothing")
	assert_false(loaded.seen_actions_initialized, "a save from before the NEW tag still needs its first pass")

func test_old_zone_progression_loads_empty_last_idle() -> void:
	var loaded := _load_hand_written_save("""[gd_resource type="Resource" script_class="SaveGameData" load_steps=3 format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]
[ext_resource type="Script" path="res://singletons/persistence_manager/zone_progression_data.gd" id="2_zone"]

[sub_resource type="Resource" id="Resource_zone"]
script = ExtResource("2_zone")
zone_id = "SpiritValley"
action_completion_count = Dictionary[String, int]({
"aura_well_training": 3
})

[resource]
script = ExtResource("1_save")
current_selected_zone_id = "SpiritValley"
zone_progression_data = Dictionary[String, ExtResource("2_zone")]({
"SpiritValley": SubResource("Resource_zone")
})
""")
	assert_not_null(loaded)
	var progression: ZoneProgressionData = loaded.get_zone_progression_data("SpiritValley")
	assert_eq(progression.action_completion_count.get("aura_well_training", 0), 3, "the old progression loads")
	assert_eq(progression.last_idle_action_id, "", "an old save has no last idle action")

#-----------------------------------------------------------------------------
# RESET
#-----------------------------------------------------------------------------

func test_reset_clears_seen_actions() -> void:
	var data := SaveGameData.new()
	data.seen_action_ids.append("wilderness_cycling_action")
	data.seen_actions_initialized = true
	data.reset()
	assert_true(data.seen_action_ids.is_empty())
	assert_false(data.seen_actions_initialized)
