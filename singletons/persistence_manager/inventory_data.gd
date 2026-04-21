class_name InventoryData
extends Resource

## Dictionary of Material -> Quantity of Material Owned
@export var materials : Dictionary[MaterialDefinitionData, int] = {}

## Dictionary of Slot Index -> ItemInstanceData (Unequipped gear)
@export var equipment: Dictionary = {} # Dictionary[int, ItemInstanceData]

## Dictionary of EquipmentSlot -> ItemInstanceData (Equipped gear)
@export var equipped_gear: Dictionary = {} # Dictionary[EquipmentDefinitionData.EquipmentSlot, ItemInstanceData]

## Dictionary of ItemDefinitionData (QUEST_ITEM type) -> Quantity owned.
@export var quest_items: Dictionary[ItemDefinitionData, int] = {}

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, quest_items: %s)" % [materials, equipment, equipped_gear, quest_items]
