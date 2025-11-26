class_name AwardItemEffectData
extends EffectData

@export var item: ItemDefinitionData
@export var quantity: int = 1

func _to_string() -> String:
	var item_name = "None"
	if item:
		item_name = item.item_name
	return "AwardItemEffectData {\n Item: %s,\n Quantity: %s\n}" % [item_name, quantity]

func process() -> void:
	Log.info("AwardItemEffectData: Awarding item: %s, quantity: %s" % [item, quantity])

	if InventoryManager:
		InventoryManager.award_items(item, quantity)
	else:
		Log.error("AwardItemEffectData: InventoryManager is not found!")
