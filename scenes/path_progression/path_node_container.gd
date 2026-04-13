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

## Optional path theme for themed connection colors
var _theme: PathThemeData = null

## Cached Line2D nodes for energy shader on purchased connections
var _energy_lines: Array[Line2D] = []

## Cached energy shader resource
var _energy_shader: Shader = null

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


## Set the visual theme for connection line colors.
func set_theme_data(path_theme: PathThemeData) -> void:
	_theme = path_theme


## Clear all registered nodes and connections.
func clear_all() -> void:
	_connections.clear()
	_node_ui_map.clear()
	_node_radii.clear()
	_clear_energy_lines()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _draw() -> void:
	_clear_energy_lines()

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
		var line_width: float = _get_connection_width(from_id, to_id)
		draw_line(from_center, to_center, line_color, line_width, true)

		# Add energy shader Line2D for purchased connections with a theme
		var from_level: int = PathManager.get_node_purchase_count(from_id)
		var to_level: int = PathManager.get_node_purchase_count(to_id)
		if _theme and from_level >= 1 and to_level >= 1:
			_add_energy_line(from_center, to_center, line_color)


func _get_connection_color(from_id: String, to_id: String) -> Color:
	var from_level: int = PathManager.get_node_purchase_count(from_id)
	var to_level: int = PathManager.get_node_purchase_count(to_id)

	if _theme:
		if from_level >= 1 and to_level >= 1:
			return _theme.line_purchased
		elif from_level >= 1:
			return _theme.line_available
		return Color(
			_theme.line_available.r * 0.5,
			_theme.line_available.g * 0.5,
			_theme.line_available.b * 0.5,
			1.0
		)

	# Fallback to hardcoded colors
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


func _clear_energy_lines() -> void:
	for line: Line2D in _energy_lines:
		if is_instance_valid(line):
			line.queue_free()
	_energy_lines.clear()


func _add_energy_line(from_point: Vector2, to_point: Vector2, base_color: Color) -> void:
	if _energy_shader == null:
		_energy_shader = load("res://assets/shaders/path_connection_energy.gdshader") as Shader
	if _energy_shader == null:
		return

	var line: Line2D = Line2D.new()
	line.add_point(from_point)
	line.add_point(to_point)
	line.width = LINE_WIDTH_PURCHASED + 1.0
	line.default_color = base_color

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _energy_shader
	mat.set_shader_parameter("line_color", base_color)
	mat.set_shader_parameter("energy_color", _theme.line_energy_color if _theme else Color(1.0, 0.9, 0.7))
	line.material = mat

	add_child(line)
	# Move energy lines behind node UIs
	move_child(line, 0)
	_energy_lines.append(line)
