class_name PathTreeView
extends Control
## Main view that renders the full path progression tree.
## Handles panning via left-click drag and instantiates path node UI components.
## Displays a benefits sidebar and header with path identity and point balance.

@export var layout_scene: PackedScene
@export var path_node_ui_scene: PackedScene

@onready var _tree_area: Control = %TreeArea
@onready var _node_container: PathNodeContainer = %NodeContainer
@onready var _path_title: Label = %PathTitle
@onready var _points_value: Label = %PointsValue
@onready var _benefits_list: VBoxContainer = %BenefitsList
@onready var _node_count_label: Label = %NodeCountLabel
@onready var _points_spent_label: Label = %PointsSpentLabel
@onready var _shared_tooltip: PathNodeTooltip = %SharedTooltip
@onready var _madra_info_popup: Control = %MadraInfoPopup
@onready var _madra_desc_label: Label = %MadraDescLabel
@onready var _madra_strengths_label: Label = %MadraStrengthsLabel
@onready var _madra_weaknesses_label: Label = %MadraWeaknessesLabel
@onready var _madra_cycling_label: Label = %MadraCyclingLabel
@onready var _madra_combat_label: Label = %MadraCombatLabel

## Maps node_id -> PathNodeUI for refresh
var _node_uis: Dictionary = {}

## Panning state
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

## Zoom state
var _zoom_level: float = 1.0
const ZOOM_MIN: float = 0.75
const ZOOM_MAX: float = 1.5
const ZOOM_STEP: float = 0.1

## Tween for madra info popup animation
var _madra_info_tween: Tween = null

## Tracks total points spent and purchased node count
var _total_spent: int = 0
var _purchased_count: int = 0

## Benefit descriptions for sidebar display
const BENEFIT_DESCRIPTIONS: Dictionary = {
	"pure_core_awakening": ["Pure Core Awakening", "Empty Palm + Smooth Flow"],
	"cycling_accuracy": ["Cycling Focus", "+15 Cycling Accuracy"],
	"madra_capacity": ["Expanded Core", "+25 Max Madra"],
	"madra_gen_up": ["Madra Surge", "+10% Madra Gen"],
	"empty_palm_duration": ["Lingering Silence", "+2s Silence Duration"],
	"empty_palm_cost": ["Efficient Palm", "-20% Palm Cost"],
	"madra_strike": ["Madra Strike", "Madra Strike unlocked"],
	"madra_strike_damage": ["Focused Strike", "+40% Strike Damage"],
	"madra_strike_efficiency": ["Strike Efficiency", "-15% Stamina Cost"],
	"torrent_flow": ["Torrent Flow", "Torrent Flow unlocked"],
	"stamina_recovery": ["Iron Will", "+20% Stamina Recovery"],
	"core_xp_boost": ["Dedicated Cultivation", "+10% Core Density XP"],
	"madra_on_levelup": ["Breakthrough Surge", "+10 Madra on Level Up"],
	"adventure_madra_return": ["Madra Reclamation", "+10% Madra Return"],
}

## NodeContainer base position to be centered
const NODE_CONTAINER_BASE_POSITION : Vector2 = Vector2(120, 100)

#-----------------------------------------------------------------------------
# STATIC METHODS
#-----------------------------------------------------------------------------

## Read layout positions from a scene containing Marker2D children.
## Returns a Dictionary mapping marker name (String) to position (Vector2).
static func read_layout_positions(layout_scene_resource: PackedScene) -> Dictionary:
	var positions: Dictionary = {}
	var root: Node = layout_scene_resource.instantiate()
	for child: Node in root.get_children():
		if child is Marker2D:
			positions[child.name] = child.position
	root.queue_free()
	return positions

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Rebuild the entire tree from the current PathManager state.
func build_tree() -> void:
	_clear_tree()

	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		_update_points_display()
		return

	var positions: Dictionary = {}
	if layout_scene:
		positions = read_layout_positions(layout_scene)

	for node_data: PathNodeData in tree.nodes:
		_create_node_ui(node_data, positions)

	# Register connections based on prerequisites
	for node_data: PathNodeData in tree.nodes:
		for prereq_id: String in node_data.prerequisites:
			_node_container.add_connection(prereq_id, node_data.id)

	_refresh_all_nodes()
	_rebuild_benefits_sidebar()
	_center_tree()
	_node_container.queue_redraw()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _ready() -> void:
	PathManager.node_purchased.connect(_on_node_purchased)
	PathManager.points_changed.connect(_on_points_changed)
	PathManager.path_set.connect(_on_path_set)

	_path_title.mouse_entered.connect(_on_path_title_mouse_entered)
	_path_title.mouse_exited.connect(_on_path_title_mouse_exited)
	_tree_area.gui_input.connect(_on_tree_area_gui_input)

	_update_points_display()
	_update_header()
	_populate_madra_info()
	build_tree()

func _on_tree_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse = mb.global_position
				_pan_start_offset = _node_container.position
			else:
				_is_panning = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(ZOOM_STEP, mb.global_position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(-ZOOM_STEP, mb.global_position)
	elif event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _pan_start_mouse
		_node_container.position = _pan_start_offset + delta


func _create_node_ui(node_data: PathNodeData, positions: Dictionary) -> void:
	if path_node_ui_scene == null:
		return

	var node_ui: PathNodeUI = path_node_ui_scene.instantiate() as PathNodeUI
	_node_container.add_child(node_ui)

	var current_level: int = PathManager.get_node_purchase_count(node_data.id)
	node_ui.setup(node_data, current_level)

	# Position from layout — adjust for variable node sizes after setup
	if positions.has(node_data.id):
		var layout_pos: Vector2 = positions[node_data.id]
		node_ui.position = layout_pos - node_ui.size / 2.0
	else:
		node_ui.position = Vector2.ZERO

	node_ui.node_clicked.connect(_on_node_clicked)
	node_ui.node_hovered.connect(_on_node_hovered)
	node_ui.node_unhovered.connect(_on_node_unhovered)

	var node_radius: float = node_ui.size.x / 2.0
	_node_uis[node_data.id] = node_ui
	_node_container.register_node_ui(node_data.id, node_ui, node_radius)


func _refresh_all_nodes() -> void:
	_update_points_display()

	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		var current_level: int = PathManager.get_node_purchase_count(node_id)
		var can_afford: bool = PathManager.can_purchase_node(node_id)
		node_ui.refresh(current_level, can_afford)

	_node_container.queue_redraw()


func _apply_zoom(delta: float, mouse_global: Vector2) -> void:
	var old_zoom: float = _zoom_level
	_zoom_level = clampf(_zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, _zoom_level):
		return

	# Zoom toward mouse position so the point under the cursor stays fixed
	var mouse_local: Vector2 = mouse_global - _tree_area.global_position
	var before: Vector2 = (mouse_local - _node_container.position) / old_zoom
	var after: Vector2 = before * _zoom_level
	_node_container.position = mouse_local - after

	_node_container.scale = Vector2(_zoom_level, _zoom_level)
	_node_container.queue_redraw()


func _center_tree() -> void:
	_node_container.position = 	NODE_CONTAINER_BASE_POSITION



func _clear_tree() -> void:
	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		node_ui.queue_free()
	_node_uis.clear()
	_node_container.clear_all()
	_clear_benefits()


func _update_points_display() -> void:
	_points_value.text = "%d" % PathManager.get_point_balance()


func _update_header() -> void:
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree:
		_path_title.text = tree.path_name.to_upper()
	else:
		_path_title.text = "NO PATH"


func _rebuild_benefits_sidebar() -> void:
	_clear_benefits()

	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return

	_total_spent = 0
	_purchased_count = 0

	for node_data: PathNodeData in tree.nodes:
		var level: int = PathManager.get_node_purchase_count(node_data.id)
		if level >= 1:
			_purchased_count += 1
			_total_spent += node_data.point_cost * level
			_add_benefit(node_data.id, level)

	_node_count_label.text = "%d" % _purchased_count
	_points_spent_label.text = "%d" % _total_spent


func _add_benefit(node_id: String, _level: int) -> void:
	var benefit_info: Array = BENEFIT_DESCRIPTIONS.get(node_id, []) as Array
	if benefit_info.size() < 2:
		return

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Icon label
	var icon_label: Label = Label.new()
	icon_label.custom_minimum_size = Vector2(20, 20)
	icon_label.text = "\u25C6"
	icon_label.theme_type_variation = &"LabelPathMuted"
	icon_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# Info vbox
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 0)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label: Label = Label.new()
	name_label.text = benefit_info[0]
	name_label.theme_type_variation = &"LabelPathBody"
	info_vbox.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = benefit_info[1]
	value_label.theme_type_variation = &"LabelPathGreen"
	info_vbox.add_child(value_label)

	hbox.add_child(info_vbox)
	_benefits_list.add_child(hbox)


func _clear_benefits() -> void:
	for child: Node in _benefits_list.get_children():
		child.queue_free()
	_total_spent = 0
	_purchased_count = 0
	_node_count_label.text = "0"
	_points_spent_label.text = "0"


func _on_node_clicked(node_id: String) -> void:
	PathManager.purchase_node(node_id)


func _on_node_hovered(node_data: PathNodeData, node_ui: PathNodeUI) -> void:
	var current_level: int = PathManager.get_node_purchase_count(node_data.id)
	# Position tooltip at the node's global position, offset to the right
	var node_global_pos: Vector2 = node_ui.global_position
	_shared_tooltip.global_position = Vector2(
		node_global_pos.x + node_ui.size.x + 16.0,
		node_global_pos.y + node_ui.size.y / 2.0 - 80.0
	)
	_shared_tooltip.show_tooltip(node_data, current_level)


func _on_node_unhovered() -> void:
	_shared_tooltip.hide_tooltip()


func _on_node_purchased(_node_id: String, _new_level: int) -> void:
	_refresh_all_nodes()
	_rebuild_benefits_sidebar()


func _on_points_changed(_new_balance: int) -> void:
	_refresh_all_nodes()


func _on_path_set(_path_tree: PathTreeData) -> void:
	_update_header()
	_populate_madra_info()
	build_tree()


func _populate_madra_info() -> void:
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return
	_madra_desc_label.text = tree.path_description
	_madra_strengths_label.text = "Strengths: %s" % tree.madra_strengths
	_madra_weaknesses_label.text = "Weaknesses: %s" % tree.madra_weaknesses
	_madra_cycling_label.text = "Cycling: %s" % tree.madra_cycling
	_madra_combat_label.text = "Combat: %s" % tree.madra_combat


func _on_path_title_mouse_entered() -> void:
	if _madra_info_tween and _madra_info_tween.is_valid():
		_madra_info_tween.kill()
	_madra_info_popup.visible = true
	_madra_info_popup.modulate.a = 0.0
	_madra_info_tween = create_tween()
	_madra_info_tween.tween_property(_madra_info_popup, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)


func _on_path_title_mouse_exited() -> void:
	if _madra_info_tween and _madra_info_tween.is_valid():
		_madra_info_tween.kill()
	_madra_info_tween = create_tween()
	_madra_info_tween.tween_property(_madra_info_popup, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
	_madra_info_tween.chain().tween_callback(func() -> void: _madra_info_popup.visible = false)
