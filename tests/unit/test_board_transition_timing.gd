extends GutTest

## Unit tests for BoardTransitionTiming, the board open and close transition's
## timing: how long the open runs, which is how long the transition's shield
## takes every click.

#-----------------------------------------------------------------------------
# DURATION
#-----------------------------------------------------------------------------

func test_durations() -> void:
	assert_eq(BoardTransitionTiming.duration_ms(true), 540.0)
	assert_eq(BoardTransitionTiming.duration_ms(false), 520.0)
