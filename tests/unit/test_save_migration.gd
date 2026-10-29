extends GutTest

## Unit tests for SaveGameData: its version stamp and the migrations behind it,
## repair(), reset(), and the save fields added for the map-first zone view. A
## save written before those fields existed must load with their defaults, and
## a save standing in the hidden Test Zone must move to Spirit Valley before
## verify() runs.

const TMP_OLD_SAVE_PATH: String = "user://__test_old_save_migration.tres"

## Where a save from before commit 0652b49 kept its two accessories in
## InventoryData.equipped_gear: the old EquipmentSlot ACCESSORY_1 and ACCESSORY_2.
const LEGACY_ACCESSORY_1: int = 4
const LEGACY_ACCESSORY_2: int = 5

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

func _make_gear(item_id: String, slot: EquipmentDefinitionData.EquipmentSlot) -> ItemInstanceData:
	var definition := EquipmentDefinitionData.new()
	definition.item_id = item_id
	definition.slot_type = slot
	var instance := ItemInstanceData.new()
	instance.item_definition = definition
	return instance

#-----------------------------------------------------------------------------
# ZONE ID MIGRATION
#-----------------------------------------------------------------------------

## migrate() moves a save standing in Test Zone to Spirit Valley, and leaves any
## other zone, the empty id included, where it is.
func test_migrate_maps_the_zone_id() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Test Zone moves to Spirit Valley", "zone": "TestZone", "expected": "SpiritValley"},
		{"name": "another zone is unchanged", "zone": "SpiritValley", "expected": "SpiritValley"},
		{"name": "an empty id still means 'the first zone in the list'", "zone": "", "expected": ""},
	]
	for case: Dictionary in cases:
		var data := SaveGameData.new()
		data.current_selected_zone_id = case.zone
		data.migrate()
		assert_eq(data.current_selected_zone_id, case.expected, case.name)

func test_migrated_test_zone_save_still_verifies() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "TestZone"
	data.migrate()
	assert_true(data.verify(), "a migrated save must never be wiped by verify()")

func test_a_current_save_in_test_zone_still_moves() -> void:
	var data := SaveGameData.new_current()
	data.current_selected_zone_id = "TestZone"
	data.migrate()
	assert_eq(data.current_selected_zone_id, "SpiritValley", "the dev panel can leave a current save in Test Zone, so the move runs on every load")
	assert_eq(data.save_version, SaveGameData.CURRENT_VERSION)

#-----------------------------------------------------------------------------
# SAVE VERSION
#-----------------------------------------------------------------------------

func test_migrate_stamps_the_current_version() -> void:
	var data := SaveGameData.new()
	assert_eq(data.save_version, 0, "a save made with new() is unversioned until it is migrated")
	data.migrate()
	assert_eq(data.save_version, SaveGameData.CURRENT_VERSION)

func test_new_current_is_stamped() -> void:
	assert_eq(SaveGameData.new_current().save_version, SaveGameData.CURRENT_VERSION)

func test_the_version_survives_a_save_and_load() -> void:
	ResourceSaver.save(SaveGameData.new_current(), TMP_OLD_SAVE_PATH)
	var loaded := ResourceLoader.load(TMP_OLD_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData
	assert_not_null(loaded)
	assert_eq(loaded.save_version, SaveGameData.CURRENT_VERSION)

func test_older_and_current_saves_are_not_from_a_newer_build() -> void:
	assert_false(SaveGameData.new().is_from_newer_build(), "an unversioned save is older, not newer")
	assert_false(SaveGameData.new_current().is_from_newer_build(), "a save at the current version is this build's own")

func test_a_newer_save_is_left_alone() -> void:
	var data := SaveGameData.new()
	data.save_version = SaveGameData.CURRENT_VERSION + 1
	data.current_selected_zone_id = "TestZone"
	data.migrate()
	assert_eq(data.save_version, SaveGameData.CURRENT_VERSION + 1, "a newer build's version is never lowered")
	assert_eq(data.current_selected_zone_id, "TestZone", "a newer build's data is not rewritten")
	assert_true(data.is_from_newer_build())

func test_to_string_names_the_version() -> void:
	assert_string_contains(str(SaveGameData.new_current()), "SaveVersion: %d" % SaveGameData.CURRENT_VERSION)

#-----------------------------------------------------------------------------
# LEGACY ACCESSORIES
#-----------------------------------------------------------------------------

func test_v1_moves_legacy_accessories() -> void:
	var data := SaveGameData.new()
	var weapon := _make_gear("test_sword", EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	var first := _make_gear("test_first_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	var second := _make_gear("test_second_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	data.inventory.equipped_gear = {
		EquipmentDefinitionData.EquipmentSlot.MAIN_HAND: weapon,
		LEGACY_ACCESSORY_1: first,
		LEGACY_ACCESSORY_2: second,
	}
	data.migrate()
	assert_eq(data.inventory.equipped_accessories, {0: first, 1: second})
	assert_false(data.inventory.equipped_gear.has(LEGACY_ACCESSORY_1), "the old accessory 1 key is cleared")
	assert_false(data.inventory.equipped_gear.has(LEGACY_ACCESSORY_2), "the old accessory 2 key is cleared")
	assert_eq(data.inventory.equipped_gear, {EquipmentDefinitionData.EquipmentSlot.MAIN_HAND: weapon}, "the singular slots are untouched")

func test_v1_keeps_an_occupied_accessory_slot() -> void:
	var data := SaveGameData.new()
	var worn := _make_gear("test_worn_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	var legacy := _make_gear("test_legacy_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	data.inventory.equipped_accessories[0] = worn
	data.inventory.equipped_gear[LEGACY_ACCESSORY_1] = legacy
	data.migrate()
	assert_eq(data.inventory.equipped_accessories, {0: worn}, "the accessory already in slot 0 is not replaced")
	assert_eq(data.inventory.equipped_gear, {LEGACY_ACCESSORY_1: legacy}, "the old accessory stays where it was found")

func test_v1_checks_each_accessory_slot_on_its_own() -> void:
	var data := SaveGameData.new()
	var worn := _make_gear("test_worn_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	var blocked := _make_gear("test_blocked_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	var movable := _make_gear("test_movable_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	data.inventory.equipped_accessories[0] = worn
	data.inventory.equipped_gear = {LEGACY_ACCESSORY_1: blocked, LEGACY_ACCESSORY_2: movable}
	data.migrate()
	assert_eq(data.inventory.equipped_accessories, {0: worn, 1: movable}, "a free slot is filled even when the other is taken")
	assert_eq(data.inventory.equipped_gear, {LEGACY_ACCESSORY_1: blocked}, "only the blocked one stays")

func test_v1_skips_a_current_save() -> void:
	var data := SaveGameData.new_current()
	var legacy := _make_gear("test_legacy_ring", EquipmentDefinitionData.EquipmentSlot.ACCESSORY)
	data.inventory.equipped_gear[LEGACY_ACCESSORY_1] = legacy
	data.migrate()
	assert_eq(data.inventory.equipped_gear, {LEGACY_ACCESSORY_1: legacy}, "the accessory move is a version 1 step, which this save has already had")
	assert_true(data.inventory.equipped_accessories.is_empty())

#-----------------------------------------------------------------------------
# REPAIR
#-----------------------------------------------------------------------------

func test_repair_clears_an_unknown_zone() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "NoSuchZone"
	assert_false(data.verify(), "the save is invalid before it is repaired")
	assert_eq(data.repair(), PackedStringArray(["current_selected_zone_id"]), "repair() names what it changed")
	assert_eq(data.current_selected_zone_id, "", "an empty id still means 'the first zone in the list'")
	assert_true(data.verify(), "a repaired save passes verify()")

func test_repair_keeps_a_known_zone() -> void:
	var data := SaveGameData.new()
	data.current_selected_zone_id = "SpiritValley"
	assert_eq(data.repair(), PackedStringArray(), "nothing needed repairing")
	assert_eq(data.current_selected_zone_id, "SpiritValley")

#-----------------------------------------------------------------------------
# OLD SAVES
#-----------------------------------------------------------------------------

func test_an_old_file_loads_as_unversioned() -> void:
	var loaded := _load_hand_written_save("""[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
gold = 42.0
""")
	assert_not_null(loaded)
	assert_eq(loaded.save_version, 0, "a file written before saves had versions holds no save_version key")

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

func test_reset_matches_a_fresh_save() -> void:
	var data := SaveGameData.new()
	var old_inventory := data.inventory
	var old_character_attributes := data.character_attributes
	var old_unlock_progression := data.unlock_progression
	var old_event_progression := data.event_progression
	var old_quest_progression := data.quest_progression
	data.madra = 99.0
	data.core_density_milestones[CultivationManager.AdvancementStage.FOUNDATION] = 10
	data.get_zone_progression_data("SpiritValley")
	data.unlocked_ability_ids.append("test_ability")
	data.get_merchant_ledger("test_merchant")

	data.reset()

	assert_eq(data.madra, 25.0)
	assert_eq(data.core_density_milestones, {})
	assert_eq(data.zone_progression_data, {})
	assert_eq(data.merchant_ledgers, {})
	assert_eq(data.unlocked_ability_ids, SaveGameData.new().unlocked_ability_ids, "the ability list is back to its declared default")
	assert_eq(data.save_version, SaveGameData.CURRENT_VERSION, "a reset save is a current one")
	assert_not_same(data.inventory, old_inventory, "reset leaves a new inventory, not the old one emptied")
	assert_not_same(data.character_attributes, old_character_attributes)
	assert_not_same(data.unlock_progression, old_unlock_progression)
	assert_not_same(data.event_progression, old_event_progression)
	assert_not_same(data.quest_progression, old_quest_progression)
