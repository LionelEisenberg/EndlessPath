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

func test_sweep_step_counts_24_steps() -> void:
	assert_eq(TechniqueSlot.SWEEP_STEPS, 24)
	assert_eq(TechniqueSlot.sweep_step(3.0, 3.0), 0, "a cooldown that just started shows no step recharged")
	assert_eq(TechniqueSlot.sweep_step(1.5, 3.0), 12, "half way: half the steps")
	assert_eq(TechniqueSlot.sweep_step(0.01, 3.0), 23, "a sliver left still shows the last step veiled")
	assert_eq(TechniqueSlot.sweep_step(0.0, 3.0), 24, "nothing left: the plain icon")
	assert_eq(TechniqueSlot.sweep_step(1.0, 0.0), 24, "a cooldown of no length: the plain icon")

## A step only counts once it is whole, even where floating point lands a
## hair short of it (the 1e-6 bias), and the count never leaves 0 to 24.
func test_sweep_step_floors_and_stays_in_range() -> void:
	assert_eq(TechniqueSlot.sweep_step(2.0, 3.0), 8, "one third recharged: 8 of 24")
	assert_eq(TechniqueSlot.sweep_step(2.9, 3.0), 0, "under one step recharged: still 0")
	assert_eq(TechniqueSlot.sweep_step(2.875, 3.0), 1, "one step recharged exactly")
	assert_eq(TechniqueSlot.sweep_step(0.7, 0.7), 0)
	assert_eq(TechniqueSlot.sweep_step(4.0, 3.0), 0, "more time left than the cooldown: none recharged")
	assert_eq(TechniqueSlot.sweep_step(-0.5, 3.0), 24, "past the end: the plain icon")
	assert_eq(TechniqueSlot.sweep_step(1.0, -2.0), 24, "a negative cooldown: the plain icon")
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

func test_seconds_round_up() -> void:
	assert_eq(TechniqueSlot.seconds_text(2.1), "3", "part of a third second still reads 3")
	assert_eq(TechniqueSlot.seconds_text(3.0), "3", "a whole number stays as it is")
	assert_eq(TechniqueSlot.seconds_text(0.0), "", "nothing left: no number")

func test_seconds_of_a_sliver_and_past_the_end() -> void:
	assert_eq(TechniqueSlot.seconds_text(0.04), "1", "a sliver left reads 1, never 0")
	assert_eq(TechniqueSlot.seconds_text(1.5), "2", "the 1.5 s every fight starts on reads 2")
	assert_eq(TechniqueSlot.seconds_text(14.9), "15")
	assert_eq(TechniqueSlot.seconds_text(-0.2), "", "past the end: no number")

#-----------------------------------------------------------------------------
# THE DAMAGE LINE
#-----------------------------------------------------------------------------

func test_format_damage() -> void:
	var attributes := CharacterAttributesData.new(13.0, 10.0, 7.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	var amount: int = roundi((BASIC_STRIKE.effects_on_target[0] as CombatEffectData).calculate_value(attributes))
	assert_eq(amount, 27, "precondition: 10 + 13 x 1 + 7 x 0.5 = 26.5, rounded")
	assert_eq(AbilityRow.format_damage(BASIC_STRIKE, attributes), "about %d Physical damage" % amount)
	assert_eq(AbilityRow.format_damage(ENFORCE, attributes), "", "a self-buff deals no damage")

func test_format_damage_names_the_damage_type() -> void:
	var attributes := CharacterAttributesData.new()
	var palm_amount: int = roundi((EMPTY_PALM.effects_on_target[0] as CombatEffectData).calculate_value(attributes))
	assert_eq(AbilityRow.format_damage(EMPTY_PALM, attributes), "about %d Spirit damage" % palm_amount)
	assert_eq(AbilityRow.format_damage(_ability_with(_damage(12.0, CombatEffectData.DamageType.TRUE)), attributes), "about 12 True damage")
	assert_eq(AbilityRow.format_damage(_ability_with(_damage(8.4, CombatEffectData.DamageType.MIXED)), attributes), "about 8 Mixed damage")
	assert_eq(AbilityRow.format_damage(_ability_with(_damage(8.5, CombatEffectData.DamageType.PHYSICAL)), attributes), "about 9 Physical damage", "a half rounds up")

## Only the first effect on the target counts, and only when it is damage.
func test_format_damage_reads_the_first_target_effect_only() -> void:
	var attributes := CharacterAttributesData.new()
	var interrupt := CombatEffectData.new()
	interrupt.effect_type = CombatEffectData.EffectType.CANCEL_CAST
	var interrupt_first: AbilityData = _ability_with(interrupt)
	interrupt_first.effects_on_target.append(_damage(20.0, CombatEffectData.DamageType.PHYSICAL))
	assert_eq(AbilityRow.format_damage(interrupt_first, attributes), "", "an interrupt first: no damage line")
	assert_eq(AbilityRow.format_damage(AbilityData.new(), attributes), "", "no effect at all: no damage line")
