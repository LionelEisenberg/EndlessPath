class_name PathNodeContainer
extends Control
## Pannable canvas that holds path node UI instances and draws connection lines.
## Connection lines are colored based on the purchase state of connected nodes.
## Lines connect to node edges (not centers) for a cleaner visual.

## Color constants for connection lines
const LINE_LOCKED: Color = Color(0.38, 0.30, 0.22)
const LINE_AVAILABLE: Color = Color(0.65, 0.52, 0.36)
const LINE_PURCHASED: Color = ThemeConstants.ACCENT_GOLD

## Width constants per state
const LINE_WIDTH_LOCKED: float = 2.0
const LINE_WIDTH_AVAILABLE: float = 2.5
const LINE_WIDTH_PURCHASED: float = 3.0

## Stores connection data: Array of { from_id: String, to_id: String }
var _connections: Array[Dictionary] = []

## Maps node_id -> PathNodeUI for looking up positions
var _node_ui_map: Dictionary = {}

## Maps node_id -> float radius for edge-to-edge line drawing
var _node_radii: Dictionary = {}

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Register a node UI in the container for connection drawing.
func register_node_ui(node_id: String, node_ui: PathNodeUI, radius: float = 22.0) -> void:
	_node_ui_map[node_id] = node_ui
	_node_radii[node_id] = radius


## Add a connection between two nodes (prerequisite -> dependent).
func add_connection(from_id: String, to_id: String) -> void:
	_connections.append({ "from_id": from_id, "to_id": to_id })


## Clear all registered nodes and connections.
func clear_all() -> void:
	_connections.clear()
	_node_ui_map.clear()
	_node_radii.clear()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _draw() -> void:
	for conn: Dictionary in _connections:
		var from_id: String = conn["from_id"]
		var to_id: String = conn["to_id"]

		if not _node_ui_map.has(from_id) or not _node_ui_map.has(to_id):
			continue

		var from_ui: PathNodeUI = _node_ui_map[from_id] as PathNodeUI
		var to_ui: PathNodeUI = _node_ui_map[to_id] as PathNodeUI

		var from_center: Vector2 = from_ui.position + from_ui.size / 2.0
		var to_center: Vector2 = to_ui.position + to_ui.size / 2.0

		# Calculate edge points using node radii
		var direction: Vector2 = (to_center - from_center).normalized()
		var from_radius: float = _node_radii.get(from_id, 22.0) as float
		var to_radius: float = _node_radii.get(to_id, 22.0) as float

		var from_edge: Vector2 = from_center + direction * from_radius
		var to_edge: Vector2 = to_center - direction * to_radius

		# Only draw if nodes are far enough apart
		if from_center.distance_to(to_center) <= (from_radius + to_radius):
			continue

		var line_color: Color = _get_connection_color(from_id, to_id)
		var line_width: float = _get_connection_width(from_id, to_id)
		draw_line(from_edge, to_edge, line_color, line_width, true)


func _get_connection_color(from_id: String, to_id: String) -> Color:
	var from_level: int = PathManager.get_node_purchase_count(from_id)
	var to_level: int = PathManager.get_node_purchase_count(to_id)

	if from_level >= 1 and to_level >= 1:
		return LINE_PURCHASED
	elif from_level >= 1:
		return LINE_AVAILABLE
	return LINE_LOCKED


func _get_connection_width(from_id: String, to_id: String) -> float:
	var from_level: int = PathManager.get_node_purchase_count(from_id)
	var to_level: int = PathManager.get_node_purchase_count(to_id)

	if from_level >= 1 and to_level >= 1:
		return LINE_WIDTH_PURCHASED
	elif from_level >= 1:
		return LINE_WIDTH_AVAILABLE
	return LINE_WIDTH_LOCKED
