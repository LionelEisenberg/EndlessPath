extends GutTest

## Unit tests for AdventureResultData
## Tests default values and data contract

#-----------------------------------------------------------------------------
# DEFAULTS
#-----------------------------------------------------------------------------

func test_defaults_victory_false() -> void:
	var data := AdventureResultData.new()
	assert_false(data.is_victory, "should default to defeat")

func test_defaults_defeat_reason_empty() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.defeat_reason, "", "defeat reason should be empty by default")

func test_defaults_combats_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.combats_fought, 0)
	assert_eq(data.combats_total, 0)

func test_defaults_gold_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.gold_earned, 0)

func test_defaults_time_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.time_elapsed, 0.0)

func test_defaults_health_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.health_remaining, 0.0)
	assert_eq(data.health_max, 0.0)

func test_defaults_tiles_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.tiles_explored, 0)
	assert_eq(data.tiles_total, 0)

func test_defaults_madra_zero() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.madra_spent, 0.0)

func test_defaults_loot_empty() -> void:
	var data := AdventureResultData.new()
	assert_eq(data.loot_items.size(), 0, "loot should be empty by default")

#-----------------------------------------------------------------------------
# POPULATION
#-----------------------------------------------------------------------------

func test_populate_victory() -> void:
	var data := AdventureResultData.new()
	data.is_victory = true
	data.combats_fought = 5
	data.combats_total = 8
	data.gold_earned = 42
	data.time_elapsed = 120.5
	data.health_remaining = 75.0
	data.health_max = 100.0
	data.tiles_explored = 7
	data.tiles_total = 12
	data.madra_spent = 150.0

	assert_true(data.is_victory)
	assert_eq(data.combats_fought, 5)
	assert_eq(data.combats_total, 8)
	assert_eq(data.gold_earned, 42)
	assert_almost_eq(data.time_elapsed, 120.5, 0.01)
	assert_eq(data.health_remaining, 75.0)
	assert_eq(data.health_max, 100.0)
	assert_eq(data.tiles_explored, 7)
	assert_eq(data.tiles_total, 12)
	assert_eq(data.madra_spent, 150.0)

func test_populate_defeat_with_reason() -> void:
	var data := AdventureResultData.new()
	data.is_victory = false
	data.defeat_reason = "Your health reached zero"
	data.health_remaining = 0.0

	assert_false(data.is_victory)
	assert_eq(data.defeat_reason, "Your health reached zero")
	assert_eq(data.health_remaining, 0.0)

func test_loot_items_accepts_resources() -> void:
	var data := AdventureResultData.new()
	var sword := EquipmentDefinitionData.new()
	sword.item_name = "Test Sword"
	var dagger := EquipmentDefinitionData.new()
	dagger.item_name = "Test Dagger"

	data.loot_items = [sword, dagger]
	assert_eq(data.loot_items.size(), 2)
	assert_eq(data.loot_items[0], sword)
	assert_eq(data.loot_items[1], dagger)
