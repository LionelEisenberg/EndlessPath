class_name CyclingTechniqueData
extends Resource

@export var technique_name: String = "Basic Cycling"
@export var path_curve: Curve2D  # The path shape
@export var cycle_duration: float = 10.0 # Seconds for one complete cycle (Replaced cycle_speed)
@export var base_madra_per_second: float = 2.5

# --- This is the key change ---
# Now it exports an Array OF CyclingZoneData resources.
# This makes it editable in the Inspector!
@export var cycling_zones: Array[CyclingZoneData] = []
