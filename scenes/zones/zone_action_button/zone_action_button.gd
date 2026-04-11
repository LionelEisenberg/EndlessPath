extends MarginContainer
## Action card button for zone actions.
## Adventure actions show a Madra badge and disable when unaffordable.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")
const FLOATING_TEXT_TRAJECTORY: Vector2 = Vector2(-200, -40)
const FLOATING_TEXT_COLOR: Color = Color(0.75, 0.92, 0.65)
const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")
const CARD_SELECTED: StyleBox = preload("res://assets/styleboxes/zones/action_card_selected.tres")
const DIMMED_MODULATE: Color = Color(0.55, 0.55, 0.55, 1.0)
const NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
## Maps active ActionTypes to their category color. Unmapped types (MERCHANT,
## TRAIN_STATS, ZONE_EVENT, QUEST_GIVER) fall back to DEFAULT_CATEGORY_COLOR
## since they have no zone action buttons yet.
const CATEGORY_COLORS: Dictionary = {
	ZoneActionData.ActionType.FORAGE: Color(0.42, 0.67, 0.37),
	ZoneActionData.ActionType.CYCLING: Color(0.37, 0.66, 0.62),
	ZoneActionData.ActionType.ADVENTURE: Color(0.61, 0.25, 0.25),
	ZoneActionData.ActionType.NPC_DIALOGUE: Color(0.83, 0.66, 0.29),
}
const DEFAULT_CATEGORY_COLOR: Color = Color(0.5, 0.5, 0.5)
const FILL_TINT_OPACITY: float = 0.45
const SWEEP_RESET_DURATION: float = 0.3
const SWEEP_FADE_IN_DURATION: float = 0.1

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()
		if is_instance_valid(_progress_fill):
			_update_progress_fill()

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: RichTextLabel = %ActionDescLabel
@onready var _madra_badge_container: HBoxContainer = %MadraBadgeContainer
@onready var _madra_icon: TextureRect = %MadraIcon
@onready var _madra_badge: RichTextLabel = %MadraBadge
@onready var _progress_fill: ColorRect = %ProgressFill

var _is_affordable: bool = true
var _sweep_tween: Tween = null
var _cached_selected_style: StyleBoxFlat = null
var _is_tracking_timer: bool = false

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	ActionManager.foraging_completed.connect(_on_foraging_completed)
	if ActionManager.get_current_action() == action_data:
		is_current_action = true
	_action_card.mouse_entered.connect(_on_mouse_entered)
	_action_card.mouse_exited.connect(_on_mouse_exited)
	_action_card.gui_input.connect(_on_card_input)
	if action_data:
		_setup_labels()

	if action_data and action_data.action_type == ZoneActionData.ActionType.ADVENTURE:
		ResourceManager.madra_changed.connect(_on_madra_changed_for_threshold)
		_update_adventure_state()

func _exit_tree() -> void:
	if ActionManager.current_action_changed.is_connected(_on_current_action_changed):
		ActionManager.current_action_changed.disconnect(_on_current_action_changed)
	if ResourceManager.madra_changed.is_connected(_on_madra_changed_for_threshold):
		ResourceManager.madra_changed.disconnect(_on_madra_changed_for_threshold)
	if ActionManager.foraging_completed.is_connected(_on_foraging_completed):
		ActionManager.foraging_completed.disconnect(_on_foraging_completed)
	_kill_sweep_tween()

## Sets up the card with action data.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_instance_valid(_action_name_label):
		_setup_labels()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _get_category_color() -> Color:
	if action_data == null:
		return DEFAULT_CATEGORY_COLOR
	return CATEGORY_COLORS.get(action_data.action_type, DEFAULT_CATEGORY_COLOR)

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

func _process(_delta: float) -> void:
	if _is_tracking_timer:
		var timer: Timer = ActionManager.action_timer
		if timer.wait_time > 0.0 and not timer.is_stopped():
			var progress: float = 1.0 - (timer.time_left / timer.wait_time)
			_set_fill_amount(progress)

func _start_sweep(_duration: float) -> void:
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	_is_tracking_timer = true

func _reset_and_restart_sweep(_duration: float) -> void:
	_is_tracking_timer = false
	_set_fill_amount(1.0)
	_kill_sweep_tween()
	_sweep_tween = create_tween()
	# Bright flash on completion — boost category color channel via HDR
	var flash_color: Color = _get_category_color()
	var flash: Color = Color(flash_color.r * 1.5, flash_color.g * 3.0, flash_color.b * 1.5, 1.0)
	_sweep_tween.tween_property(_progress_fill, "self_modulate", flash, 0.1).set_ease(Tween.EASE_OUT)
	# Fade out while still bright
	_sweep_tween.tween_property(_progress_fill, "self_modulate:a", 0.0, SWEEP_RESET_DURATION).set_ease(Tween.EASE_OUT)
	# Reset to normal, resume tracking
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

func _update_progress_fill() -> void:
	if not is_instance_valid(_progress_fill):
		return

	if is_current_action and action_data:
		var cat_color: Color = _get_category_color()
		_set_fill_color(cat_color)

		if action_data is ForageActionData:
			var forage_data: ForageActionData = action_data as ForageActionData
			_start_sweep(forage_data.foraging_interval_in_sec)
		else:
			# Non-timed action: instant full tint
			_set_fill_amount(1.0)
	else:
		_stop_sweep()

func _setup_labels() -> void:
	_action_name_label.text = action_data.action_name
	if action_data.description != "":
		_action_desc_label.text = action_data.description
		_action_desc_label.visible = true
	else:
		_action_desc_label.text = ""
		_action_desc_label.visible = false

func _update_madra_badge() -> void:
	if action_data == null or action_data.action_type != ZoneActionData.ActionType.ADVENTURE:
		_madra_badge_container.visible = false
		return

	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var current: float = ResourceManager.get_madra()
	var capacity: float = ResourceManager.get_adventure_madra_capacity()

	_madra_badge_container.visible = true
	if current >= threshold:
		_madra_badge.text = "[right][font_size=20][color=#D4A84A]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, capacity]
	else:
		_madra_badge.text = "[right][font_size=20][color=#E06060]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, threshold]

func _update_adventure_state() -> void:
	_is_affordable = ResourceManager.can_start_adventure()
	_update_madra_badge()
	# Only dim the name/description — keep the Madra badge bright so requirements are visible
	_action_name_label.modulate = NORMAL_MODULATE if _is_affordable else DIMMED_MODULATE
	_action_desc_label.modulate = NORMAL_MODULATE if _is_affordable else DIMMED_MODULATE

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_current_action:
			if action_data and action_data.action_type == ZoneActionData.ActionType.ADVENTURE:
				if not _is_affordable:
					_shake_reject()
					if LogManager:
						var threshold: float = ResourceManager.get_adventure_madra_threshold()
						var current: float = ResourceManager.get_madra()
						LogManager.log_message("[color=red]Not enough Madra! Need %.0f, have %.0f[/color]" % [threshold, current])
					return
			ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	if not is_current_action and _is_affordable:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)

func _on_mouse_exited() -> void:
	_update_card_style()

func _update_card_style() -> void:
	if is_current_action:
		if _cached_selected_style == null:
			_cached_selected_style = CARD_SELECTED.duplicate() as StyleBoxFlat
		var cat_color: Color = _get_category_color()
		_cached_selected_style.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.4)
		_action_card.add_theme_stylebox_override("panel", _cached_selected_style)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	var new_is_current: bool = ActionManager.get_current_action() == action_data
	is_current_action = new_is_current

func _on_foraging_completed(items: Dictionary) -> void:
	if is_current_action and action_data is ForageActionData:
		var forage_data: ForageActionData = action_data as ForageActionData
		_reset_and_restart_sweep(forage_data.foraging_interval_in_sec)
		_spawn_foraging_floating_text(items)

func _spawn_foraging_floating_text(items: Dictionary) -> void:
	if items.is_empty():
		return
	var text_parts: Array[String] = []
	for item in items:
		var quantity: int = items[item]
		text_parts.append("+%d %s" % [quantity, item.item_name])
	var full_text: String = ", ".join(text_parts)
	var floating_text: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	# Add to the root viewport so it's not clipped by parent containers
	get_tree().current_scene.add_child(floating_text)
	# Spawn from right-of-center of the button card
	var spawn_pos: Vector2 = _action_card.global_position + Vector2(-150, 20)
	floating_text.show_text(full_text, FLOATING_TEXT_COLOR, spawn_pos, FLOATING_TEXT_TRAJECTORY)

func _on_madra_changed_for_threshold(_amount: float) -> void:
	_update_adventure_state()

func _shake_reject() -> void:
	_madra_badge_container.pivot_offset = _madra_badge_container.size * 0.5
	var tween: Tween = create_tween()
	var original_pos: Vector2 = _madra_badge_container.position
	# Scale up slightly
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.10, 1.10), 0.05)
	# Shake left-right
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-2, 0), 0.03)
	# Settle back
	tween.tween_property(_madra_badge_container, "position", original_pos, 0.05)
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.0, 1.0), 0.1)
