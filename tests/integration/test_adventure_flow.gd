extends GutTest

## Integration tests for the Madra side of starting an adventure with one pool:
## a run starts on whatever the pool holds, and Mind gear moves the pool's max
## through the real InventoryManager and CharacterManager. Taking the gear off
## brings a pool above the new max down to it (plan Review Focus 5).

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

const ACCESSORY := EquipmentDefinitionData.EquipmentSlot.ACCESSORY

var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Wears a ring of +50% Mind: +5 at Lv 1, so 150 max Madra.
func _wear_mind_ring() -> void:
	var percents: Dictionary[StringName, float] = {&"mind": 0.5}
	var ring := EquipmentDefinitionData.new()
	ring.item_id = "test_adventure_flow_ring"
	ring.item_name = "Test Mind Ring"
	ring.slot_type = ACCESSORY
	ring.stat_percent_bonuses = percents
	var instance := ItemInstanceData.new()
	instance.item_definition = ring
	InventoryManager.equip_item(instance, ACCESSORY, -1, 0)

#-----------------------------------------------------------------------------
# NO THRESHOLD
#-----------------------------------------------------------------------------

## The run plays on the pool as it stands: an empty pool, a little and a full
## pool all start it, whatever Mind sets the max to.
func test_any_pool_starts_an_adventure() -> void:
	var adventure: ZoneActionData = ZoneManager.get_action_by_id("shallow_woods_adventure_action")
	var cases: Array[Dictionary] = [
		{"name": "an empty pool", "madra": 0.0, "mind_level": 1},
		{"name": "a little Madra", "madra": 10.0, "mind_level": 1},
		{"name": "a full pool at Mind Lv 15", "madra": 250.0, "mind_level": 15},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.MIND, case.mind_level)
		ResourceManager.set_madra(case.madra)
		ActionManager.select_action(adventure)
		assert_eq(ActionManager.get_current_action(), adventure, case.name)
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# THE OVER-MAX RULE
#-----------------------------------------------------------------------------

func test_taking_mind_gear_off_brings_the_pool_down() -> void:
	_wear_mind_ring()
	ResourceManager.set_madra(140.0)
	assert_eq(ResourceManager.get_madra(), 140.0, "precondition: the ring makes room past 100")
	InventoryManager.unequip_item(ACCESSORY, 0)
	assert_eq(ResourceManager.get_madra(), 100.0, "the pool comes down to the max without the ring")
