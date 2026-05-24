class_name InventoryData
extends Resource

## Dictionary of Material -> Quantity of Material Owned
@export var materials : Dictionary[MaterialDefinitionData, int] = {}

## Dictionary of Slot Index -> ItemInstanceData (Unequipped gear)
@export var equipment: Dictionary = {} # Dictionary[int, ItemInstanceData]

## Dictionary of EquipmentSlot -> ItemInstanceData (Equipped gear, singular slots only — MAIN_HAND/OFF_HAND/HEAD/ARMOR)
@export var equipped_gear: Dictionary = {} # Dictionary[EquipmentDefinitionData.EquipmentSlot, ItemInstanceData]

## Equipped accessories indexed by physical slot (0 or 1). Accessories all share
## slot_type = ACCESSORY; the index distinguishes the two physical slots in the UI.
@export var equipped_accessories: Dictionary = {} # Dictionary[int, ItemInstanceData]

## Dictionary of ItemDefinitionData (QUEST_ITEM type) -> Quantity owned.
@export var quest_items: Dictionary[ItemDefinitionData, int] = {}

## Dictionary of ConsumableDefinitionData -> Quantity owned. Stacks like materials.
@export var consumables: Dictionary[ConsumableDefinitionData, int] = {}

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, equipped_accessories: %s, quest_items: %s, consumables: %s)" % [materials, equipment, equipped_gear, equipped_accessories, quest_items, consumables]
