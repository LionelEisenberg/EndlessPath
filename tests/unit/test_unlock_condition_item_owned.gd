extends GutTest

## Unit tests for UnlockConditionData.ITEM_OWNED.

const ITEM_ID: String = "itm_owned_test"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func _make_condition() -> UnlockConditionData:
	var cond := UnlockConditionData.new()
	cond.condition_id = "has_%s" % ITEM_ID
	cond.condition_type = UnlockConditionData.ConditionType.ITEM_OWNED
	cond.target_value = ITEM_ID
	return cond

func _award_quest_item() -> void:
	var def := ItemDefinitionData.new()
	def.item_id = ITEM_ID
	def.item_name = "Owned Test Item"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM
	InventoryManager.award_items(def, 1)

func test_item_owned_false_when_not_owned() -> void:
	var cond := _make_condition()
	assert_false(cond.evaluate(), "should be false when inventory is empty")

func test_item_owned_true_when_owned() -> void:
	_award_quest_item()
	var cond := _make_condition()
	assert_true(cond.evaluate(), "should be true after awarding the item")
