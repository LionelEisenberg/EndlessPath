class_name CyclingTechniqueData
extends Resource

@export var id: String = ""
@export var technique_name: String = "Basic Cycling"
## The technique's icon, 16 art px shown at 32 (its drawer in the zone chest).
@export var icon: Texture2D
@export var path_curve: Curve2D  # The path shape
@export var cycle_duration: float = 10.0 # Seconds for one complete cycle (Replaced cycle_speed)
@export var base_madra_per_cycle: float = 25.0  # Base madra awarded per cycle (scaled by mouse tracking accuracy)

@export var cycling_zones: Array[CyclingZoneData] = []
