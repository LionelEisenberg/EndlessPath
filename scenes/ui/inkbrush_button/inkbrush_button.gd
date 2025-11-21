class_name InkbrushButton
extends TextureButton

# Animation constants
const HOVER_ANIMATION_DURATION = 0.2
const HOVER_SCALE_FACTOR = 0.05

# Label color constants
const LABEL_COLOR_NORMAL = Color(1, 1, 1)
const LABEL_COLOR_HOVER = Color(0, 0, 0)

static var button_texture_list : Array[Texture2D] = [
	load("res://assets/ui_images/action_buttons/action_button_1.png"), 
	load("res://assets/ui_images/action_buttons/action_button_2.png"), 
	load("res://assets/ui_images/action_buttons/action_button_3.png")
]

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel

var is_current : bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	material.set_shader_parameter("fill_amount", 0.0)
	

func setup(label: String, texture: Texture2D, fill_color: Color = Color(1, 1, 1)) -> void:
	# Set all the button texture randomly from the button_texture_list
	var random_texture : Texture = button_texture_list[randi() % button_texture_list.size()]
	texture_normal = random_texture
	$MarginContainer/IconTexture.texture = texture
	$MarginContainer/NameLabel.text = label
	material.set_shader_parameter("fill_color", fill_color)

func _on_mouse_entered():
	pivot_offset = size / 2
	if not is_current:
		var hover_tween = create_tween()
		hover_tween.parallel().tween_method(_set_shader_fill_amount, 0.0, 1.0, HOVER_ANIMATION_DURATION)
		hover_tween.parallel().tween_method(_scale_container, 0.0, 1.0, HOVER_ANIMATION_DURATION)
		hover_tween.parallel().tween_method(_set_label_color, 0.0, 1.0, HOVER_ANIMATION_DURATION)
		hover_tween.play()

func _on_mouse_exited():
	if not is_current:
		var hover_tween = create_tween()
		hover_tween.parallel().tween_method(_set_shader_fill_amount, 1.0, 0.0, HOVER_ANIMATION_DURATION)
		hover_tween.parallel().tween_method(_scale_container, 1.0, 0.0, HOVER_ANIMATION_DURATION)
		hover_tween.parallel().tween_method(_set_label_color, 1.0, 0.0, HOVER_ANIMATION_DURATION)
		hover_tween.play()

func _set_shader_fill_amount(amount : float) -> void:
	self.material.set_shader_parameter("fill_amount", amount)

func _set_label_color(amount: float) -> void:
	var interpolated_color = LABEL_COLOR_NORMAL.lerp(LABEL_COLOR_HOVER, amount)
	name_label.add_theme_color_override("font_color", interpolated_color)

func _scale_container(r: float) -> void:
	scale = Vector2(r * HOVER_SCALE_FACTOR + 1.0, r * HOVER_SCALE_FACTOR + 1.0)
