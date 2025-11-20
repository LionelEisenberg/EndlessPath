class_name ResourceBar
extends Control

const FLOATING_TEXT_SCENE = preload("res://scenes/ui/floating_text/floating_text.tscn")

@export var progress : Texture2D
@export var show_floating_text : bool = true

@onready var timer = %GhostTimer
@onready var main_bar = %ResourceProgressBar
@onready var ghost_bar = %GhostProgressBar

var _current_value: float = -1.0
var _max_value: float = -1.0

func _ready() -> void:
	if not progress:
		Log.error("ResourceBar: Progress texture is missing!")
		return
	setup_progress_bars()
	setup_timer()

func setup_timer() -> void:
	timer.wait_time = 0.5
	timer.one_shot = true
	if not timer.timeout.is_connected(_on_ghost_timer_timeout):
		timer.timeout.connect(_on_ghost_timer_timeout)

func setup_progress_bars() -> void:
	main_bar.texture_progress = progress
	ghost_bar.texture_progress = progress
	
	# Ensure ghost bar is behind main bar (should be set in scene, but good to enforce)
	ghost_bar.show_behind_parent = true

func update_values(new_current: float, new_max: float) -> void:
	# Initialize if first run
	if _current_value < 0:
		_current_value = new_current
		_max_value = new_max
		main_bar.max_value = new_max
		main_bar.value = new_current
		ghost_bar.max_value = new_max
		ghost_bar.value = new_current
		return

	var diff = new_current - _current_value
	_current_value = new_current
	_max_value = new_max
	
	main_bar.max_value = new_max
	ghost_bar.max_value = new_max
	
	if diff < 0:
		# Damage taken
		main_bar.value = new_current
		timer.start()
		
		if new_current != new_max and show_floating_text:
			_spawn_floating_text(str(int(diff)), Color.RED)
		
	elif diff > 0:
		# Healed
		main_bar.value = new_current
		ghost_bar.value = new_current # Ghost bar catches up immediately on heal
		
		if new_current != new_max and show_floating_text:
			_spawn_floating_text("+" + str(int(diff)), Color.GREEN)
	
	# If equal, do nothing

func _on_ghost_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(ghost_bar, "value", _current_value, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_floating_text(text: String, color: Color) -> void:
	var floating_text = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(floating_text)
	# Position slightly above the center of the bar
	var center_pos = main_bar.global_position + main_bar.size / 2
	center_pos.y -= 20 # Offset up
	floating_text.show_text(text, color, center_pos)
