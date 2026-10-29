extends GutTest

## Tests the pure-function getters on ChangeVitalsEffectData that compute
## final health/madra/stamina changes, including attribute-scaled contributions.
## Getters are used by process() when applying vitals changes — this avoids
## requiring a live VitalsManager in unit tests.

const AttributeType = CharacterAttributesData.AttributeType

var _effect: ChangeVitalsEffectData
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_effect = ChangeVitalsEffectData.new()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## Overwrites base attributes directly so `CharacterManager.get_total_attributes_data()`
## (which rebuilds from live_save_data + bonuses each call) reads these values.
func _set_attrs(body: float, foundation: float) -> void:
	var attrs: CharacterAttributesData = PersistenceManager.save_game_data.character_attributes
	attrs.body = body
	attrs.foundation = foundation

## Each final change is its flat value plus its multiplier x the attribute:
## Health scales with Body, Madra with Foundation, and Stamina never scales.
## The cases cover flat values with zero multipliers, each multiplier alone,
## flat and multiplier together, and Stamina at Body and Foundation 100.
func test_final_changes_are_flat_plus_scaled_attribute() -> void:
	var cases: Array[Dictionary] = [
		{"name": "flat values with zero multipliers", "body": 10.0, "foundation": 10.0,
			"flat": [5.0, 3.0, 2.0], "body_mult": 0.0, "foundation_mult": 0.0, "final": [5.0, 3.0, 2.0]},
		{"name": "0 flat + 5 x Body 10", "body": 10.0, "foundation": 0.0,
			"flat": [0.0, 0.0, 0.0], "body_mult": 5.0, "foundation_mult": 0.0, "final": [50.0, 0.0, 0.0]},
		{"name": "0 flat + 2 x Foundation 10", "body": 0.0, "foundation": 10.0,
			"flat": [0.0, 0.0, 0.0], "body_mult": 0.0, "foundation_mult": 2.0, "final": [0.0, 20.0, 0.0]},
		{"name": "2 + 5 x Body 4 and 1 + 2 x Foundation 3", "body": 4.0, "foundation": 3.0,
			"flat": [2.0, 1.0, 0.0], "body_mult": 5.0, "foundation_mult": 2.0, "final": [22.0, 7.0, 0.0]},
		{"name": "Stamina is never scaled", "body": 100.0, "foundation": 100.0,
			"flat": [0.0, 0.0, 3.0], "body_mult": 0.0, "foundation_mult": 0.0, "final": [0.0, 0.0, 3.0]},
	]
	for case: Dictionary in cases:
		_set_attrs(case.body, case.foundation)
		var effect := ChangeVitalsEffectData.new()
		effect.health_change = case.flat[0]
		effect.madra_change = case.flat[1]
		effect.stamina_change = case.flat[2]
		effect.body_hp_multiplier = case.body_mult
		effect.foundation_madra_multiplier = case.foundation_mult
		assert_eq(effect.get_final_health_change(), case.final[0], "%s: Health" % case.name)
		assert_eq(effect.get_final_madra_change(), case.final[1], "%s: Madra" % case.name)
		assert_eq(effect.get_final_stamina_change(), case.final[2], "%s: Stamina" % case.name)

func test_multipliers_default_to_zero() -> void:
	assert_eq(_effect.body_hp_multiplier, 0.0)
	assert_eq(_effect.foundation_madra_multiplier, 0.0)
