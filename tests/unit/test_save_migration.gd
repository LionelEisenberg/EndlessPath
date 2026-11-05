extends GutTest

## Unit tests for SaveGameData: its version stamp and the migrations behind it
## (version 1 moves the old accessories; version 2 turns the stat values a
## version 1 save kept into trained levels, capped by the save's own stage),
## repair(), reset(), the training record a new or reset save writes out, and
## the save fields added for the map-first zone view. A save written before
## those fields existed must load with their defaults, and a save standing in
## the hidden Test Zone must move to Spirit Valley before verify() runs.
##
## The version 2 tests put in their own stages and stat caps (_use_stat_caps());
## after_each() puts the game's stages back.

const AttributeType = CharacterAttributesData.AttributeType
const Stage := CultivationManager.AdvancementStage

const TMP_OLD_SAVE_PATH: String = "user://__test_old_save_migration.tres"

## Where a save from before commit 0652b49 kept its two accessories in
## InventoryData.equipped_gear: the old EquipmentSlot ACCESSORY_1 and ACCESSORY_2.
const LEGACY_ACCESSORY_1: int = 4
const LEGACY_ACCESSORY_2: int = 5

var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_stages = CultivationManager.advancement_stage_resources

func after_each() -> void:
	CultivationManager.advancement_stage_resources = _original_stages
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

## Puts one stage per entry in place of the game's stages: the key is its
## stage_id and the value its stat_level_cap. A stage with no entry has no
## resource.
func _use_stat_caps(caps: Dictionary) -> void:
	var stages: Array[AdvancementStageResource] = []
	for stage: Stage in caps:
		var resource := AdvancementStageResource.new()
		resource.stage_id = stage
		resource.stat_level_cap = caps[stage]
		stages.append(resource)
	CultivationManager.advancement_stage_resources = stages

## The level the save's training record gives each of the six stats.
func _levels(data: SaveGameData) -> Dictionary:
	var levels: Dictionary = {}
	for stat: AttributeType in AttributeType.values():
		levels[stat] = data.stat_training.get_level(stat)
	return levels

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
# STAT TRAINING
#-----------------------------------------------------------------------------

## A new save writes every stat out at Lv 1 with no XP. It reads the record's
## dictionaries: get_level() and get_xp() give 1 and 0.0 for a missing key too.
func test_a_new_save_holds_every_stat_at_level_one() -> void:
	var training: StatTrainingData = SaveGameData.new_current().stat_training
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		var key: StringName = CharacterAttributesData.stat_key(stat)
		assert_eq(training.levels.get(key), 1, "%s is written at Lv 1" % key)
		assert_eq(training.xp.get(key), 0.0, "%s is written with no XP" % key)

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
# OLD STAT VALUES
#-----------------------------------------------------------------------------

## A v1 save's stat values become levels: one per point above the Lv 1 value,
## rounded down, from Lv 1, up to the cap of the save's own stage (no cap for a
## stage with no resource), with no XP. The old values are cleared.
func test_v2_turns_old_stat_values_into_levels() -> void:
	_use_stat_caps({Stage.FOUNDATION: 5, Stage.COPPER: 8})
	var cases: Array[Dictionary] = [
		{"name": "Aura Well Spirit 13 is Lv 4", "stage": Stage.FOUNDATION, "old_values": {&"spirit": 13.0}, "levels": {AttributeType.SPIRIT: 4}},
		{"name": "Spirit past the cap stops at it", "stage": Stage.FOUNDATION, "old_values": {&"spirit": 25.0}, "levels": {AttributeType.SPIRIT: 5}},
		{"name": "the save's own stage's cap", "stage": Stage.COPPER, "old_values": {&"spirit": 25.0}, "levels": {AttributeType.SPIRIT: 8}},
		{"name": "a fraction rounds down", "stage": Stage.FOUNDATION, "old_values": {&"strength": 12.5}, "levels": {AttributeType.STRENGTH: 3}},
		{"name": "below the Lv 1 value is Lv 1", "stage": Stage.FOUNDATION, "old_values": {&"body": 8.0}, "levels": {}},
		{"name": "no stage resource, no cap", "stage": Stage.IRON, "old_values": {&"spirit": 25.0}, "levels": {AttributeType.SPIRIT: 16}},
	]
	for case: Dictionary in cases:
		var data := SaveGameData.new()
		data.save_version = 1
		data.current_advancement_stage = case.stage
		data.character_attributes = CharacterAttributesData.make(case.old_values)
		data.migrate()
		for stat: AttributeType in AttributeType.values():
			var key: StringName = CharacterAttributesData.stat_key(stat)
			assert_eq(data.stat_training.get_level(stat), case.levels.get(stat, 1), "%s: %s's level" % [case.name, key])
			assert_eq(data.stat_training.get_xp(stat), 0.0, "%s: %s has no XP" % [case.name, key])
		assert_null(data.character_attributes, "%s: the old values are cleared" % case.name)

## A v1 save with no old values still comes out with every stat written.
func test_v2_with_no_old_stats_writes_every_stat_at_level_one() -> void:
	var data := SaveGameData.new()
	data.save_version = 1
	data.migrate()
	for stat: AttributeType in AttributeType.values():
		var key: StringName = CharacterAttributesData.stat_key(stat)
		assert_eq(data.stat_training.levels.get(key), 1, "%s is written at Lv 1" % key)
	assert_true(data.verify(), "the record is whole")

func test_v2_skips_a_current_save() -> void:
	var data := SaveGameData.new_current()
	data.stat_training.set_level(AttributeType.SPIRIT, 3)
	var old_values := CharacterAttributesData.make({&"spirit": 20.0})
	data.character_attributes = old_values
	data.migrate()
	assert_eq(data.stat_training.get_level(AttributeType.SPIRIT), 3, "turning old values into levels is a version 2 step, which this save has had")
	assert_same(data.character_attributes, old_values, "the old values are left as they were")

#-----------------------------------------------------------------------------
# REPAIR
#-----------------------------------------------------------------------------

func test_repair_clears_an_unknown_zone() -> void:
	var data := SaveGameData.new_current()
	data.current_selected_zone_id = "NoSuchZone"
	assert_false(data.verify(), "the save is invalid before it is repaired")
	assert_eq(data.repair(), PackedStringArray(["current_selected_zone_id"]), "repair() names what it changed")
	assert_eq(data.current_selected_zone_id, "", "an empty id still means 'the first zone in the list'")
	assert_true(data.verify(), "a repaired save passes verify()")

func test_repair_keeps_a_known_zone() -> void:
	var data := SaveGameData.new_current()
	data.current_selected_zone_id = "SpiritValley"
	assert_eq(data.repair(), PackedStringArray(), "nothing needed repairing")
	assert_eq(data.current_selected_zone_id, "SpiritValley")

func test_repair_fills_a_missing_stat() -> void:
	var data := SaveGameData.new_current()
	data.stat_training.set_level(AttributeType.SPIRIT, 4)
	data.stat_training.levels.erase(&"mind")
	assert_false(data.verify(), "a record missing a stat is invalid")
	assert_eq(data.repair(), PackedStringArray(["stat_training"]), "repair() names what it changed")
	assert_eq(data.stat_training.levels.get(&"mind"), 1, "written out at Lv 1, not left to the default")
	assert_eq(data.stat_training.get_level(AttributeType.SPIRIT), 4, "the rest is kept")
	assert_true(data.verify(), "a repaired save passes verify()")

func test_repair_makes_a_missing_record() -> void:
	var data := SaveGameData.new_current()
	data.stat_training = null
	assert_false(data.verify(), "a save with no training record is invalid")
	assert_eq(data.repair(), PackedStringArray(["stat_training"]), "repair() names what it changed")
	assert_true(data.verify(), "every stat is written at Lv 1")
	assert_eq(_levels(data).values(), [1, 1, 1, 1, 1, 1], "each stat's level is Lv 1")

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

## A v1 file as an older build wrote it. The Aura Well's Spirit becomes levels, and
## the loader drops the stats this build no longer has (Foundation, Resilience,
## Willpower).
func test_an_old_file_keeps_its_aura_well_spirit() -> void:
	_use_stat_caps({Stage.FOUNDATION: 5})
	var loaded := _load_hand_written_save("""[gd_resource type="Resource" script_class="SaveGameData" load_steps=3 format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]
[ext_resource type="Script" path="res://scripts/resource_definitions/character/character_attributes_data.gd" id="2_attrs"]

[sub_resource type="Resource" id="Resource_attrs"]
script = ExtResource("2_attrs")
strength = 12.5
spirit = 13.0
foundation = 15.0
resilience = 12.0
willpower = 11.0

[resource]
script = ExtResource("1_save")
save_version = 1
character_attributes = SubResource("Resource_attrs")
""")
	assert_not_null(loaded)
	if loaded == null:
		return
	loaded.migrate()
	assert_eq(loaded.save_version, SaveGameData.CURRENT_VERSION)
	assert_eq(_levels(loaded), {AttributeType.STRENGTH: 3, AttributeType.BODY: 1, AttributeType.AGILITY: 1,
		AttributeType.SPIRIT: 4, AttributeType.MIND: 1, AttributeType.CONTROL: 1})
	assert_null(loaded.character_attributes)

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
	var old_stat_training := data.stat_training
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
	assert_not_same(data.stat_training, old_stat_training, "reset leaves a new training record")
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		var key: StringName = CharacterAttributesData.stat_key(stat)
		assert_true(data.stat_training.levels.has(key), "the reset writes %s out: a current save is never migrated" % key)
	assert_not_same(data.unlock_progression, old_unlock_progression)
	assert_not_same(data.event_progression, old_event_progression)
	assert_not_same(data.quest_progression, old_quest_progression)
