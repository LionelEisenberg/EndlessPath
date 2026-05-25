class_name CombatHotbar
extends VBoxContainer

## CombatHotbar
## A row of 4 HotbarSlots. Reads from InventoryManager.equipped_consumables
## (slot_index -> def) and InventoryManager.consumables (def -> count).
## Refreshes automatically on inventory_changed. Re-emits slot_clicked from
## any child slot.

signal slot_clicked(slot: HotbarSlot, event: InputEvent)

@onready var _slots: Array[HotbarSlot] = [
	%SlotsRow.get_child(0) as HotbarSlot,
	%SlotsRow.get_child(1) as HotbarSlot,
	%SlotsRow.get_child(2) as HotbarSlot,
	%SlotsRow.get_child(3) as HotbarSlot,
]

func _ready() -> void:
	for s in _slots:
		s.slot_clicked.connect(_on_slot_clicked)
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
