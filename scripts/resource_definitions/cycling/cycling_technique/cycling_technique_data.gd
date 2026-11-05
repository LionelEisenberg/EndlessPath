class_name CyclingTechniqueData
extends Resource

## One cycling technique: the path the Madra ball follows, how long a cycle takes,
## the Madra a cycle pays and the scoring zones along the path, with the icon its
## drawer shows in the zone chest, and what it trains: Spirit, and at most one
## other Spiritual stat. CyclingManager loads the catalog from
## resources/cycling/cycling_techniques/cycling_technique_list.tres.

@export var id: String = ""
@export var technique_name: String = "Basic Cycling"
## The technique's icon, 16 art px shown at 32 (its drawer in the zone chest).
@export var icon: Texture2D
@export var path_curve: Curve2D  # The path shape
@export var cycle_duration: float = 10.0 # Seconds for one complete cycle
@export var base_madra_per_cycle: float = 25.0  # Madra a cycle pays at Spirit Lv 1, in 0.08 s steps while the cursor is on the ball
## The Spirit XP a fully followed cycle pays. Every technique pays some.
@export var spirit_xp_per_cycle: float = 0.0
## The one other stat the technique trains, through its own mini-game: an
## AttributeType (MIND or CONTROL), or -1 for none.
@export var minor_stat: int = -1

@export var cycling_zones: Array[CyclingZoneData] = []

## Returns the Madra a followed cycle draws at `madra_multiplier`, Spirit's
## (CharacterAttributesData.get_cycling_madra_multiplier()):
## base_madra_per_cycle x madra_multiplier.
func get_madra_per_cycle(madra_multiplier: float = 1.0) -> float:
	return base_madra_per_cycle * madra_multiplier

## Returns the Madra a second of drawing pays at `madra_multiplier`: the Madra
## per cycle over cycle_duration, which is the top of the rate a cycle reads.
## 0.0 for a cycle of no length.
func get_madra_per_second(madra_multiplier: float = 1.0) -> float:
	if cycle_duration <= 0.0:
		return 0.0
	return get_madra_per_cycle(madra_multiplier) / cycle_duration
