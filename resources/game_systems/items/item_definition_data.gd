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
