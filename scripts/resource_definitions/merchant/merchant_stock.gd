class_name MerchantStock
extends Resource

## MerchantStock
## Everything one merchant sells. Purchases are remembered per merchant in
## SaveGameData.merchant_ledgers, keyed by merchant_id.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Key of this merchant's ledger in the save. Unique across merchants and
## stable across releases: renaming it forgets past purchases.
@export var merchant_id: String = ""

## Stock lines, in display order.
@export var entries: Array[MerchantStockEntry] = []
