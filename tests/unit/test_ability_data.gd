extends GutTest

## AbilityData's Madra cost and cooldown under Control's cuts. Stamina and
## Health costs are never cut.

## The Madra a cast costs after a cut, rounded to whole Madra (a half rounds up).
func test_madra_cost_is_cut_and_rounded() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cut", "cost": 10.0, "cut": 0.0, "paid": 10.0},
		{"name": "a quarter off 8 Madra", "cost": 8.0, "cut": 0.25, "paid": 6.0},
		{"name": "a half rounds up: 10 less a quarter is 7.5, paid as 8", "cost": 10.0, "cut": 0.25, "paid": 8.0},
		{"name": "under a half rounds down: 29.28 is paid as 29", "cost": 30.0, "cut": 0.024, "paid": 29.0},
		{"name": "a free technique stays free", "cost": 0.0, "cut": 0.25, "paid": 0.0},
	]
	for case: Dictionary in cases:
		var ability := AbilityData.new()
		ability.madra_cost = case["cost"]
		assert_eq(ability.get_madra_cost(case["cut"]), case["paid"], case["name"])

## The cooldown after a cut, not rounded. A technique with no cooldown keeps none.
func test_cooldown_is_cut() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cut", "cooldown": 2.0, "cut": 0.0, "expected": 2.0},
		{"name": "a fifth off 2 s", "cooldown": 2.0, "cut": 0.2, "expected": 1.6},
		{"name": "a fifth off 15 s", "cooldown": 15.0, "cut": 0.2, "expected": 12.0},
		{"name": "no cooldown stays none", "cooldown": 0.0, "cut": 0.2, "expected": 0.0},
	]
	for case: Dictionary in cases:
		var ability := AbilityData.new()
		ability.base_cooldown = case["cooldown"]
		assert_almost_eq(ability.get_cooldown(case["cut"]), case["expected"], 0.0001, case["name"])

## The check and the payment use the cut Madra cost; Stamina is paid in full.
func test_costs_are_checked_and_paid_after_the_cut() -> void:
	var ability := AbilityData.new()
	ability.madra_cost = 8.0
	ability.stamina_cost = 3.0
	var vitals := VitalsManager.new()
	add_child_autofree(vitals)
	vitals.current_madra = 6.0
	vitals.current_stamina = 3.0
	assert_false(ability.can_afford(vitals), "6 Madra can't pay the full 8")
	assert_true(ability.can_afford(vitals, 0.25), "but can pay 8 cut by a quarter")
	assert_true(ability.consume_costs(vitals, 0.25), "the payment goes through")
	assert_eq(vitals.current_madra, 0.0, "6 Madra paid, not 8")
	assert_eq(vitals.current_stamina, 0.0, "the Stamina cost is paid in full")
