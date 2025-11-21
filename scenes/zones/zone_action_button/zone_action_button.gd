extends MarginContainer

#signal action_selected(action_data: ZoneActionData)

@export var action_data: ZoneActionData = null
@export var is_current_action: bool:
	set(value):
		is_current_action = value
		zone_action_button.is_current = is_current_action

@onready var zone_action_button: TextureButton = %ZoneActionButton

func _ready() -> void:	
	if ActionManager:
		ActionManager.current_action_changed.connect(_on_current_action_changed)
		is_current_action = ActionManager.get_current_action() == action_data

	if action_data:
		setup_action(action_data)
	
	zone_action_button.pressed.connect(_on_button_pressed)

func setup_action(data: ZoneActionData) -> void:
	action_data = data
	
	if zone_action_button:
		zone_action_button.setup(data.action_name, data.icon)

func _on_button_pressed() -> void:
	if action_data and not zone_action_button.disabled and not is_current_action:
		if ActionManager:
			ActionManager.select_action(action_data)

func _on_current_action_changed(new_current_action_changed: ZoneActionData) -> void:
	if action_data == new_current_action_changed:
		is_current_action = true
	elif is_current_action:
		is_current_action = false
		zone_action_button._on_mouse_exited()
