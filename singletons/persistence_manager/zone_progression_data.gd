class_name ZoneProgressionData
extends Resource

@export var zone_id: String = ""
@export var unlocked_actions: Array[String] = []  # Action IDs
@export var completed_actions: Array[String] = []  # Completed one-time or multi-time action IDs
@export var forage_active: bool = false
@export var forage_start_time: float = 0.0
