extends GutTest

## Unit tests for MerchantManager: the purchase rules (sold out, gold, equipment
## space), per-merchant ledgers, and the item_purchased signal.

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

var _stock: MerchantStock
## Equipment, 100 gold, one copy per save.
var _blade: MerchantStockEntry
## Consumable, 10 gold, unlimited.
var _scale: MerchantStockEntry

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_blade = _make_entry("test_blade", _make_equipment("test_blade", 100.0), 1)
	_scale = _make_entry("test_scale", _make_consumable("test_scale", 10.0), 0)
	_stock = _make_stock("test_merchant", [_blade, _scale])

func _make_equipment(item_id: String, price: float) -> EquipmentDefinitionData:
	var item := EquipmentDefinitionData.new()
	item.item_id = item_id
	item.item_name = "Test Blade"
	item.base_value = price
	return item

func _make_consumable(item_id: String, price: float) -> ConsumableDefinitionData:
	var item := ConsumableDefinitionData.new()
	item.item_id = item_id
	item.item_name = "Test Scale"
	item.base_value = price
	return item

func _make_entry(entry_id: String, item: ItemDefinitionData, stock_limit: int) -> MerchantStockEntry:
	var entry := MerchantStockEntry.new()
	entry.entry_id = entry_id
	entry.item = item
	entry.stock_limit = stock_limit
	return entry

func _make_stock(merchant_id: String, entries: Array[MerchantStockEntry]) -> MerchantStock:
	var stock := MerchantStock.new()
	stock.merchant_id = merchant_id
	stock.entries = entries
	return stock

func _fill_equipment() -> void:
	var inventory := InventoryManager.get_inventory()
	for i: int in inventory.equipment_capacity():
		inventory.equipment[i] = ItemInstanceData.new()

func _equipment_key_of(item_id: String) -> int:
	var inventory := InventoryManager.get_inventory()
	for key: int in inventory.equipment:
		var instance: ItemInstanceData = inventory.equipment[key]
		if instance.item_definition and instance.item_definition.item_id == item_id:
			return key
	return -1

#-----------------------------------------------------------------------------
# SUCCESSFUL PURCHASES
#-----------------------------------------------------------------------------

func test_purchase_spends_gold_and_awards_equipment() -> void:
	ResourceManager.set_gold(150.0)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.OK)
	assert_eq(ResourceManager.get_gold(), 50.0)
	assert_true(InventoryManager.has_item("test_blade"))
	assert_eq(MerchantManager.get_purchase_count(_stock, _blade), 1)

func test_exact_gold_is_enough() -> void:
	ResourceManager.set_gold(100.0)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.OK)
	assert_eq(ResourceManager.get_gold(), 0.0)

func test_unlimited_entry_never_sells_out() -> void:
	ResourceManager.set_gold(30.0)
	for i: int in 3:
		assert_eq(MerchantManager.purchase(_stock, _scale), MerchantManager.PurchaseResult.OK)
	assert_eq(InventoryManager.get_inventory().consumables.get(_scale.item, 0), 3)
	assert_eq(MerchantManager.get_purchase_count(_stock, _scale), 3)
	assert_eq(MerchantManager.get_remaining_stock(_stock, _scale), -1)

#-----------------------------------------------------------------------------
# STOCK LIMITS
#-----------------------------------------------------------------------------

func test_second_purchase_is_sold_out_and_charged_once() -> void:
	ResourceManager.set_gold(300.0)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.OK)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.SOLD_OUT)
	assert_eq(ResourceManager.get_gold(), 200.0, "the sold-out click must not charge")

func test_sold_out_survives_trashing() -> void:
	ResourceManager.set_gold(300.0)
	MerchantManager.purchase(_stock, _blade)
	var key := _equipment_key_of("test_blade")
	assert_ne(key, -1, "the bought blade should be in the equipment grid")
	InventoryManager.get_inventory().equipment.erase(key)
	assert_false(InventoryManager.has_item("test_blade"))
	assert_eq(MerchantManager.get_purchase_status(_stock, _blade), MerchantManager.PurchaseResult.SOLD_OUT)

func test_remaining_stock_counts_down() -> void:
	ResourceManager.set_gold(100.0)
	assert_eq(MerchantManager.get_remaining_stock(_stock, _blade), 1)
	MerchantManager.purchase(_stock, _blade)
	assert_eq(MerchantManager.get_remaining_stock(_stock, _blade), 0)

func test_limits_are_tracked_per_merchant() -> void:
	var cowl := _make_equipment("test_cowl", 10.0)
	var stock_a := _make_stock("merchant_a", [_make_entry("test_cowl", cowl, 1)])
	var stock_b := _make_stock("merchant_b", [_make_entry("test_cowl", cowl, 3)])
	var entry_a: MerchantStockEntry = stock_a.entries[0]
	var entry_b: MerchantStockEntry = stock_b.entries[0]
	ResourceManager.set_gold(1000.0)

	assert_eq(MerchantManager.purchase(stock_a, entry_a), MerchantManager.PurchaseResult.OK)
	assert_eq(MerchantManager.get_purchase_status(stock_a, entry_a), MerchantManager.PurchaseResult.SOLD_OUT)
	for i: int in 3:
		assert_eq(MerchantManager.purchase(stock_b, entry_b), MerchantManager.PurchaseResult.OK,
			"merchant B keeps its own limit of 3 (copy %d)" % (i + 1))
	assert_eq(MerchantManager.get_purchase_status(stock_b, entry_b), MerchantManager.PurchaseResult.SOLD_OUT)

#-----------------------------------------------------------------------------
# BLOCKED PURCHASES
#-----------------------------------------------------------------------------

func test_insufficient_gold_changes_nothing() -> void:
	ResourceManager.set_gold(99.0)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.INSUFFICIENT_GOLD)
	assert_eq(ResourceManager.get_gold(), 99.0)
	assert_false(InventoryManager.has_item("test_blade"))
	assert_eq(MerchantManager.get_purchase_count(_stock, _blade), 0)
	assert_eq(MerchantManager.get_gold_shortfall(_blade), 1)

func test_full_equipment_blocks_before_spending() -> void:
	_fill_equipment()
	ResourceManager.set_gold(500.0)
	assert_eq(MerchantManager.purchase(_stock, _blade), MerchantManager.PurchaseResult.EQUIPMENT_FULL)
	assert_eq(ResourceManager.get_gold(), 500.0)
	assert_eq(MerchantManager.get_purchase_count(_stock, _blade), 0)

func test_consumable_ignores_full_equipment() -> void:
	_fill_equipment()
	ResourceManager.set_gold(500.0)
	assert_eq(MerchantManager.purchase(_stock, _scale), MerchantManager.PurchaseResult.OK)
	assert_eq(InventoryManager.get_inventory().consumables.get(_scale.item, 0), 1)

func test_invalid_entries() -> void:
	ResourceManager.set_gold(1000.0)
	var nameless_stock := _make_stock("", [_blade])
	var idless_entry := _make_entry("", _make_equipment("test_axe", 10.0), 1)
	var itemless_entry := _make_entry("test_nothing", null, 1)

	assert_eq(MerchantManager.purchase(null, _blade), MerchantManager.PurchaseResult.INVALID_ENTRY, "null stock")
	assert_eq(MerchantManager.purchase(nameless_stock, _blade), MerchantManager.PurchaseResult.INVALID_ENTRY, "empty merchant_id")
	assert_eq(MerchantManager.purchase(_stock, null), MerchantManager.PurchaseResult.INVALID_ENTRY, "null entry")
	assert_eq(MerchantManager.purchase(_stock, idless_entry), MerchantManager.PurchaseResult.INVALID_ENTRY, "empty entry_id")
	assert_eq(MerchantManager.purchase(_stock, itemless_entry), MerchantManager.PurchaseResult.INVALID_ENTRY, "no item")
	assert_eq(ResourceManager.get_gold(), 1000.0, "invalid purchases must not charge")

#-----------------------------------------------------------------------------
# QUERIES AND SIGNALS
#-----------------------------------------------------------------------------

func test_status_has_no_side_effects() -> void:
	ResourceManager.set_gold(150.0)
	assert_eq(MerchantManager.get_purchase_status(_stock, _blade), MerchantManager.PurchaseResult.OK)
	assert_eq(ResourceManager.get_gold(), 150.0)
	assert_false(InventoryManager.has_item("test_blade"))
	assert_eq(MerchantManager.get_purchase_count(_stock, _blade), 0)

func test_item_purchased_emitted_only_on_success() -> void:
	watch_signals(MerchantManager)
	ResourceManager.set_gold(50.0)
	MerchantManager.purchase(_stock, _blade)
	assert_signal_not_emitted(MerchantManager, "item_purchased")

	ResourceManager.set_gold(150.0)
	MerchantManager.purchase(_stock, _blade)
	assert_signal_emitted_with_parameters(MerchantManager, "item_purchased", [_stock, _blade])
