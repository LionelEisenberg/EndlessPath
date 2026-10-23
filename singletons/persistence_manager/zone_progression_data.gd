class_name ZoneProgressionData
extends Resource

@export var zone_id: String = ""

## Dict ZoneActionData.action_id -> num_completions
@export var action_completion_count : Dictionary[String, int] = {}
@export var forage_active: bool = false
@export var forage_start_time: float = 0.0

## Accumulated ticks per training action_id in this zone.
@export var training_tick_progress: Dictionary[String, int] = {}

## action_id of the idle action (foraging or training) last started in this
## zone. The zone resumes it when it is still available. Empty when none has run.
@export var last_idle_action_id: String = ""

func _to_string() -> String:
	return "ZoneProgressionData(ZoneId: %s\n, ActionCompletionCount: %s\n, ForageActive: %s\n, ForageStartTime: %s\n, TrainingTickProgress: %s\n, LastIdleActionId: %s\n)" % [zone_id, str(action_completion_count), forage_active, forage_start_time, str(training_tick_progress), last_idle_action_id]
