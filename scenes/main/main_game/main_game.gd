extends Node2D

@export var log_print_level: Log.Event = Log.Event.DEBUG

@onready var _dev_password_modal: Control = %DevPasswordModal
@onready var _dev_panel: PanelContainer = %DevPanel

var _dev_unlocked: bool = false

func _ready() -> void:
	Log.set_print_level(log_print_level)
	_dev_password_modal.unlocked.connect(_on_dev_unlocked)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_D:
			_on_dev_hotkey()
			get_viewport().set_input_as_handled()

func _on_dev_hotkey() -> void:
	if not FileAccess.file_exists("user://dev_password.txt"):
		return
	if _dev_unlocked:
		if _dev_panel.visible:
			_dev_panel.visible = false
		else:
			_dev_panel.open()
	else:
		_dev_password_modal.open()

func _on_dev_unlocked() -> void:
	_dev_unlocked = true
	_dev_panel.open()
