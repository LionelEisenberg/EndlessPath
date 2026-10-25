extends GutTest

## Pins TribulationStage's geometry, what the stage draws its spheres and the hold's
## brass arc by. The stage draws per art cell (one CELL, 2 px) from one band rule: the
## cell at offset (x, y) from the centre corner lies in the band [inner, outer) when
## inner <= hypot(x + 0.5, y + 0.5) < outer. The drawing itself needs the board's scene
## (its %SphereLayer and %ArcLayer nodes), so it runs with the board. These tests call
## the statics it draws by: the sphere's radius in cells, a band as horizontal runs, and
## a band's cells in clockwise order from 12 o'clock.
##
## The oracle is the rule itself, tried on every cell of the square round the centre
## corner, never the stage's own arithmetic. The rule never lands on a band edge: twice a
## cell's offsets are odd numbers, so four times its squared distance is 2 more than a
## multiple of 4, while an edge's is a multiple of 4. A float hypot cannot disagree
## with an exact count.

## The ring strip the spheres cross: two frames side by side, the ring and its lit frame,
## each 272 px (136 art px) square. The ring is drawn on the band rule round the frame's
## middle corner, which is the stage's centre corner.
const RING_STRIP_PATH: String = "res://assets/ui/lacquer/tribulation/lacquer_trib_ring_strip_ai.png"
const RING_FRAME_PX: int = 272
const RING_FRAMES: int = 2
const RING_CENTRE_CELLS: int = 68

## Ink, the colour of the ring's outline. The brass between is any other colour.
const INK_HTML: String = "150909"

## How far an angle may fall short of the one before it, in radians. The engine measures
## an angle in 32-bit floats, and cells on one ray (such as (0, -2) and (1, -5)) are meant
## to tie. Cells on different rays of the bands tested are at least 8e-5 radians apart (the
## hold arc's band holds the closest), well clear of this.
const ANGLE_EPS: float = 1.0e-5

## The sphere radii the stage draws, in cells: the smallest sphere (ratio 0.42), the one
## on the ring (1.0), the biggest of a phase (1.88) and the biggest of the last breath (2.54).
const SPHERE_RADII: Array[int] = [27, 65, 122, 165]

## How many offenders a failure lists.
const SHOWN: int = 5

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The distance from the centre corner to the middle of `cell`, which the band rule measures.
func _distance(cell: Vector2i) -> float:
	var x: float = cell.x + 0.5
	var y: float = cell.y + 0.5
	return sqrt(x * x + y * y)

## Returns how far round `cell` lies from 12 o'clock, clockwise on the screen, in radians
## from 0 to TAU. The engine's own signed angle from UP is positive toward the right.
func _clockwise_angle(cell: Vector2i) -> float:
	return fposmod(Vector2.UP.angle_to(Vector2(cell.x + 0.5, cell.y + 0.5)), TAU)

## Returns the cells of `runs`, run by run and left to right.
func _expand(runs: Array[Rect2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for run: Rect2i in runs:
		for x: int in range(run.position.x, run.position.x + run.size.x):
			cells.append(Vector2i(x, run.position.y))
	return cells

## Returns `cells` as a set.
func _set_of(cells: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var set: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		set[cell] = true
	return set

## Returns the cells the band rule names for [inner, outer), found by trying every cell of
## the square round the centre corner.
func _cells_by_the_rule(inner: int, outer: int) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for y: int in range(-outer, outer):
		for x: int in range(-outer, outer):
			var distance: float = _distance(Vector2i(x, y))
			if distance >= inner and distance < outer:
				cells[Vector2i(x, y)] = true
	return cells

## Asserts `found` is exactly the cells of `expected`, naming the first that are missing or
## extra.
func _assert_same_cells(found: Dictionary[Vector2i, bool], expected: Dictionary[Vector2i, bool], label: String) -> void:
	var missing: Array[Vector2i] = []
	for cell: Vector2i in expected:
		if not found.has(cell):
			missing.append(cell)
	var extra: Array[Vector2i] = []
	for cell: Vector2i in found:
		if not expected.has(cell):
			extra.append(cell)
	assert_true(missing.is_empty() and extra.is_empty(),
			"%s: %d missing %s, %d extra %s" % [label, missing.size(), missing.slice(0, SHOWN), extra.size(), extra.slice(0, SHOWN)])

## Asserts the stage's band [inner, outer) holds exactly the cells the rule names, once
## each, whether it is read as clockwise cells or as runs, and that its runs come row by
## row from the top and left to right, with no two of a row touching: each run is as long
## as it can be, so the stage draws the band in the fewest rects.
func _assert_band_is_the_rule(inner: int, outer: int) -> void:
	var label: String = "band [%d, %d)" % [inner, outer]
	var expected: Dictionary[Vector2i, bool] = _cells_by_the_rule(inner, outer)
	assert_gt(expected.size(), 0, "%s: the rule names cells" % label)
	var clockwise: Array[Vector2i] = TribulationStage.band_cells_clockwise(inner, outer)
	var runs: Array[Rect2i] = TribulationStage.band_runs(inner, outer)
	var from_runs: Array[Vector2i] = _expand(runs)
	assert_eq(clockwise.size(), expected.size(), "%s: each cell once, clockwise" % label)
	assert_eq(from_runs.size(), expected.size(), "%s: each cell once, in runs" % label)
	_assert_same_cells(_set_of(clockwise), expected, "%s clockwise" % label)
	_assert_same_cells(_set_of(from_runs), expected, "%s runs" % label)
	var out_of_order: Array[Rect2i] = []
	for index: int in range(1, runs.size()):
		var before: Rect2i = runs[index - 1]
		var run: Rect2i = runs[index]
		if not (run.position.y > before.position.y or (run.position.y == before.position.y and run.position.x > before.end.x)):
			out_of_order.append(run)
	assert_eq(out_of_order.size(), 0, "%s: %d runs out of order or touching the one before, first %s" % [label, out_of_order.size(), out_of_order.slice(0, SHOWN)])

## Asserts the cells of the band [inner, outer) start at 12 o'clock and never turn back:
## the first has x 0 and lies above the centre, and no cell's angle falls short of the
## largest before it (by more than ANGLE_EPS).
func _assert_clockwise_from_twelve(inner: int, outer: int) -> void:
	var label: String = "band [%d, %d)" % [inner, outer]
	var cells: Array[Vector2i] = TribulationStage.band_cells_clockwise(inner, outer)
	assert_gt(cells.size(), 0, "%s has cells" % label)
	if cells.is_empty():
		return
	assert_eq(cells[0].x, 0, "%s: the first cell is in column 0" % label)
	assert_lt(cells[0].y, 0, "%s: the first cell is above the centre" % label)
	var turned_back: Array[String] = []
	var previous: float = 0.0
	for cell: Vector2i in cells:
		var angle: float = _clockwise_angle(cell)
		if angle < previous - ANGLE_EPS:
			turned_back.append("%s at %.5f after %.5f" % [cell, angle, previous])
		previous = maxf(previous, angle)
	assert_eq(turned_back.size(), 0, "%s: %d cells turn back, first %s" % [label, turned_back.size(), turned_back.slice(0, SHOWN)])

#-----------------------------------------------------------------------------
# RADIUS
#-----------------------------------------------------------------------------

## A sphere's radius in cells is its ratio of the ring's 65 cells (130 px), rounded.
func test_radius_cells() -> void:
	assert_eq(TribulationStage.radius_cells(1.0), 65, "on the ring")
	assert_eq(TribulationStage.radius_cells(0.42), 27, "the smallest sphere")
	assert_eq(TribulationStage.radius_cells(1.88), 122, "the biggest of a phase")
	assert_eq(TribulationStage.radius_cells(2.54), 165, "the biggest of the last breath")
	# The figures above all fall short of the next cell by under half, so they would not tell
	# rounding from cutting: 1.01 is 65.65 cells and 0.99 is 64.35.
	assert_eq(TribulationStage.radius_cells(1.01), 66, "rounds up past half a cell")
	assert_eq(TribulationStage.radius_cells(0.99), 64, "rounds down short of half a cell")

## The centre corner is the middle of the 900 x 600 stage and a corner of its 2 px grid, so
## every cell drawn from it lands on the grid, and the ring (a 272 px frame) and the core
## are placed about the same point.
func test_the_centre_is_a_grid_corner_in_the_middle_of_the_stage() -> void:
	var centre: Vector2 = TribulationStage.CENTRE
	assert_eq(centre, Vector2(900, 600) / 2.0, "the middle of the stage")
	assert_eq(fmod(centre.x, TribulationStage.CELL), 0.0, "on a cell column")
	assert_eq(fmod(centre.y, TribulationStage.CELL), 0.0, "on a cell row")

#-----------------------------------------------------------------------------
# BAND
#-----------------------------------------------------------------------------

## Every cell of the band [10, 12) lies in it by the rule, none twice, and their number is
## the annulus's area within 5%. A band this thin holds a lattice count, not an area: the
## rule's cells number 132 here (the kit's own in_band counts the same), 4.5% under the
## annulus's 138.2, so the plan's 3% cannot hold. The tests below pin the exact set.
func test_band_cells_lie_in_the_band() -> void:
	var cells: Array[Vector2i] = TribulationStage.band_cells_clockwise(10, 12)
	var outside: Array[String] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var twice: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var distance: float = _distance(cell)
		if distance < 10.0 or distance >= 12.0:
			outside.append("%s at %.3f" % [cell, distance])
		if seen.has(cell):
			twice.append(cell)
		seen[cell] = true
	assert_eq(outside.size(), 0, "%d cells outside [10, 12), first %s" % [outside.size(), outside.slice(0, SHOWN)])
	assert_eq(twice.size(), 0, "%d cells twice, first %s" % [twice.size(), twice.slice(0, SHOWN)])
	var area: float = PI * (144 - 100)
	assert_almost_eq(float(cells.size()), area, area * 0.05, "the count is the annulus's area within 5%")

## The band is a ring about the centre corner: mirroring a cell across the vertical or the
## horizontal axis (x to -1 - x, y to -1 - y) lands on a cell of the band.
func test_band_is_symmetric() -> void:
	var cells: Array[Vector2i] = TribulationStage.band_cells_clockwise(10, 12)
	assert_gt(cells.size(), 0, "the band has cells")
	var band: Dictionary[Vector2i, bool] = _set_of(cells)
	var unmirrored: Array[String] = []
	for cell: Vector2i in cells:
		if not band.has(Vector2i(-1 - cell.x, cell.y)):
			unmirrored.append("%s across the vertical axis" % cell)
		if not band.has(Vector2i(cell.x, -1 - cell.y)):
			unmirrored.append("%s across the horizontal axis" % cell)
	assert_eq(unmirrored.size(), 0, "%d cells without a mirror, first %s" % [unmirrored.size(), unmirrored.slice(0, SHOWN)])

## The runs are the same cells as the clockwise list: each run is one cell tall, and no two
## runs overlap.
func test_band_runs_cover_the_same_cells() -> void:
	var runs: Array[Rect2i] = TribulationStage.band_runs(10, 12)
	assert_gt(runs.size(), 0, "the band has runs")
	var not_flat: Array[Rect2i] = []
	for run: Rect2i in runs:
		if run.size.y != 1 or run.size.x < 1:
			not_flat.append(run)
	assert_eq(not_flat.size(), 0, "runs one cell tall and at least one wide, first offenders %s" % [not_flat.slice(0, SHOWN)])
	var expanded: Array[Vector2i] = _expand(runs)
	var covered: Dictionary[Vector2i, bool] = _set_of(expanded)
	assert_eq(covered.size(), expanded.size(), "no two runs overlap")
	var clockwise: Array[Vector2i] = TribulationStage.band_cells_clockwise(10, 12)
	assert_gt(clockwise.size(), 0, "the band has cells")
	_assert_same_cells(covered, _set_of(clockwise), "the runs against the clockwise cells")

## The clockwise list starts at 12 o'clock: its first cell is in column 0 above the centre,
## and no angle falls short of the one before it.
func test_clockwise_starts_at_twelve() -> void:
	_assert_clockwise_from_twelve(10, 12)

## The band holds exactly the cells the rule names, however thin or thick: for every outer
## edge from 1 to 40 cells and every thickness from 1 to 4 that fits (a thickness equal to
## the outer edge is a disc). It catches what the five checks above would not: a missing
## cell, or an off-by-one at a band's top or bottom row, or where its hole closes.
func test_small_bands_hold_exactly_the_cells_the_rule_names() -> void:
	for outer: int in range(1, 41):
		for thickness: int in range(1, mini(outer, 4) + 1):
			_assert_band_is_the_rule(outer - thickness, outer)

## An inner edge below 0 reaches every cell inside the outer edge, as the rule does: a disc.
func test_an_inner_edge_below_zero_makes_a_disc() -> void:
	_assert_band_is_the_rule(-3, 4)

## The bands the stage draws hold exactly the cells the rule names: for each sphere radius, the
## bright band [r - 2, r), its crest [r - 3, r - 2) and the faint band [r - 1, r), and the
## hold's arc [75, 79).
func test_the_stage_bands_hold_exactly_the_cells_the_rule_names() -> void:
	for radius: int in SPHERE_RADII:
		_assert_band_is_the_rule(radius - 2, radius)
		_assert_band_is_the_rule(radius - 3, radius - 2)
		_assert_band_is_the_rule(radius - 1, radius)
	_assert_band_is_the_rule(TribulationStage.HOLD_ARC_INNER, TribulationStage.HOLD_ARC_OUTER)

## The faint band's dashes and the hold's arc run clockwise from 12 o'clock too, at every
## radius the stage draws them.
func test_the_stage_bands_run_clockwise_from_twelve() -> void:
	for radius: int in SPHERE_RADII:
		_assert_clockwise_from_twelve(radius - 1, radius)
	_assert_clockwise_from_twelve(TribulationStage.HOLD_ARC_INNER, TribulationStage.HOLD_ARC_OUTER)

## A band with no width, or an inner edge past the outer, holds no cells, though the band
## just outside it does.
func test_an_empty_band_has_no_cells() -> void:
	assert_gt(TribulationStage.band_runs(5, 6).size(), 0, "the band [5, 6) has runs")
	assert_gt(TribulationStage.band_cells_clockwise(5, 6).size(), 0, "the band [5, 6) has cells")
	assert_eq(TribulationStage.band_runs(5, 5).size(), 0, "no runs between equal edges")
	assert_eq(TribulationStage.band_cells_clockwise(5, 5).size(), 0, "no cells between equal edges")
	assert_eq(TribulationStage.band_runs(6, 5).size(), 0, "no runs with the inner edge past the outer")
	assert_eq(TribulationStage.band_cells_clockwise(6, 5).size(), 0, "no cells with the inner edge past the outer")

#-----------------------------------------------------------------------------
# DRAWING RULES
#-----------------------------------------------------------------------------

## The hold's arc shows the first cells * steps / 24 of its cells, steps being the whole 24ths
## of the hold that have run: none short of the first step, a step at a time, every cell at
## the end, and never more or less than the band. The progress figures sit mid-step, clear of
## the boundary where float rounding could tip a step.
func test_the_arc_fills_in_whole_steps() -> void:
	# 240 cells make a step 10 cells, so each figure reads at a glance.
	assert_eq(TribulationStage._arc_cell_count(240, 0.0), 0, "nothing before the hold")
	assert_eq(TribulationStage._arc_cell_count(240, 0.5 / 24.0), 0, "short of the first step")
	assert_eq(TribulationStage._arc_cell_count(240, 1.5 / 24.0), 10, "one step")
	assert_eq(TribulationStage._arc_cell_count(240, 11.5 / 24.0), 110, "eleven steps")
	assert_eq(TribulationStage._arc_cell_count(240, 23.5 / 24.0), 230, "twenty-three steps")
	assert_eq(TribulationStage._arc_cell_count(240, 1.0), 240, "every cell at the end")
	assert_eq(TribulationStage._arc_cell_count(240, 1.5), 240, "no more than the band")
	assert_eq(TribulationStage._arc_cell_count(240, -0.5), 0, "no less than nothing")

## On the hold arc's real band, 1924 cells (the kit's own in_band counts them), a step shows its
## share rounded down to a whole cell: 5 steps are 400 cells, 11 are 881 and 23 are 1843.
func test_the_arc_shares_its_real_band_in_whole_cells() -> void:
	var cells: int = TribulationStage.band_cells_clockwise(TribulationStage.HOLD_ARC_INNER, TribulationStage.HOLD_ARC_OUTER).size()
	assert_eq(cells, 1924, "the arc's band")
	assert_eq(TribulationStage._arc_cell_count(cells, 5.5 / 24.0), 400, "5 steps")
	assert_eq(TribulationStage._arc_cell_count(cells, 11.5 / 24.0), 881, "11 steps")
	assert_eq(TribulationStage._arc_cell_count(cells, 23.5 / 24.0), 1843, "23 steps")

## A faint sphere's dashes: 4 cells drawn, then 4 skipped, counting clockwise from 12 o'clock.
## The cells whose index / 4 is even are drawn.
func test_dashes_alternate_every_four_cells() -> void:
	var pattern: String = "TTTTFFFFTTTTFFFFTTTTFFFF"
	for index: int in pattern.length():
		assert_eq(TribulationStage._is_dash_cell(index), pattern[index] == "T", "cell %d" % index)

#-----------------------------------------------------------------------------
# RING ART
#-----------------------------------------------------------------------------

## The ring art is drawn by the same rule, so the spheres line up with it: in both of its
## frames, the ring's brass is the band [R - 1, R + 1) round the stage's ring radius R (65
## cells), its ink outline is [R - 2, R - 1) and [R + 1, R + 2), and every other cell is clear.
func test_the_ring_art_lies_on_the_bands_the_spheres_cross() -> void:
	var texture: Texture2D = load(RING_STRIP_PATH) as Texture2D
	assert_not_null(texture, "the ring strip loads")
	if texture == null:
		return
	var image: Image = texture.get_image()
	var ring: int = TribulationStage.radius_cells(1.0)
	# Each cell of the ring maps to whether it is ink.
	var expected: Dictionary[Vector2i, bool] = {}
	for edge: Vector2i in [Vector2i(ring - 2, ring - 1), Vector2i(ring + 1, ring + 2)]:
		for cell: Vector2i in _expand(TribulationStage.band_runs(edge.x, edge.y)):
			expected[cell] = true
	for cell: Vector2i in _expand(TribulationStage.band_runs(ring - 1, ring + 1)):
		expected[cell] = false
	assert_gt(expected.size(), 0, "the ring has cells")
	var wrong: Array[String] = []
	for frame: int in RING_FRAMES:
		for y: int in range(-RING_CENTRE_CELLS, RING_CENTRE_CELLS):
			for x: int in range(-RING_CENTRE_CELLS, RING_CENTRE_CELLS):
				var cell := Vector2i(x, y)
				var pixel: Color = image.get_pixel(frame * RING_FRAME_PX + 2 * (RING_CENTRE_CELLS + x), 2 * (RING_CENTRE_CELLS + y))
				var opaque: bool = pixel.a > 0.0
				if not expected.has(cell):
					if opaque:
						wrong.append("frame %d: %s is drawn, outside the ring" % [frame, cell])
				elif not opaque:
					wrong.append("frame %d: %s is clear, inside the ring" % [frame, cell])
				elif (pixel.to_html(false) == INK_HTML) != expected[cell]:
					wrong.append("frame %d: %s is %s, not %s" % [frame, cell, "ink" if expected[cell] else "brass", "brass" if expected[cell] else "ink"])
	assert_eq(wrong.size(), 0, "%d cells off the bands, first %s" % [wrong.size(), wrong.slice(0, SHOWN)])
