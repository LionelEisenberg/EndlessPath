class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE actions. Owns the sweep ColorRect (action_card_sweep shader)
## and spawns floating text for rolled loot on foraging_completed.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")
const FLOATING_TEXT_TRAJECTORY: Vector2 = Vector2(-200, -40)
const FLOATING_TEXT_COLOR: Color = Color(0.75, 0.92, 0.65)
const FILL_TINT_OPACITY: float = 0.45
const SWEEP_RESET_DURATION: float = 0.3
const SWEEP_FADE_IN_DURATION: float = 0.1

@onready var _progress_fill: ColorRect = %ProgressFill

var _sweep_tween: Tween = null
var _is_tracking_timer: bool = false

func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, _inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button
	_progress_fill.reparent(overlay_slot)
	_progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_fill_color(button.get_category_color())
	_set_fill_amount(0.0)
	ActionManager.foraging_completed.connect(_on_foraging_completed)

func teardown() -> void:
	if ActionManager.foraging_completed.is_connected(_on_foraging_completed):
		ActionManager.foraging_completed.disconnect(_on_foraging_completed)
	_kill_sweep_tween()

func set_is_current(is_current: bool) -> void:
	if is_current:
		_start_sweep()
	else:
		_stop_sweep()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _is_tracking_timer:
		var timer: Timer = ActionManager.action_timer
		if timer.wait_time > 0.0 and not timer.is_stopped():
			var progress: float = 1.0 - (timer.time_left / timer.wait_time)
			_set_fill_amount(progress)

func _set_fill_amount(amount: float) -> void:
	if is_instance_valid(_progress_fill) and _progress_fill.material:
		_progress_fill.material.set_shader_parameter("fill_amount", amount)

func _set_fill_color(cat_color: Color) -> void:
	if is_instance_valid(_progress_fill):
		_progress_fill.color = Color(cat_color, FILL_TINT_OPACITY)

func _kill_sweep_tween() -> void:
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	_sweep_tween = null

func _start_sweep() -> void:
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	_is_tracking_timer = true

func _reset_and_restart_sweep() -> void:
	_is_tracking_timer = false
	_set_fill_amount(1.0)
	_kill_sweep_tween()
	_sweep_tween = create_tween()
	var cat_color: Color = button.get_category_color()
	var flash: Color = Color(cat_color.r * 1.5, cat_color.g * 3.0, cat_color.b * 1.5, 1.0)
	_sweep_tween.tween_property(_progress_fill, "self_modulate", flash, 0.1).set_ease(Tween.EASE_OUT)
	_sweep_tween.tween_property(_progress_fill, "self_modulate:a", 0.0, SWEEP_RESET_DURATION).set_ease(Tween.EASE_OUT)
	_sweep_tween.tween_callback(func() -> void:
		_progress_fill.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		_is_tracking_timer = true
	)
	_sweep_tween.tween_property(_progress_fill, "self_modulate:a", 1.0, SWEEP_FADE_IN_DURATION)

func _stop_sweep() -> void:
	_is_tracking_timer = false
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	if is_instance_valid(_progress_fill):
		_progress_fill.self_modulate.a = 1.0

func _on_foraging_completed(items: Dictionary) -> void:
	if action_data != ActionManager.get_current_action():
		return
	_reset_and_restart_sweep()
	_spawn_floating_text(items)

func _spawn_floating_text(items: Dictionary) -> void:
	if items.is_empty():
		return
	var text_parts: Array[String] = []
	for item in items:
		var quantity: int = items[item]
		text_parts.append("+%d %s" % [quantity, item.item_name])
	var full_text: String = ", ".join(text_parts)
	var floating_text: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	get_tree().current_scene.add_child(floating_text)
	var spawn_pos: Vector2 = button.get_action_card().global_position + Vector2(-150, 20)
	floating_text.show_text(full_text, FLOATING_TEXT_COLOR, spawn_pos, FLOATING_TEXT_TRAJECTORY)
