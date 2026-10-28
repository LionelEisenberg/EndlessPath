class_name ConsumablesHotbar
extends VBoxContainer

## ConsumablesHotbar
## The combat hotbar's four slots in a row, with their keys (1 to 4) printed
## under them. Reads from InventoryManager.equipped_consumables
## (slot_index -> def) and InventoryManager.consumables (def -> count).
## Refreshes automatically on inventory_changed. Re-emits each child slot's
## clicks, drops and hovers.

signal slot_clicked(slot: HotbarSlot, event: InputEvent)
## Re-emitted from a child slot when a consumable is dropped onto it. `from_slot`
## is the source slot for a slot-to-slot move, or -1 when dragged from the list.
signal consumable_dropped(def: ConsumableDefinitionData, slot_index: int, from_slot: int)
## Re-emitted when the pointer enters a child slot.
signal slot_hovered(slot: HotbarSlot)

@onready var _slots: Array[HotbarSlot] = [
	%SlotsRow.get_child(0) as HotbarSlot,
	%SlotsRow.get_child(1) as HotbarSlot,
	%SlotsRow.get_child(2) as HotbarSlot,
	%SlotsRow.get_child(3) as HotbarSlot,
]

func _ready() -> void:
	for s in _slots:
		s.slot_clicked.connect(_on_slot_clicked)
		s.consumable_dropped.connect(_on_consumable_dropped)
		s.hovered.connect(_on_slot_hovered)
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_refresh(InventoryManager.get_inventory())

func _refresh(inv: InventoryData) -> void:
	for i in 4:
		var def: ConsumableDefinitionData = inv.equipped_consumables.get(i, null)
		var count: int = 0
		if def != null:
			count = inv.consumables.get(def, 0)
		_slots[i].setup(def, count)

func _on_inventory_changed(inv: InventoryData) -> void:
	_refresh(inv)

func _on_slot_clicked(slot: HotbarSlot, event: InputEvent) -> void:
	slot_clicked.emit(slot, event)

func _on_consumable_dropped(def: ConsumableDefinitionData, slot_index: int, from_slot: int) -> void:
	consumable_dropped.emit(def, slot_index, from_slot)

func _on_slot_hovered(slot: HotbarSlot) -> void:
	slot_hovered.emit(slot)
