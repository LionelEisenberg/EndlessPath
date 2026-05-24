extends GutTest

## Unit + integration tests for the consumables MVP.
## Covers InventoryData.consumables field, InventoryManager.award_items dispatch,
## InventoryManager.has_item, and InventoryManager.use_consumable.

var _inventory: InventoryData

func before_each() -> void:
	_inventory = InventoryData.new()

func test_inventory_starts_with_empty_consumables_dict() -> void:
	assert_eq(_inventory.consumables.size(), 0, "consumables should start empty")
	assert_true(_inventory.consumables is Dictionary, "consumables should be a Dictionary")
