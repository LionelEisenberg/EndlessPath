extends GutTest

## Unit tests for MapGlyph's shake: the two keyframe sets and shake_offset_at(),
## the one function that steps through them. SHAKE_KEYFRAMES is the lock shake
## (0, -8, 8, -6, 4, 0; the padlock, the adventure's coins, Stamina row and Here
## tray), SOFT_SHAKE_KEYFRAMES the shake of a button that was pressed when it
## could not act (0, -4, 4, -2, 2, 0; the technique slots). The lock shake's
## numbers are pinned in test_zone_travel.gd, the padlock's own shake there and
## the slots' in test_technique_dock.gd.

#-----------------------------------------------------------------------------
# THE SOFT SHAKE
#-----------------------------------------------------------------------------

func test_soft_shake_keyframes() -> void:
	assert_eq(MapGlyph.SOFT_SHAKE_KEYFRAMES, [0, -4, 4, -2, 2, 0] as Array[int])

## Sampled in the middle of each 0.088 s step, as the lock shake's steps are in
## test_zone_travel.gd.
func test_soft_shake_steps() -> void:
	assert_eq(MapGlyph.shake_offset_at(0.0, MapGlyph.SOFT_SHAKE_KEYFRAMES), 0)
	assert_eq(MapGlyph.shake_offset_at(0.1, MapGlyph.SOFT_SHAKE_KEYFRAMES), -4)
	assert_eq(MapGlyph.shake_offset_at(0.2, MapGlyph.SOFT_SHAKE_KEYFRAMES), 4)
	assert_eq(MapGlyph.shake_offset_at(0.3, MapGlyph.SOFT_SHAKE_KEYFRAMES), -2)
	assert_eq(MapGlyph.shake_offset_at(0.4, MapGlyph.SOFT_SHAKE_KEYFRAMES), 2)
	assert_eq(MapGlyph.shake_offset_at(0.44, MapGlyph.SOFT_SHAKE_KEYFRAMES), 0, "back home after 0.44 s")
	assert_eq(MapGlyph.shake_offset_at(1.0, MapGlyph.SOFT_SHAKE_KEYFRAMES), 0)

## Each keyframe is held until the next one's edge, a multiple of the step: a hair
## before the edge still reads the old keyframe, on it the new one (the bias that
## keeps 0.44 s from flooring short).
func test_each_soft_keyframe_is_held_for_a_step() -> void:
	var soft: Array[int] = MapGlyph.SOFT_SHAKE_KEYFRAMES
	for index: int in range(1, soft.size()):
		var edge: float = index * MapGlyph.SHAKE_STEP_SECONDS
		assert_eq(MapGlyph.shake_offset_at(edge - 0.001, soft), soft[index - 1], "a hair before step %d" % index)
		assert_eq(MapGlyph.shake_offset_at(edge, soft), soft[index], "on step %d" % index)

## The soft shake keeps the lock shake's rhythm and direction at no more than half
## its travel, in whole even px (-2 where half of -6 would be the odd -3).
func test_soft_shake_is_the_lock_shake_at_half_the_travel_in_even_px() -> void:
	var soft: Array[int] = MapGlyph.SOFT_SHAKE_KEYFRAMES
	var lock: Array[int] = MapGlyph.SHAKE_KEYFRAMES
	assert_eq(soft.size(), lock.size(), "the same six keyframes: the same rhythm")
	for index: int in soft.size():
		assert_eq(soft[index] % 2, 0, "keyframe %d is an even number of px" % index)
		assert_lte(absi(soft[index]) * 2, absi(lock[index]), "keyframe %d goes no more than half as far as the lock shake's" % index)
		assert_eq(signi(soft[index]), signi(lock[index]), "keyframe %d goes the same way" % index)
	assert_eq(soft.max() * 2, lock.max(), "the reach to the right is half: 4 px against 8")
	assert_eq(soft.min() * 2, lock.min(), "and to the left")

## A shake's owner stops it at SHAKE_SECONDS (TechniqueSlot does), so that must be
## the end of either set: one step per keyframe after the first, home at both ends.
func test_shake_seconds_ends_both_sets() -> void:
	for keyframes: Array[int] in [MapGlyph.SHAKE_KEYFRAMES, MapGlyph.SOFT_SHAKE_KEYFRAMES]:
		assert_almost_eq(MapGlyph.SHAKE_SECONDS, MapGlyph.SHAKE_STEP_SECONDS * (keyframes.size() - 1), 0.000001, "one step per keyframe after the first")
		assert_eq(keyframes[0], 0, "it starts at home")
		assert_eq(keyframes[keyframes.size() - 1], 0, "and ends at home")
		assert_eq(MapGlyph.shake_offset_at(MapGlyph.SHAKE_SECONDS, keyframes), 0, "home when SHAKE_SECONDS is up")

## At no moment, sampled every 5 ms from before the shake to long after it, does
## a soft shake leave 4 px or stand on an odd px.
func test_soft_shake_stays_within_4_even_px_at_every_moment() -> void:
	var outside: Array[int] = []
	for milliseconds: int in range(-100, 1001, 5):
		var offset: int = MapGlyph.shake_offset_at(milliseconds / 1000.0, MapGlyph.SOFT_SHAKE_KEYFRAMES)
		if absi(offset) > 4 or offset % 2 != 0:
			outside.append(milliseconds)
	assert_eq(outside, [] as Array[int], "milliseconds into the shake that are past 4 px or on an odd px")

#-----------------------------------------------------------------------------
# THE DEFAULT
#-----------------------------------------------------------------------------

## With no keyframes given, shake_offset_at() steps the lock shake, as it did before
## the soft set existed: the shakes that do not ask for the soft one keep their numbers.
func test_the_lock_shake_is_the_default() -> void:
	for tenths: int in range(-1, 12):
		var elapsed: float = tenths / 10.0
		assert_eq(MapGlyph.shake_offset_at(elapsed), MapGlyph.shake_offset_at(elapsed, MapGlyph.SHAKE_KEYFRAMES), "%.1f s" % elapsed)
	assert_eq(MapGlyph.shake_offset_at(0.1), -8, "the lock shake's first step, not the soft one's -4")
