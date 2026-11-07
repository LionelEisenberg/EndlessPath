extends GutTest

## Unit tests for LacquerStarRow, the row of Core Density stars: each star's frame
## follows its fill in tenths, the row shows as many stars as it is handed fills,
## and handed the fills from before a run, a star that rose shows jade with its
## old part in brass over it. On parchment the stars take the strip's paper rows.

const ROW_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_star_row/lacquer_star_row.tscn")

func _row() -> LacquerStarRow:
	var row: LacquerStarRow = ROW_SCENE.instantiate() as LacquerStarRow
	add_child_autofree(row)
	return row

func _slot(row: LacquerStarRow, index: int) -> Control:
	return row.get_child(index) as Control

func _base(row: LacquerStarRow, index: int) -> LacquerStripRect:
	return _slot(row, index).get_child(0) as LacquerStripRect

func _before(row: LacquerStarRow, index: int) -> LacquerStripRect:
	return _slot(row, index).get_child(1) as LacquerStripRect

## A fill shows its tenths rounded down: empty, part-way, a float that lands a
## hair under its tenth (0.4 from 34 levels), and lit.
func test_a_fill_shows_its_tenths() -> void:
	var cases: Array[Dictionary] = [
		{"fill": 0.0, "step": 0},
		{"fill": 0.09, "step": 0},
		{"fill": 0.4, "step": 4},
		{"fill": 3.4 - 3.0, "step": 4},
		{"fill": 0.99, "step": 9},
		{"fill": 1.0, "step": 10},
		{"fill": 1.5, "step": 10},
	]
	for case: Dictionary in cases:
		assert_eq(LacquerStarRow.step_of(case.fill), case.step, "fill %f" % case.fill)

## Each star's frame is its step on the brass row; slots past the fills hide.
func test_the_row_shows_one_star_per_fill() -> void:
	var row: LacquerStarRow = _row()
	row.set_fills([1.0, 1.0, 0.4, 0.0] as Array[float])
	assert_eq(row.get_star_count(), 4)
	assert_eq(_base(row, 0).get_frame(), Vector2i(10, LacquerStarRow.ROW_BRASS), "a lit star")
	assert_eq(_base(row, 2).get_frame(), Vector2i(4, LacquerStarRow.ROW_BRASS), "four tenths")
	assert_eq(_base(row, 3).get_frame(), Vector2i(0, LacquerStarRow.ROW_BRASS), "empty")
	assert_true(_slot(row, 3).visible)
	assert_false(_slot(row, 4).visible, "no fifth star")
	assert_false(_before(row, 2).visible, "no old part without fills from before")
	row.set_fills([] as Array[float])
	assert_eq(row.get_star_count(), 0)
	assert_false(_slot(row, 0).visible, "no stars, none shown")

## A star that rose since the fills from before shows jade, with its old part
## drawn brass over it; a star that did not rise stays brass.
func test_a_star_that_rose_shows_jade_over_its_old_part() -> void:
	var row: LacquerStarRow = _row()
	row.set_fills([1.0, 1.0, 0.2, 0.0] as Array[float], [1.0, 0.4, 0.0, 0.0] as Array[float])
	assert_false(row.is_star_gained(0), "lit before, lit now")
	assert_eq(_base(row, 0).get_frame().y, LacquerStarRow.ROW_BRASS)
	assert_true(row.is_star_gained(1))
	assert_eq(_base(row, 1).get_frame(), Vector2i(10, LacquerStarRow.ROW_JADE), "the risen star is jade")
	assert_true(_before(row, 1).visible, "its old four tenths show over it")
	assert_eq(_before(row, 1).get_frame(), Vector2i(4, LacquerStarRow.ROW_FILL_ONLY))
	assert_true(row.is_star_gained(2))
	assert_false(_before(row, 2).visible, "a star empty before has no old part")
	assert_false(row.is_star_gained(3), "an empty star rose by nothing")

## On parchment the brass and jade rows are the strip's paper ones.
func test_paper_takes_the_parchment_rows() -> void:
	var row: LacquerStarRow = _row()
	row.paper = true
	row.set_fills([0.5, 1.0] as Array[float], [0.5, 0.5] as Array[float])
	assert_eq(_base(row, 0).get_frame(), Vector2i(5, LacquerStarRow.ROW_BRASS + LacquerStarRow.PAPER_ROWS))
	assert_eq(_base(row, 1).get_frame(), Vector2i(10, LacquerStarRow.ROW_JADE + LacquerStarRow.PAPER_ROWS))
