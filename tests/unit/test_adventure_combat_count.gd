extends GutTest

## Unit tests for adventure combat counting logic
## Tests the encounter type filtering used by get_total_combat_count()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _combat_types: Array = [
	AdventureEncounter.EncounterType.COMBAT_REGULAR,
	AdventureEncounter.EncounterType.COMBAT_BOSS,
	AdventureEncounter.EncounterType.COMBAT_ELITE,
	AdventureEncounter.EncounterType.COMBAT_AMBUSH,
]

func _make_encounter(type: AdventureEncounter.EncounterType) -> AdventureEncounter:
	var encounter := AdventureEncounter.new()
	encounter.encounter_type = type
	return encounter

func _count_combats(encounters: Dictionary) -> int:
	var count: int = 0
	for encounter in encounters.values():
		if encounter.encounter_type in _combat_types:
			count += 1
	return count

#-----------------------------------------------------------------------------
# EMPTY MAP
#-----------------------------------------------------------------------------

func test_empty_map_zero_combats() -> void:
	var encounters: Dictionary = {}
	assert_eq(_count_combats(encounters), 0)

#-----------------------------------------------------------------------------
# COMBAT TYPES COUNTED
#-----------------------------------------------------------------------------

func test_regular_combat_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	}
	assert_eq(_count_combats(encounters), 1)

func test_boss_combat_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.COMBAT_BOSS)
	}
	assert_eq(_count_combats(encounters), 1)

func test_elite_combat_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.COMBAT_ELITE)
	}
	assert_eq(_count_combats(encounters), 1)

func test_ambush_combat_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	}
	assert_eq(_count_combats(encounters), 1)

#-----------------------------------------------------------------------------
# NON-COMBAT TYPES NOT COUNTED
#-----------------------------------------------------------------------------

func test_rest_site_not_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.REST_SITE)
	}
	assert_eq(_count_combats(encounters), 0)

func test_trap_not_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.TRAP)
	}
	assert_eq(_count_combats(encounters), 0)

func test_treasure_not_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.TREASURE)
	}
	assert_eq(_count_combats(encounters), 0)

func test_none_not_counted() -> void:
	var encounters: Dictionary = {
		Vector3i.ZERO: _make_encounter(AdventureEncounter.EncounterType.NONE)
	}
	assert_eq(_count_combats(encounters), 0)

#-----------------------------------------------------------------------------
# MIXED MAPS
#-----------------------------------------------------------------------------

func test_mixed_map_counts_only_combats() -> void:
	var encounters: Dictionary = {
		Vector3i(0, 0, 0): _make_encounter(AdventureEncounter.EncounterType.NONE),
		Vector3i(1, 0, -1): _make_encounter(AdventureEncounter.EncounterType.COMBAT_REGULAR),
		Vector3i(0, 1, -1): _make_encounter(AdventureEncounter.EncounterType.REST_SITE),
		Vector3i(-1, 1, 0): _make_encounter(AdventureEncounter.EncounterType.COMBAT_ELITE),
		Vector3i(1, -1, 0): _make_encounter(AdventureEncounter.EncounterType.TREASURE),
		Vector3i(2, 0, -2): _make_encounter(AdventureEncounter.EncounterType.COMBAT_BOSS),
	}
	assert_eq(_count_combats(encounters), 3, "should count regular + elite + boss")

func test_all_combat_types_in_one_map() -> void:
	var encounters: Dictionary = {
		Vector3i(0, 0, 0): _make_encounter(AdventureEncounter.EncounterType.COMBAT_REGULAR),
		Vector3i(1, 0, -1): _make_encounter(AdventureEncounter.EncounterType.COMBAT_BOSS),
		Vector3i(0, 1, -1): _make_encounter(AdventureEncounter.EncounterType.COMBAT_ELITE),
		Vector3i(-1, 1, 0): _make_encounter(AdventureEncounter.EncounterType.COMBAT_AMBUSH),
	}
	assert_eq(_count_combats(encounters), 4, "all four combat types should count")

func test_no_combats_on_peaceful_map() -> void:
	var encounters: Dictionary = {
		Vector3i(0, 0, 0): _make_encounter(AdventureEncounter.EncounterType.NONE),
		Vector3i(1, 0, -1): _make_encounter(AdventureEncounter.EncounterType.REST_SITE),
		Vector3i(0, 1, -1): _make_encounter(AdventureEncounter.EncounterType.TREASURE),
		Vector3i(-1, 1, 0): _make_encounter(AdventureEncounter.EncounterType.TRAP),
	}
	assert_eq(_count_combats(encounters), 0, "no combat encounters on peaceful map")
