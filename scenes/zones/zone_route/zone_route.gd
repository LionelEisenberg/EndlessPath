class_name ZoneRoute
extends Node2D

## ZoneRoute
## A dotted route between two zones on the zone map (kit §0, §6.7): a short
## run of 4x4 map-space dots (8x8 on screen at zoom 2), 12 map px apart,
## centred on the midpoint between the two hex centres. Between neighbouring
## hexes that is six dots crossing their shared rim; the run stops 52 map px
## from either centre, so it never reaches a zone's middle, glyph or plate.
## The dots are tan, or cream while lit (a zone you can travel to is hovered).
## ZoneTilemap lays one route per pair of zones and keeps it at its origin, so
## the points are in the map's own space.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The tan dot.
@export var dot_texture: Texture2D
## The cream dot, while the route is lit.
@export var lit_dot_texture: Texture2D

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Map px between two dots (24 screen px at zoom 2).
const DOT_SPACING: float = 12.0
## The run keeps this far from either hex centre (104 screen px at zoom 2).
const ZONE_CLEARANCE: float = 52.0
## Half a dot's side in map px: a dot is placed by its top-left.
const DOT_HALF_SIZE: float = 2.0
## Absorbs float error when the run is a whole number of spacings long.
const _SPACING_EPSILON: float = 0.001

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _dots: PackedVector2Array = PackedVector2Array()
var _lit: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _draw() -> void:
	var texture: Texture2D = get_dot_texture()
	if texture == null:
		return
	for dot: Vector2 in _dots:
		draw_texture(texture, dot)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Lays the dots between the two hex centres, given in the route's parent space.
func set_points(from: Vector2, to: Vector2) -> void:
	_dots = dot_positions(from - position, to - position)
	queue_redraw()

## Lit routes draw cream dots: the route toward a zone you can travel to while
## that zone is hovered.
func set_lit(lit: bool) -> void:
	if lit == _lit:
		return
	_lit = lit
	queue_redraw()

## True while the route draws its cream dots.
func is_lit() -> bool:
	return _lit

## The top-left of each dot in the route's own space, from the first zone
## toward the second.
func get_dot_positions() -> PackedVector2Array:
	return _dots

## The dot texture drawn now.
func get_dot_texture() -> Texture2D:
	return lit_dot_texture if _lit else dot_texture

## The dot top-lefts of a route from one hex centre to another: as many dots
## as fit 12 px apart between 52 px out of each centre, centred on the
## midpoint, each snapped to a whole map px (an even screen px at zoom 2).
static func dot_positions(from: Vector2, to: Vector2) -> PackedVector2Array:
	var dots := PackedVector2Array()
	var length: float = from.distance_to(to)
	var run: float = length - 2.0 * ZONE_CLEARANCE
	if run < 0.0:
		return dots
	var count: int = floori(run / DOT_SPACING + _SPACING_EPSILON) + 1
	var direction: Vector2 = from.direction_to(to)
	for index: int in count:
		var along: float = length / 2.0 + DOT_SPACING * (index - (count - 1) / 2.0)
		dots.append((from + direction * along - Vector2(DOT_HALF_SIZE, DOT_HALF_SIZE)).round())
	return dots
