extends GutTest

## Unit tests for the Merchant v1 data layer: MerchantStockEntry pricing and
## limits, MerchantActionData defaults, per-merchant ledgers on SaveGameData
## (including save round-trips, old saves and the debug string) and
## InventoryData.has_free_equipment_slot().

const TMP_SAVE_PATH: String = "user://test_merchant_save.tres"
const TMP_OLD_SAVE_PATH: String = "user://test_merchant_old_save.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func after_each() -> void:
	for path: String in [TMP_SAVE_PATH, TMP_OLD_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _make_entry(base_value: float, stock_limit: int = 0) -> MerchantStockEntry:
	var item := EquipmentDefinitionData.new()
	item.item_id = "test_blade"
	item.base_value = base_value
	var entry := MerchantStockEntry.new()
	entry.entry_id = "test_blade"
	entry.item = item
	entry.stock_limit = stock_limit
	return entry

#-----------------------------------------------------------------------------
# MERCHANT STOCK ENTRY
#-----------------------------------------------------------------------------

func test_price_rounds_base_value() -> void:
	assert_eq(_make_entry(149.6).get_price(), 150)

func test_price_is_zero_without_item() -> void:
	var entry := MerchantStockEntry.new()
	assert_eq(entry.get_price(), 0)

func test_stock_limit_zero_is_unlimited() -> void:
	assert_true(_make_entry(10.0, 0).is_unlimited())

func test_stock_limit_one_is_limited() -> void:
	assert_false(_make_entry(10.0, 1).is_unlimited())

#-----------------------------------------------------------------------------
# MERCHANT ACTION DATA
#-----------------------------------------------------------------------------

func test_merchant_action_data_sets_merchant_type() -> void:
	var action := MerchantActionData.new()
	assert_eq(action.action_type, ZoneActionData.ActionType.MERCHANT)

#-----------------------------------------------------------------------------
# LEDGERS
#-----------------------------------------------------------------------------

func test_get_merchant_ledger_creates_on_demand() -> void:
	var data := SaveGameData.new()
	var ledger := data.get_merchant_ledger("spirit_valley_merchant")
	assert_eq(ledger.merchant_id, "spirit_valley_merchant")
	assert_same(data.get_merchant_ledger("spirit_valley_merchant"), ledger,
		"a second call must return the stored ledger, not a fresh one")
	assert_true(data.merchant_ledgers.has("spirit_valley_merchant"))

func test_ledger_counts_per_entry() -> void:
	var ledger := MerchantLedgerData.new()
	assert_eq(ledger.add_purchase("cowl"), 1)
	assert_eq(ledger.add_purchase("cowl"), 2)
	assert_eq(ledger.get_count("cowl"), 2)
	assert_eq(ledger.get_count("ring"), 0)

func test_ledgers_round_trip() -> void:
	var data := SaveGameData.new()
	data.get_merchant_ledger("spirit_valley_merchant").add_purchase("iron_shortsword")
	assert_eq(ResourceSaver.save(data, TMP_SAVE_PATH), OK)

	var loaded: SaveGameData = ResourceLoader.load(TMP_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(loaded.merchant_ledgers.has("spirit_valley_merchant"))
	assert_eq(loaded.get_merchant_ledger("spirit_valley_merchant").get_count("iron_shortsword"), 1)

func test_save_to_string_lists_ledgers() -> void:
	var data := SaveGameData.new()
	data.get_merchant_ledger("spirit_valley_merchant").add_purchase("iron_shortsword")
	var text := str(data)
	assert_string_contains(text, "spirit_valley_merchant")
	assert_string_contains(text, "iron_shortsword")

func test_reset_clears_ledgers() -> void:
	var data := SaveGameData.new()
	data.get_merchant_ledger("spirit_valley_merchant").add_purchase("cowl")
	data.reset()
	assert_true(data.merchant_ledgers.is_empty())

func test_old_save_without_field_loads_empty() -> void:
	var file := FileAccess.open(TMP_OLD_SAVE_PATH, FileAccess.WRITE)
	file.store_string("""[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
gold = 42.0
""")
	file.close()

	var loaded: SaveGameData = ResourceLoader.load(TMP_OLD_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_not_null(loaded)
	assert_eq(loaded.gold, 42.0)
	assert_true(loaded.merchant_ledgers.is_empty(), "a save written before Merchant v1 has no ledgers")

#-----------------------------------------------------------------------------
# INVENTORY CAPACITY
#-----------------------------------------------------------------------------

func test_has_free_equipment_slot() -> void:
	var inventory := InventoryData.new()
	assert_true(inventory.has_free_equipment_slot(), "a new inventory has room")

	for i: int in inventory.equipment_capacity():
		inventory.equipment[i] = ItemInstanceData.new()
	assert_false(inventory.has_free_equipment_slot(), "every slot is taken")

	inventory.equipment.erase(17)
	assert_true(inventory.has_free_equipment_slot(), "one emptied slot is room again")
