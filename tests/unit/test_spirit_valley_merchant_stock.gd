extends GutTest

## Content tests for the Spirit Valley merchant: the action's wiring, the stock
## rules from the Merchant v1 spec (gear once per save, Crude Scale unlimited)
## and the data every row needs (ids, prices, icons).

const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

const SPEC_ITEM_IDS: Array[String] = [
	"crude_scale",
	"cultivators_cowl",
	"makeshift_dagger",
	"scripted_bark",
	"leeching_ring",
	"iron_shortsword",
	"reinforced_robes",
]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _action() -> MerchantActionData:
	return load(ACTION_PATH) as MerchantActionData

func _entries() -> Array[MerchantStockEntry]:
	return _action().stock.entries

#-----------------------------------------------------------------------------
# WIRING
#-----------------------------------------------------------------------------

func test_action_is_merchant_action_data() -> void:
	var action := _action()
	assert_not_null(action, "spirit_valley_merchant must load as MerchantActionData")
	assert_eq(action.action_id, "spirit_valley_merchant")
	assert_not_null(action.stock)

func test_stock_has_merchant_id() -> void:
	# The ledger key: renaming it would forget every player's purchases.
	assert_eq(_action().stock.merchant_id, "spirit_valley_merchant")

func test_stock_sells_the_six_gear_pieces_and_crude_scale() -> void:
	var item_ids: Array[String] = []
	for entry: MerchantStockEntry in _entries():
		item_ids.append(entry.item.item_id)
	for item_id: String in SPEC_ITEM_IDS:
		assert_has(item_ids, item_id)

#-----------------------------------------------------------------------------
# RULES
#-----------------------------------------------------------------------------

func test_entry_ids_are_unique_and_set() -> void:
	var seen: Dictionary[String, bool] = {}
	for entry: MerchantStockEntry in _entries():
		assert_false(entry.entry_id.is_empty(), "every entry needs a ledger key")
		assert_false(seen.has(entry.entry_id), "duplicate entry_id %s" % entry.entry_id)
		seen[entry.entry_id] = true

func test_gear_entries_limited_to_one() -> void:
	for entry: MerchantStockEntry in _entries():
		if entry.item.item_type == ItemDefinitionData.ItemType.EQUIPMENT:
			assert_eq(entry.stock_limit, 1, "%s sells once per save" % entry.entry_id)

func test_crude_scale_unlimited() -> void:
	for entry: MerchantStockEntry in _entries():
		if entry.item.item_type == ItemDefinitionData.ItemType.CONSUMABLE:
			assert_true(entry.is_unlimited(), "%s never sells out" % entry.entry_id)

func test_every_entry_has_a_positive_price() -> void:
	for entry: MerchantStockEntry in _entries():
		assert_gt(entry.get_price(), 0, "%s would be free (missing base_value?)" % entry.entry_id)

func test_every_entry_has_icon() -> void:
	for entry: MerchantStockEntry in _entries():
		assert_not_null(entry.item.icon, "%s would render an empty slot" % entry.entry_id)
