extends GutTest

## Unit tests for AdventureResultData
## Tests default values and data contract

#-----------------------------------------------------------------------------
# DEFAULTS
#-----------------------------------------------------------------------------

## A fresh result is a defeat with no reason, nothing counted and no loot.
func test_defaults() -> void:
	var data := AdventureResultData.new()
	var cases: Array[Array] = [
		["is_victory", false],
		["defeat_reason", ""],
		["combats_fought", 0],
		["combats_total", 0],
		["gold_earned", 0],
		["time_elapsed", 0.0],
		["health_remaining", 0.0],
		["health_max", 0.0],
		["tiles_explored", 0],
		["tiles_total", 0],
		["madra_spent", 0.0],
	]
	for case: Array in cases:
		assert_eq(data.get(case[0]), case[1], "%s default" % case[0])
	assert_eq(data.loot_items.size(), 0, "loot should be empty by default")

#-----------------------------------------------------------------------------
# POPULATION
#-----------------------------------------------------------------------------

## The result keeps what the view fills in: a victory's figures, and a
## defeat's reason.
func test_populate() -> void:
	var cases: Array[Dictionary] = [
		{"name": "victory", "fields": {
			"is_victory": true,
			"combats_fought": 5,
			"combats_total": 8,
			"gold_earned": 42,
			"time_elapsed": 120.5,
			"health_remaining": 75.0,
			"health_max": 100.0,
			"tiles_explored": 7,
			"tiles_total": 12,
			"madra_spent": 150.0,
		}},
		{"name": "defeat with reason", "fields": {
			"is_victory": false,
			"defeat_reason": "Your health reached zero",
			"health_remaining": 0.0,
		}},
	]
	for case: Dictionary in cases:
		var data := AdventureResultData.new()
		for field: String in case.fields:
			data.set(field, case.fields[field])
		for field: String in case.fields:
			assert_eq(data.get(field), case.fields[field], "%s: %s" % [case.name, field])

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
