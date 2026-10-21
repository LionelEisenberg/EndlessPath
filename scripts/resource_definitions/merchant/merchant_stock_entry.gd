class_name MerchantStockEntry
extends Resource

## MerchantStockEntry
## One line of a merchant's stock: the item, how many copies a save may buy
## from this merchant, and the price (the item's base_value).

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Key of this entry in the merchant's ledger. Unique within its MerchantStock
## and stable across releases: renaming it forgets past purchases.
@export var entry_id: String = ""

## The item sold.
@export var item: ItemDefinitionData

## Copies one save may buy from this merchant. 0 = unlimited.
@export_range(0, 99) var stock_limit: int = 0

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Gold price of one copy: the item's base_value, rounded. 0 without an item.
func get_price() -> int:
	if item == null:
		return 0
	return roundi(item.base_value)

## True when a save can buy any number of copies.
func is_unlimited() -> bool:
	return stock_limit <= 0
