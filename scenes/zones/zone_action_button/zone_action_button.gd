extends MarginContainer
## Action card button for zone actions.
## Adventure actions show Madra cost and disable below threshold.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: Label = %ActionDescLabel
var _madra_cost_label: Label = null

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
		_create_madra_cost_label()
		ResourceManager.madra_changed.connect(_on_madra_changed_for_threshold)
		_update_madra_cost_display()

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

func _create_madra_cost_label() -> void:
	_madra_cost_label = Label.new()
	_madra_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_madra_cost_label.add_theme_font_size_override("font_size", 18)
	_action_card.get_child(0).add_child(_madra_cost_label)

func _update_madra_cost_display() -> void:
	if _madra_cost_label == null or action_data == null:
		return

	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var budget: float = ResourceManager.get_adventure_madra_budget()
	var current: float = ResourceManager.get_madra()
	var can_afford: bool = ResourceManager.can_start_adventure()

	if can_afford:
		_madra_cost_label.text = "Madra: %.0f" % budget
		_madra_cost_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
	else:
		_madra_cost_label.text = "Need %.0f Madra (%.0f)" % [threshold, current]
		_madra_cost_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_RED)

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_current_action:
			if action_data and action_data.action_type == ZoneActionData.ActionType.ADVENTURE:
				if ResourceManager.can_start_adventure():
					_spawn_madra_drain_particles()
			ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	if not is_current_action:
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
	_update_madra_cost_display()

func _spawn_madra_drain_particles() -> void:
	var zone_resource_panel: ZoneResourcePanel = get_tree().get_first_node_in_group("ZoneResourcePanel") as ZoneResourcePanel
	if zone_resource_panel == null:
		return

	var from_pos: Vector2 = zone_resource_panel.get_madra_orb_global_position()
	var to_pos: Vector2 = _action_card.global_position + _action_card.size * 0.5
	var particle_color: Color = Color(0.5, 0.78, 1.0, 0.85)

	for i in 8:
		var particle: FlyingParticle = FlyingParticle.new()
		var offset: Vector2 = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var duration: float = randf_range(0.3, 0.6)
		var size: float = randf_range(3.0, 5.0)
		get_tree().current_scene.add_child(particle)
		particle.launch(from_pos + offset, to_pos + offset, particle_color, duration, size)
