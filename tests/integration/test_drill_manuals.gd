extends GutTest

## Integration tests for drill manuals: every drill but the starting one has a
## manual under resources/items/drill_manuals/, each drops from a Shallow Woods
## encounter at its approved chance, and a manual teaches its drill however it
## arrives (the encounter's own loot effect, the dev panel), lighting the body
## refining card and logging one line. A second copy teaches nothing and is not
## kept. Every test runs on a fresh save; after_each() puts the original back.

const MANUALS_DIR: String = "res://resources/items/drill_manuals/"
const SHALLOW_WOODS: AdventureData = preload("res://resources/adventure/data/shallow_woods.tres")
const BODY_REFINING_ID: String = "riverbank_training_action"
const STARTING_DRILL_ID: String = "stone_lifting"

## The approved drops: each manual's drill → the encounter that drops it and the
## chance a win drops it.
const APPROVED_DROPS: Dictionary = {
	"horse_stance": {"encounter": "ravenous_dreadbeast_encounter", "chance": 0.25},
	"falling_leaf": {"encounter": "coalescing_spirit_encounter", "chance": 0.25},
	"waterfall_tempering": {"encounter": "manifested_spirit_encounter", "chance": 0.35},
}

var _original_save: SaveGameData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every manual under MANUALS_DIR, by the drill it teaches.
func _manuals() -> Dictionary:
	var result: Dictionary = {}
	for file_name: String in ResourceLoader.list_directory(MANUALS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var manual := load(MANUALS_DIR + file_name) as DrillManualDefinitionData
		assert_not_null(manual, "%s is a drill manual" % file_name)
		if manual != null:
			result[manual.drill_id] = manual
	return result

## Every encounter a Shallow Woods map can hold: its quotas and its boss.
func _shallow_woods_encounters() -> Array[AdventureEncounter]:
	var result: Array[AdventureEncounter] = []
	for quota: EncounterQuota in SHALLOW_WOODS.encounter_quotas:
		result.append(quota.encounter)
	result.append(SHALLOW_WOODS.boss_encounter)
	return result

## The loot effect and entry on `encounter` that drop `item`, as
## {"effect": AwardLootTableEffectData, "entry": LootTableEntry}, or {} for none.
func _drop_of(encounter: AdventureEncounter, item: ItemDefinitionData) -> Dictionary:
	for choice: EncounterChoice in encounter.choices:
		for effect: EffectData in choice.success_effects:
			if effect is AwardLootTableEffectData and effect.loot_table != null:
				for entry: LootTableEntry in effect.loot_table.entries:
					if entry != null and entry.item == item:
						return {"effect": effect, "entry": entry}
	return {}

## A copy of `encounter`'s loot effect for `item` in which only that item's entry
## rolls, and always drops: the encounter's drop, with the luck taken out.
func _sure_drop(encounter: AdventureEncounter, item: ItemDefinitionData) -> AwardLootTableEffectData:
	var drop: Dictionary = _drop_of(encounter, item)
	var entry := (drop.entry as LootTableEntry).duplicate() as LootTableEntry
	entry.drop_chance = 1.0
	var effect := (drop.effect as AwardLootTableEffectData).duplicate() as AwardLootTableEffectData
	effect.loot_table = LootTable.new()
	effect.loot_table.entries = [entry] as Array[LootTableEntry]
	return effect

func _encounter_by_id(encounter_id: String) -> AdventureEncounter:
	for encounter: AdventureEncounter in _shallow_woods_encounters():
		if encounter.encounter_id == encounter_id:
			return encounter
	return null

#-----------------------------------------------------------------------------
# CONTENT
#-----------------------------------------------------------------------------

func test_each_drill_but_the_starting_one_has_a_manual() -> void:
	var expected: Array = []
	for drill: DrillData in BodyRefiningManager.get_all_drills():
		if drill.id != STARTING_DRILL_ID:
			expected.append(drill.id)
	var taught: Array = _manuals().keys()
	expected.sort()
	taught.sort()
	assert_eq(taught, expected)

func test_every_manual_drops_in_the_shallow_woods() -> void:
	var manuals: Dictionary = _manuals()
	for drill_id: String in manuals:
		var approved: Dictionary = APPROVED_DROPS.get(drill_id, {})
		var dropped_by: Array[String] = []
		var chance: float = -1.0
		for encounter: AdventureEncounter in _shallow_woods_encounters():
			var drop: Dictionary = _drop_of(encounter, manuals[drill_id])
			if not drop.is_empty():
				dropped_by.append(encounter.encounter_id)
				chance = (drop.entry as LootTableEntry).drop_chance
		assert_eq(dropped_by, [approved.get("encounter", "?")] as Array[String], "%s's manual drops from one encounter" % drill_id)
		assert_almost_eq(chance, float(approved.get("chance", -1.0)), 0.0001, "%s's manual drops at its approved chance" % drill_id)

func test_each_manual_has_an_icon_and_a_description() -> void:
	for manual: DrillManualDefinitionData in _manuals().values():
		assert_not_null(manual.icon, "%s has an icon" % manual.item_id)
		assert_false(manual.description.is_empty(), "%s has a description" % manual.item_id)

#-----------------------------------------------------------------------------
# TEACHING
#-----------------------------------------------------------------------------

func test_a_looted_manual_teaches_its_drill() -> void:
	var manuals: Dictionary = _manuals()
	for drill_id: String in APPROVED_DROPS:
		var encounter: AdventureEncounter = _encounter_by_id(APPROVED_DROPS[drill_id].encounter)
		ZoneManager.mark_action_seen(BODY_REFINING_ID)
		watch_signals(InventoryManager)
		watch_signals(LogManager)

		_sure_drop(encounter, manuals[drill_id]).process()

		assert_true(BodyRefiningManager.is_drill_unlocked(drill_id), "%s is learned from its drop" % drill_id)
		assert_signal_emitted_with_parameters(InventoryManager, "item_awarded", [manuals[drill_id], 1])
		assert_false(ZoneManager.is_action_seen(BODY_REFINING_ID), "Riverbank Training shows NEW for %s" % drill_id)
		var line: String = str(get_signal_parameters(LogManager, "message_logged")[0])
		assert_string_contains(line, "Learned %s from its manual" % BodyRefiningManager.get_drill(drill_id).drill_name)
		assert_false(InventoryManager.has_item(manuals[drill_id].item_id), "%s's manual isn't kept" % drill_id)

func test_a_second_copy_teaches_nothing() -> void:
	var manual: DrillManualDefinitionData = _manuals()["horse_stance"]
	InventoryManager.award_items(manual, 1)
	ZoneManager.mark_action_seen(BODY_REFINING_ID)
	watch_signals(BodyRefiningManager)
	watch_signals(LogManager)

	InventoryManager.award_items(manual, 1)

	assert_signal_not_emitted(BodyRefiningManager, "drill_unlocked")
	assert_true(ZoneManager.is_action_seen(BODY_REFINING_ID), "the card doesn't show NEW again")
	assert_string_contains(str(get_signal_parameters(LogManager, "message_logged")[0]), "You know Horse Stance already")
	assert_false(InventoryManager.has_item(manual.item_id), "the copy isn't kept")

func test_a_known_drills_manual_stops_dropping() -> void:
	var manual: DrillManualDefinitionData = _manuals()["falling_leaf"]
	var drop := _sure_drop(_encounter_by_id("coalescing_spirit_encounter"), manual)
	BodyRefiningManager.unlock_drill("falling_leaf")
	watch_signals(InventoryManager)

	drop.process()

	assert_signal_not_emitted(InventoryManager, "item_awarded")

func test_a_manual_from_the_dev_panel_teaches() -> void:
	var manual: DrillManualDefinitionData = _manuals()["waterfall_tempering"]

	assert_eq(DevCommands.award_item(manual.resource_path, 1), "")

	assert_true(BodyRefiningManager.is_drill_unlocked("waterfall_tempering"))
