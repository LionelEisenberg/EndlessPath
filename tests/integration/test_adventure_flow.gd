extends GutTest

## Integration tests for the Madra side of starting an adventure: the stage
## pool cap (CultivationManager), the adventure capacity from total Foundation
## (CharacterManager, including equipment from InventoryManager), and
## ResourceManager's threshold gate, budget and spend. Every test calls the real
## singletons, bound to a fresh save and a stub Foundation stage.

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stub stage: the pool cap is 100 at Core Density level 0, +10 per level.
const STAGE_MAX_MADRA_BASE: float = 100.0
const STAGE_MAX_MADRA_PER_LEVEL: float = 10.0
## Foundation granted by the test helmet.
const FOUNDATION_BONUS: float = 5.0

var _save: SaveGameData
var _stage: AdvancementStageResource

var _original_resource_save: SaveGameData
var _original_cultivation_save: SaveGameData
var _original_stage_resources: Array[AdvancementStageResource]
var _original_character_save: SaveGameData
var _original_inventory_save: SaveGameData
var _original_unlock_save: SaveGameData
var _original_event_save: SaveGameData
var _original_quest_save: SaveGameData

func before_each() -> void:
	_save = SaveGameData.new()
	_save.madra = 0.0
	_save.core_density_level = 0.0
	_save.current_advancement_stage = CultivationManager.AdvancementStage.FOUNDATION
	_save.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

	_stage = AdvancementStageResource.new()
	_stage.stage_name = "Test Foundation"
	_stage.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	_stage.max_madra_base = STAGE_MAX_MADRA_BASE
	_stage.max_madra_per_core_density_level = STAGE_MAX_MADRA_PER_LEVEL

	# ResourceManager reads the pool cap from CultivationManager and the
	# adventure capacity from CharacterManager, whose equipment bonuses come
	# from InventoryManager. Every madra_changed also makes UnlockManager
	# evaluate all conditions (reading EventManager) and QuestManager react to
	# new unlocks, so those use the test save too.
	_original_resource_save = ResourceManager.live_save_data
	_original_cultivation_save = CultivationManager.live_save_data
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_original_character_save = CharacterManager.live_save_data
	_original_inventory_save = InventoryManager.live_save_data
	_original_unlock_save = UnlockManager.live_save_data
	_original_event_save = EventManager.live_save_data
	_original_quest_save = QuestManager._live_save_data

	var stages: Array[AdvancementStageResource] = [_stage]
	ResourceManager.live_save_data = _save
	CultivationManager.live_save_data = _save
	CultivationManager.advancement_stage_resources = stages
	CharacterManager.live_save_data = _save
	InventoryManager.live_save_data = _save
	UnlockManager.live_save_data = _save
	EventManager.live_save_data = _save
	QuestManager._live_save_data = _save

func after_each() -> void:
	ResourceManager.live_save_data = _original_resource_save
	CultivationManager.live_save_data = _original_cultivation_save
	CultivationManager.advancement_stage_resources = _original_stage_resources
	CharacterManager.live_save_data = _original_character_save
	InventoryManager.live_save_data = _original_inventory_save
	UnlockManager.live_save_data = _original_unlock_save
	EventManager.live_save_data = _original_event_save
	QuestManager._live_save_data = _original_quest_save

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The Madra pool cap for the save's current Core Density level, from the stub stage.
func _pool_cap() -> float:
	return _stage.get_max_madra(int(_save.core_density_level))

## The adventure capacity for the save's base attributes, with no equipment.
func _base_capacity() -> float:
	return _save.character_attributes.get_max_madra()

func _set_foundation(value: float) -> void:
	_save.character_attributes.set_attribute(CharacterAttributesData.AttributeType.FOUNDATION, value)

## Equips a helmet that grants FOUNDATION_BONUS Foundation.
func _equip_foundation_helmet() -> void:
	var helmet := EquipmentDefinitionData.new()
	helmet.item_id = "test_foundation_helmet"
	helmet.item_name = "Test Foundation Helmet"
	helmet.slot_type = EquipmentDefinitionData.EquipmentSlot.HEAD
	helmet.attribute_bonuses = {CharacterAttributesData.AttributeType.FOUNDATION: FOUNDATION_BONUS}
	var instance := ItemInstanceData.new()
	instance.item_definition = helmet
	_save.inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.HEAD] = instance

#-----------------------------------------------------------------------------
# THRESHOLD GATE
#-----------------------------------------------------------------------------

## Below the threshold, from an empty pool to one Madra short of it, the
## adventure is blocked and the budget still reports current Madra.
func test_madra_below_threshold_blocks_adventure() -> void:
	var cases: Array[Array] = [
		["no Madra", 0.0],
		["one Madra short", _base_capacity() * 0.5 - 1.0],
	]
	for case: Array in cases:
		_save.madra = 0.0
		if case[1] > 0.0:
			ResourceManager.add_madra(case[1])
		assert_false(ResourceManager.can_start_adventure(), "%s: blocked" % case[0])
		assert_eq(ResourceManager.get_adventure_madra_budget(), _save.madra,
			"%s: the budget still reports current Madra for the badge while blocked" % case[0])

func test_cycling_up_to_threshold_allows_adventure_with_partial_budget() -> void:
	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	ResourceManager.add_madra(threshold - 10.0)
	assert_false(ResourceManager.can_start_adventure())
	ResourceManager.add_madra(10.0)
	assert_true(ResourceManager.can_start_adventure())
	assert_eq(ResourceManager.get_adventure_madra_budget(), threshold,
		"below capacity the whole pool is the budget")

func test_full_stage_pool_allows_adventure() -> void:
	ResourceManager.add_madra(1000.0)
	assert_eq(_save.madra, _pool_cap(), "cycling stops at the stage pool cap")
	assert_true(ResourceManager.can_start_adventure())
	assert_eq(ResourceManager.get_adventure_madra_budget(), _pool_cap(),
		"at level 0 the stub pool cap fits within the Foundation-10 capacity, so the whole pool is the budget")

#-----------------------------------------------------------------------------
# BUDGET AND SPEND
#-----------------------------------------------------------------------------

func test_budget_capped_at_capacity_when_pool_exceeds_it() -> void:
	_save.core_density_level = 10.0
	ResourceManager.add_madra(1000.0)
	assert_gt(_save.madra, _base_capacity(), "precondition: the level-10 pool holds more than one adventure")
	assert_eq(ResourceManager.get_adventure_madra_budget(), _base_capacity())

func test_spending_budget_keeps_excess_madra_in_pool() -> void:
	_save.core_density_level = 10.0
	ResourceManager.add_madra(1000.0)
	var pool_before: float = _save.madra
	var budget: float = ResourceManager.get_adventure_madra_budget()
	assert_true(ResourceManager.spend_madra(budget))
	assert_eq(_save.madra, pool_before - budget)

func test_spending_full_budget_below_capacity_empties_pool() -> void:
	ResourceManager.add_madra(_base_capacity() * 0.75)
	assert_true(ResourceManager.spend_madra(ResourceManager.get_adventure_madra_budget()))
	assert_eq(_save.madra, 0.0)
	assert_false(ResourceManager.can_start_adventure(), "an empty pool must be refilled before the next adventure")

#-----------------------------------------------------------------------------
# CAPACITY SCALES WITH FOUNDATION
#-----------------------------------------------------------------------------

func test_higher_foundation_raises_threshold() -> void:
	_save.madra = _base_capacity() * 0.5
	assert_true(ResourceManager.can_start_adventure(), "precondition: enough at Foundation 10")
	_set_foundation(20.0)
	assert_false(ResourceManager.can_start_adventure(), "the same Madra falls short at Foundation 20")

func test_higher_foundation_raises_budget_ceiling() -> void:
	_save.core_density_level = 10.0
	ResourceManager.add_madra(1000.0)
	var budget_at_foundation_10: float = ResourceManager.get_adventure_madra_budget()
	_set_foundation(20.0)
	assert_eq(ResourceManager.get_adventure_madra_budget(), _base_capacity())
	assert_gt(ResourceManager.get_adventure_madra_budget(), budget_at_foundation_10,
		"the same full pool carries more Madra into an adventure at Foundation 20")

func test_equipment_foundation_bonus_raises_capacity() -> void:
	_equip_foundation_helmet()
	var total := CharacterAttributesData.new()
	total.foundation = _save.character_attributes.foundation + FOUNDATION_BONUS
	assert_eq(ResourceManager.get_adventure_madra_capacity(), total.get_max_madra())
	assert_gt(ResourceManager.get_adventure_madra_capacity(), _base_capacity())
