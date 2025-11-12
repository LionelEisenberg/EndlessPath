extends MarginContainer

signal action_selected(action_data: ZoneActionData)

@export var action_data: ZoneActionData = null
@export var is_unlocked: bool = true
@export var is_completed: bool = false
@export var completion_count: int = 0
@export var is_current_action: bool = false

@onready var icon_texture: TextureRect = %IconTexture
@onready var zone_action_button: Button = %ZoneActionButton
@onready var name_label: Label = %NameLabel

func _ready():
	if ActionManager:
		ActionManager.current_action_changed.connect(_on_current_action_changed)
		is_current_action = ActionManager.get_current_action() == action_data

	if action_data:
		setup_action(action_data)
	
	zone_action_button.pressed.connect(_on_button_pressed)

func setup_action(data: ZoneActionData) -> void:
	action_data = data
	
	if name_label:
		name_label.text = data.action_name
	
	if icon_texture and data.icon:
		icon_texture.texture = data.icon

func _on_button_pressed() -> void:
	if action_data and not zone_action_button.disabled and not is_current_action:
		if ActionManager:
			ActionManager.select_action(action_data)

func _on_current_action_changed(new_current_action_changed: ZoneActionData) -> void:
	if action_data == new_current_action_changed:
		self.modulate = Color.WHITE
		is_current_action = true
	else:
		self.modulate.a = 0.5
		is_current_action = false
