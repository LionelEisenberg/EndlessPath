extends GutTest

## Regression test: locks in the field values on the shipped
## Crude Scale .tres so future inspector edits are intentional.

const SCALE_PATH := "res://resources/items/consumables/crude_scale.tres"

var _def: ConsumableDefinitionData

func before_each() -> void:
	_def = load(SCALE_PATH)

func test_tres_loads_as_consumable_definition_data() -> void:
	assert_not_null(_def, "crude_scale.tres should load")
	assert_true(_def is ConsumableDefinitionData,
		"loaded resource should be a ConsumableDefinitionData")

func test_item_identity_fields() -> void:
	assert_eq(_def.item_id, "crude_scale", "item_id locked")
	assert_eq(_def.item_name, "Crude Scale", "item_name locked")
	assert_eq(_def.item_type, ItemDefinitionData.ItemType.CONSUMABLE, "item_type locked")

func test_icon_is_assigned() -> void:
	assert_not_null(_def.icon, "icon should be wired up")
	assert_true(_def.icon is Texture2D, "icon should be a Texture2D")

func test_cooldown_seconds_locked() -> void:
	assert_eq(_def.cooldown_seconds, 10.0, "cooldown_seconds locked at 10.0")

func test_effects_array_has_one_change_vitals_effect() -> void:
	assert_eq(_def.effects.size(), 1, "should have exactly one effect")
	var effect = _def.effects[0]
	assert_true(effect is ChangeVitalsEffectData,
		"effect should be a ChangeVitalsEffectData")

func test_effect_grants_twenty_madra_only() -> void:
	var effect: ChangeVitalsEffectData = _def.effects[0]
	assert_eq(effect.madra_change, 20.0, "madra_change locked at 20.0")
	assert_eq(effect.health_change, 0.0, "health_change should be 0")
	assert_eq(effect.stamina_change, 0.0, "stamina_change should be 0")
	assert_eq(effect.body_hp_multiplier, 0.0, "body_hp_multiplier should be 0")
	assert_eq(effect.foundation_madra_multiplier, 0.0, "foundation_madra_multiplier should be 0")
