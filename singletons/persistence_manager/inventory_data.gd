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

## Equipment page dimensions. SLOTS_PER_PAGE derives from these so the data
## capacity and the EquipmentGrid layout share one definition of page size
## (EquipmentGrid's num_rows / num_columns exports default to these).
const PAGE_ROWS := 6
const PAGE_COLUMNS := 6
## Slots per equipment page. Global slot index for page P, local position i is
## P * SLOTS_PER_PAGE + i.
const SLOTS_PER_PAGE := PAGE_ROWS * PAGE_COLUMNS

## Number of equipment pages the player has unlocked. Starts at 2; granted
## by InventoryManager.grant_equipment_page(). Total capacity is
## unlocked_equipment_pages * SLOTS_PER_PAGE.
@export var unlocked_equipment_pages: int = 2

## Total equipment slots currently available across all unlocked pages.
func equipment_capacity() -> int:
	return unlocked_equipment_pages * SLOTS_PER_PAGE

## The empty slots below equipment_capacity(), lowest first. The one scan for a free
## slot: an awarded item goes into the first, and the rest answer how much room is left.
func free_equipment_slots() -> PackedInt32Array:
	var free := PackedInt32Array()
	for i: int in equipment_capacity():
		if not equipment.has(i):
			free.append(i)
	return free

## True while any slot below equipment_capacity() is empty.
func has_free_equipment_slot() -> bool:
	return not free_equipment_slots().is_empty()

func _to_string() -> String:
	return "InventoryData(materials: %s, equipment: %s, equipped_gear: %s, equipped_accessories: %s, quest_items: %s, consumables: %s, equipped_consumables: %s)" % [materials, equipment, equipped_gear, equipped_accessories, quest_items, consumables, equipped_consumables]
