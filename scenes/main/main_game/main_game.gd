extends Node2D

@export var log_print_level: Log.Event = Log.Event.DEBUG

@onready var _dev_panel: PanelContainer = %DevPanel

func _ready() -> void:
	Log.set_print_level(log_print_level)

## Adds the frame to the save's playtime. The delta is already scaled by
## Engine.time_scale, so the dev time speeds count as fast as they run.
func _process(delta: float) -> void:
	PersistenceManager.save_game_data.stats.add_play_time(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_D:
			_on_dev_hotkey()
			get_viewport().set_input_as_handled()

func _on_dev_hotkey() -> void:
	if _dev_panel.visible:
		_dev_panel.visible = false
	else:
		_dev_panel.open()
