extends GutTest

## Unit tests for RunClock's two pure rules: how a time left reads (M:SS, the
## truncating arithmetic the old timer pill used) and when the clock turns to
## the low-time seal (30 s or less). The clock's scene behaviour (it following
## a Timer, the seal, the header layout) is in test_adventure_chest.gd.

#-----------------------------------------------------------------------------
# TIME LEFT
#-----------------------------------------------------------------------------

## How a time left reads, M:SS: the minutes floor and do not wrap at ten, and the
## seconds are cut, not rounded, as the old timer pill's countdown was: 119.99 s
## still reads 1:59, and the whole of the last second reads 0:00.
func test_format_time() -> void:
	var cases: Array[Dictionary] = [
		{"seconds": 125.9, "reads": "2:05", "why": "minutes floor and seconds truncate"},
		{"seconds": 59.9, "reads": "0:59", "why": "59.9 s has not reached a minute"},
		{"seconds": 0.0, "reads": "0:00", "why": "no time left"},
		{"seconds": 600.0, "reads": "10:00", "why": "minutes do not wrap at ten"},
		{"seconds": 0.99, "reads": "0:00", "why": "the whole of the last second"},
		{"seconds": 1.0, "reads": "0:01", "why": "one second"},
		{"seconds": 59.99, "reads": "0:59", "why": "just short of a minute"},
		{"seconds": 60.0, "reads": "1:00", "why": "one minute"},
		{"seconds": 119.99, "reads": "1:59", "why": "just short of two minutes"},
	]
	for case: Dictionary in cases:
		assert_eq(RunClock.format_time(case.seconds), case.reads, "%s s: %s" % [case.seconds, case.why])

#-----------------------------------------------------------------------------
# LOW TIME
#-----------------------------------------------------------------------------

func test_low_at_thirty_not_thirty_one() -> void:
	assert_eq(RunClock.LOW_SECONDS, 30.0)
	assert_true(RunClock.is_low(30.0), "30 s is low")
	assert_true(RunClock.is_low(0.0), "no time left is low")
	assert_false(RunClock.is_low(30.4), "30.4 s is not low yet")
	assert_false(RunClock.is_low(31.0))
