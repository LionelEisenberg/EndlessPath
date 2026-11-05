extends GutTest

## Tests the pure-function getters on ChangeVitalsEffectData that compute
## final health/madra/stamina changes, including attribute-scaled contributions.
## Getters are used by process() when applying vitals changes — this avoids
## requiring a live VitalsManager in unit tests.

const AttributeType = CharacterAttributesData.AttributeType

## The modifier source _set_totals() sets; after_each() removes it.
const TEST_SOURCE: StringName = &"test"

var _effect: ChangeVitalsEffectData
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_effect = ChangeVitalsEffectData.new()

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## Moves the total Body and Mind to these values with flat modifiers over their
## Lv 1 values, so `CharacterManager.get_total_attributes_data()` (rebuilt from
## the trained levels and the modifier sources each call) reads them.
func _set_totals(body: float, mind: float) -> void:
	var modifiers: Array[StatModifierData] = [
		StatModifierData.new(StatModifierData.Stat.BODY, StatModifierData.Kind.FLAT, body - CharacterAttributesData.STAT_BASELINE),
		StatModifierData.new(StatModifierData.Stat.MIND, StatModifierData.Kind.FLAT, mind - CharacterAttributesData.STAT_BASELINE),
	]
	CharacterManager.set_modifier_source(TEST_SOURCE, func() -> Array[StatModifierData]: return modifiers)

## Each final change is its flat value plus its multiplier x the attribute:
## Health scales with Body, Madra with Mind, and Stamina never scales.
## The cases cover flat values with zero multipliers, each multiplier alone,
## flat and multiplier together, and Stamina at Body and Mind 100.
func test_final_changes_are_flat_plus_scaled_attribute() -> void:
	var cases: Array[Dictionary] = [
		{"name": "flat values with zero multipliers", "body": 10.0, "mind": 10.0,
			"flat": [5.0, 3.0, 2.0], "body_mult": 0.0, "mind_mult": 0.0, "final": [5.0, 3.0, 2.0]},
		{"name": "0 flat + 5 x Body 10", "body": 10.0, "mind": 0.0,
			"flat": [0.0, 0.0, 0.0], "body_mult": 5.0, "mind_mult": 0.0, "final": [50.0, 0.0, 0.0]},
		{"name": "0 flat + 2 x Mind 10", "body": 0.0, "mind": 10.0,
			"flat": [0.0, 0.0, 0.0], "body_mult": 0.0, "mind_mult": 2.0, "final": [0.0, 20.0, 0.0]},
		{"name": "2 + 5 x Body 4 and 1 + 2 x Mind 3", "body": 4.0, "mind": 3.0,
			"flat": [2.0, 1.0, 0.0], "body_mult": 5.0, "mind_mult": 2.0, "final": [22.0, 7.0, 0.0]},
		{"name": "Stamina is never scaled", "body": 100.0, "mind": 100.0,
			"flat": [0.0, 0.0, 3.0], "body_mult": 0.0, "mind_mult": 0.0, "final": [0.0, 0.0, 3.0]},
	]
	for case: Dictionary in cases:
		_set_totals(case.body, case.mind)
		var effect := ChangeVitalsEffectData.new()
		effect.health_change = case.flat[0]
		effect.madra_change = case.flat[1]
		effect.stamina_change = case.flat[2]
		effect.body_hp_multiplier = case.body_mult
		effect.mind_madra_multiplier = case.mind_mult
		assert_eq(effect.get_final_health_change(), case.final[0], "%s: Health" % case.name)
		assert_eq(effect.get_final_madra_change(), case.final[1], "%s: Madra" % case.name)
		assert_eq(effect.get_final_stamina_change(), case.final[2], "%s: Stamina" % case.name)

func test_multipliers_default_to_zero() -> void:
	assert_eq(_effect.body_hp_multiplier, 0.0)
	assert_eq(_effect.mind_madra_multiplier, 0.0)
