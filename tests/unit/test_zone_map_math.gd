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
# FOG ART
#-----------------------------------------------------------------------------

## Kit §6.2's hand-placed fog art on the 32 cells the default framing shows,
## as fog pool indices (Basic 0, Mountains1 1, Clearing1 2, Lake1 3, Lake2 4,
## Hole 5, Dead 6, Ravine 7, Cave 8). Every other listed cell is Basic.
const KIT_FOG_FEATURES: Dictionary[Vector2i, int] = {
	Vector2i(-1, -3): 2, Vector2i(1, -3): 5,
	Vector2i(-1, -2): 7, Vector2i(0, -2): 3, Vector2i(1, -2): 1,
	Vector2i(-2, -1): 4, Vector2i(1, -1): 6,
	Vector2i(-1, 0): 3, Vector2i(1, 0): 7, Vector2i(2, 0): 2,
	Vector2i(-2, 1): 8, Vector2i(0, 1): 4,
}
## The kit's rows and their first and last columns.
const KIT_FOG_ROWS: Dictionary[int, Vector2i] = {
	-3: Vector2i(-3, 2), -2: Vector2i(-3, 3), -1: Vector2i(-3, 2), 0: Vector2i(-3, 3), 1: Vector2i(-3, 2),
}

func _is_kit_cell(cell: Vector2i) -> bool:
	return KIT_FOG_ROWS.has(cell.y) and cell.x >= KIT_FOG_ROWS[cell.y].x and cell.x <= KIT_FOG_ROWS[cell.y].y

func test_fog_art_follows_the_kit_on_its_cells() -> void:
	var cells: int = 0
	for row: int in KIT_FOG_ROWS:
		for col: int in range(KIT_FOG_ROWS[row].x, KIT_FOG_ROWS[row].y + 1):
			var cell := Vector2i(col, row)
			cells += 1
			assert_eq(ZoneMapMath.fog_art_index(cell), KIT_FOG_FEATURES.get(cell, 0), "kit art on %s" % cell)
	assert_eq(cells, 32, "the kit's 32 cells")

func test_fog_art_beyond_the_kit_is_mostly_basic() -> void:
	var basic: int = 0
	var total: int = 0
	var features: Dictionary[int, bool] = {}
	for row: int in range(-12, 13):
		for col: int in range(-12, 13):
			var cell := Vector2i(col, row)
			if _is_kit_cell(cell):
				continue
			var index: int = ZoneMapMath.fog_art_index(cell)
			assert_true(index >= 0 and index < ZoneMapMath.FOG_POOL_SIZE, "index %d in the pool for %s" % [index, cell])
			total += 1
			if index == 0:
				basic += 1
			else:
				features[index] = true
	var share: float = float(basic) / total
	assert_between(share, 0.5, 0.7, "about 60%% Basic like the kit's own cells, got %.2f" % share)
	assert_eq(features.size(), ZoneMapMath.FOG_POOL_SIZE - 1, "every feature shows somewhere")

#-----------------------------------------------------------------------------
# FOG TIERS
#-----------------------------------------------------------------------------

## With Spirit Valley alone charted at (0, 0), a cell's tier is its hex
## distance to it, capped at 3: a run east (1, 0) to (3, 0), a far cell
## (7, -4) for the cap, and kit §6.2's "base" column.
func test_fog_tier_distances() -> void:
	var charted: Array[Vector3i] = [ZoneMapMath.cell_to_cube(Vector2i(0, 0))]
	var expected: Dictionary[Vector2i, int] = {
		Vector2i(1, 0): 1, Vector2i(2, 0): 2, Vector2i(3, 0): 3, Vector2i(7, -4): 3,
		Vector2i(-1, -1): 1, Vector2i(0, -1): 1, Vector2i(1, -1): 2, Vector2i(-2, -1): 2,
		Vector2i(-3, -1): 3, Vector2i(-1, -2): 2, Vector2i(0, -2): 2, Vector2i(2, -2): 3,
		Vector2i(-1, 1): 1, Vector2i(0, 1): 1, Vector2i(1, 1): 2, Vector2i(-2, 1): 2,
		Vector2i(2, 1): 3, Vector2i(0, -3): 3,
	}
	for cell: Vector2i in expected:
		assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(cell), charted), expected[cell], "cell %s" % cell)

func test_fog_tier_is_three_with_nothing_charted() -> void:
	var charted: Array[Vector3i] = []
	assert_eq(ZoneMapMath.fog_tier(Vector3i.ZERO, charted), 3)

func test_fog_tier_uses_the_nearest_charted_zone() -> void:
	# Spirit Valley (0, 0) and the Advancement demo (0, -1): (1, -2) is next to the demo zone.
	var charted: Array[Vector3i] = [
		ZoneMapMath.cell_to_cube(Vector2i(0, 0)),
		ZoneMapMath.cell_to_cube(Vector2i(0, -1)),
	]
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(1, -2)), charted), 1)
	assert_eq(ZoneMapMath.fog_tier(ZoneMapMath.cell_to_cube(Vector2i(1, -3)), charted), 2)

#-----------------------------------------------------------------------------
# FORAGING
#-----------------------------------------------------------------------------

func test_forage_wander_keyframes() -> void:
	# Out to -24 world px by 1.2 s, searching there until 3 s, home by 4.2 s,
	# then the find held up at the stand until the haul at 5 s.
	assert_eq(ZoneMapMath.forage_wander_x(0.0), 0.0)
	assert_eq(ZoneMapMath.forage_wander_x(0.6), -12.0, "halfway out")
	assert_eq(ZoneMapMath.forage_wander_x(1.2), -24.0, "furthest west as the search starts")
	assert_eq(ZoneMapMath.forage_wander_x(2.99), -24.0, "still there as the search ends")
	assert_eq(ZoneMapMath.forage_wander_x(3.6), -12.0, "halfway home")
	assert_eq(ZoneMapMath.forage_wander_x(4.2), 0.0, "home")
	assert_eq(ZoneMapMath.forage_wander_x(5.0), 0.0, "home at the haul")

func test_forage_wander_moves_west_only_in_whole_px() -> void:
	var t: float = 0.0
	while t < 5.0:
		var x: float = ZoneMapMath.forage_wander_x(t)
		assert_true(x <= 0.0 and x >= -24.0, "x %s at %s s" % [x, t])
		assert_eq(x, roundf(x), "whole world px at %s s" % t)
		t += 0.05

func test_forage_animation_follows_the_haul() -> void:
	assert_eq(ZoneMapMath.forage_animation(0.0), &"walk_left")
	assert_eq(ZoneMapMath.forage_animation(1.19), &"walk_left")
	assert_eq(ZoneMapMath.forage_animation(1.2), &"forage_search", "kneels where the walk ends")
	assert_eq(ZoneMapMath.forage_animation(3.0), &"walk_right")
	assert_eq(ZoneMapMath.forage_animation(4.2), &"forage_present", "home, the find held up")
	assert_eq(ZoneMapMath.forage_animation(4.99), &"forage_present", "still held up as the haul comes in")
	assert_eq(ZoneMapMath.forage_animation(5.0), &"walk_left", "and the next haul sets out again")

func test_forage_animation_position_is_the_time_into_its_segment() -> void:
	assert_almost_eq(ZoneMapMath.forage_animation_position(0.5), 0.5, 0.0001)
	assert_almost_eq(ZoneMapMath.forage_animation_position(2.0), 0.8, 0.0001)
	assert_almost_eq(ZoneMapMath.forage_animation_position(4.5), 0.3, 0.0001)
	assert_almost_eq(ZoneMapMath.forage_animation_position(6.0), 1.0, 0.0001, "the next haul starts over")

#-----------------------------------------------------------------------------
# AURA WELL
#-----------------------------------------------------------------------------

func test_aura_well_starts_meditating_at_the_stand() -> void:
	var start: float = ZoneMapMath.AURA_WELL_START_SECONDS
	assert_eq(ZoneMapMath.AURA_WELL_SPOTS[0], Vector2.ZERO, "the first spot is the stand")
	assert_eq(ZoneMapMath.aura_well_spot(start), Vector2.ZERO)
	assert_eq(ZoneMapMath.aura_well_animation(start), &"meditate", "sits down at once, without re-forming")
	assert_false(ZoneMapMath.is_aura_well_gone(start))

func test_aura_well_spot_sequence() -> void:
	# One spot: re-forms (0.45 s), three breaths (7.2 s), dissolves (0.45 s), gone (0.3 s).
	assert_eq(ZoneMapMath.aura_well_animation(0.0), &"teleport_in")
	assert_eq(ZoneMapMath.aura_well_animation(0.44), &"teleport_in")
	assert_eq(ZoneMapMath.aura_well_animation(0.45), &"meditate")
	assert_eq(ZoneMapMath.aura_well_animation(7.64), &"meditate")
	assert_eq(ZoneMapMath.aura_well_animation(7.65), &"teleport_out")
	assert_false(ZoneMapMath.is_aura_well_gone(8.09), "still dissolving")
	assert_true(ZoneMapMath.is_aura_well_gone(8.1))
	assert_true(ZoneMapMath.is_aura_well_gone(8.39))
	assert_false(ZoneMapMath.is_aura_well_gone(8.4))
	assert_eq(ZoneMapMath.aura_well_animation(8.4), &"teleport_in", "re-forms at the next spot")

func test_aura_well_visits_every_spot_in_turn() -> void:
	var spot_seconds: float = ZoneMapMath.AURA_WELL_SPOT_SECONDS
	for i: int in ZoneMapMath.AURA_WELL_SPOTS.size():
		assert_eq(ZoneMapMath.aura_well_spot(i * spot_seconds + 1.0), ZoneMapMath.AURA_WELL_SPOTS[i], "spot %d" % i)
	assert_eq(ZoneMapMath.aura_well_cycle_seconds(), spot_seconds * ZoneMapMath.AURA_WELL_SPOTS.size())
	assert_eq(ZoneMapMath.aura_well_spot(ZoneMapMath.aura_well_cycle_seconds() + 1.0), ZoneMapMath.AURA_WELL_SPOTS[0], "and round again")

func test_aura_well_moves_only_out_of_sight() -> void:
	# Each spot change comes right after the gap: never under a visible character.
	# The step is shorter than the gap and does not divide the spot's 8.4 s,
	# so no sample lands on a boundary.
	var step: float = 0.047
	var last: Vector2 = ZoneMapMath.aura_well_spot(0.0)
	var changes: int = 0
	var i: int = 1
	while i * step < ZoneMapMath.aura_well_cycle_seconds() * 1.5:
		var t: float = i * step
		var spot: Vector2 = ZoneMapMath.aura_well_spot(t)
		if spot != last:
			changes += 1
			assert_true(ZoneMapMath.is_aura_well_gone(t - step), "gone just before the move at %s s" % t)
			assert_eq(ZoneMapMath.aura_well_animation(t), &"teleport_in", "and re-forming just after it")
			last = spot
		i += 1
	assert_gt(changes, ZoneMapMath.AURA_WELL_SPOTS.size(), "precondition: went round every spot")

func test_aura_well_spots_are_whole_px() -> void:
	for spot: Vector2 in ZoneMapMath.AURA_WELL_SPOTS:
		assert_eq(spot, spot.round(), "spot %s on whole world px" % spot)

func test_aura_well_animation_position_loops_the_breath() -> void:
	assert_almost_eq(ZoneMapMath.aura_well_animation_position(0.2), 0.2, 0.0001, "into the re-forming")
	assert_almost_eq(ZoneMapMath.aura_well_animation_position(0.45 + 2.5), 0.1, 0.0001, "the breath loops every 2.4 s")
	assert_almost_eq(ZoneMapMath.aura_well_animation_position(7.75), 0.1, 0.0001, "into the dissolve")
