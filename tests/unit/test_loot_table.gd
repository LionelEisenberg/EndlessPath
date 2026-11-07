extends GutTest

## Unit tests for LootTable.roll_loot(): sure entries drop, and an entry whose
## item can't drop now (a manual whose drill is known) is skipped while the rest
## of the table still rolls. Tests run on a fresh save with the real drill
## catalog; after_each() puts the original save back.

var _original_save: SaveGameData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

func _sure_entry(item: ItemDefinitionData) -> LootTableEntry:
	var entry := LootTableEntry.new()
	entry.item = item
	entry.drop_chance = 1.0
	return entry

func _manual(drill_id: String) -> DrillManualDefinitionData:
	var manual := DrillManualDefinitionData.new()
	manual.drill_id = drill_id
	return manual

func test_a_known_drills_manual_is_skipped_and_the_rest_still_rolls() -> void:
	var manual := _manual("horse_stance")
	var other := ItemDefinitionData.new()
	var table := LootTable.new()
	table.entries = [_sure_entry(manual), _sure_entry(other)] as Array[LootTableEntry]

	assert_eq(table.roll_loot(), {manual: 1, other: 1}, "an unknown drill's manual drops")
	BodyRefiningManager.unlock_drill("horse_stance")
	assert_eq(table.roll_loot(), {other: 1}, "a known drill's manual doesn't")
