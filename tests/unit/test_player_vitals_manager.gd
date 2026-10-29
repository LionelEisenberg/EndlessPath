extends GutTest

## Unit tests for the player's VitalsManager following CharacterManager's stats:
## its maximum Health, Stamina and Madra move with equipped gear, with base
## attributes, and with any modifier source, while an enemy's do not. Each test
## builds a VitalsManager the way PlayerManager does (is_player, no attribute
## data of its own), on a fresh SaveGameData every manager is re-bound to. The
## original save is restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType
const EquipmentSlot = EquipmentDefinitionData.EquipmentSlot
const Stat = StatModifierData.Stat
const Kind = StatModifierData.Kind

## The modifier source these tests set; after_each() removes it.
const TEST_SOURCE: StringName = &"test"

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _vitals: VitalsManager

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	PersistenceManager.save_game_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

	_vitals = VitalsManager.new()
	_vitals.is_player = true
	add_child_autofree(_vitals)

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
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

## Puts the gear in the first grid slot and equips it from there, as a drag
## from the grid does.
func _equip(instance: ItemInstanceData, slot: EquipmentSlot, accessory_index: int = -1) -> void:
	InventoryManager.get_inventory().equipment[0] = instance
	InventoryManager.equip_item(instance, slot, 0, accessory_index)

#-----------------------------------------------------------------------------
# GEAR
#-----------------------------------------------------------------------------

func test_equipping_body_gear_raises_max_health_and_stamina() -> void:
	assert_eq(_vitals.max_health, 100.0, "10 Body before the armor")
	_equip(_make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0}), EquipmentSlot.ARMOR)
	assert_eq(_vitals.max_health, 140.0, "14 Body x 10")
	assert_eq(_vitals.max_stamina, 70.0, "14 Body x 5")

func test_unequipping_body_gear_lowers_max_health_again() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0}), EquipmentSlot.ARMOR)
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_eq(_vitals.max_health, 100.0)
	assert_eq(_vitals.max_stamina, 50.0)

func test_equipping_a_foundation_accessory_raises_max_madra() -> void:
	_equip(_make_gear(EquipmentSlot.ACCESSORY, {AttributeType.FOUNDATION: 2.0}), EquipmentSlot.ACCESSORY, 1)
	assert_eq(_vitals.max_madra, 120.0, "12 Foundation x 10")

func test_new_max_health_fills_the_next_run() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0}), EquipmentSlot.ARMOR)
	_vitals.initialize_current_values()
	assert_eq(_vitals.current_health, 140.0, "an adventure starts at the geared maximum")

#-----------------------------------------------------------------------------
# BASE ATTRIBUTES
#-----------------------------------------------------------------------------

func test_base_attribute_change_still_moves_the_maxima() -> void:
	CharacterManager.add_base_attribute(AttributeType.BODY, 2.0)
	assert_eq(_vitals.max_health, 120.0)

func test_gear_and_base_add_up() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0}), EquipmentSlot.ARMOR)
	CharacterManager.add_base_attribute(AttributeType.BODY, 2.0)
	assert_eq(_vitals.max_health, 160.0, "12 base + 4 gear Body")

#-----------------------------------------------------------------------------
# MODIFIER SOURCES
#-----------------------------------------------------------------------------

func _max_health_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(Stat.MAX_HEALTH, Kind.FLAT, amount)]
		return modifiers

func test_a_max_health_source_reaches_the_players_vitals() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_health_source(20.0))
	assert_eq(_vitals.max_health, 120.0, "100 from Body, + 20 on max Health itself")

func test_gear_already_in_the_save_counts_at_once() -> void:
	InventoryManager.get_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {AttributeType.BODY: 4.0})
	var vitals := VitalsManager.new()
	vitals.is_player = true
	add_child_autofree(vitals)
	assert_eq(vitals.max_health, 140.0, "gear a loaded save already wears, with no inventory signal")

func test_an_enemys_vitals_ignore_player_modifiers() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_health_source(20.0))
	var enemy := VitalsManager.new()
	enemy.character_attributes_data = CharacterAttributesData.new()
	add_child_autofree(enemy)
	assert_eq(_vitals.max_health, 120.0, "precondition: the player's maximum moves")
	assert_eq(enemy.max_health, 100.0, "an enemy's is its own Body x 10")
