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

## Consumables equipped to the combat hotbar. Keys are physical slot
## indices 0..3 (corresponding to hotkeys 1..4). Stack count is read
## from `consumables`, not stored here.
@export var equipped_consumables: Dictionary[int, ConsumableDefinitionData] = {}

## Slots per equipment page (6 columns × 6 rows). Global slot index for
## page P, local position i is P * SLOTS_PER_PAGE + i.
const SLOTS_PER_PAGE := 36

## Number of equipment pages the player has unlocked. Starts at 1; granted
## by InventoryManager.grant_equipment_page(). Total capacity is
## unlocked_equipment_pages * SLOTS_PER_PAGE.
@export var unlocked_equipment_pages: int = 1

## Total equipment slots currently available across all unlocked pages.
func equipment_capacity() -> int:
	return unlocked_equipment_pages * SLOTS_PER_PAGE

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, equipped_accessories: %s, quest_items: %s, consumables: %s, equipped_consumables: %s)" % [materials, equipment, equipped_gear, equipped_accessories, quest_items, consumables, equipped_consumables]
