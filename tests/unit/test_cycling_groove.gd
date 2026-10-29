extends GutTest

## Unit tests for CyclingGroove, the carved channel the Madra ball travels: a
## technique with no path leaves it empty, and it redraws only when the number
## of lit cells changes.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

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
# SETUP
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# LIGHTING
#-----------------------------------------------------------------------------

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
