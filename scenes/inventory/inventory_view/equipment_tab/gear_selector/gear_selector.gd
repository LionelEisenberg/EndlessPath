extends Control

signal slot_clicked(slot: GearSlot, event: InputEvent)

var slots: Array[GearSlot] = []

func _ready() -> void:
	_setup_slots()
	
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_update_slots(InventoryManager.get_inventory())

func _setup_slots() -> void:
	var group_slots: Array[Node] = get_tree().get_nodes_in_group("GearSlots")
	for slot in group_slots:
		if slot is GearSlot:
			slots.append(slot)
			slot.clicked.connect(_on_slot_clicked)
	_validate_slot_coverage()

func _validate_slot_coverage() -> void:
	var covered_slots: Dictionary = {}
	for slot in slots:
		if covered_slots.has(slot.slot_type):
			Log.warn("GearSelector: Duplicate GearSlot for %s" % EquipmentDefinitionData.EquipmentSlot.keys()[slot.slot_type])
		covered_slots[slot.slot_type] = true

	for slot_value: int in EquipmentDefinitionData.EquipmentSlot.values():
		if not covered_slots.has(slot_value):
			Log.error("GearSelector: Missing GearSlot for %s — items in this slot will be unequippable" % EquipmentDefinitionData.EquipmentSlot.keys()[slot_value])

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	if slot is GearSlot:
		slot_clicked.emit(slot, event)

func _on_inventory_changed(inventory: InventoryData) -> void:
	_update_slots(inventory)

func _update_slots(inventory: InventoryData) -> void:
	for slot in slots:
		var item_data = inventory.equipped_gear.get(slot.slot_type, null)
		slot.setup(item_data)

## Returns all gear slots managed by this selector.
func get_slots() -> Array[GearSlot]:
	return slots
