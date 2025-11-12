class_name CyclingZone
extends Area2D

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal zone_clicked(zone: CyclingZone, zone_data: CyclingZoneData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var zone_sprite: Sprite2D = $Sprite2D

#-----------------------------------------------------------------------------
# ZONE DATA
#-----------------------------------------------------------------------------
var zone_data: CyclingZoneData
var is_used: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

## Configure this zone with the provided data.
func setup(data: CyclingZoneData) -> void:
	zone_data = data
	
	# Configure collision shape radius
	var circle_shape = collision_shape.shape as CircleShape2D
	circle_shape.radius = 20
	
	# Enable input detection
	input_pickable = true
	monitoring = true
	
	# Connect input events
	input_event.connect(_on_input_event)
	
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
			# Consume the input event to prevent it from propagating
			get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Set whether this zone is currently active (ball is inside).
func set_active(active: bool) -> void:
	if is_used:
		return
	if active:
		zone_sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)  # Brighter
	else:
		zone_sprite.modulate = Color.WHITE

## Mark this zone as used for the current cycle.
func mark_as_used() -> void:
	is_used = true
	input_pickable = false  # Disable further clicks
	zone_sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Dimmed

## Reset this zone for a new cycle.
func reset_for_new_cycle() -> void:
	is_used = false
	input_pickable = true  # Re-enable input
	monitoring = true
	zone_sprite.modulate = Color.WHITE
	visible = false

## Show this zone (called when cycle starts).
func show_zone() -> void:
	visible = true

## Hide this zone (called when cycle ends).
func hide_zone() -> void:
	visible = false

## Flash this zone with a specific color.
func flash_zone(color: Color) -> void:
	zone_sprite.modulate = color
	# Return to normal after a brief flash
	await get_tree().create_timer(0.2).timeout
	if not is_used:
		zone_sprite.modulate = Color.WHITE
