class_name PathTreeView
extends Control
## Main view that renders the full path progression tree.
## Handles panning via left-click drag and instantiates path node UI components.

@export var layout_scene: PackedScene
@export var path_node_ui_scene: PackedScene

@onready var _node_container: PathNodeContainer = %NodeContainer
@onready var _points_label: Label = %PointsLabel

## Maps node_id -> PathNodeUI for refresh
var _node_uis: Dictionary = {}

## Panning state
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

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
		_points_label.text = "Path Points: %d" % PathManager.get_point_balance()
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
	_node_container.queue_redraw()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _ready() -> void:
	PathManager.node_purchased.connect(_on_node_purchased)
	PathManager.points_changed.connect(_on_points_changed)
	PathManager.path_set.connect(_on_path_set)

	_points_label.text = "Path Points: %d" % PathManager.get_point_balance()
	build_tree()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse = mb.global_position
				_pan_start_offset = _node_container.position
			else:
				_is_panning = false
	elif event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _pan_start_mouse
		_node_container.position = _pan_start_offset + delta


func _create_node_ui(node_data: PathNodeData, positions: Dictionary) -> void:
	if path_node_ui_scene == null:
		return

	var node_ui: PathNodeUI = path_node_ui_scene.instantiate() as PathNodeUI
	_node_container.add_child(node_ui)

	# Position from layout
	if positions.has(node_data.id):
		var layout_pos: Vector2 = positions[node_data.id]
		node_ui.position = layout_pos - node_ui.size / 2.0
	else:
		node_ui.position = Vector2.ZERO

	var current_level: int = PathManager.get_node_purchase_count(node_data.id)
	node_ui.setup(node_data, current_level)
	node_ui.node_clicked.connect(_on_node_clicked)

	_node_uis[node_data.id] = node_ui
	_node_container.register_node_ui(node_data.id, node_ui)


func _refresh_all_nodes() -> void:
	_points_label.text = "Path Points: %d" % PathManager.get_point_balance()

	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		var current_level: int = PathManager.get_node_purchase_count(node_id)
		var can_afford: bool = PathManager.can_purchase_node(node_id)
		node_ui.refresh(current_level, can_afford)

	_node_container.queue_redraw()


func _clear_tree() -> void:
	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		node_ui.queue_free()
	_node_uis.clear()
	_node_container.clear_all()


func _on_node_clicked(node_id: String) -> void:
	PathManager.purchase_node(node_id)


func _on_node_purchased(_node_id: String, _new_level: int) -> void:
	_refresh_all_nodes()


func _on_points_changed(_new_balance: int) -> void:
	_refresh_all_nodes()


func _on_path_set(_path_tree: PathTreeData) -> void:
	build_tree()
