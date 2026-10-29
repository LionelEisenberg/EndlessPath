extends GutTest

## The pure rules behind the technique dock: how many of the cooldown sweep's
## 24 steps a slot shows for the time left (TechniqueSlot.sweep_step()), the
## whole seconds in its centre (TechniqueSlot.seconds_text()), and the damage
## line its tooltip reads (AbilityRow.format_damage()). The dock and its tests
## ask these statics, so the numbers here are the numbers a slot shows.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")
const EMPTY_PALM: AbilityData = preload("res://resources/abilities/empty_palm.tres")
const ENFORCE: AbilityData = preload("res://resources/abilities/enforce.tres")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## An ability whose only effect on its target is `effect`.
func _ability_with(effect: CombatEffectData) -> AbilityData:
	var ability := AbilityData.new()
	ability.ability_id = "test_technique"
	ability.ability_name = "Test Technique"
	var effects: Array[CombatEffectData] = [effect]
	ability.effects_on_target = effects
	return ability

func _damage(base_value: float, damage_type: CombatEffectData.DamageType) -> CombatEffectData:
	var effect := CombatEffectData.new()
	effect.effect_type = CombatEffectData.EffectType.DAMAGE
	effect.base_value = base_value
	effect.damage_type = damage_type
	return effect

#-----------------------------------------------------------------------------
# THE SWEEP
#-----------------------------------------------------------------------------

## The steps recharged for the time left of a cooldown, out of 24. A step only
## counts once it is whole, even where floating point lands a hair short of it
## (the 1e-6 bias). More time left than the cooldown shows none; no time left, a
## time past the end and a cooldown of no length or below show the plain icon.
## The count never leaves 0 to 24.
func test_sweep_step_counts_24_steps() -> void:
	assert_eq(TechniqueSlot.SWEEP_STEPS, 24)
	var cases: Array[Dictionary] = [
		{"name": "a cooldown that just started shows no step recharged", "left": 3.0, "cooldown": 3.0, "step": 0},
		{"name": "half way: half the steps", "left": 1.5, "cooldown": 3.0, "step": 12},
		{"name": "a sliver left still shows the last step veiled", "left": 0.01, "cooldown": 3.0, "step": 23},
		{"name": "nothing left: the plain icon", "left": 0.0, "cooldown": 3.0, "step": 24},
		{"name": "a cooldown of no length: the plain icon", "left": 1.0, "cooldown": 0.0, "step": 24},
		{"name": "one third recharged: 8 of 24", "left": 2.0, "cooldown": 3.0, "step": 8},
		{"name": "under one step recharged: still 0", "left": 2.9, "cooldown": 3.0, "step": 0},
		{"name": "one step recharged exactly", "left": 2.875, "cooldown": 3.0, "step": 1},
		{"name": "a 0.7 s cooldown that just started", "left": 0.7, "cooldown": 0.7, "step": 0},
		{"name": "more time left than the cooldown: none recharged", "left": 4.0, "cooldown": 3.0, "step": 0},
		{"name": "past the end: the plain icon", "left": -0.5, "cooldown": 3.0, "step": 24},
		{"name": "a negative cooldown: the plain icon", "left": 1.0, "cooldown": -2.0, "step": 24},
	]
	for case: Dictionary in cases:
		assert_eq(TechniqueSlot.sweep_step(case["left"], case["cooldown"]), case["step"], case["name"])
	for tenths: int in range(0, 31):
		var step: int = TechniqueSlot.sweep_step(tenths / 10.0, 3.0)
		assert_between(step, 0, TechniqueSlot.SWEEP_STEPS, "%.1f s left of 3 s" % (tenths / 10.0))

## Every step from 0 to 24 is reached as the time runs down: the sweep never
## skips a step of a 24-step cooldown sampled once a step.
func test_sweep_step_reaches_every_step() -> void:
	var seen: Array[int] = []
	for k: int in range(0, TechniqueSlot.SWEEP_STEPS + 1):
		seen.append(TechniqueSlot.sweep_step(24.0 - k, 24.0))
	var expected: Array[int] = []
	for k: int in range(0, TechniqueSlot.SWEEP_STEPS + 1):
		expected.append(k)
	assert_eq(seen, expected)

#-----------------------------------------------------------------------------
# THE SECONDS
#-----------------------------------------------------------------------------

## The whole seconds left, rounded up, so a sliver reads 1 and never 0; nothing
## left, or a time past the end, shows no number.
func test_seconds_round_up() -> void:
	var cases: Array[Dictionary] = [
		{"name": "part of a third second still reads 3", "left": 2.1, "text": "3"},
		{"name": "a whole number stays as it is", "left": 3.0, "text": "3"},
		{"name": "nothing left: no number", "left": 0.0, "text": ""},
		{"name": "a sliver left reads 1, never 0", "left": 0.04, "text": "1"},
		{"name": "the 1.5 s every fight starts on reads 2", "left": 1.5, "text": "2"},
		{"name": "14.9 s reads 15", "left": 14.9, "text": "15"},
		{"name": "past the end: no number", "left": -0.2, "text": ""},
	]
	for case: Dictionary in cases:
		assert_eq(TechniqueSlot.seconds_text(case["left"]), case["text"], case["name"])

#-----------------------------------------------------------------------------
# THE DAMAGE LINE
#-----------------------------------------------------------------------------

## The line gives the damage of the first effect on the target for the
## attributes, rounded (a half rounds up), and names its damage type.
func test_format_damage() -> void:
	var strong := CharacterAttributesData.new(13.0, 10.0, 7.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	var plain := CharacterAttributesData.new()
	var amount: int = roundi((BASIC_STRIKE.effects_on_target[0] as CombatEffectData).calculate_value(strong))
	assert_eq(amount, 27, "precondition: 10 + 13 x 1 + 7 x 0.5 = 26.5, rounded")
	var palm_amount: int = roundi((EMPTY_PALM.effects_on_target[0] as CombatEffectData).calculate_value(plain))
	var cases: Array[Dictionary] = [
		{"name": "Basic Strike: Physical", "ability": BASIC_STRIKE, "attributes": strong, "line": "about %d Physical damage" % amount},
		{"name": "Empty Palm: Spirit", "ability": EMPTY_PALM, "attributes": plain, "line": "about %d Spirit damage" % palm_amount},
		{"name": "True", "ability": _ability_with(_damage(12.0, CombatEffectData.DamageType.TRUE)), "attributes": plain, "line": "about 12 True damage"},
		{"name": "Mixed", "ability": _ability_with(_damage(8.4, CombatEffectData.DamageType.MIXED)), "attributes": plain, "line": "about 8 Mixed damage"},
		{"name": "a half rounds up", "ability": _ability_with(_damage(8.5, CombatEffectData.DamageType.PHYSICAL)), "attributes": plain, "line": "about 9 Physical damage"},
	]
	for case: Dictionary in cases:
		assert_eq(AbilityRow.format_damage(case["ability"], case["attributes"]), case["line"], case["name"])
	assert_eq(AbilityRow.format_damage(ENFORCE, strong), "", "a self-buff deals no damage")

## Only the first effect on the target counts, and only when it is damage.
func test_format_damage_reads_the_first_target_effect_only() -> void:
	var attributes := CharacterAttributesData.new()
	var interrupt := CombatEffectData.new()
	interrupt.effect_type = CombatEffectData.EffectType.CANCEL_CAST
	var interrupt_first: AbilityData = _ability_with(interrupt)
	interrupt_first.effects_on_target.append(_damage(20.0, CombatEffectData.DamageType.PHYSICAL))
	assert_eq(AbilityRow.format_damage(interrupt_first, attributes), "", "an interrupt first: no damage line")
	assert_eq(AbilityRow.format_damage(AbilityData.new(), attributes), "", "no effect at all: no damage line")
