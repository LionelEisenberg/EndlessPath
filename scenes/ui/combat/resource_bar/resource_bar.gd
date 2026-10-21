class_name ResourceBar
extends Control

## ResourceBar
## Flat vitals bar (health / madra / stamina) with a delayed "ghost" segment
## that trails behind damage, a name on the left and the value on the right.

const FLOATING_TEXT_SCENE = preload("res://scenes/ui/floating_text/floating_text.tscn")
const PREVIEW_TINT_OK: Color = Color(1.0, 1.0, 1.0, 1.0)
const PREVIEW_TINT_SHORT: Color = Color(1.0, 0.35, 0.3, 1.0)

## Fill stylebox for this resource (e.g. bar_fill_health.tres).
@export var fill_style: StyleBox
## Spawns floating "+/-" text next to the bar on changes.
@export var show_floating_text: bool = true
## Name shown on the left side of the bar.
@export var label_prefix: String = "Resource":
	set(value):
		label_prefix = value
		if is_node_ready():
			_name_label.text = value
## Thin variant: smaller text, used for secondary resources.
@export var compact: bool = false

@onready var timer: Timer = %GhostTimer
@onready var main_bar: ProgressBar = %MainBar
@onready var ghost_bar: ProgressBar = %GhostBar
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _cost_preview: Panel = %CostPreview

var _current_value: float = -1.0
var _max_value: float = -1.0
var _main_tween: Tween
var _ghost_tween: Tween
var _preview_amount: float = 0.0
var _preview_tween: Tween

func _ready() -> void:
	if fill_style:
		main_bar.add_theme_stylebox_override("fill", fill_style)
	_name_label.text = label_prefix
	if compact:
		custom_minimum_size.y = 18.0
		_name_label.theme_type_variation = &"LabelSmall"
		_value_label.theme_type_variation = &"LabelSmall"
	_setup_timer()

func _setup_timer() -> void:
	timer.wait_time = 0.45
	timer.one_shot = true
	if not timer.timeout.is_connected(_on_ghost_timer_timeout):
		timer.timeout.connect(_on_ghost_timer_timeout)

## Updates the bar values. `regen_rate` is surfaced in the tooltip only.
func update_values(new_current: float, new_max: float, regen_rate: float = 0.0) -> void:
	_value_label.text = "%d / %d" % [int(new_current), int(new_max)]
	tooltip_text = "%s regenerates %.1f / s" % [label_prefix, regen_rate] if regen_rate != 0.0 else ""

	main_bar.max_value = new_max
	ghost_bar.max_value = new_max

	if _preview_amount > 0.0:
		_update_cost_preview.call_deferred()

	# Initialize if first run
	if _current_value < 0:
		_current_value = new_current
		_max_value = new_max
		main_bar.value = new_current
		ghost_bar.value = new_current
		return

	var diff: float = new_current - _current_value
	_current_value = new_current
	_max_value = new_max

	if diff < 0:
		# Damage / spend: main bar snaps quickly, ghost trails after a delay
		_tween_main(new_current, 0.12)
		timer.start()
		if diff <= -1.0 and show_floating_text:
			_spawn_floating_text(str(int(diff)), Color("#e86a5c"))
	elif diff > 0:
		# Gain: both move together
		_tween_main(new_current, 0.2)
		_kill(_ghost_tween)
		ghost_bar.value = maxf(ghost_bar.value, new_current)
		if diff >= 1.0 and show_floating_text:
			_spawn_floating_text("+" + str(int(diff)), Color("#7fd18b"))

## Highlights the part of the bar that spending `amount` would use (0 hides it).
## Turns red when the amount can't be afforded.
func preview_cost(amount: float) -> void:
	_preview_amount = maxf(amount, 0.0)
	_update_cost_preview()

func _update_cost_preview() -> void:
	if _preview_amount <= 0.0 or _max_value <= 0.0:
		_cost_preview.visible = false
		if _preview_tween and _preview_tween.is_valid():
			_preview_tween.kill()
		return
	var current: float = maxf(_current_value, 0.0)
	var start: float = maxf(current - _preview_amount, 0.0)
	var width: float = main_bar.size.x
	_cost_preview.position = main_bar.position + Vector2(width * start / _max_value, 0.0)
	_cost_preview.size = Vector2(width * (current - start) / _max_value, main_bar.size.y)
	_cost_preview.self_modulate = PREVIEW_TINT_OK if _preview_amount <= current else PREVIEW_TINT_SHORT
	if not _cost_preview.visible:
		_cost_preview.visible = true
		_preview_tween = create_tween().set_loops()
		_preview_tween.tween_property(_cost_preview, "modulate:a", 0.45, 0.35).set_trans(Tween.TRANS_SINE)
		_preview_tween.tween_property(_cost_preview, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)

## Snaps both bars to the given values without animation.
func reset_values(new_current: float, new_max: float) -> void:
	_current_value = -1.0
	update_values(new_current, new_max)

func _tween_main(target: float, duration: float) -> void:
	_kill(_main_tween)
	_main_tween = create_tween()
	_main_tween.tween_property(main_bar, "value", target, duration).set_ease(Tween.EASE_OUT)

func _on_ghost_timer_timeout() -> void:
	_kill(_ghost_tween)
	_ghost_tween = create_tween()
	_ghost_tween.tween_property(ghost_bar, "value", _current_value, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_floating_text(text: String, color: Color) -> void:
	var floating_text = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(floating_text)
	var spawn_pos: Vector2 = global_position + Vector2(size.x + 12.0, -size.y * 0.5)
	floating_text.show_text(text, color, spawn_pos)

func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
