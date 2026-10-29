extends GutTest

## Unit tests for AdventureTilemap.get_total_combat_count(), which fills
## AdventureResultData.combats_total for the end card.
## The method only reads the tilemap's encounter dictionary, which
## start_adventure() fills from the map generator. The tests build the tilemap
## from its script without entering the tree and fill that dictionary directly.

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _tilemap: AdventureTilemap

func before_each() -> void:
	_tilemap = autofree(AdventureTilemap.new())

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Places an encounter of the given type on the tilemap's map at coord.
func _place(coord: Vector3i, type: AdventureEncounter.EncounterType) -> void:
	var encounter := AdventureEncounter.new()
	encounter.encounter_type = type
	_tilemap._encounter_tile_dictionary[coord] = encounter

#-----------------------------------------------------------------------------
# ONE ENCOUNTER
#-----------------------------------------------------------------------------

## Each encounter type alone on the map: the four combat types count once, the
## rest not at all.
func test_each_encounter_type_on_its_own() -> void:
	var cases: Array[Array] = [
		[AdventureEncounter.EncounterType.COMBAT_REGULAR, 1],
		[AdventureEncounter.EncounterType.COMBAT_BOSS, 1],
		[AdventureEncounter.EncounterType.COMBAT_ELITE, 1],
		[AdventureEncounter.EncounterType.COMBAT_AMBUSH, 1],
		[AdventureEncounter.EncounterType.REST_SITE, 0],
		[AdventureEncounter.EncounterType.TRAP, 0],
		[AdventureEncounter.EncounterType.TREASURE, 0],
		[AdventureEncounter.EncounterType.NONE, 0],
	]
	var type_names: Array = AdventureEncounter.EncounterType.keys()
	for case: Array in cases:
		_tilemap._encounter_tile_dictionary.clear()
		_place(Vector3i.ZERO, case[0])
		assert_eq(_tilemap.get_total_combat_count(), case[1], type_names[case[0]])

#-----------------------------------------------------------------------------
# WHOLE MAPS
#-----------------------------------------------------------------------------

## Maps of several encounters count only their combats: an empty map, a mixed
## one, all four combat types at once, and a peaceful map with none.
func test_maps_count_only_their_combats() -> void:
	var cases: Array[Dictionary] = [
		{"name": "empty map", "count": 0, "tiles": {}},
		{"name": "mixed map: regular + elite + boss", "count": 3, "tiles": {
			Vector3i(0, 0, 0): AdventureEncounter.EncounterType.NONE,
			Vector3i(1, 0, -1): AdventureEncounter.EncounterType.COMBAT_REGULAR,
			Vector3i(0, 1, -1): AdventureEncounter.EncounterType.REST_SITE,
			Vector3i(-1, 1, 0): AdventureEncounter.EncounterType.COMBAT_ELITE,
			Vector3i(1, -1, 0): AdventureEncounter.EncounterType.TREASURE,
			Vector3i(2, 0, -2): AdventureEncounter.EncounterType.COMBAT_BOSS,
		}},
		{"name": "all four combat types", "count": 4, "tiles": {
			Vector3i(0, 0, 0): AdventureEncounter.EncounterType.COMBAT_REGULAR,
			Vector3i(1, 0, -1): AdventureEncounter.EncounterType.COMBAT_BOSS,
			Vector3i(0, 1, -1): AdventureEncounter.EncounterType.COMBAT_ELITE,
			Vector3i(-1, 1, 0): AdventureEncounter.EncounterType.COMBAT_AMBUSH,
		}},
		{"name": "peaceful map", "count": 0, "tiles": {
			Vector3i(0, 0, 0): AdventureEncounter.EncounterType.NONE,
			Vector3i(1, 0, -1): AdventureEncounter.EncounterType.REST_SITE,
			Vector3i(0, 1, -1): AdventureEncounter.EncounterType.TREASURE,
			Vector3i(-1, 1, 0): AdventureEncounter.EncounterType.TRAP,
		}},
	]
	for case: Dictionary in cases:
		_tilemap._encounter_tile_dictionary.clear()
		for coord: Vector3i in case.tiles:
			_place(coord, case.tiles[coord])
		assert_eq(_tilemap.get_total_combat_count(), case.count, case.name)
