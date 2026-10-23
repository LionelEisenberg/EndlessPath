extends RefCounted

## AdventureMapFixture
## The six-tile adventure map that the tests driving the real AdventureTilemap
## scene play on, shared so that no test file copies it: its tiles in cube
## coordinates, the map and its choices, the action it is played with, a click
## on a tile, and the player's vitals set to known values for the walks.
## Statics only. GUT collects only files named test_*, so it never runs this
## one; tests preload it as a const.
##
## START and the two OPEN tiles hold nothing. FIGHT sits next to START and
## BOSS behind FIGHT, so the boss is revealed only once FIGHT is visited. From
## START the player sees FIGHT, OPEN_NEAR and REST; OPEN_FAR and BOSS are fog
## until a tile next to them is visited, and a fogged tile cannot be hovered
## or clicked in the game.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The action the map is played with (the Shallow Woods: its map reaches 5
## tiles from the start).
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")

const START := Vector3i(0, 0, 0)
const FIGHT := Vector3i(1, -1, 0)
const OPEN_NEAR := Vector3i(0, 1, -1)
const OPEN_FAR := Vector3i(0, 2, -2)
const REST := Vector3i(-1, 1, 0)
const BOSS := Vector3i(2, -2, 0)

## One hop between neighbouring tiles takes about a second; allow a few.
const HOP_TIMEOUT_SECONDS := 3.0

## The player's vitals are one persistent object shared by every test: the ones
## swap_in_known_vitals() sets, remembered and put back.
const VITALS_FIELDS: Array[StringName] = [
	&"max_health", &"current_health", &"max_stamina", &"current_stamina",
	&"health_regen", &"stamina_regen",
]

#-----------------------------------------------------------------------------
# THE MAP
#-----------------------------------------------------------------------------

## A fresh copy of the fixture map. FIGHT holds a combat choice against one
## Amorphous Spirit (fight_choice()), REST a choice that heals 10 Health
## (rest_choice()) and BOSS the boss's combat choice.
static func build_map() -> Dictionary[Vector3i, AdventureEncounter]:
	var map: Dictionary[Vector3i, AdventureEncounter] = {}
	map[START] = NoOpEncounter.new()
	map[OPEN_NEAR] = NoOpEncounter.new()
	map[OPEN_FAR] = NoOpEncounter.new()

	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	var fight := CombatChoice.new()
	fight.label = "Fight"
	fight.enemy_pool = pool
	map[FIGHT] = encounter(AdventureEncounter.EncounterType.COMBAT_REGULAR, fight)

	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 10.0
	var heal_effects: Array[EffectData] = [heal]
	var rest := EncounterChoice.new()
	rest.label = "Rest"
	rest.success_effects = heal_effects
	map[REST] = encounter(AdventureEncounter.EncounterType.REST_SITE, rest)

	var boss_choice := CombatChoice.new()
	boss_choice.label = "Face the boss"
	boss_choice.is_boss = true
	boss_choice.enemy_pool = pool
	map[BOSS] = encounter(AdventureEncounter.EncounterType.COMBAT_BOSS, boss_choice)
	return map

## An encounter of the given type with one choice.
static func encounter(type: AdventureEncounter.EncounterType, choice: EncounterChoice) -> AdventureEncounter:
	var choices: Array[EncounterChoice] = [choice]
	var result := AdventureEncounter.new()
	result.encounter_type = type
	result.choices = choices
	return result

## The map's fight choice, on FIGHT.
static func fight_choice(map: Dictionary[Vector3i, AdventureEncounter]) -> CombatChoice:
	return map[FIGHT].choices[0] as CombatChoice

## The map's rest choice, on REST.
static func rest_choice(map: Dictionary[Vector3i, AdventureEncounter]) -> EncounterChoice:
	return map[REST].choices[0]

#-----------------------------------------------------------------------------
# PLAYING IT
#-----------------------------------------------------------------------------

## Clicks a tile the way the map layer reports a click: with the tile's map cell.
static func click(tilemap: AdventureTilemap, coord: Vector3i) -> void:
	tilemap.visible_map.tile_clicked.emit(tilemap.visible_map.cube_to_map(coord))

## Remembers the player's vitals, then sets known ones: Health 50 of 100, full
## Stamina, no regeneration while a walk takes its time. Returns what it
## remembered, for restore_vitals().
static func swap_in_known_vitals() -> Dictionary[StringName, float]:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	var saved: Dictionary[StringName, float] = {}
	for field: StringName in VITALS_FIELDS:
		saved[field] = vitals.get(field)
	vitals.max_health = 100.0
	vitals.current_health = 50.0
	vitals.max_stamina = 100.0
	vitals.current_stamina = 100.0
	vitals.health_regen = 0.0
	vitals.stamina_regen = 0.0
	return saved

## Puts back the vitals swap_in_known_vitals() remembered.
static func restore_vitals(saved: Dictionary[StringName, float]) -> void:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	for field: StringName in saved:
		vitals.set(field, saved[field])
