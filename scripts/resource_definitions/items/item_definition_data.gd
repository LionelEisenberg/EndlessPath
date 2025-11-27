class_name ItemDefinitionData
extends Resource

enum ItemType {
	MATERIAL,
	CONSUMABLE,
	EQUIPMENT,
	QUEST_ITEM
}

@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export var stack_size: int = 99  # Max stack size
@export var base_value: float = 0.0  # Base gold value

func _to_string() -> String:
	return "ItemDefinitionData(item_id: %s, item_name: %s, description: %s, icon: %s, item_type: %s, stack_size: %s, base_value: %s)" % [
		item_id,
		item_name,
		description,
		icon,
		item_type,
		stack_size,
		base_value
	]

func _get_item_type() -> String:
	match item_type:
		ItemType.MATERIAL:
			return "Material"
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.EQUIPMENT:
			return "Equipment"
		ItemType.QUEST_ITEM:
			return "Quest Item"
		_:
			Log.warn("ItemDefinitionData: item_type %s not recognized" % str(item_type))
			return ""

func _get_item_effects() -> Array[String]:
	return []
