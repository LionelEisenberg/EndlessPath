extends GutTest

## Unit tests for DrillManualDefinitionData: its type and tooltip, teaching its
## drill once through BodyRefiningManager, the log line for each case, and
## refusing to drop once its drill is known. Every test runs on a fresh save with
## the real drill catalog; after_each() puts the original save back.

var _original_save: SaveGameData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

func _manual(drill_id: String) -> DrillManualDefinitionData:
	var manual := DrillManualDefinitionData.new()
	manual.drill_id = drill_id
	manual.item_name = "%s Manual" % drill_id.capitalize()
	return manual

#-----------------------------------------------------------------------------
# TYPE AND TOOLTIP
#-----------------------------------------------------------------------------

func test_inits_as_a_drill_manual() -> void:
	var manual := _manual("horse_stance")
	assert_eq(manual.item_type, ItemDefinitionData.ItemType.DRILL_MANUAL)
	assert_eq(manual._get_item_type(), "Drill Manual")

func test_tooltip_names_the_drill_it_teaches() -> void:
	assert_eq(_manual("horse_stance")._get_item_effects(), ["Teaches Horse Stance"] as Array[String])

#-----------------------------------------------------------------------------
# TEACHING
#-----------------------------------------------------------------------------

func test_teach_unlocks_the_drill_once() -> void:
	var manual := _manual("falling_leaf")
	watch_signals(BodyRefiningManager)

	assert_true(manual.teach(), "the first reading teaches")
	assert_true(BodyRefiningManager.is_drill_unlocked("falling_leaf"))
	assert_false(manual.teach(), "a second reading teaches nothing")
	assert_signal_emit_count(BodyRefiningManager, "drill_unlocked", 1)

func test_is_known_follows_the_unlock() -> void:
	var manual := _manual("waterfall_tempering")
	assert_false(manual.is_known())
	BodyRefiningManager.unlock_drill("waterfall_tempering")
	assert_true(manual.is_known())

func test_an_unknown_drill_teaches_nothing() -> void:
	var manual := _manual("no_such_drill")
	assert_false(manual.teach())
	assert_push_error("unknown drill_id")

func test_log_lines() -> void:
	var manual := _manual("horse_stance")
	var cases: Array[Dictionary] = [
		{"taught": true, "text": "Learned Horse Stance from its manual"},
		{"taught": false, "text": "You know Horse Stance already"},
	]
	for case: Dictionary in cases:
		var line: String = manual.log_line(case.taught)
		assert_string_contains(line, case.text)
		assert_string_contains(line, "[color=")

#-----------------------------------------------------------------------------
# DROPPING
#-----------------------------------------------------------------------------

func test_drops_only_while_its_drill_is_unknown() -> void:
	var manual := _manual("horse_stance")
	assert_true(manual.can_drop())
	BodyRefiningManager.unlock_drill("horse_stance")
	assert_false(manual.can_drop())

func test_other_items_always_drop() -> void:
	assert_true(ItemDefinitionData.new().can_drop())
