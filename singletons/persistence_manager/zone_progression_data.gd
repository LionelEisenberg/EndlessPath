class_name ZoneProgressionData
extends Resource

@export var zone_id: String = ""

## Dict ZoneActionData.action_id -> num_completions
@export var action_completion_count : Dictionary[String, int] = {}
@export var forage_active: bool = false
@export var forage_start_time: float = 0.0

## Accumulated ticks per training action_id in this zone.
@export var training_tick_progress: Dictionary[String, int] = {}

func _to_string() -> String:
	return "ZoneProgressionData(ZoneId: %s\n, ActionCompletionCount: %s\n, ForageActive: %s\n, ForageStartTime: %s\n, TrainingTickProgress: %s\n)" % [zone_id, str(action_completion_count), forage_active, forage_start_time, str(training_tick_progress)]
