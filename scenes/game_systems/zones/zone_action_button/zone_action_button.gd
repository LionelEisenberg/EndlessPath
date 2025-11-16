extends MarginContainer

signal action_selected(action_data: ZoneActionData)

const hover_animation_duration : float = 0.2

static var button_texture_list : Array[Texture2D] = [
	load("res://assets/ui_images/action_buttons/action_button_1.png"), 
	load("res://assets/ui_images/action_buttons/action_button_2.png"), 
	load("res://assets/ui_images/action_buttons/action_button_3.png")
]

@export var action_data: ZoneActionData = null
@export var is_unlocked: bool = true
@export var is_completed: bool = false
@export var completion_count: int = 0
@export var is_current_action: bool = false

@onready var icon_texture: TextureRect = %IconTexture
@onready var zone_action_button: TextureButton = %ZoneActionButton
@onready var name_label: Label = %NameLabel

func _ready():	
	if ActionManager:
		ActionManager.current_action_changed.connect(_on_current_action_changed)
		is_current_action = ActionManager.get_current_action() == action_data

	if action_data:
		setup_action(action_data)
	
	zone_action_button.pressed.connect(_on_button_pressed)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	zone_action_button.material.set_shader_parameter("fill_amount", 0.0)

func _on_mouse_entered():
	pivot_offset = size / 2
	if not is_current_action:
		var hover_tween = create_tween()
		hover_tween.parallel().tween_method(_set_shader_fill_amount, 0.0, 1.0, hover_animation_duration)
		hover_tween.parallel().tween_method(_scale_container, 0.0, 1.0, hover_animation_duration)
		hover_tween.parallel().tween_method(_set_label_color, 0.0, 1.0, hover_animation_duration)
		hover_tween.play()

func _on_mouse_exited():
	if not is_current_action:
		var hover_tween = create_tween()
		hover_tween.parallel().tween_method(_set_shader_fill_amount, 1.0, 0.0, hover_animation_duration)
		hover_tween.parallel().tween_method(_scale_container, 1.0, 0.0, hover_animation_duration)
		hover_tween.parallel().tween_method(_set_label_color, 1.0, 0.0, hover_animation_duration)
		hover_tween.play()

func _set_shader_fill_amount(amount : float) -> void:
	zone_action_button.material.set_shader_parameter("fill_amount", amount)

func _set_label_color(amount: float) -> void:
	var end_color = Color(0, 0, 0)
	var start_color = Color(1, 1, 1)
	var interpolated_color = start_color.lerp(end_color, amount)
	name_label.add_theme_color_override("font_color", interpolated_color)

func _scale_container(r: float) -> void:
	const scale_factor : float = 0.05
	scale = Vector2(r * scale_factor + 1.0, r * scale_factor + 1.0)

func setup_action(data: ZoneActionData) -> void:
	action_data = data

	if zone_action_button:
		# Set all the button texture randomly from the button_texture_list
		var random_texture : Texture = button_texture_list[randi() % button_texture_list.size()]
		zone_action_button.texture_normal = random_texture
		zone_action_button.texture_pressed = random_texture
		zone_action_button.texture_hover = random_texture
		zone_action_button.texture_focused = random_texture
		zone_action_button.texture_disabled = random_texture
	
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
		is_current_action = true
	elif is_current_action:
		is_current_action = false
		_on_mouse_exited()
