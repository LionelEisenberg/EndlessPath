extends GutTest

## Unit tests for ZoneMapMath, the zone map's framing and fog helpers: the
## current zone's centre lands at screen (960, 702) at every zoom, and a fog
## cell's tier is its hex distance to the nearest charted zone, capped at 3.

#-----------------------------------------------------------------------------
# FRAMING
#-----------------------------------------------------------------------------

func test_camera_position_frames_anchor() -> void:
	var centres: Array[Vector2] = [Vector2.ZERO, Vector2(82.0, -142.5), Vector2(-164.0, 285.0)]
	for zoom: float in [1.0, 1.5, 2.0]:
		for centre: Vector2 in centres:
			var camera_position: Vector2 = ZoneMapMath.camera_position_for(centre, zoom)
			var screen: Vector2 = ZoneMapMath.world_to_screen(centre, camera_position, zoom)
			assert_almost_eq(screen.x, 960.0, 0.001, "x at zoom %s for %s" % [zoom, centre])
			assert_almost_eq(screen.y, 702.0, 0.001, "y at zoom %s for %s" % [zoom, centre])

func test_camera_sits_above_the_zone_by_the_anchor_offset() -> void:
	# The anchor is 162 screen px below the screen centre: 81 world px at zoom 2.
	assert_eq(ZoneMapMath.camera_position_for(Vector2.ZERO, 2.0), Vector2(0.0, -81.0))
	assert_eq(ZoneMapMath.camera_position_for(Vector2.ZERO, 1.0), Vector2(0.0, -162.0))

func test_world_to_screen_scales_by_zoom() -> void:
	# A point 100 world px right of the camera is 200 screen px right of the centre at zoom 2.
	assert_eq(ZoneMapMath.world_to_screen(Vector2(100.0, 0.0), Vector2.ZERO, 2.0), Vector2(1160.0, 540.0))

#-----------------------------------------------------------------------------
# CAMERA CLAMP WINDOWS
#-----------------------------------------------------------------------------

func test_camera_window_scales_with_the_zoom() -> void:
	# The free map window is x 546-1374, y 95-881: from the screen centre
	# (960, 540) that is 414 px either side, 445 up and 341 down. At zoom 2 the
	# camera may sit 207 world px either side of the zone, 170.5 above it and
	# 222.5 below it; at zoom 1 twice that.
	assert_eq(ZoneMapMath.camera_window_for(Vector2.ZERO, 2.0), Rect2(-207.0, -170.5, 414.0, 393.0))
	assert_eq(ZoneMapMath.camera_window_for(Vector2.ZERO, 1.0), Rect2(-414.0, -341.0, 828.0, 786.0))

func test_camera_window_corners_put_the_zone_on_the_free_window_corners() -> void:
	var centre := Vector2(82.0, -142.5)
	for zoom: float in [1.0, 1.5, 2.0]:
		var window: Rect2 = ZoneMapMath.camera_window_for(centre, zoom)
		var at_top_left: Vector2 = ZoneMapMath.world_to_screen(centre, window.position, zoom)
		var at_bottom_right: Vector2 = ZoneMapMath.world_to_screen(centre, window.end, zoom)
		assert_almost_eq(at_top_left.x, ZoneMapMath.FREE_MAP_WINDOW.end.x, 0.001, "camera at the window's left: the zone on the free window's right edge (zoom %s)" % zoom)
		assert_almost_eq(at_top_left.y, ZoneMapMath.FREE_MAP_WINDOW.end.y, 0.001, "camera at the window's top: the zone on the free window's bottom edge (zoom %s)" % zoom)
		assert_almost_eq(at_bottom_right.x, ZoneMapMath.FREE_MAP_WINDOW.position.x, 0.001, "camera at the window's right: the zone on the free window's left edge (zoom %s)" % zoom)
		assert_almost_eq(at_bottom_right.y, ZoneMapMath.FREE_MAP_WINDOW.position.y, 0.001, "camera at the window's bottom: the zone on the free window's top edge (zoom %s)" % zoom)

#-----------------------------------------------------------------------------
# CUBE COORDINATES
#-----------------------------------------------------------------------------

func test_cell_to_cube_matches_the_odd_row_offset_layout() -> void:
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(0, 0)), Vector3i(0, 0, 0))
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(1, 0)), Vector3i(1, 0, -1))
	# Odd rows (negative ones too) sit half a hex right, so (0, -1) is up and right of (0, 0).
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(0, -1)), Vector3i(1, -1, 0))
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(-1, -1)), Vector3i(0, -1, 1))
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(0, -2)), Vector3i(1, -2, 1))
	assert_eq(ZoneMapMath.cell_to_cube(Vector2i(0, 1)), Vector3i(0, 1, -1))

#-----------------------------------------------------------------------------
# FOG TIERS
#-----------------------------------------------------------------------------

func test_fog_tier_distances() -> void:
	var charted: Array[Vector3i] = [ZoneMapMath.cell_to_cube(Vector2i(0, 0))]
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(1, 0)), charted), 1, "a neighbour is tier 1")
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(2, 0)), charted), 2, "two away is tier 2")
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(3, 0)), charted), 3, "three away is tier 3")
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(7, -4)), charted), 3, "far away is capped at 3")

func test_fog_tier_is_three_with_nothing_charted() -> void:
	var charted: Array[Vector3i] = []
	assert_eq(ZoneMapMath.fog_tier(Vector3i.ZERO, charted), 3)

func test_fog_tiers_match_the_kit_base_state() -> void:
	# Kit §6.2, "base" column: Spirit Valley alone at (0, 0).
	var charted: Array[Vector3i] = [ZoneMapMath.cell_to_cube(Vector2i(0, 0))]
	var expected: Dictionary[Vector2i, int] = {
		Vector2i(-1, -1): 1, Vector2i(0, -1): 1, Vector2i(1, -1): 2, Vector2i(-2, -1): 2,
		Vector2i(-3, -1): 3, Vector2i(-1, -2): 2, Vector2i(0, -2): 2, Vector2i(2, -2): 3,
		Vector2i(-1, 1): 1, Vector2i(0, 1): 1, Vector2i(1, 1): 2, Vector2i(-2, 1): 2,
		Vector2i(2, 1): 3, Vector2i(0, -3): 3,
	}
	for cell: Vector2i in expected:
		assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(cell), charted), expected[cell], "cell %s" % cell)

func test_fog_tier_uses_the_nearest_charted_zone() -> void:
	# Spirit Valley (0, 0) and the Advancement demo (0, -1): (1, -2) is next to the demo zone.
	var charted: Array[Vector3i] = [
		ZoneMapMath.cell_to_cube(Vector2i(0, 0)),
		ZoneMapMath.cell_to_cube(Vector2i(0, -1)),
	]
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(1, -2)), charted), 1)
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(1, -3)), charted), 2)

#-----------------------------------------------------------------------------
# FORAGING WANDER
#-----------------------------------------------------------------------------

func test_forage_wander_keyframes() -> void:
	# Kit §0: 0 -> -24 -> -8 -> 0 world px over the 5 s haul (screen 0 -> -48 -> -16 -> 0).
	assert_eq(ZoneMapMath.forage_wander_x(0.0), 0.0)
	assert_eq(ZoneMapMath.forage_wander_x(0.75), -12.0, "halfway out")
	assert_eq(ZoneMapMath.forage_wander_x(1.5), -24.0, "furthest west at 30%")
	assert_eq(ZoneMapMath.forage_wander_x(3.25), -8.0, "back to -8 at 65%")
	assert_eq(ZoneMapMath.forage_wander_x(5.0), 0.0, "home at the haul")

func test_training_bob_steps() -> void:
	# Mock: bob 2.4 s steps(2, end), 0 -> -4 -> 0 screen px, so screen 0, -2,
	# -4, -2 a step every 0.6 s: world 0, -1, -2, -1.
	assert_eq(ZoneMapMath.training_bob_y(0.0), 0.0)
	assert_eq(ZoneMapMath.training_bob_y(0.59), 0.0)
	assert_eq(ZoneMapMath.training_bob_y(0.6), -1.0)
	assert_eq(ZoneMapMath.training_bob_y(1.2), -2.0, "highest at half the cycle")
	assert_eq(ZoneMapMath.training_bob_y(1.8), -1.0)
	assert_eq(ZoneMapMath.training_bob_y(2.4), 0.0, "home at the end of the cycle")
	assert_eq(ZoneMapMath.training_bob_y(3.6), -2.0, "and it repeats")

func test_forage_wander_moves_west_only_in_whole_px() -> void:
	var t: float = 0.0
	while t < 5.0:
		var x: float = ZoneMapMath.forage_wander_x(t)
		assert_true(x <= 0.0 and x >= -24.0, "x %s at %s s" % [x, t])
		assert_eq(x, roundf(x), "whole world px at %s s" % t)
		t += 0.05
