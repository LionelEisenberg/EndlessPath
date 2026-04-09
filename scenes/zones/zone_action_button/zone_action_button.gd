extends MarginContainer
## Action card button for zone actions.
## Adventure actions show a Madra badge and disable when unaffordable.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")
const DIMMED_MODULATE: Color = Color(0.55, 0.55, 0.55, 1.0)
const NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: RichTextLabel = %ActionDescLabel
@onready var _madra_badge_container: HBoxContainer = %MadraBadgeContainer
@onready var _madra_icon: TextureRect = %MadraIcon
@onready var _madra_badge: RichTextLabel = %MadraBadge

var _is_affordable: bool = true

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
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

## Sets up the card with action data.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_instance_valid(_action_name_label):
		_setup_labels()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

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
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	var new_is_current: bool = ActionManager.get_current_action() == action_data
	is_current_action = new_is_current

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
