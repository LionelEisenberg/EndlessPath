extends Node2D

@export var reset_save_data : bool = false

func _ready() -> void:
	if reset_save_data and PersistenceManager:
		PersistenceManager.load_new_save_data()
	
func _input(event: InputEvent):
	# check if a dialog is already running
	if Dialogic.current_timeline != null:
		return

	if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
		DialogueManager.start_timeline("spirit_valley")
