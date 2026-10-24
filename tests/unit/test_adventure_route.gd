extends GutTest

## AdventureRoute: the lit route dots a walk on the adventure map shows, laid
## hop by hop through ZoneRoute.dot_positions(), and the first hop's dots
## hiding one at a time behind the walking character.

const AdventureRouteScene: PackedScene = preload("res://scenes/adventure/adventure_route/adventure_route.tscn")

## Three neighbouring hex centres in map px, as the adventure map lays them:
## a hop east along the x axis, then one down-left.
const A: Vector2 = Vector2(0.0, 0.0)
const B: Vector2 = Vector2(164.0, 0.0)
const C: Vector2 = Vector2(82.0, 142.5)

var _route: AdventureRoute

func before_each() -> void:
	_route = AdventureRouteScene.instantiate()
	add_child_autofree(_route)

## The route through A, B and C.
func _lay_route() -> void:
	var centres: Array[Vector2] = [A, B, C]
	_route.set_route(centres)

## Where a dot of the A-B hop has its centre along x (the hop runs along the
## x axis from A, so that is how far along the hop it lies).
func _first_hop_dot_x(index: int) -> float:
	return _route.get_dot_positions()[index].x + ZoneRoute.DOT_HALF_SIZE

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_route_dots_follow_each_hop() -> void:
	_lay_route()

	var expected: PackedVector2Array = ZoneRoute.dot_positions(A, B) + ZoneRoute.dot_positions(B, C)
	assert_eq(_route.get_dot_positions(), expected, "each hop's dots, hop after hop")
	assert_eq(expected.size(), 12, "precondition: six dots cross each pair of neighbours")
	assert_eq(_route.get_visible_dot_count(), 12, "every dot shows until the walk passes it")
	assert_not_null(_route.dot_texture, "the scene sets the lit dot")

func test_hide_passed_hides_first_hop_dots_one_at_a_time() -> void:
	_lay_route()

	_route.hide_passed(A)
	assert_eq(_route.get_visible_dot_count(), 12, "on the first tile, nothing is passed")

	for index: int in 3:
		_route.hide_passed(Vector2(_first_hop_dot_x(index) + 1.0, 0.0))
		assert_eq(_route.get_visible_dot_count(), 12 - (index + 1), "just past dot %d of the first hop" % index)

	_route.hide_passed((A + B) / 2.0)
	assert_eq(_route.get_visible_dot_count(), 9,
		"at the hop's midpoint three dots of the first hop are hidden, the next hop's six all show")

	_route.hide_passed(B)
	assert_eq(_route.get_visible_dot_count(), 6, "at the hop's end the whole first hop is hidden")

	_route.hide_passed((B + C) / 2.0)
	assert_eq(_route.get_visible_dot_count(), 6, "later hops keep their dots until the route is laid again")

func test_clear_empties_the_route() -> void:
	_lay_route()
	_route.hide_passed((A + B) / 2.0)

	_route.clear()

	assert_eq(_route.get_dot_positions().size(), 0, "no dots left")
	assert_eq(_route.get_visible_dot_count(), 0, "none drawn")
