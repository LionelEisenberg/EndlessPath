class_name AdventureRoute
extends Node2D

## AdventureRoute
## The route of a walk on the adventure map (spec: The map, Route): the zone
## map's lit route dots (map/lacquer_route_dot_lit_ai.png, 4x4 map px, 1x at
## the adventure's zoom 1) laid hop by hop along the walk, through
## ZoneRoute.dot_positions() for each pair of neighbouring tile centres, so
## each hop is six dots crossing the two tiles' shared rim. While the character
## walks the first hop, its dots hide one at a time as the character passes
## them; the later hops keep theirs until AdventureTilemap lays the route
## again from the next tile. AdventureTilemap keeps the route at its origin,
## so the centres are in the map's own space.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The cream (lit) route dot.
@export var dot_texture: Texture2D

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The top-left of every dot in the route's own space, hop by hop, each hop's
## from its first tile toward its second.
var _dots: PackedVector2Array = PackedVector2Array()
## How many of the dots, from the front, belong to the first hop.
var _first_hop_dot_count: int = 0
## The first hop's first tile centre, in the route's own space.
var _first_hop_from: Vector2 = Vector2.ZERO
## The first hop's direction, from its first tile toward its second.
var _first_hop_direction: Vector2 = Vector2.ZERO
## How many of the first hop's dots, from the front, the character has passed.
var _passed_dot_count: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _draw() -> void:
	if dot_texture == null:
		return
	for index: int in range(_passed_dot_count, _dots.size()):
		draw_texture(dot_texture, _dots[index])

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Lays the route through the tile centres, given in the route's parent space
## in walking order: each pair of neighbours is a hop. Fewer than two centres
## lay no dots.
func set_route(centres: Array[Vector2]) -> void:
	_dots = PackedVector2Array()
	_first_hop_dot_count = 0
	_passed_dot_count = 0
	for index: int in range(1, centres.size()):
		var from: Vector2 = centres[index - 1] - position
		var to: Vector2 = centres[index] - position
		var hop_dots: PackedVector2Array = ZoneRoute.dot_positions(from, to)
		if index == 1:
			_first_hop_dot_count = hop_dots.size()
			_first_hop_from = from
			_first_hop_direction = from.direction_to(to)
		_dots.append_array(hop_dots)
	queue_redraw()

## Takes every dot away.
func clear() -> void:
	_dots = PackedVector2Array()
	_first_hop_dot_count = 0
	_passed_dot_count = 0
	queue_redraw()

## Hides the first hop's dots the character has passed, one at a time: a dot
## goes once the character's position (in the route's parent space), projected
## on the first hop, lies past the dot's centre. The later hops keep theirs.
func hide_passed(character_position: Vector2) -> void:
	var travelled: float = _along_first_hop(character_position - position)
	var passed: int = 0
	while passed < _first_hop_dot_count and _along_first_hop(_dot_centre(passed)) < travelled:
		passed += 1
	if passed == _passed_dot_count:
		return
	_passed_dot_count = passed
	queue_redraw()

## The top-left of every dot of the route in its own space, hidden ones too,
## hop by hop.
func get_dot_positions() -> PackedVector2Array:
	return _dots

## How many dots the route draws now: the ones the character has not passed.
func get_visible_dot_count() -> int:
	return _dots.size() - _passed_dot_count

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## The centre of the dot at the index, in the route's own space.
func _dot_centre(index: int) -> Vector2:
	return _dots[index] + Vector2(ZoneRoute.DOT_HALF_SIZE, ZoneRoute.DOT_HALF_SIZE)

## How far along the first hop a point in the route's own space lies.
func _along_first_hop(point: Vector2) -> float:
	return (point - _first_hop_from).dot(_first_hop_direction)
