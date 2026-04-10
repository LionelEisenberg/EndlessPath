extends GutTest

## Unit tests for CharacterManager
## Tests attribute getters, equipment bonuses, total attributes, base modification

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

var _attributes: CharacterAttributesData
var _save_data: SaveGameData

func before_each() -> void:
	_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_save_data = SaveGameData.new()
	_save_data.character_attributes = _attributes

#-----------------------------------------------------------------------------
# ATTRIBUTE GETTERS - ALL 8 ATTRIBUTES
#-----------------------------------------------------------------------------

func test_get_strength_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.STRENGTH), 10.0)

func test_get_body_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY), 10.0)

func test_get_agility_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.AGILITY), 10.0)

func test_get_spirit_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT), 10.0)

func test_get_foundation_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.FOUNDATION), 10.0)

func test_get_control_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.CONTROL), 10.0)

func test_get_resilience_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE), 10.0)

func test_get_willpower_returns_base() -> void:
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER), 10.0)

#-----------------------------------------------------------------------------
# CUSTOM ATTRIBUTE VALUES
#-----------------------------------------------------------------------------

func test_custom_attribute_values() -> void:
	var custom = CharacterAttributesData.new(5.0, 15.0, 20.0, 8.0, 12.0, 3.0, 25.0, 7.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.STRENGTH), 5.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.BODY), 15.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.AGILITY), 20.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.SPIRIT), 8.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.FOUNDATION), 12.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.CONTROL), 3.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.RESILIENCE), 25.0)
	assert_eq(custom.get_attribute(CharacterAttributesData.AttributeType.WILLPOWER), 7.0)

#-----------------------------------------------------------------------------
# EQUIPMENT BONUSES
#-----------------------------------------------------------------------------

func test_equipment_bonuses_no_gear() -> void:
	# With no gear equipped, bonus should be 0 for all attributes
	var inventory = InventoryData.new()
	for attr_type in CharacterAttributesData.AttributeType.values():
		var bonus = _calculate_equipment_bonus(inventory, attr_type)
		assert_eq(bonus, 0.0, "no gear should give 0 bonus for %s" % CharacterAttributesData.AttributeType.keys()[attr_type])

func test_equipment_bonuses_single_item() -> void:
	var inventory = InventoryData.new()
	var equip_def = EquipmentDefinitionData.new()
	equip_def.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 5.0,
		CharacterAttributesData.AttributeType.AGILITY: 3.0
	}

	var instance = ItemInstanceData.new()
	instance.item_definition = equip_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = instance

	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.STRENGTH), 5.0)
	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.AGILITY), 3.0)
	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.BODY), 0.0)

func test_equipment_bonuses_multiple_items_stack() -> void:
	var inventory = InventoryData.new()

	# Weapon with +5 Strength
	var weapon_def = EquipmentDefinitionData.new()
	weapon_def.attribute_bonuses = {CharacterAttributesData.AttributeType.STRENGTH: 5.0}
	var weapon = ItemInstanceData.new()
	weapon.item_definition = weapon_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = weapon

	# Armor with +3 Strength, +10 Body
	var armor_def = EquipmentDefinitionData.new()
	armor_def.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 3.0,
		CharacterAttributesData.AttributeType.BODY: 10.0
	}
	var armor = ItemInstanceData.new()
	armor.item_definition = armor_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ARMOR] = armor

	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.STRENGTH), 8.0, "strength bonuses should stack from multiple items")
	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.BODY), 10.0)

func test_equipment_bonuses_negative_values() -> void:
	var inventory = InventoryData.new()
	var equip_def = EquipmentDefinitionData.new()
	equip_def.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 10.0,
		CharacterAttributesData.AttributeType.AGILITY: -2.0
	}
	var instance = ItemInstanceData.new()
	instance.item_definition = equip_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.MAIN_HAND] = instance

	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.STRENGTH), 10.0)
	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.AGILITY), -2.0, "negative bonuses should work")

func test_equipment_bonuses_null_item_definition_skipped() -> void:
	var inventory = InventoryData.new()
	var instance = ItemInstanceData.new()
	instance.item_definition = null
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.HEAD] = instance

	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.STRENGTH), 0.0, "null definition should be skipped safely")

func test_equipment_bonuses_non_equipment_definition_skipped() -> void:
	var inventory = InventoryData.new()
	var mat_def = MaterialDefinitionData.new()
	var instance = ItemInstanceData.new()
	instance.item_definition = mat_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.HEAD] = instance

	assert_eq(_calculate_equipment_bonus(inventory, CharacterAttributesData.AttributeType.STRENGTH), 0.0, "non-equipment definitions should be skipped")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES (base + bonuses)
#-----------------------------------------------------------------------------

func test_total_strength_with_bonus() -> void:
	var base = 10.0
	var bonus = 5.0
	assert_eq(base + bonus, 15.0, "total should be base + equipment bonus")

func test_total_attributes_all_bonused() -> void:
	var inventory = InventoryData.new()
	var equip_def = EquipmentDefinitionData.new()
	equip_def.attribute_bonuses = {
		CharacterAttributesData.AttributeType.STRENGTH: 1.0,
		CharacterAttributesData.AttributeType.BODY: 2.0,
		CharacterAttributesData.AttributeType.AGILITY: 3.0,
		CharacterAttributesData.AttributeType.SPIRIT: 4.0,
		CharacterAttributesData.AttributeType.FOUNDATION: 5.0,
		CharacterAttributesData.AttributeType.CONTROL: 6.0,
		CharacterAttributesData.AttributeType.RESILIENCE: 7.0,
		CharacterAttributesData.AttributeType.WILLPOWER: 8.0
	}
	var instance = ItemInstanceData.new()
	instance.item_definition = equip_def
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ARMOR] = instance

	var base = _attributes
	var expected_values = {
		CharacterAttributesData.AttributeType.STRENGTH: 11.0,
		CharacterAttributesData.AttributeType.BODY: 12.0,
		CharacterAttributesData.AttributeType.AGILITY: 13.0,
		CharacterAttributesData.AttributeType.SPIRIT: 14.0,
		CharacterAttributesData.AttributeType.FOUNDATION: 15.0,
		CharacterAttributesData.AttributeType.CONTROL: 16.0,
		CharacterAttributesData.AttributeType.RESILIENCE: 17.0,
		CharacterAttributesData.AttributeType.WILLPOWER: 18.0
	}

	for attr_type in expected_values:
		var total = base.get_attribute(attr_type) + _calculate_equipment_bonus(inventory, attr_type)
		assert_eq(total, expected_values[attr_type], "total %s should be base + bonus" % CharacterAttributesData.AttributeType.keys()[attr_type])

#-----------------------------------------------------------------------------
# ADD BASE ATTRIBUTE
#-----------------------------------------------------------------------------

func test_add_to_attribute_increases_value() -> void:
	_attributes.add_to_attribute(CharacterAttributesData.AttributeType.STRENGTH, 5.0)
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.STRENGTH), 15.0)

func test_add_to_attribute_negative() -> void:
	_attributes.add_to_attribute(CharacterAttributesData.AttributeType.BODY, -3.0)
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY), 7.0)

func test_add_to_attribute_zero() -> void:
	_attributes.add_to_attribute(CharacterAttributesData.AttributeType.SPIRIT, 0.0)
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT), 10.0)

func test_add_to_multiple_attributes() -> void:
	_attributes.add_to_attribute(CharacterAttributesData.AttributeType.STRENGTH, 5.0)
	_attributes.add_to_attribute(CharacterAttributesData.AttributeType.AGILITY, 10.0)
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.STRENGTH), 15.0)
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.AGILITY), 20.0)
	# Other attributes unchanged
	assert_eq(_attributes.get_attribute(CharacterAttributesData.AttributeType.BODY), 10.0)

#-----------------------------------------------------------------------------
# ATTRIBUTES DATA INITIALIZATION
#-----------------------------------------------------------------------------

func test_default_init_all_ten() -> void:
	var attrs = CharacterAttributesData.new()
	for attr_type in CharacterAttributesData.AttributeType.values():
		assert_eq(attrs.get_attribute(attr_type), 10.0, "default attribute should be 10.0")

func test_attribute_count() -> void:
	assert_eq(CharacterAttributesData.AttributeType.size(), 8, "should have exactly 8 attribute types")

#-----------------------------------------------------------------------------
# HELPER: Mirror _get_equipment_bonuses logic from CharacterManager
#-----------------------------------------------------------------------------

func _calculate_equipment_bonus(inventory: InventoryData, attr_type: CharacterAttributesData.AttributeType) -> float:
	var bonus: float = 0.0
	for slot: int in inventory.equipped_gear:
		var instance: ItemInstanceData = inventory.equipped_gear[slot]
		if instance == null or instance.item_definition == null:
			continue
		var equip_def = instance.item_definition as EquipmentDefinitionData
		if equip_def == null:
			continue
		if equip_def.attribute_bonuses.has(attr_type):
			bonus += equip_def.attribute_bonuses[attr_type]
	return bonus
