# MerchantManager.gd
# AUTOLOADED SINGLETON
extends Node

## MerchantManager
## Buys merchant stock with gold. Owns the purchase rules (stock limits, gold,
## equipment space) and the per-merchant ledgers in
## SaveGameData.merchant_ledgers. ActionManager only opens and closes the shop;
## the shop view asks this manager what each row may do and calls purchase().

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted after a successful purchase, once gold is spent and the item awarded.
signal item_purchased(stock: MerchantStock, entry: MerchantStockEntry)

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## Whether one copy can be bought, checked in this order. Every check runs
## before any gold moves, so a blocked purchase changes nothing.
enum PurchaseResult {
	OK,
	INVALID_ENTRY,
	SOLD_OUT,
	INSUFFICIENT_GOLD,
	EQUIPMENT_FULL,
}

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var live_save_data: SaveGameData

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		Log.critical("MerchantManager: PersistenceManager or save data missing on ready()")
		return
	live_save_data = PersistenceManager.save_game_data
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns whether one copy of entry can be bought from stock right now.
## Has no side effects; the shop uses it to set each row's state.
func get_purchase_status(stock: MerchantStock, entry: MerchantStockEntry) -> PurchaseResult:
	if not _is_valid(stock, entry):
		return PurchaseResult.INVALID_ENTRY
	if get_remaining_stock(stock, entry) == 0:
		return PurchaseResult.SOLD_OUT
	if not ResourceManager.can_afford_gold(entry.get_price()):
		return PurchaseResult.INSUFFICIENT_GOLD
	if entry.item.item_type == ItemDefinitionData.ItemType.EQUIPMENT \
			and not InventoryManager.get_inventory().has_free_equipment_slot():
		return PurchaseResult.EQUIPMENT_FULL
	return PurchaseResult.OK

## Buys one copy of entry from stock: spends the gold, awards the item and
## records it in the merchant's ledger. Returns why nothing happened otherwise.
func purchase(stock: MerchantStock, entry: MerchantStockEntry) -> PurchaseResult:
	var status := get_purchase_status(stock, entry)
	if status != PurchaseResult.OK:
		return status

	var price := entry.get_price()
	if not ResourceManager.spend_gold(price):
		return PurchaseResult.INSUFFICIENT_GOLD
	InventoryManager.award_items(entry.item, 1)
	live_save_data.get_merchant_ledger(stock.merchant_id).add_purchase(entry.entry_id)

	Log.info("MerchantManager: Bought %s from %s for %d gold" % [entry.entry_id, stock.merchant_id, price])
	item_purchased.emit(stock, entry)
	return PurchaseResult.OK

## Copies of entry bought from this merchant so far this save.
func get_purchase_count(stock: MerchantStock, entry: MerchantStockEntry) -> int:
	if not _is_valid(stock, entry):
		return 0
	var ledger: MerchantLedgerData = live_save_data.merchant_ledgers.get(stock.merchant_id, null)
	return ledger.get_count(entry.entry_id) if ledger else 0

## Copies of entry this merchant can still sell this save, or -1 when unlimited.
func get_remaining_stock(stock: MerchantStock, entry: MerchantStockEntry) -> int:
	if not _is_valid(stock, entry):
		return 0
	if entry.is_unlimited():
		return -1
	return maxi(0, entry.stock_limit - get_purchase_count(stock, entry))

## Gold still needed to afford one copy of entry (0 when affordable).
func get_gold_shortfall(entry: MerchantStockEntry) -> int:
	if entry == null:
		return 0
	return maxi(0, ceili(entry.get_price() - ResourceManager.get_gold()))

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _is_valid(stock: MerchantStock, entry: MerchantStockEntry) -> bool:
	return stock != null \
		and not stock.merchant_id.is_empty() \
		and entry != null \
		and not entry.entry_id.is_empty() \
		and entry.item != null

func _on_save_data_reset() -> void:
	live_save_data = PersistenceManager.save_game_data
