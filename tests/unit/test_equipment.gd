extends GutTest

## Unit tests for EquipmentDefinitionData
## Tests slot enum, attribute bonuses, BBCode effects, and initialization

#-----------------------------------------------------------------------------
# EQUIPMENT SLOT ENUM
#-----------------------------------------------------------------------------

func test_equipment_slot_has_six_values() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.size(), 6, "should have exactly 6 equipment slots")

func test_equipment_slot_main_hand() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, 0)

func test_equipment_slot_off_hand() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.OFF_HAND, 1)

func test_equipment_slot_head() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.HEAD, 2)

func test_equipment_slot_armor() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.ARMOR, 3)

func test_equipment_slot_accessory_1() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.ACCESSORY_1, 4)

func test_equipment_slot_accessory_2() -> void:
	assert_eq(EquipmentDefinitionData.EquipmentSlot.ACCESSORY_2, 5)

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func test_init_sets_item_type_to_equipment() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.item_type, ItemDefinitionData.ItemType.EQUIPMENT, "_init should set item_type to EQUIPMENT")

func test_init_default_slot_is_main_hand() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.slot_type, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, "default slot should be MAIN_HAND")

func test_init_empty_bonuses() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_eq(equip.attribute_bonuses.size(), 0, "default bonuses should be empty")

#-----------------------------------------------------------------------------
# ATTRIBUTE BONUSES DICTIONARY
#-----------------------------------------------------------------------------

func test_attribute_bonuses_stores_values() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 5.0,
		CharacterAttributesData.AttributeType.AGILITY: 3.0
	}
	assert_eq(equip.attribute_bonuses[CharacterAttributesData.AttributeType.STRENGTH], 5.0)
	assert_eq(equip.attribute_bonuses[CharacterAttributesData.AttributeType.AGILITY], 3.0)

func test_attribute_bonuses_supports_all_types() -> void:
	var equip = EquipmentDefinitionData.new()
	for attr_type in CharacterAttributesData.AttributeType.values():
		equip.attribute_bonuses[attr_type] = float(attr_type) + 1.0
	assert_eq(equip.attribute_bonuses.size(), 8, "should support all 8 attribute types")

func test_attribute_bonuses_negative_values() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.AGILITY: -5.0}
	assert_eq(equip.attribute_bonuses[CharacterAttributesData.AttributeType.AGILITY], -5.0)

func test_attribute_bonuses_float_precision() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.SPIRIT: 2.5}
	assert_almost_eq(equip.attribute_bonuses[CharacterAttributesData.AttributeType.SPIRIT], 2.5, 0.001)

#-----------------------------------------------------------------------------
# _get_item_effects() BBCode FORMATTING
#-----------------------------------------------------------------------------

func test_get_item_effects_empty_bonuses() -> void:
	var equip = EquipmentDefinitionData.new()
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 0, "empty bonuses should return empty effects array")

func test_get_item_effects_positive_bonus() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.STRENGTH: 5.0}
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 1, "should have one effect for one bonus")
	assert_true(effects[0].contains("+5"), "positive bonus should show +value: %s" % effects[0])
	assert_true(effects[0].contains("Strength"), "effect should name the attribute: %s" % effects[0])
	assert_true(effects[0].contains("[color=#a89070]"), "should use color tag: %s" % effects[0])

func test_get_item_effects_negative_bonus() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.AGILITY: -3.0}
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 1)
	assert_true(effects[0].contains("-3"), "negative bonus should show negative value: %s" % effects[0])
	assert_true(effects[0].contains("Agility"), "should name the attribute: %s" % effects[0])
	assert_false(effects[0].contains("+"), "negative bonus should not have +: %s" % effects[0])

func test_get_item_effects_multiple_bonuses() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 5.0,
		CharacterAttributesData.AttributeType.BODY: 3.0,
		CharacterAttributesData.AttributeType.AGILITY: -1.0
	}
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 3, "should have one effect per bonus")

func test_get_item_effects_zero_bonus_excluded() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 5.0,
		CharacterAttributesData.AttributeType.BODY: 0.0
	}
	var effects = equip._get_item_effects()
	# Zero values are excluded by the > 0 and < 0 checks
	assert_eq(effects.size(), 1, "zero bonuses should be excluded from effects")

func test_get_item_effects_float_shown_correctly() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.SPIRIT: 2.5}
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 1)
	assert_true(effects[0].contains("2.5"), "non-integer bonus should show decimal: %s" % effects[0])

func test_get_item_effects_integer_shown_without_decimal() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.attribute_bonuses = {CharacterAttributesData.AttributeType.FOUNDATION: 10.0}
	var effects = equip._get_item_effects()
	assert_eq(effects.size(), 1)
	assert_true(effects[0].contains("+10"), "integer bonus should show without decimal: %s" % effects[0])

#-----------------------------------------------------------------------------
# SLOT TYPE ASSIGNMENT
#-----------------------------------------------------------------------------

func test_slot_type_assignment() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.slot_type = EquipmentDefinitionData.EquipmentSlot.ARMOR
	assert_eq(equip.slot_type, EquipmentDefinitionData.EquipmentSlot.ARMOR)

func test_different_slot_types() -> void:
	for slot in EquipmentDefinitionData.EquipmentSlot.values():
		var equip = EquipmentDefinitionData.new()
		equip.slot_type = slot
		assert_eq(equip.slot_type, slot, "should accept slot type %d" % slot)

#-----------------------------------------------------------------------------
# INHERITANCE
#-----------------------------------------------------------------------------

func test_extends_item_definition_data() -> void:
	var equip = EquipmentDefinitionData.new()
	assert_true(equip is ItemDefinitionData, "should extend ItemDefinitionData")

func test_has_item_name_field() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.item_name = "Iron Sword"
	assert_eq(equip.item_name, "Iron Sword")

func test_has_item_id_field() -> void:
	var equip = EquipmentDefinitionData.new()
	equip.item_id = "iron_sword_01"
	assert_eq(equip.item_id, "iron_sword_01")
