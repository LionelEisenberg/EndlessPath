extends GutTest

## Unit tests for CharacterManager and CharacterAttributesData: base attribute
## getters, total attributes (base + equipment bonuses from equipped gear and
## both accessory slots) through the real CharacterManager, and
## add_base_attribute().
##
## Manager tests run on a fresh SaveGameData that every manager is re-bound
## to, so CharacterManager and InventoryManager share it. The original save is
## restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType
const EquipmentSlot = EquipmentDefinitionData.EquipmentSlot

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _attributes: CharacterAttributesData
var _original_save: SaveGameData
var _save: SaveGameData

func before_each() -> void:
	_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_save = PersistenceManager.save_game_data
	_save.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

func _make_gear(slot: EquipmentSlot, bonuses: Dictionary) -> ItemInstanceData:
	var definition := EquipmentDefinitionData.new()
	definition.item_id = "test_gear_%d" % slot
	definition.slot_type = slot
	definition.attribute_bonuses = bonuses
	var instance := ItemInstanceData.new()
	instance.item_definition = definition
	return instance

func _inventory() -> InventoryData:
	return InventoryManager.get_inventory()

func _total(attr_type: AttributeType) -> float:
	return CharacterManager.get_total_attributes_data().get_attribute(attr_type)

#-----------------------------------------------------------------------------
# ATTRIBUTE GETTERS - ALL 8 ATTRIBUTES
#-----------------------------------------------------------------------------

func test_get_strength_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.STRENGTH), 10.0)

func test_get_body_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.BODY), 10.0)

func test_get_agility_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.AGILITY), 10.0)

func test_get_spirit_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.SPIRIT), 10.0)

func test_get_foundation_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.FOUNDATION), 10.0)

func test_get_control_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.CONTROL), 10.0)

func test_get_resilience_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.RESILIENCE), 10.0)

func test_get_willpower_returns_base() -> void:
	assert_eq(_attributes.get_attribute(AttributeType.WILLPOWER), 10.0)

#-----------------------------------------------------------------------------
# CUSTOM ATTRIBUTE VALUES
#-----------------------------------------------------------------------------

func test_custom_attribute_values() -> void:
	var custom := CharacterAttributesData.new(5.0, 15.0, 20.0, 8.0, 12.0, 3.0, 25.0, 7.0)
	assert_eq(custom.get_attribute(AttributeType.STRENGTH), 5.0)
	assert_eq(custom.get_attribute(AttributeType.BODY), 15.0)
	assert_eq(custom.get_attribute(AttributeType.AGILITY), 20.0)
	assert_eq(custom.get_attribute(AttributeType.SPIRIT), 8.0)
	assert_eq(custom.get_attribute(AttributeType.FOUNDATION), 12.0)
	assert_eq(custom.get_attribute(AttributeType.CONTROL), 3.0)
	assert_eq(custom.get_attribute(AttributeType.RESILIENCE), 25.0)
	assert_eq(custom.get_attribute(AttributeType.WILLPOWER), 7.0)

#-----------------------------------------------------------------------------
# ADD TO ATTRIBUTE (CharacterAttributesData)
#-----------------------------------------------------------------------------

func test_add_to_attribute_increases_value() -> void:
	_attributes.add_to_attribute(AttributeType.STRENGTH, 5.0)
	assert_eq(_attributes.get_attribute(AttributeType.STRENGTH), 15.0)

func test_add_to_attribute_negative() -> void:
	_attributes.add_to_attribute(AttributeType.BODY, -3.0)
	assert_eq(_attributes.get_attribute(AttributeType.BODY), 7.0)

func test_add_to_attribute_zero() -> void:
	_attributes.add_to_attribute(AttributeType.SPIRIT, 0.0)
	assert_eq(_attributes.get_attribute(AttributeType.SPIRIT), 10.0)

func test_add_to_multiple_attributes() -> void:
	_attributes.add_to_attribute(AttributeType.STRENGTH, 5.0)
	_attributes.add_to_attribute(AttributeType.AGILITY, 10.0)
	assert_eq(_attributes.get_attribute(AttributeType.STRENGTH), 15.0)
	assert_eq(_attributes.get_attribute(AttributeType.AGILITY), 20.0)
	# Other attributes unchanged
	assert_eq(_attributes.get_attribute(AttributeType.BODY), 10.0)

#-----------------------------------------------------------------------------
# ATTRIBUTES DATA INITIALIZATION
#-----------------------------------------------------------------------------

func test_default_init_all_ten() -> void:
	var attrs := CharacterAttributesData.new()
	for attr_type: AttributeType in AttributeType.values():
		assert_eq(attrs.get_attribute(attr_type), 10.0, "default attribute should be 10.0")

func test_attribute_count() -> void:
	assert_eq(AttributeType.size(), 8, "should have exactly 8 attribute types")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: NO EQUIPMENT
#-----------------------------------------------------------------------------

func test_totals_equal_base_with_nothing_equipped() -> void:
	_save.character_attributes = CharacterAttributesData.new(5.0, 15.0, 20.0, 8.0, 12.0, 3.0, 25.0, 7.0)
	var expected: Dictionary = {
		AttributeType.STRENGTH: 5.0,
		AttributeType.BODY: 15.0,
		AttributeType.AGILITY: 20.0,
		AttributeType.SPIRIT: 8.0,
		AttributeType.FOUNDATION: 12.0,
		AttributeType.CONTROL: 3.0,
		AttributeType.RESILIENCE: 25.0,
		AttributeType.WILLPOWER: 7.0,
	}
	var totals: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: AttributeType in expected:
		assert_eq(totals.get_attribute(attr_type), expected[attr_type],
			"%s total with no gear" % AttributeType.keys()[attr_type])

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: EQUIPPED GEAR
#-----------------------------------------------------------------------------

func test_gear_bonus_adds_to_matching_attributes_only() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 5.0,
		AttributeType.AGILITY: 3.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 15.0)
	assert_eq(_total(AttributeType.AGILITY), 13.0)
	assert_eq(_total(AttributeType.BODY), 10.0, "no BODY bonus on the item")

func test_bonuses_stack_across_gear_slots() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 5.0,
	})
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {
		AttributeType.STRENGTH: 3.0,
		AttributeType.BODY: 10.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 18.0, "10 base + 5 weapon + 3 armor")
	assert_eq(_total(AttributeType.BODY), 20.0)

func test_negative_bonus_lowers_total() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 10.0,
		AttributeType.AGILITY: -2.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 20.0)
	assert_eq(_total(AttributeType.AGILITY), 8.0)

func test_each_attribute_receives_its_own_bonus() -> void:
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {
		AttributeType.STRENGTH: 1.0,
		AttributeType.BODY: 2.0,
		AttributeType.AGILITY: 3.0,
		AttributeType.SPIRIT: 4.0,
		AttributeType.FOUNDATION: 5.0,
		AttributeType.CONTROL: 6.0,
		AttributeType.RESILIENCE: 7.0,
		AttributeType.WILLPOWER: 8.0,
	})
	var expected: Dictionary = {
		AttributeType.STRENGTH: 11.0,
		AttributeType.BODY: 12.0,
		AttributeType.AGILITY: 13.0,
		AttributeType.SPIRIT: 14.0,
		AttributeType.FOUNDATION: 15.0,
		AttributeType.CONTROL: 16.0,
		AttributeType.RESILIENCE: 17.0,
		AttributeType.WILLPOWER: 18.0,
	}
	var totals: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: AttributeType in expected:
		assert_eq(totals.get_attribute(attr_type), expected[attr_type],
			"%s total should be base + its own bonus" % AttributeType.keys()[attr_type])

func test_items_without_equipment_definition_are_ignored() -> void:
	var no_definition := ItemInstanceData.new()
	var material := ItemInstanceData.new()
	material.item_definition = MaterialDefinitionData.new()
	_inventory().equipped_gear[EquipmentSlot.HEAD] = no_definition
	_inventory().equipped_gear[EquipmentSlot.OFF_HAND] = material
	_inventory().equipped_accessories[0] = no_definition
	_inventory().equipped_accessories[1] = material
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 2.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 12.0, "only the real equipment counts")

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: ACCESSORIES
#-----------------------------------------------------------------------------

func test_accessory_in_slot_0_adds_bonus() -> void:
	_inventory().equipped_accessories[0] = _make_gear(EquipmentSlot.ACCESSORY, {
		AttributeType.SPIRIT: 4.0,
	})
	assert_eq(_total(AttributeType.SPIRIT), 14.0)

func test_accessory_in_slot_1_adds_bonus() -> void:
	_inventory().equipped_accessories[1] = _make_gear(EquipmentSlot.ACCESSORY, {
		AttributeType.WILLPOWER: 2.0,
	})
	assert_eq(_total(AttributeType.WILLPOWER), 12.0)

func test_gear_and_both_accessories_stack() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 5.0,
	})
	_inventory().equipped_accessories[0] = _make_gear(EquipmentSlot.ACCESSORY, {
		AttributeType.STRENGTH: 2.0,
	})
	_inventory().equipped_accessories[1] = _make_gear(EquipmentSlot.ACCESSORY, {
		AttributeType.STRENGTH: 1.0,
		AttributeType.CONTROL: 3.0,
	})
	assert_eq(_total(AttributeType.STRENGTH), 18.0, "10 base + 5 weapon + 2 + 1 accessories")
	assert_eq(_total(AttributeType.CONTROL), 13.0)

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES: EQUIPPING THROUGH INVENTORY MANAGER
#-----------------------------------------------------------------------------

func test_equip_and_unequip_gear_updates_totals() -> void:
	var armor := _make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0})
	_inventory().equipment[0] = armor

	InventoryManager.equip_item(armor, EquipmentSlot.ARMOR, 0)
	assert_eq(_total(AttributeType.BODY), 14.0, "equipped armor adds its bonus")
	assert_eq(_save.character_attributes.get_attribute(AttributeType.BODY), 10.0, "the bonus never touches the base")

	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_eq(_total(AttributeType.BODY), 10.0, "the bonus goes away with the armor")

func test_equip_and_unequip_accessory_updates_totals() -> void:
	var ring := _make_gear(EquipmentSlot.ACCESSORY, {AttributeType.FOUNDATION: 3.0})
	_inventory().equipment[0] = ring

	InventoryManager.equip_item(ring, EquipmentSlot.ACCESSORY, 0, 1)
	assert_eq(_total(AttributeType.FOUNDATION), 13.0, "an accessory in the second slot adds its bonus")

	InventoryManager.unequip_item(EquipmentSlot.ACCESSORY, 1)
	assert_eq(_total(AttributeType.FOUNDATION), 10.0)

#-----------------------------------------------------------------------------
# ADD BASE ATTRIBUTE (CharacterManager)
#-----------------------------------------------------------------------------

func test_add_base_attribute_raises_base_and_total() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {
		AttributeType.STRENGTH: 3.0,
	})
	CharacterManager.add_base_attribute(AttributeType.STRENGTH, 5.0)
	assert_eq(_save.character_attributes.get_attribute(AttributeType.STRENGTH), 15.0)
	assert_eq(_total(AttributeType.STRENGTH), 18.0, "new base + gear bonus")

func test_add_base_attribute_emits_new_base_value() -> void:
	watch_signals(CharacterManager)
	CharacterManager.add_base_attribute(AttributeType.BODY, -3.0)
	assert_signal_emit_count(CharacterManager, "base_attribute_changed", 1)
	assert_signal_emitted_with_parameters(CharacterManager, "base_attribute_changed", [AttributeType.BODY, 7.0])

#-----------------------------------------------------------------------------
# TOTAL ATTRIBUTES CHANGED SIGNAL
#-----------------------------------------------------------------------------

func test_add_base_attribute_emits_total_attributes_changed() -> void:
	watch_signals(CharacterManager)
	CharacterManager.add_base_attribute(AttributeType.BODY, 2.0)
	assert_signal_emit_count(CharacterManager, "total_attributes_changed", 1)

func test_equipping_gear_emits_total_attributes_changed() -> void:
	var armor := _make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0})
	_inventory().equipment[0] = armor
	watch_signals(CharacterManager)
	InventoryManager.equip_item(armor, EquipmentSlot.ARMOR, 0)
	assert_signal_emitted(CharacterManager, "total_attributes_changed")

func test_unequipping_gear_emits_total_attributes_changed() -> void:
	var armor := _make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0})
	_inventory().equipment[0] = armor
	InventoryManager.equip_item(armor, EquipmentSlot.ARMOR, 0)
	watch_signals(CharacterManager)
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_signal_emitted(CharacterManager, "total_attributes_changed")

func test_save_reset_emits_total_attributes_changed_once() -> void:
	watch_signals(CharacterManager)
	PersistenceManager.save_data_reset.emit()
	assert_signal_emit_count(CharacterManager, "total_attributes_changed", 1)
