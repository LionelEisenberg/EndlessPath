extends GutTest

## Unit tests for CombatEffectData damage calculations
## Tests base damage, attribute scaling, defense types, and reduction formula

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _effect: CombatEffectData
var _caster: CharacterAttributesData
var _target: CharacterAttributesData

func before_each() -> void:
	_effect = CombatEffectData.new()
	_effect.effect_type = CombatEffectData.EffectType.DAMAGE
	_effect.effect_name = "Test Attack"
	_effect.base_value = 50.0
	_effect.damage_type = CombatEffectData.DamageType.PHYSICAL

	_caster = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

#-----------------------------------------------------------------------------
# BASE DAMAGE CALCULATION
#-----------------------------------------------------------------------------

func test_base_damage_no_scaling() -> void:
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 50.0, "base damage with no scaling should equal base_value")

func test_base_damage_null_caster() -> void:
	var value = _effect.calculate_value(null)
	assert_eq(value, 50.0, "null caster should return base_value")

func test_base_damage_zero() -> void:
	_effect.base_value = 0.0
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 0.0, "zero base should give zero damage")

#-----------------------------------------------------------------------------
# ATTRIBUTE SCALING
#-----------------------------------------------------------------------------

func test_strength_scaling() -> void:
	_effect.strength_scaling = 1.5
	# Expected: 50 + (10 * 1.5) = 65
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 65.0, "damage should include strength scaling")

func test_body_scaling() -> void:
	_effect.body_scaling = 2.0
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 70.0, "damage should include body scaling")

func test_agility_scaling() -> void:
	_effect.agility_scaling = 0.5
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 55.0, "damage should include agility scaling")

func test_spirit_scaling() -> void:
	_effect.spirit_scaling = 3.0
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 80.0, "damage should include spirit scaling")

func test_foundation_scaling() -> void:
	_effect.foundation_scaling = 1.0
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 60.0, "damage should include foundation scaling")

func test_control_scaling() -> void:
	_effect.control_scaling = 0.8
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 58.0, "damage should include control scaling")

func test_resilience_scaling() -> void:
	_effect.resilience_scaling = 1.2
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 62.0, "damage should include resilience scaling")

func test_willpower_scaling() -> void:
	_effect.willpower_scaling = 0.3
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 53.0, "damage should include willpower scaling")

func test_multiple_scaling_attributes() -> void:
	_effect.strength_scaling = 1.0
	_effect.spirit_scaling = 2.0
	# Expected: 50 + (10*1) + (10*2) = 50 + 10 + 20 = 80
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 80.0, "multiple scalings should add together")

func test_scaling_with_high_attributes() -> void:
	_caster = CharacterAttributesData.new(50.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_effect.strength_scaling = 1.0
	# Expected: 50 + (50 * 1.0) = 100
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 100.0, "high attributes should multiply with scaling")

func test_zero_scaling_no_contribution() -> void:
	_effect.strength_scaling = 0.0
	_effect.spirit_scaling = 0.0
	var value = _effect.calculate_value(_caster)
	assert_eq(value, 50.0, "zero scaling should not add damage")

#-----------------------------------------------------------------------------
# DEFENSE: PHYSICAL (Resilience)
#-----------------------------------------------------------------------------

func test_physical_damage_applies_resilience() -> void:
	_effect.damage_type = CombatEffectData.DamageType.PHYSICAL
	# Target resilience = 10, formula: 50 * (100 / (100 + 10)) = 50 * (100/110)
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 110.0)
	assert_almost_eq(damage, expected, 0.01, "physical damage should be reduced by resilience")

func test_physical_damage_high_resilience() -> void:
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0, 10.0)
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 200.0)  # = 25
	assert_almost_eq(damage, expected, 0.01, "high resilience should reduce damage significantly")

#-----------------------------------------------------------------------------
# DEFENSE: SPIRIT (Spirit)
#-----------------------------------------------------------------------------

func test_spirit_damage_applies_spirit_defense() -> void:
	_effect.damage_type = CombatEffectData.DamageType.SPIRIT
	# Target spirit = 10
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 110.0)
	assert_almost_eq(damage, expected, 0.01, "spirit damage should be reduced by spirit")

func test_spirit_damage_high_spirit_defense() -> void:
	_effect.damage_type = CombatEffectData.DamageType.SPIRIT
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 200.0, 10.0, 10.0, 10.0, 10.0)
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 300.0)
	assert_almost_eq(damage, expected, 0.01, "high spirit should heavily reduce spirit damage")

#-----------------------------------------------------------------------------
# DEFENSE: MIXED (Resilience + Willpower) / 2
#-----------------------------------------------------------------------------

func test_mixed_damage_uses_resilience_willpower_avg() -> void:
	_effect.damage_type = CombatEffectData.DamageType.MIXED
	# Target: resilience=10, willpower=10 -> avg=10
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 110.0)
	assert_almost_eq(damage, expected, 0.01, "mixed damage should use (resilience+willpower)/2")

func test_mixed_damage_asymmetric_stats() -> void:
	_effect.damage_type = CombatEffectData.DamageType.MIXED
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 20.0, 40.0)
	# (20 + 40) / 2 = 30
	var damage = _effect.calculate_damage(_caster, _target)
	var expected = 50.0 * (100.0 / 130.0)
	assert_almost_eq(damage, expected, 0.01, "mixed defense should average resilience and willpower")

#-----------------------------------------------------------------------------
# DEFENSE: TRUE (ignores all defense)
#-----------------------------------------------------------------------------

func test_true_damage_ignores_defense() -> void:
	_effect.damage_type = CombatEffectData.DamageType.TRUE
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0, 100.0)
	var damage = _effect.calculate_damage(_caster, _target)
	assert_eq(damage, 50.0, "true damage should ignore all defense")

func test_true_damage_with_scaling() -> void:
	_effect.damage_type = CombatEffectData.DamageType.TRUE
	_effect.strength_scaling = 1.0
	var damage = _effect.calculate_damage(_caster, _target)
	assert_eq(damage, 60.0, "true damage should still apply scaling, just skip defense")

#-----------------------------------------------------------------------------
# DAMAGE REDUCTION FORMULA
#-----------------------------------------------------------------------------

func test_zero_defense_full_damage() -> void:
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 0.0, 10.0)
	_effect.damage_type = CombatEffectData.DamageType.PHYSICAL
	var damage = _effect.calculate_damage(_caster, _target)
	# 100 / (100 + 0) = 1.0 -> full damage
	assert_eq(damage, 50.0, "zero defense should mean full damage")

func test_hundred_defense_halves_damage() -> void:
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0, 10.0)
	_effect.damage_type = CombatEffectData.DamageType.PHYSICAL
	var damage = _effect.calculate_damage(_caster, _target)
	# 100 / (100 + 100) = 0.5
	assert_almost_eq(damage, 25.0, 0.01, "100 defense should halve damage")

func test_high_defense_doesnt_go_negative() -> void:
	_target = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10000.0, 10.0)
	_effect.damage_type = CombatEffectData.DamageType.PHYSICAL
	var damage = _effect.calculate_damage(_caster, _target)
	assert_gt(damage, 0.0, "damage should never go negative even with extreme defense")

func test_null_target_no_defense() -> void:
	var damage = _effect.calculate_damage(_caster, null)
	assert_eq(damage, 50.0, "null target should apply no defense reduction")

#-----------------------------------------------------------------------------
# EFFECT TYPE GUARD
#-----------------------------------------------------------------------------

func test_calculate_damage_on_heal_returns_zero() -> void:
	_effect.effect_type = CombatEffectData.EffectType.HEAL
	var damage = _effect.calculate_damage(_caster, _target)
	assert_eq(damage, 0.0, "calculate_damage on non-damage effect should return 0")

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

func test_effect_type_enum_values() -> void:
	assert_eq(CombatEffectData.EffectType.DAMAGE, 0)
	assert_eq(CombatEffectData.EffectType.HEAL, 1)
	assert_eq(CombatEffectData.EffectType.BUFF, 2)
	assert_eq(CombatEffectData.EffectType.CANCEL_CAST, 3)
	assert_eq(CombatEffectData.EffectType.STRIP_BUFFS, 4)

func test_damage_type_enum_values() -> void:
	assert_eq(CombatEffectData.DamageType.PHYSICAL, 0)
	assert_eq(CombatEffectData.DamageType.SPIRIT, 1)
	assert_eq(CombatEffectData.DamageType.TRUE, 2)
	assert_eq(CombatEffectData.DamageType.MIXED, 3)
