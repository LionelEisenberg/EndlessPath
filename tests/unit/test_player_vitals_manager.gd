extends GutTest

## Unit tests for the player's VitalsManager following CharacterManager's stats:
## its maximum Health, Stamina and Madra move with equipped gear, with trained
## levels, and with any modifier source, while an enemy's do not. Its Madra is
## ResourceManager's saved pool: reads, writes and changes go through it, while
## an enemy keeps Madra of its own. Each test builds a VitalsManager the way
## PlayerManager does (is_player, no attribute data of its own), on a fresh
## SaveGameData every manager is re-bound to, holding 25 Madra. The original
## save is restored in after_each().

const AttributeType = CharacterAttributesData.AttributeType
const EquipmentSlot = EquipmentDefinitionData.EquipmentSlot
const Stat = StatModifierData.Stat
const Kind = StatModifierData.Kind
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")
const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")

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

	_vitals = VitalsManager.new()
	_vitals.is_player = true
	add_child_autofree(_vitals)

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## An instance of GearFixture's item for the slot, with these stat percents
## (stat key to fraction of the trained value).
func _make_gear(slot: EquipmentSlot, percents: Dictionary) -> ItemInstanceData:
	var definition: EquipmentDefinitionData = GearFixture.item(percents)
	definition.item_id = "test_gear_%d" % slot
	definition.slot_type = slot
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

func test_equipping_body_gear_raises_max_health() -> void:
	assert_eq(_vitals.max_health, 100.0, "10 Body before the armor")
	_equip(_make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}), EquipmentSlot.ARMOR)
	assert_eq(_vitals.max_health, 140.0, "14 Body x 10")

func test_equipping_agility_gear_raises_max_stamina() -> void:
	assert_eq(_vitals.max_stamina, 50.0, "10 Agility before the gear")
	_equip(_make_gear(EquipmentSlot.MAIN_HAND, {&"agility": 0.4}), EquipmentSlot.MAIN_HAND)
	assert_eq(_vitals.max_stamina, 70.0, "14 Agility x 5")

func test_unequipping_body_gear_lowers_max_health_again() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}), EquipmentSlot.ARMOR)
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_eq(_vitals.max_health, 100.0, "back to 10 Body x 10")

func test_equipping_a_mind_accessory_raises_max_madra() -> void:
	_equip(_make_gear(EquipmentSlot.ACCESSORY, {&"mind": 0.2}), EquipmentSlot.ACCESSORY, 1)
	assert_eq(_vitals.max_madra, 120.0, "12 Mind x 10")

func test_new_max_health_fills_the_next_run() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}), EquipmentSlot.ARMOR)
	_vitals.initialize_current_values()
	assert_eq(_vitals.current_health, 140.0, "an adventure starts at the geared maximum")

#-----------------------------------------------------------------------------
# TRAINED LEVELS
#-----------------------------------------------------------------------------

func test_a_level_gained_moves_the_maxima() -> void:
	CharacterManager.add_stat_levels(AttributeType.BODY, 2)
	assert_eq(_vitals.max_health, CharacterManager.get_stat(Stat.MAX_HEALTH), "the vitals follow the new Body")
	assert_gt(_vitals.max_health, 100.0, "two Body levels raise max Health past Lv 1's")

func test_gear_and_levels_add_up() -> void:
	_equip(_make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}), EquipmentSlot.ARMOR)
	CharacterManager.add_stat_levels(AttributeType.BODY, 2)
	assert_eq(_vitals.max_health, CharacterManager.get_stat(Stat.MAX_HEALTH), "the vitals follow the trained and geared Body")
	assert_gt(_vitals.max_health, 140.0, "the levels add to the armor's 140")

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
	InventoryManager.get_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4})
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

#-----------------------------------------------------------------------------
# MADRA: THE ONE POOL
#-----------------------------------------------------------------------------

func _max_madra_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(Stat.MAX_MADRA, Kind.FLAT, amount)]
		return modifiers

func test_the_players_madra_reads_the_pool() -> void:
	ResourceManager.set_madra(46.0)
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(20.0))
	assert_eq(_vitals.current_madra, 46.0, "current Madra is the pool")
	assert_eq(_vitals.max_madra, 120.0, "max Madra is the pool's max")

func test_madra_changes_land_in_the_pool() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Empty Palm's cost", "madra": 50.0, "change": -8.0, "expected": 42.0},
		{"name": "a Scale's refill", "madra": 50.0, "change": 20.0, "expected": 70.0},
		{"name": "a refill past the max stops at it", "madra": 90.0, "change": 20.0, "expected": 100.0},
		{"name": "a cost past the pool stops at 0", "madra": 5.0, "change": -8.0, "expected": 0.0},
	]
	for case: Dictionary in cases:
		ResourceManager.set_madra(case.madra)
		_vitals.apply_vitals_change(0.0, 0.0, case.change)
		assert_eq(ResourceManager.get_madra(), case.expected, case.name)

func test_writing_current_madra_sets_the_pool() -> void:
	_vitals.current_madra = 33.0
	assert_eq(ResourceManager.get_madra(), 33.0)

func test_each_pool_change_reaches_the_vitals_once() -> void:
	watch_signals(_vitals)
	ResourceManager.add_madra(5.0, true)
	_vitals.apply_vitals_change(0.0, 0.0, -10.0)
	assert_signal_emit_count(_vitals, "madra_changed", 2, "cycling's add and a technique's cost, once each")
	assert_signal_emitted_with_parameters(_vitals, "madra_changed", [20.0])

## A hit or a step changes no Madra, so the pool stays quiet: each of its
## signals sweeps every unlock condition.
func test_a_change_with_no_madra_leaves_the_pool_quiet() -> void:
	watch_signals(ResourceManager)
	_vitals.apply_vitals_change(-10.0, -5.0, 0.0)
	assert_signal_not_emitted(ResourceManager, "madra_changed")

## In-run refills stay quiet: no "Gained" line.
func test_a_scale_refills_the_pool_quietly() -> void:
	watch_signals(LogManager)
	CRUDE_SCALE.effects[0].process()
	assert_eq(ResourceManager.get_madra(), 45.0, "25 + 20")
	assert_signal_not_emitted(LogManager, "message_logged")

func test_initialize_current_values_leaves_the_pool_alone() -> void:
	ResourceManager.set_madra(30.0)
	_vitals.initialize_current_values()
	assert_eq(ResourceManager.get_madra(), 30.0)

func test_an_enemys_madra_is_its_own() -> void:
	var enemy := VitalsManager.new()
	enemy.character_attributes_data = CharacterAttributesData.make()
	add_child_autofree(enemy)
	enemy.initialize_current_values()
	enemy.apply_vitals_change(0.0, 0.0, -30.0)
	assert_eq(enemy.current_madra, 70.0, "100 of its own, less 30")
	assert_eq(ResourceManager.get_madra(), 25.0, "the pool is untouched")
