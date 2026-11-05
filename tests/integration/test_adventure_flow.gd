extends GutTest

## Integration tests for the Madra side of starting an adventure with one pool:
## the threshold is half the pool's max, and Mind gear moves both through the
## real InventoryManager and CharacterManager. Taking the gear off brings a
## pool above the new max down to it (plan Review Focus 5).

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

## Wears a ring of +50% Mind: +5 at Lv 1, so 150 max Madra and a threshold of 75.
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
# THE THRESHOLD
#-----------------------------------------------------------------------------

func test_mind_gear_raises_the_threshold() -> void:
	ResourceManager.set_madra(60.0)
	assert_true(ResourceManager.can_start_adventure(), "precondition: 60 clears a threshold of 50")
	_wear_mind_ring()
	assert_eq(ResourceManager.get_adventure_madra_threshold(), 75.0, "half of the ring's 150")
	assert_false(ResourceManager.can_start_adventure(), "60 falls short of 75")

## The lock-out the old cap hid: a full pool always clears the threshold.
func test_a_full_pool_clears_the_threshold_at_any_mind() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new character", "mind_level": 1},
		{"name": "Mind Lv 15, past the old cap's reach", "mind_level": 15},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.MIND, case.mind_level)
		ResourceManager.set_madra(ResourceManager.get_max_madra())
		assert_true(ResourceManager.can_start_adventure(), case.name)

#-----------------------------------------------------------------------------
# THE OVER-MAX RULE
#-----------------------------------------------------------------------------

func test_taking_mind_gear_off_brings_the_pool_down() -> void:
	_wear_mind_ring()
	ResourceManager.set_madra(140.0)
	assert_eq(ResourceManager.get_madra(), 140.0, "precondition: the ring makes room past 100")
	InventoryManager.unequip_item(ACCESSORY, 0)
	assert_eq(ResourceManager.get_madra(), 100.0, "the pool comes down to the max without the ring")
	assert_true(ResourceManager.can_start_adventure(), "100 still clears a threshold of 50")
