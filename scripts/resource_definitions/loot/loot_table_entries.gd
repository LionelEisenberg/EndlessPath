class_name LootTableEntry 
extends Resource

## Represents a single item entry in the loot table

## The item that can be awarded
@export var item: ItemDefinitionData

## Probability of this item dropping (0.0 = never, 1.0 = always)
@export_range(0.0, 1.0) var drop_chance: float = 1.0

## Minimum quantity to award if the drop succeeds
@export var min_quantity: int = 1

## Maximum quantity to award if the drop succeeds
@export var max_quantity: int = 1

func _to_string() -> String:
	var item_name = "None"
	if item:
		item_name = item.item_name
	return "LootTableEntry { Item: %s, Chance: %.1f%%, Qty: %d-%d }" % [
		item_name,
		drop_chance * 100.0,
		min_quantity,
		max_quantity
	]
