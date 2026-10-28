extends Node2D

@export var log_print_level: Log.Event = Log.Event.DEBUG

func _ready() -> void:
	Log.set_print_level(log_print_level)

## Adds the frame to the save's playtime. The delta is already scaled by
## Engine.time_scale, so the dev time speeds count as fast as they run.
func _process(delta: float) -> void:
	PersistenceManager.save_game_data.stats.add_play_time(delta)
