class_name AwardLootTableEffectData
extends EffectData

## AwardLootTableEffectData
## An effect that rolls a LootTable and awards all resulting items to the player's inventory.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## The loot table to roll when this effect is processed
@export var loot_table: LootTable

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var table_info = "None"
	if loot_table:
		table_info = "%d entries" % loot_table.entries.size()
	return "AwardLootTableEffectData {\n LootTable: %s\n}" % table_info

#-----------------------------------------------------------------------------
# EFFECT PROCESSING
#-----------------------------------------------------------------------------

func process() -> void:
	if not loot_table:
		Log.error("AwardLootTableEffectData: Loot table is null!")
		return
	
	# Roll the loot table
	var rolled_items: Dictionary = loot_table.roll_loot()
	
	if rolled_items.is_empty():
		Log.info("AwardLootTableEffectData: No items were rolled from the loot table")
		return
	
	# Award each item to the inventory
	if not InventoryManager:
		Log.error("AwardLootTableEffectData: InventoryManager is not found!")
		return
	
	for item in rolled_items:
		var quantity: int = rolled_items[item]
		Log.info("AwardLootTableEffectData: Awarding %s x%d" % [item.item_name, quantity])
		InventoryManager.award_items(item, quantity)
