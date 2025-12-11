extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted whenever the inventory collection changes.
signal inventory_changed(inventory: InventoryData)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var live_save_data: SaveGameData

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		Log.critical("InventoryManager: PersistenceManager or save data missing on ready()")
		return
	else:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(func(): live_save_data = PersistenceManager.save_game_data)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

func get_inventory() -> InventoryData:
	return live_save_data.inventory

func get_material_items() -> Dictionary[MaterialDefinitionData, int]:
	return live_save_data.inventory.materials

func award_items(item: ItemDefinitionData, quantity: int) -> void:
	match item.item_type:
		ItemDefinitionData.ItemType.MATERIAL:
			if item is MaterialDefinitionData:
				_award_material(item as MaterialDefinitionData, quantity)
				if LogManager:
					LogManager.log_message("[color=light_gray]Looted %dx %s[/color]" % [quantity, item.item_name])
			else:
				Log.error("InventoryManager: Item type not supported: %s" % item.item_type)
		ItemDefinitionData.ItemType.EQUIPMENT:
			if item is EquipmentDefinitionData:
				_award_equipment(item as EquipmentDefinitionData, quantity)
				if LogManager:
					LogManager.log_message("[color=purple]Looted %dx %s[/color]" % [quantity, item.item_name])
			else:
				Log.error("InventoryManager: Item type not supported: %s" % item.item_type)
		_:
			Log.error("InventoryManager: Item type not supported: %s" % item.item_type)

func equip_item(instance: ItemInstanceData, slot: EquipmentDefinitionData.EquipmentSlot, from_index: int = -1) -> void:
	var inventory = get_inventory()
	
	# Check if something is already equipped in that slot
	if inventory.equipped_gear.has(slot):
		var currently_equipped = inventory.equipped_gear[slot]
		# Move currently equipped back to equipment list (first available slot)
		_add_to_first_available_slot(inventory, currently_equipped)
		inventory.equipped_gear.erase(slot)
	
	# Remove from equipment list if it's there
	if from_index != -1:
		if inventory.equipment.has(from_index) and inventory.equipment[from_index] == instance:
			inventory.equipment.erase(from_index)
	else:
		# Fallback: find by value if index not provided (less safe with duplicates)
		var key_to_remove = -1
		for key in inventory.equipment:
			if inventory.equipment[key] == instance:
				key_to_remove = key
				break
		if key_to_remove != -1:
			inventory.equipment.erase(key_to_remove)
	
	# Equip new item
	inventory.equipped_gear[slot] = instance
	inventory_changed.emit(inventory)

func unequip_item(slot: EquipmentDefinitionData.EquipmentSlot) -> void:
	var inventory = get_inventory()
	
	if inventory.equipped_gear.has(slot):
		var item = inventory.equipped_gear[slot]
		inventory.equipped_gear.erase(slot)
		_add_to_first_available_slot(inventory, item)
		inventory_changed.emit(inventory)

func unequip_item_to_slot(slot: EquipmentDefinitionData.EquipmentSlot, target_index: int) -> void:
	var inventory = get_inventory()
	
	if inventory.equipped_gear.has(slot):
		var item = inventory.equipped_gear[slot]
		
		# Check if target slot is occupied
		if inventory.equipment.has(target_index):
			var existing_item = inventory.equipment[target_index]
			# Swap: equip the existing item, unequip the current one to this slot
			# But wait, can we equip the existing item? Only if it fits the slot.
			if existing_item.item_definition is EquipmentDefinitionData and existing_item.item_definition.slot_type == slot:
				inventory.equipped_gear[slot] = existing_item
				inventory.equipment[target_index] = item
			else:
				# Cannot swap (type mismatch), so just dump to first available? 
				# Or fail? For drag and drop, we usually expect a swap or return.
				# If we can't swap, we should probably just add to first available or cancel.
				# Let's try to add to first available as fallback.
				inventory.equipped_gear.erase(slot)
				_add_to_first_available_slot(inventory, item)
		else:
			# Empty slot, just move there
			inventory.equipped_gear.erase(slot)
			inventory.equipment[target_index] = item
			
		inventory_changed.emit(inventory)

func move_equipment(from_index: int, to_index: int) -> void:
	var inventory = get_inventory()
	
	if inventory.equipment.has(from_index):
		var item = inventory.equipment[from_index]
		
		if inventory.equipment.has(to_index):
			# Swap
			var target_item = inventory.equipment[to_index]
			inventory.equipment[to_index] = item
			inventory.equipment[from_index] = target_item
		else:
			# Move to empty
			inventory.equipment.erase(from_index)
			inventory.equipment[to_index] = item
			
		inventory_changed.emit(inventory)

func get_equipped_item(slot: EquipmentDefinitionData.EquipmentSlot) -> ItemInstanceData:
	var inventory = get_inventory()
	return inventory.equipped_gear.get(slot, null)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _award_material(material: MaterialDefinitionData, quantity: int) -> void:
	if live_save_data.inventory.materials.has(material):
		live_save_data.inventory.materials[material] += quantity
	else:
		live_save_data.inventory.materials[material] = quantity
	inventory_changed.emit(get_inventory())

func _award_equipment(equipment_def: EquipmentDefinitionData, quantity: int) -> void:
	var inventory = get_inventory()
	for i in quantity:
		var instance = ItemInstanceData.new()
		instance.item_definition = equipment_def
		instance.quantity = 1
		_add_to_first_available_slot(inventory, instance)
	
	inventory_changed.emit(inventory)

func _add_to_first_available_slot(inventory: InventoryData, item: ItemInstanceData) -> void:
	# Find first available slot index
	# Assuming a max slot count, e.g., 50 from EquipmentGrid
	# We should probably define this constant somewhere shared.
	var max_slots = 50
	
	for i in max_slots:
		if not inventory.equipment.has(i):
			inventory.equipment[i] = item
			return
	
	Log.warn("InventoryManager: Inventory full, cannot add equipment.")
