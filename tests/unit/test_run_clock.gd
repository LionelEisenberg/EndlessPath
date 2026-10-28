extends GutTest

## Unit tests for RunClock's two pure rules: how a time left reads (M:SS, the
## truncating arithmetic the old timer pill used) and when the clock turns to
## the low-time seal (30 s or less). The clock's scene behaviour (it following
## a Timer, the seal, the header layout) is in test_adventure_chest.gd.

#-----------------------------------------------------------------------------
# TIME LEFT
#-----------------------------------------------------------------------------

func test_format_time() -> void:
	assert_eq(RunClock.format_time(125.9), "2:05", "minutes floor and seconds truncate")
	assert_eq(RunClock.format_time(59.9), "0:59", "59.9 s has not reached a minute")
	assert_eq(RunClock.format_time(0.0), "0:00")
	assert_eq(RunClock.format_time(600.0), "10:00", "minutes do not wrap at ten")

## The seconds are cut, not rounded, as the old timer pill's countdown was: 119.99
## s still reads 1:59, and the whole of the last second reads 0:00.
func test_format_time_truncates_to_the_second() -> void:
	assert_eq(RunClock.format_time(0.99), "0:00")
	assert_eq(RunClock.format_time(1.0), "0:01")
	assert_eq(RunClock.format_time(59.99), "0:59")
	assert_eq(RunClock.format_time(60.0), "1:00")
	assert_eq(RunClock.format_time(119.99), "1:59")

#-----------------------------------------------------------------------------
# LOW TIME
#-----------------------------------------------------------------------------

func test_low_at_thirty_not_thirty_one() -> void:
	assert_eq(RunClock.LOW_SECONDS, 30.0)
	assert_true(RunClock.is_low(30.0), "30 s is low")
	assert_true(RunClock.is_low(0.0), "no time left is low")
	assert_false(RunClock.is_low(30.4), "30.4 s is not low yet")
	assert_false(RunClock.is_low(31.0))
