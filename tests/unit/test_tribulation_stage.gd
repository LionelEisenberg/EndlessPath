extends GutTest

## Unit tests for the two TribulationStage statics the player's timing reads from
## the stage: a sphere's radius in cells, which puts a sphere at ratio 1 on the
## ring the beats are judged at, and the hold arc's fill, which shows the whole arc
## only once the hold has run its full length.

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
