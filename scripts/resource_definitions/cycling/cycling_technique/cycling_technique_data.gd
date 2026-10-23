class_name CyclingTechniqueData
extends Resource

## One cycling technique: the path the Madra ball follows, how long a cycle takes,
## the Madra a cycle pays and the click zones along the path, with the icon its
## drawer shows in the zone chest. CyclingManager loads the catalog from
## resources/cycling/cycling_techniques/cycling_technique_list.tres.

@export var id: String = ""
@export var technique_name: String = "Basic Cycling"
## The technique's icon, 16 art px shown at 32 (its drawer in the zone chest).
@export var icon: Texture2D
@export var path_curve: Curve2D  # The path shape
@export var cycle_duration: float = 10.0 # Seconds for one complete cycle
@export var base_madra_per_cycle: float = 25.0  # Madra a cycle pays, in 0.08 s steps while the cursor is on the ball

@export var cycling_zones: Array[CyclingZoneData] = []
