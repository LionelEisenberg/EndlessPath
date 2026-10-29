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
# BASE DAMAGE AND ATTRIBUTE SCALING
#-----------------------------------------------------------------------------

func test_base_damage_null_caster() -> void:
	var value = _effect.calculate_value(null)
	assert_eq(value, 50.0, "null caster should return base_value")

## calculate_value() is base_value plus each attribute times its scaling: no
## scaling, a zero base, each of the eight attributes on its own (caster at 10
## in everything), two scalings together, and a high attribute.
func test_value_adds_each_attribute_times_its_scaling() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no scaling", "base": 50.0, "scaling": {}, "expected": 50.0},
		{"name": "zero base", "base": 0.0, "scaling": {}, "expected": 0.0},
		{"name": "strength", "base": 50.0, "scaling": {"strength_scaling": 1.5}, "expected": 65.0},
		{"name": "body", "base": 50.0, "scaling": {"body_scaling": 2.0}, "expected": 70.0},
		{"name": "agility", "base": 50.0, "scaling": {"agility_scaling": 0.5}, "expected": 55.0},
		{"name": "spirit", "base": 50.0, "scaling": {"spirit_scaling": 3.0}, "expected": 80.0},
		{"name": "foundation", "base": 50.0, "scaling": {"foundation_scaling": 1.0}, "expected": 60.0},
		{"name": "control", "base": 50.0, "scaling": {"control_scaling": 0.8}, "expected": 58.0},
		{"name": "resilience", "base": 50.0, "scaling": {"resilience_scaling": 1.2}, "expected": 62.0},
		{"name": "willpower", "base": 50.0, "scaling": {"willpower_scaling": 0.3}, "expected": 53.0},
		# 50 + (10*1) + (10*2) = 80: multiple scalings add together
		{"name": "strength and spirit", "base": 50.0, "scaling": {"strength_scaling": 1.0, "spirit_scaling": 2.0}, "expected": 80.0},
		# 50 + (50 * 1.0) = 100: high attributes multiply with scaling
		{"name": "strength at 50", "base": 50.0, "scaling": {"strength_scaling": 1.0}, "expected": 100.0,
			"caster": CharacterAttributesData.new(50.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)},
	]
	for case: Dictionary in cases:
		var effect := CombatEffectData.new()
		effect.base_value = case.base
		for property: String in case.scaling:
			effect.set(property, case.scaling[property])
		var caster: CharacterAttributesData = case.get("caster", _caster)
		assert_eq(effect.calculate_value(caster), case.expected, "%s scaling" % case.name)

#-----------------------------------------------------------------------------
# DEFENSE
#-----------------------------------------------------------------------------

## calculate_damage() reduces the value by 100 / (100 + defense), the defense
## picked by damage type: Physical reads Resilience, Spirit reads Spirit, Mixed
## averages Resilience and Willpower, True ignores defense. Zero defense is
## full damage and 100 halves it.
func test_damage_type_picks_its_defense() -> void:
	var cases: Array[Dictionary] = [
		{"name": "physical, resilience 10", "type": CombatEffectData.DamageType.PHYSICAL,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0), "expected": 50.0 * (100.0 / 110.0)},
		{"name": "physical, resilience 100 halves", "type": CombatEffectData.DamageType.PHYSICAL,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0, 10.0), "expected": 25.0},
		{"name": "physical, resilience 0 is full damage", "type": CombatEffectData.DamageType.PHYSICAL,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 0.0, 10.0), "expected": 50.0},
		{"name": "spirit, spirit 10", "type": CombatEffectData.DamageType.SPIRIT,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0), "expected": 50.0 * (100.0 / 110.0)},
		{"name": "spirit, spirit 200", "type": CombatEffectData.DamageType.SPIRIT,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 200.0, 10.0, 10.0, 10.0, 10.0), "expected": 50.0 * (100.0 / 300.0)},
		{"name": "mixed, resilience 10 and willpower 10", "type": CombatEffectData.DamageType.MIXED,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0), "expected": 50.0 * (100.0 / 110.0)},
		# (20 + 40) / 2 = 30
		{"name": "mixed, resilience 20 and willpower 40", "type": CombatEffectData.DamageType.MIXED,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 20.0, 40.0), "expected": 50.0 * (100.0 / 130.0)},
		{"name": "true, resilience and willpower 100", "type": CombatEffectData.DamageType.TRUE,
			"target": CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0, 100.0), "expected": 50.0},
	]
	for case: Dictionary in cases:
		_effect.damage_type = case.type
		assert_almost_eq(_effect.calculate_damage(_caster, case.target), case.expected, 0.01, case.name)

func test_true_damage_with_scaling() -> void:
	_effect.damage_type = CombatEffectData.DamageType.TRUE
	_effect.strength_scaling = 1.0
	var damage = _effect.calculate_damage(_caster, _target)
	assert_eq(damage, 60.0, "true damage should still apply scaling, just skip defense")

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
# The ability .tres files store effect_type and damage_type as these ints, so
# renumbering either enum would change what every shipped ability does.

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
