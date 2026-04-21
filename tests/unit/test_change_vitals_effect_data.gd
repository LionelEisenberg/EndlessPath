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
	attrs.attributes[AttributeType.BODY] = body
	attrs.attributes[AttributeType.FOUNDATION] = foundation

func test_flat_values_with_zero_multipliers() -> void:
	_set_attrs(10.0, 10.0)
	_effect.health_change = 5.0
	_effect.madra_change = 3.0
	_effect.stamina_change = 2.0
	_effect.body_hp_multiplier = 0.0
	_effect.foundation_madra_multiplier = 0.0

	assert_eq(_effect.get_final_health_change(), 5.0)
	assert_eq(_effect.get_final_madra_change(), 3.0)
	assert_eq(_effect.get_final_stamina_change(), 2.0)

func test_body_multiplier_scales_health() -> void:
	_set_attrs(10.0, 0.0)
	_effect.health_change = 0.0
	_effect.body_hp_multiplier = 5.0

	# 0 flat + 5 * BODY(10) = 50
	assert_eq(_effect.get_final_health_change(), 50.0)

func test_foundation_multiplier_scales_madra() -> void:
	_set_attrs(0.0, 10.0)
	_effect.madra_change = 0.0
	_effect.foundation_madra_multiplier = 2.0

	# 0 flat + 2 * FOUNDATION(10) = 20
	assert_eq(_effect.get_final_madra_change(), 20.0)

func test_flat_and_multiplier_combine() -> void:
	_set_attrs(4.0, 3.0)
	_effect.health_change = 2.0
	_effect.madra_change = 1.0
	_effect.body_hp_multiplier = 5.0
	_effect.foundation_madra_multiplier = 2.0

	# health: 2 + 5*4 = 22
	# madra:  1 + 2*3 = 7
	assert_eq(_effect.get_final_health_change(), 22.0)
	assert_eq(_effect.get_final_madra_change(), 7.0)

func test_stamina_is_never_scaled() -> void:
	_set_attrs(100.0, 100.0)
	_effect.stamina_change = 3.0
	assert_eq(_effect.get_final_stamina_change(), 3.0)

func test_multipliers_default_to_zero() -> void:
	assert_eq(_effect.body_hp_multiplier, 0.0)
	assert_eq(_effect.foundation_madra_multiplier, 0.0)
