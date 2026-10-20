class_name MerchantLedgerData
extends Resource

## MerchantLedgerData
## What the player has bought from one merchant this save. Compared with that
## merchant's MerchantStock to find what is sold out. Stored once per merchant
## in SaveGameData.merchant_ledgers.

@export var merchant_id: String = ""

## Dict MerchantStockEntry.entry_id -> copies bought
@export var purchase_counts: Dictionary[String, int] = {}

## Copies of the entry bought so far (0 if never bought).
func get_count(entry_id: String) -> int:
	return purchase_counts.get(entry_id, 0)

## Records one more copy of the entry and returns the new count.
func add_purchase(entry_id: String) -> int:
	purchase_counts[entry_id] = get_count(entry_id) + 1
	return purchase_counts[entry_id]

func _to_string() -> String:
	return "MerchantLedgerData(MerchantId: %s, PurchaseCounts: %s)" % [merchant_id, str(purchase_counts)]
