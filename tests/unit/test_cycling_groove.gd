extends GutTest

## Unit tests for CyclingGroove, the carved channel the Madra ball travels: the
## art-pixel cells a path covers (each point covers a 2 x 2 block, so a straight
## line is two cells thick), the lip under its bottom edge, the Madra colour of
## a lit cell, how many cells a travelled length lights, and the sweep that
## darkens the last cycle's light as a new cycle starts.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Points one px apart along the horizontal line at `y` from `from_x` to
## `to_x` (either way round), the spacing setup() samples a curve at.
func _line(from_x: int, to_x: int, y: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var step: int = 1 if to_x >= from_x else -1
	for x: int in range(from_x, to_x + step, step):
		points.append(Vector2(x, y))
	return points

## A straight Curve2D from `from` to `to`.
func _curve(from: Vector2, to: Vector2) -> Curve2D:
	var curve: Curve2D = Curve2D.new()
	curve.add_point(from)
	curve.add_point(to)
	return curve

## A CyclingGroove in the tree, set up on `curve`.
func _groove_on(curve: Curve2D) -> CyclingGroove:
	var groove: CyclingGroove = add_child_autofree(CyclingGroove.new())
	groove.setup(curve)
	return groove

#-----------------------------------------------------------------------------
# CELLS
#-----------------------------------------------------------------------------

## A point covers the 2 x 2 block whose top-left cell is floor(p / CELL - 0.5).
## The line at y = 10 covers rows 4 and 5, and the points at x = 0 to 20 cover
## columns -1 to 10: 12 columns of 2 cells.
func test_a_line_covers_two_rows() -> void:
	var cells: Dictionary = CyclingGroove.build_cells(_line(0, 20, 10.0))
	assert_eq(cells.size(), 24, "12 columns of 2 rows")
	for column: int in range(-1, 11):
		assert_true(cells.has(Vector2i(column, 4)), "column %d, row 4" % column)
		assert_true(cells.has(Vector2i(column, 5)), "column %d, row 5" % column)
		assert_false(cells.has(Vector2i(column, 6)), "column %d has nothing in row 6" % column)

## Out along the line and back covers the same cells twice. A cell keeps the
## length of the first pass, so a crossing lights as the path first reaches it.
func test_cells_keep_their_first_pass() -> void:
	var points: PackedVector2Array = _line(0, 20, 10.0)
	points.append_array(_line(19, 0, 10.0))
	var cells: Dictionary = CyclingGroove.build_cells(points)
	assert_eq(cells.size(), 24, "the way back covers no new cell")
	assert_lt(cells[Vector2i(0, 4)], 3.0, "the way out reaches the cell near the start")
	assert_eq(cells[Vector2i(10, 4)], 19.0, "the last column is first reached 19 px along")

## A cell's length is the distance along the points, not how many points came
## before it.
func test_a_cell_keeps_the_distance_along_the_points() -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(0, 10), Vector2(10, 10), Vector2(10, 16)])
	var cells: Dictionary = CyclingGroove.build_cells(points)
	assert_eq(cells[Vector2i(-1, 4)], 0.0, "the first point covers its cells at length 0")
	assert_eq(cells[Vector2i(4, 4)], 10.0, "the second point is 10 px along")
	assert_eq(cells[Vector2i(4, 7)], 16.0, "the third is 6 px further")

#-----------------------------------------------------------------------------
# LIPS
#-----------------------------------------------------------------------------

## The lip is the cell under each cell that has no cell below it: row 6, under
## the line's bottom row (row 5), in each of its 12 columns.
func test_lips_sit_under_the_bottom_row() -> void:
	var cells: Dictionary = CyclingGroove.build_cells(_line(0, 20, 10.0))
	var lips: Array[Vector2i] = CyclingGroove.lip_cells(cells)
	assert_eq(lips.size(), 12, "one lip under each column")
	for lip: Vector2i in lips:
		assert_eq(lip.y, 6, "the lip at column %d is in row 6" % lip.x)
	for column: int in range(-1, 11):
		assert_true(lips.has(Vector2i(column, 6)), "column %d has its lip" % column)

#-----------------------------------------------------------------------------
# COLOURS
#-----------------------------------------------------------------------------

## A lit cell with no cell above is the Madra ramp's light top edge, one with no
## cell below its deep bottom edge, and the cells between are its body. A cell
## with neither neighbour is a top edge: the top takes priority.
func test_lit_cells_shade_by_their_edges() -> void:
	var strip: Dictionary[Vector2i, float] = {Vector2i(0, 0): 0.0, Vector2i(0, 1): 1.0, Vector2i(0, 2): 2.0}
	assert_eq(CyclingGroove._lit_color(strip, Vector2i(0, 0)), ThemeConstants.LACQUER_MADRA_HI, "no cell above")
	assert_eq(CyclingGroove._lit_color(strip, Vector2i(0, 1)), ThemeConstants.LACQUER_MADRA, "cells above and below")
	assert_eq(CyclingGroove._lit_color(strip, Vector2i(0, 2)), ThemeConstants.LACQUER_MADRA_MID, "no cell below")
	var lone: Dictionary[Vector2i, float] = {Vector2i(5, 5): 0.0}
	assert_eq(CyclingGroove._lit_color(lone, Vector2i(5, 5)), ThemeConstants.LACQUER_MADRA_HI, "a lone cell is a top edge")

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

## The curve is sampled every px and once more at its end. From x = 0.5 to 101.2
## the steps stop at 100.5, which covers columns -1 to 50; only the end point
## at 101.2 reaches column 51, so there are 53 columns of 2 cells.
func test_setup_samples_the_end_point() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0.5, 10), Vector2(101.2, 10)))
	assert_eq(groove.get_cell_count(), 106, "53 columns of 2 rows")

## A technique may have no path, and a curve with no points cannot be sampled.
func test_no_curve_has_no_cells() -> void:
	var groove: CyclingGroove = _groove_on(null)
	assert_eq(groove.get_cell_count(), 0, "no curve")
	groove.setup(Curve2D.new())
	assert_eq(groove.get_cell_count(), 0, "a curve with no points")
	groove.set_lit_length(1e9)
	assert_eq(groove.get_lit_count(), 0, "nothing to light")
	groove.light_all()
	assert_eq(groove.get_lit_count(), 0, "nothing to light at all")

## Setting up again, when another technique is equipped, replaces the cells and
## leaves the groove dark.
func test_setup_again_replaces_the_cells_and_goes_dark() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	var long_path_cells: int = groove.get_cell_count()
	groove.set_lit_length(1e9)
	groove.setup(_curve(Vector2(0, 10), Vector2(20, 10)))
	assert_eq(groove.get_lit_count(), 0, "the new path starts dark")
	assert_eq(groove.get_cell_count(), 24, "the new path's own cells")
	assert_gt(long_path_cells, 24, "the old path had more")

#-----------------------------------------------------------------------------
# LIGHTING
#-----------------------------------------------------------------------------

## Cells light in path order: none before the start, more as the length grows,
## all of them past the end, and none again once the length goes back to the
## start.
func test_lit_count_follows_the_length() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	assert_gt(groove.get_cell_count(), 0, "the line has cells")
	groove.set_lit_length(-1.0)
	assert_eq(groove.get_lit_count(), 0, "a length before the start lights nothing")
	groove.set_lit_length(0.0)
	var at_start: int = groove.get_lit_count()
	groove.set_lit_length(50.0)
	var halfway: int = groove.get_lit_count()
	groove.set_lit_length(75.0)
	var three_quarters: int = groove.get_lit_count()
	assert_gt(at_start, 0, "the cells under the start light at length 0")
	assert_gt(halfway, at_start, "more light by halfway")
	assert_gt(three_quarters, halfway, "and more still by three quarters")
	assert_lt(three_quarters, groove.get_cell_count(), "but not all of them yet")
	groove.set_lit_length(1e9)
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "a length past the end lights every cell")
	groove.set_lit_length(-1.0)
	assert_eq(groove.get_lit_count(), 0, "going back to before the start darkens it again")

## Redrawing re-issues every cell, so it only happens when the lit count
## changes. The CanvasItem's `draw` signal fires once per redraw. The samples
## are 1 px apart, so cells start at whole px along the line (to within about
## 0.01), and none starts between 50.25 and 50.75.
func test_redraws_only_when_the_lit_count_changes() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	await wait_process_frames(2)
	watch_signals(groove)
	groove.set_lit_length(50.25)
	await wait_process_frames(2)
	assert_signal_emit_count(groove, "draw", 1, "a new lit count redraws")
	groove.set_lit_length(50.25)
	groove.set_lit_length(50.75)
	await wait_process_frames(2)
	assert_signal_emit_count(groove, "draw", 1, "the same lit count does not")
	groove.set_lit_length(60.0)
	await wait_process_frames(2)
	assert_signal_emit_count(groove, "draw", 2, "a changed lit count does again")

#-----------------------------------------------------------------------------
# THE SWEEP
#-----------------------------------------------------------------------------

## light_all() shows every cell lit, as a finished cycle leaves the groove.
func test_light_all_lights_every_cell() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	assert_eq(groove.get_lit_count(), 0, "precondition: a new groove is dark")
	groove.light_all()
	assert_eq(groove.get_lit_count(), groove.get_cell_count())

## With nothing swept the cells past the trail keep the last cycle's light. The
## sweep darkens the cells at or under its length, and the cells past it stay lit
## until it reaches them. A full sweep leaves only the trail.
func test_a_sweep_darkens_the_cells_it_has_passed() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	var total: int = groove.get_cell_count()
	groove.set_lit_length(-1.0)
	groove.set_swept_length(-1.0)
	assert_eq(groove.get_lit_count(), total, "nothing swept: the old light shows on every cell")
	groove.set_swept_length(50.0)
	var unswept: int = groove.get_lit_count()
	assert_gt(unswept, 0, "the cells past the sweep keep their light")
	assert_lt(unswept, total, "the cells it passed went dark")
	groove.set_swept_length(75.0)
	assert_lt(groove.get_lit_count(), unswept, "the dark grows as the sweep goes on")
	groove.set_swept_length(1e9)
	assert_eq(groove.get_lit_count(), 0, "a full sweep leaves only the trail, empty here")

## A cell is lit while the trail covers it or the sweep has not reached it, so the
## trail lights through the swept part and the old light lies past the sweep.
func test_the_trail_lights_through_the_swept_part() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	groove.set_swept_length(1e9)
	groove.set_lit_length(20.0)
	var trail: int = groove.get_lit_count()
	groove.set_lit_length(-1.0)
	groove.set_swept_length(50.0)
	var unswept: int = groove.get_lit_count()
	groove.set_lit_length(20.0)
	assert_eq(groove.get_lit_count(), trail + unswept, "the trail behind the sweep and the old light past it")
	groove.set_lit_length(1e9)
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "a trail over the whole path lights it all")

## Setting up a new path leaves it dark, whatever the old one showed.
func test_setup_after_a_sweep_starts_dark() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	groove.set_lit_length(-1.0)
	groove.set_swept_length(-1.0)
	groove.setup(_curve(Vector2(0, 10), Vector2(20, 10)))
	assert_eq(groove.get_lit_count(), 0)

## A changed swept count redraws, the same one does not.
func test_redraws_only_when_the_swept_count_changes() -> void:
	var groove: CyclingGroove = _groove_on(_curve(Vector2(0, 10), Vector2(100, 10)))
	await wait_process_frames(2)
	watch_signals(groove)
	groove.set_swept_length(50.25)
	await wait_process_frames(2)
	assert_signal_emit_count(groove, "draw", 1, "a new swept count redraws")
	groove.set_swept_length(50.75)
	await wait_process_frames(2)
	assert_signal_emit_count(groove, "draw", 1, "the same swept count does not")
