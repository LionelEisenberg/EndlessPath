extends GutTest

## Unit tests for HexForestAtlas static helper.

const HEX_FOREST_ATLAS := preload("res://scripts/utils/hex_forest_atlas.gd")

func test_pick_is_deterministic_for_same_coord() -> void:
	var a: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(1, 2, -3))
	var b: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(1, 2, -3))
	assert_eq(a, b, "pick() must return the same cell for the same coord")

func test_pick_returns_cell_within_atlas_bounds() -> void:
	for q in range(-5, 6):
		for r in range(-5, 6):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			assert_true(cell.x >= 0 and cell.x < HEX_FOREST_ATLAS.FOREST_ATLAS_COLS,
				"cell.x=%d out of range for coord (%d,%d)" % [cell.x, q, r])
			# 23 variants in a 6-wide grid → rows 0..3 (row 3 is partial: cols 0..4).
			assert_true(cell.y >= 0 and cell.y <= 3,
				"cell.y=%d out of range for coord (%d,%d)" % [cell.y, q, r])

func test_pick_distributes_across_multiple_variants() -> void:
	var uniques: Dictionary = {}
	for q in range(-5, 6):
		for r in range(-5, 6):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			uniques[cell] = true
	assert_gt(uniques.size(), 5,
		"pick() should produce a reasonable spread, got only %d unique cells" % uniques.size())

func test_pick_index_stays_within_variant_count() -> void:
	# The underlying idx must be < FOREST_VARIANT_COUNT (23) for every coord.
	# We verify indirectly: any cell returned should be representable as
	# idx = cell.y * FOREST_ATLAS_COLS + cell.x, and idx < 23.
	for q in range(-10, 11):
		for r in range(-10, 11):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			var idx: int = cell.y * HEX_FOREST_ATLAS.FOREST_ATLAS_COLS + cell.x
			assert_lt(idx, HEX_FOREST_ATLAS.FOREST_VARIANT_COUNT,
				"idx=%d exceeds FOREST_VARIANT_COUNT for coord (%d,%d)" % [idx, q, r])

#-----------------------------------------------------------------------------
# pick_from (fog pools)
#-----------------------------------------------------------------------------

func test_pick_from_is_deterministic_and_in_range() -> void:
	for q in range(-6, 7):
		for r in range(-6, 7):
			var coord := Vector3i(q, r, -q - r)
			var index: int = HEX_FOREST_ATLAS.pick_from(coord, 9)
			assert_eq(index, HEX_FOREST_ATLAS.pick_from(coord, 9), "same cell for the same coord %s" % coord)
			assert_true(index >= 0 and index < 9, "index %d out of [0, 9) for %s" % [index, coord])

func test_pick_from_spreads_across_the_pool() -> void:
	var uniques: Dictionary = {}
	for q in range(-6, 7):
		for r in range(-6, 7):
			uniques[HEX_FOREST_ATLAS.pick_from(Vector3i(q, r, -q - r), 9)] = true
	assert_gt(uniques.size(), 5, "a 9-cell pool should see most of its cells, got %d" % uniques.size())

func test_pick_from_an_empty_pool_is_zero() -> void:
	assert_eq(HEX_FOREST_ATLAS.pick_from(Vector3i(2, -1, -1), 0), 0)
