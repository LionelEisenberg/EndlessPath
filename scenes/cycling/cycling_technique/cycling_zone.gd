class_name CyclingZone
extends Area2D

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal zone_clicked(zone: CyclingZone, zone_data: CyclingZoneData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var zone_sprite: Sprite2D = %Sprite2D

#-----------------------------------------------------------------------------
# ZONE DATA
#-----------------------------------------------------------------------------
var zone_data: CyclingZoneData
var is_used: bool = false

var _zone_shader: Shader = preload("res://assets/shaders/cycling_zone.gdshader")
var _shader_material: ShaderMaterial = null
var _default_active_color: Color = Color(0.85, 0.95, 1.0, 0.95)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Configure this zone with the provided data.
func setup(data: CyclingZoneData) -> void:
	zone_data = data

	# Configure collision shape radius
	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = 20

	# Enable input detection
	input_pickable = true
	monitoring = true

	# Connect input events
	input_event.connect(_on_input_event)

	# Apply shader material to sprite
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _zone_shader
	zone_sprite.material = _shader_material
	_set_state(0.0)

	# Initially hide the zone
	visible = false

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Handle clicking on this zone.
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_used:
			zone_clicked.emit(self, zone_data)
			get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Set whether this zone is currently active (ball is inside).
func set_active(active: bool) -> void:
	if is_used:
		return
	_set_state(1.0 if active else 0.0)

## Mark this zone as used for the current cycle.
func mark_as_used() -> void:
	is_used = true
	input_pickable = false
	_set_state(-1.0)

## Reset this zone for a new cycle.
func reset_for_new_cycle() -> void:
	is_used = false
	input_pickable = true
	monitoring = true
	_set_state(0.0)
	visible = false

## Show this zone (called when cycle starts).
func show_zone() -> void:
	visible = true

## Hide this zone (called when cycle ends).
func hide_zone() -> void:
	visible = false

## Flash this zone with a specific color on successful click.
func flash_zone(color: Color) -> void:
	if _shader_material:
		# Temporarily override the active color for the flash
		_shader_material.set_shader_parameter("active_color", color)
		_set_state(1.0)
	await get_tree().create_timer(0.4).timeout
	# Restore default active color
	if _shader_material:
		_shader_material.set_shader_parameter("active_color", _default_active_color)
	if is_used:
		_set_state(-1.0)
	else:
		_set_state(0.0)

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _set_state(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("state", value)
