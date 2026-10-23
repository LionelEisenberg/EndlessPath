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
# EMPTY MAP
#-----------------------------------------------------------------------------

func test_empty_map_zero_combats() -> void:
	assert_eq(_tilemap.get_total_combat_count(), 0)

#-----------------------------------------------------------------------------
# COMBAT TYPES COUNTED
#-----------------------------------------------------------------------------

func test_regular_combat_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.COMBAT_REGULAR)
	assert_eq(_tilemap.get_total_combat_count(), 1)

func test_boss_combat_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_eq(_tilemap.get_total_combat_count(), 1)

func test_elite_combat_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.COMBAT_ELITE)
	assert_eq(_tilemap.get_total_combat_count(), 1)

func test_ambush_combat_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	assert_eq(_tilemap.get_total_combat_count(), 1)

#-----------------------------------------------------------------------------
# NON-COMBAT TYPES NOT COUNTED
#-----------------------------------------------------------------------------

func test_rest_site_not_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.REST_SITE)
	assert_eq(_tilemap.get_total_combat_count(), 0)

func test_trap_not_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.TRAP)
	assert_eq(_tilemap.get_total_combat_count(), 0)

func test_treasure_not_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.TREASURE)
	assert_eq(_tilemap.get_total_combat_count(), 0)

func test_none_not_counted() -> void:
	_place(Vector3i.ZERO, AdventureEncounter.EncounterType.NONE)
	assert_eq(_tilemap.get_total_combat_count(), 0)

#-----------------------------------------------------------------------------
# MIXED MAPS
#-----------------------------------------------------------------------------

func test_mixed_map_counts_only_combats() -> void:
	_place(Vector3i(0, 0, 0), AdventureEncounter.EncounterType.NONE)
	_place(Vector3i(1, 0, -1), AdventureEncounter.EncounterType.COMBAT_REGULAR)
	_place(Vector3i(0, 1, -1), AdventureEncounter.EncounterType.REST_SITE)
	_place(Vector3i(-1, 1, 0), AdventureEncounter.EncounterType.COMBAT_ELITE)
	_place(Vector3i(1, -1, 0), AdventureEncounter.EncounterType.TREASURE)
	_place(Vector3i(2, 0, -2), AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_eq(_tilemap.get_total_combat_count(), 3, "should count regular + elite + boss")

func test_all_combat_types_in_one_map() -> void:
	_place(Vector3i(0, 0, 0), AdventureEncounter.EncounterType.COMBAT_REGULAR)
	_place(Vector3i(1, 0, -1), AdventureEncounter.EncounterType.COMBAT_BOSS)
	_place(Vector3i(0, 1, -1), AdventureEncounter.EncounterType.COMBAT_ELITE)
	_place(Vector3i(-1, 1, 0), AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	assert_eq(_tilemap.get_total_combat_count(), 4, "all four combat types should count")

func test_no_combats_on_peaceful_map() -> void:
	_place(Vector3i(0, 0, 0), AdventureEncounter.EncounterType.NONE)
	_place(Vector3i(1, 0, -1), AdventureEncounter.EncounterType.REST_SITE)
	_place(Vector3i(0, 1, -1), AdventureEncounter.EncounterType.TREASURE)
	_place(Vector3i(-1, 1, 0), AdventureEncounter.EncounterType.TRAP)
	assert_eq(_tilemap.get_total_combat_count(), 0, "no combat encounters on peaceful map")
