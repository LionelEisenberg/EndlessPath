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
	# Non-accessory slots: each EquipmentSlot must have exactly one GearSlot.
	# Accessories: must have exactly two GearSlots with accessory_index 0 and 1.
	var covered_singular: Dictionary = {}  # EquipmentSlot -> bool
	var covered_accessory_indices: Dictionary = {}  # int -> bool
	for slot in slots:
		if slot.slot_type == EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
			if covered_accessory_indices.has(slot.accessory_index):
				Log.warn("GearSelector: Duplicate accessory GearSlot at index %d" % slot.accessory_index)
			covered_accessory_indices[slot.accessory_index] = true
		else:
			if covered_singular.has(slot.slot_type):
				Log.warn("GearSelector: Duplicate GearSlot for %s" % EquipmentDefinitionData.EquipmentSlot.keys()[slot.slot_type])
			covered_singular[slot.slot_type] = true

	for slot_value: int in EquipmentDefinitionData.EquipmentSlot.values():
		if slot_value == EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
			for required_index in [0, 1]:
				if not covered_accessory_indices.has(required_index):
					Log.error("GearSelector: Missing accessory GearSlot at index %d" % required_index)
		else:
			if not covered_singular.has(slot_value):
				Log.error("GearSelector: Missing GearSlot for %s — items in this slot will be unequippable" % EquipmentDefinitionData.EquipmentSlot.keys()[slot_value])

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	if slot is GearSlot:
		slot_clicked.emit(slot, event)

func _on_inventory_changed(inventory: InventoryData) -> void:
	_update_slots(inventory)

func _update_slots(inventory: InventoryData) -> void:
	for slot in slots:
		var item_data: ItemInstanceData
		if slot.slot_type == EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
			item_data = inventory.equipped_accessories.get(slot.accessory_index, null)
		else:
			item_data = inventory.equipped_gear.get(slot.slot_type, null)
		slot.setup(item_data)

## Returns all gear slots managed by this selector.
func get_slots() -> Array[GearSlot]:
	return slots
