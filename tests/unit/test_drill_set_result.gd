extends GutTest

## Unit tests for DrillSetResult's bead order: the tiers of a set's reps read in
## the order of the beads they lit, which is not the order they were judged in
## when a drill judges out of turn (Falling Leaf's leaves). The Last set card shows
## them so.

const Tier = DrillRules.Tier

func test_the_tiers_read_in_bead_order() -> void:
	var result := DrillSetResult.new()
	for rep: Array in [[Tier.PERFECT, 0], [Tier.OK, 2], [Tier.GOOD, 1], [Tier.MISS, 3]]:
		result.add_rep(rep[0], 1.0)
		result.place_last_rep(rep[1])
	assert_eq(result.get_bead_tiers(), [Tier.PERFECT, Tier.GOOD, Tier.OK, Tier.MISS] as Array[Tier])

## A rep never placed on a bead keeps the order it was judged in.
func test_reps_never_placed_read_in_the_order_judged() -> void:
	var result := DrillSetResult.new()
	result.add_rep(Tier.GOOD, 1.0)
	result.add_rep(Tier.PERFECT, 1.0)
	assert_eq(result.get_bead_tiers(), [Tier.GOOD, Tier.PERFECT] as Array[Tier])
