class_name PathNodeUI
extends TextureButton
## Visual representation of a single path tree node.
## Draws shaped outlines (hexagon, diamond, circle) based on node type.
## Handles hover effects, click signaling, purchase particles, and display state.

signal node_clicked(node_id: String)
signal node_hovered(node_data: PathNodeData, node_ui: PathNodeUI)
signal node_unhovered()

@onready var _border: Panel = %Border
@onready var _level_label: Label = %LevelLabel

var _node_data: PathNodeData = null
var _theme: PathThemeData = null
var _hover_tween: Tween = null
var _is_purchased: bool = false
var _is_maxed: bool = false
var _can_afford: bool = false
var _glow_phase: float = 0.0
var _is_keystone_available: bool = false
var _swirl_rect: ColorRect = null
var _border_rect: ColorRect = null

## Fill colors per state
const FILL_LOCKED: Color = Color(0.25, 0.20, 0.15, 1.0)
const FILL_AVAILABLE: Color = Color(0.38, 0.30, 0.20, 1.0)
const FILL_PURCHASED: Color = Color(0.44, 0.34, 0.20, 1.0)
const FILL_MAXED: Color = Color(0.50, 0.38, 0.22, 1.0)

## Border colors per state
const BORDER_LOCKED: Color = Color(0.40, 0.32, 0.24, 0.7)
const BORDER_AVAILABLE: Color = Color(0.72, 0.56, 0.36, 1.0)
const BORDER_PURCHASED: Color = Color(0.85, 0.65, 0.29, 1.0)
const BORDER_MAXED: Color = Color(0.95, 0.78, 0.35, 1.0)

## Border widths per state
const BORDER_W_LOCKED: float = 2.0
const BORDER_W_AVAILABLE: float = 2.5
const BORDER_W_PURCHASED: float = 3.0
const BORDER_W_MAXED: float = 3.5

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Initialize the node UI with its data, current purchase level, and optional path theme.
func setup(data: PathNodeData, current_level: int, path_theme: PathThemeData = null) -> void:
	_node_data = data
	_theme = path_theme
	if data.icon:
		texture_normal = data.icon
	tooltip_text = ""

	# Resize based on node type
	match data.node_type:
		PathNodeData.NodeType.KEYSTONE:
			custom_minimum_size = Vector2(72, 72)
			size = Vector2(72, 72)
		PathNodeData.NodeType.MAJOR:
			custom_minimum_size = Vector2(50, 50)
			size = Vector2(50, 50)
		_:  # MINOR, REPEATABLE
			custom_minimum_size = Vector2(40, 40)
			size = Vector2(40, 40)
	pivot_offset = size / 2.0

	# Create shader overlays when a theme is provided
	if _theme != null:
		if data.node_type == PathNodeData.NodeType.KEYSTONE:
			_create_keystone_swirl()
		else:
			_create_border_shader(data.node_type)

	refresh(current_level, false)


## Update visual state after a purchase or point balance change.
func refresh(current_level: int, can_afford: bool) -> void:
	if _node_data == null:
		return

	_is_maxed = current_level >= _node_data.max_purchases
	_is_purchased = current_level >= 1
	_can_afford = can_afford

	# Determine if this is an available keystone for breathing glow
	_is_keystone_available = (
		_node_data.node_type == PathNodeData.NodeType.KEYSTONE
		and not _is_purchased
		and _can_afford
	)

	# Level label for repeatable nodes
	if _node_data.max_purchases > 1:
		_level_label.text = "%d/%d" % [current_level, _node_data.max_purchases]
		_level_label.visible = true
	else:
		_level_label.visible = false

	# All nodes stay fully opaque so lines behind them are hidden.
	# Locked state is conveyed via darker fill/border colors, not alpha.
	modulate.a = 1.0

	_update_swirl_state()
	queue_redraw()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	pivot_offset = size / 2.0
	# Hide old border panel — shapes are now drawn in _draw()
	_border.visible = false


func _process(delta: float) -> void:
	if _is_keystone_available:
		_glow_phase += delta * 2.0
		if _glow_phase > TAU:
			_glow_phase -= TAU
		queue_redraw()


func _draw() -> void:
	if _node_data == null:
		return

	var center: Vector2 = size / 2.0
	var fill_color: Color = _get_fill_color()
	var border_color: Color = _get_border_color()
	var border_width: float = _get_border_width()

	match _node_data.node_type:
		PathNodeData.NodeType.KEYSTONE:
			_draw_hexagon(center, 34.0, fill_color, border_color, border_width)
		PathNodeData.NodeType.MAJOR:
			# Only draw via _draw() if no border shader is active
			if _border_rect == null:
				_draw_diamond(center, 23.0, fill_color, border_color, border_width)
		_:
			if _border_rect == null:
				_draw_circle(center, 18.0, fill_color, border_color, border_width)

	# Breathing glow for available keystones
	if _is_keystone_available:
		var glow_alpha: float = 0.15 + 0.15 * sin(_glow_phase)
		var glow_base: Color = _theme.border_glow_color if _theme else ThemeConstants.ACCENT_GOLD
		var glow_col: Color = Color(glow_base.r, glow_base.g, glow_base.b, glow_alpha)
		match _node_data.node_type:
			PathNodeData.NodeType.KEYSTONE:
				_draw_hexagon(center, 38.0, Color.TRANSPARENT, glow_col, 2.0)
			_:
				pass


func _draw_hexagon(center: Vector2, radius: float, fill: Color, border: Color, border_w: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		var angle: float = (TAU * i / 6.0) - PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	if fill.a > 0.0:
		draw_colored_polygon(points, fill)

	# Close the polyline loop
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, border_w, true)


func _draw_diamond(center: Vector2, radius: float, fill: Color, border: Color, border_w: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center + Vector2(0, -radius))       # top
	points.append(center + Vector2(radius, 0))         # right
	points.append(center + Vector2(0, radius))          # bottom
	points.append(center + Vector2(-radius, 0))         # left

	if fill.a > 0.0:
		draw_colored_polygon(points, fill)

	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, border_w, true)


func _draw_circle(center: Vector2, radius: float, fill: Color, border: Color, border_w: float) -> void:
	if fill.a > 0.0:
		draw_circle(center, radius, fill)

	# Draw circle border using arc
	var point_count: int = 32
	var arc_points: PackedVector2Array = PackedVector2Array()
	for i: int in point_count + 1:
		var angle: float = (TAU * i) / point_count
		arc_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(arc_points, border, border_w, true)


func _get_fill_color() -> Color:
	if _theme == null:
		if _is_maxed:
			return FILL_MAXED
		elif _is_purchased:
			return FILL_PURCHASED
		elif _can_afford:
			return FILL_AVAILABLE
		return FILL_LOCKED
	# Theme-aware fill
	if _is_maxed or _is_purchased:
		return _theme.fill_purchased
	elif _can_afford:
		return _theme.fill_available
	return Color(
		_theme.fill_available.r * 0.75,
		_theme.fill_available.g * 0.75,
		_theme.fill_available.b * 0.75,
		1.0
	)


func _get_border_color() -> Color:
	if _theme == null:
		if _is_maxed:
			return BORDER_MAXED
		elif _is_purchased:
			return BORDER_PURCHASED
		elif _can_afford:
			return BORDER_AVAILABLE
		return BORDER_LOCKED
	# Theme-aware border
	if _is_maxed or _is_purchased:
		return _theme.border_glow_color
	elif _can_afford:
		return _theme.border_color
	return Color(
		_theme.border_color.r * 0.65,
		_theme.border_color.g * 0.65,
		_theme.border_color.b * 0.65,
		0.8
	)


func _get_border_width() -> float:
	if _is_maxed:
		return BORDER_W_MAXED
	elif _is_purchased:
		return BORDER_W_PURCHASED
	elif _can_afford:
		return BORDER_W_AVAILABLE
	return BORDER_W_LOCKED


func _create_keystone_swirl() -> void:
	if _swirl_rect != null:
		return

	var shader: Shader = load("res://assets/shaders/path_node_keystone.gdshader") as Shader
	if shader == null:
		return

	_swirl_rect = ColorRect.new()
	_swirl_rect.color = Color.WHITE
	# Inset slightly so the hexagon border is visible around the swirl
	var inset: float = 6.0
	_swirl_rect.position = Vector2(inset, inset)
	_swirl_rect.size = size - Vector2(inset * 2.0, inset * 2.0)
	_swirl_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("swirl_col_primary", _theme.swirl_primary)
	mat.set_shader_parameter("swirl_col_secondary", _theme.swirl_secondary)
	mat.set_shader_parameter("swirl_col_tertiary", _theme.swirl_tertiary)
	mat.set_shader_parameter("glow_color", _theme.border_glow_color)
	mat.set_shader_parameter("state", 1.0)
	_swirl_rect.material = mat

	add_child(_swirl_rect)
	# Move behind the level label so text is visible on top
	move_child(_swirl_rect, 0)


func _set_swirl_hover(value: float) -> void:
	if _swirl_rect == null or _swirl_rect.material == null:
		return
	var mat: ShaderMaterial = _swirl_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("hover", value)


func _create_border_shader(node_type: PathNodeData.NodeType) -> void:
	if _border_rect != null:
		return

	var shader: Shader = load("res://assets/shaders/path_node_border.gdshader") as Shader
	if shader == null:
		return

	_border_rect = ColorRect.new()
	_border_rect.color = Color.WHITE
	_border_rect.position = Vector2.ZERO
	_border_rect.size = size
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("border_color", _theme.border_color)
	mat.set_shader_parameter("glow_color", _theme.border_glow_color)
	mat.set_shader_parameter("fill_color", _theme.fill_available)
	mat.set_shader_parameter("state", 1.0)

	# Set shape type: 0=circle (minor/repeatable), 1=diamond (major)
	if node_type == PathNodeData.NodeType.MAJOR:
		mat.set_shader_parameter("shape_type", 1.0)
		mat.set_shader_parameter("radius", 0.44)
	else:
		mat.set_shader_parameter("shape_type", 0.0)
		mat.set_shader_parameter("radius", 0.42)

	_border_rect.material = mat
	add_child(_border_rect)
	move_child(_border_rect, 0)


func _update_swirl_state() -> void:
	var state_val: float = 0.0
	if _is_maxed or _is_purchased:
		state_val = 2.0
	elif _can_afford:
		state_val = 1.0

	# Update keystone swirl
	if _swirl_rect and _swirl_rect.material:
		var mat: ShaderMaterial = _swirl_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("state", state_val)

	# Update non-keystone border shader
	if _border_rect and _border_rect.material:
		var mat: ShaderMaterial = _border_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("state", state_val)
			# Update fill color based on state
			if _theme:
				var fill: Color = _theme.fill_purchased if (_is_purchased or _is_maxed) else _theme.fill_available
				mat.set_shader_parameter("fill_color", fill)


func _spawn_purchase_particles() -> void:
	var particle_color: Color = _theme.border_glow_color if _theme else ThemeConstants.ACCENT_GOLD
	for i: int in 12:
		var particle: ColorRect = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = particle_color
		particle.position = size / 2.0
		add_child(particle)
		var angle: float = (TAU * i) / 12.0
		var dist: float = 25.0 + randf() * 35.0
		var target: Vector2 = particle.position + Vector2(cos(angle), sin(angle)) * dist
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.6).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(particle.queue_free)


func _on_mouse_entered() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	_set_swirl_hover(1.0)

	if _node_data:
		node_hovered.emit(_node_data, self)


func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_set_swirl_hover(0.0)
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	node_unhovered.emit()


func _on_pressed() -> void:
	if _node_data:
		var was_purchased: bool = _is_purchased
		node_clicked.emit(_node_data.id)
		# Fire particles if this was a new purchase
		if not was_purchased and PathManager.get_node_purchase_count(_node_data.id) >= 1:
			_spawn_purchase_particles()
