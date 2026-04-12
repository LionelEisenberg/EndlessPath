class_name PathNodeContainer
extends Control
## Pannable canvas that holds path node UI instances and draws connection lines.
## Connection lines are colored based on the purchase state of connected nodes.

## Color constants for connection lines
const LINE_GOLD: Color = Color("#a89070")
const LINE_WHITE: Color = Color.WHITE
const LINE_LOCKED: Color = Color(1.0, 1.0, 1.0, 0.2)
const LINE_WIDTH: float = 2.0

## Stores connection data: Array of { from_id: String, to_id: String }
var _connections: Array[Dictionary] = []

## Maps node_id -> PathNodeUI for looking up positions
var _node_ui_map: Dictionary = {}

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Register a node UI in the container for connection drawing.
func register_node_ui(node_id: String, node_ui: PathNodeUI) -> void:
	_node_ui_map[node_id] = node_ui


## Add a connection between two nodes (prerequisite -> dependent).
func add_connection(from_id: String, to_id: String) -> void:
	_connections.append({ "from_id": from_id, "to_id": to_id })


## Clear all registered nodes and connections.
func clear_all() -> void:
	_connections.clear()
	_node_ui_map.clear()

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

		var line_color: Color = _get_connection_color(from_id, to_id)
		draw_line(from_center, to_center, line_color, LINE_WIDTH, true)


func _get_connection_color(from_id: String, to_id: String) -> Color:
	var from_level: int = PathManager.get_node_purchase_count(from_id)
	var to_level: int = PathManager.get_node_purchase_count(to_id)

	if from_level >= 1 and to_level >= 1:
		return LINE_GOLD
	elif from_level >= 1:
		return LINE_WHITE
	return LINE_LOCKED
