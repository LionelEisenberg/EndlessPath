extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted whenever the inventory collection changes.
signal inventory_changed(inventory: InventoryData)

## Emitted when a specific item is awarded, with the definition and quantity.
signal item_awarded(item: ItemDefinitionData, quantity: int)

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
	item_awarded.emit(item, quantity)
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
		ItemDefinitionData.ItemType.QUEST_ITEM:
			_award_quest_item(item, quantity)
			if LogManager:
				LogManager.log_message("[color=yellow]Obtained %dx %s[/color]" % [quantity, item.item_name])
		_:
			Log.error("InventoryManager: Item type not supported: %s" % item.item_type)

func equip_item(instance: ItemInstanceData, slot: EquipmentDefinitionData.EquipmentSlot, from_index: int = -1) -> void:
	var inventory = get_inventory()
	
	# Check if something is already equipped in that slot
	var has_equipped = inventory.equipped_gear.has(slot)
	if has_equipped:
		var currently_equipped = inventory.equipped_gear[slot]
		# Swap: move currently equipped to where the dragged item came from
		if from_index != -1:
			inventory.equipment[from_index] = currently_equipped
		else:
			_add_to_first_available_slot(inventory, currently_equipped)
		inventory.equipped_gear.erase(slot)

	# Remove the dragged item from the grid (only if we didn't already swap into its slot)
	if not has_equipped:
		if from_index != -1:
			inventory.equipment.erase(from_index)
		else:
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

	if not inventory.equipped_gear.has(slot):
		return

	var item = inventory.equipped_gear[slot]

	# If target slot has a compatible item, swap it into the gear slot
	if inventory.equipment.has(target_index):
		var existing_item = inventory.equipment[target_index]
		if existing_item.item_definition is EquipmentDefinitionData and existing_item.item_definition.slot_type == slot:
			inventory.equipped_gear[slot] = existing_item
		else:
			inventory.equipped_gear.erase(slot)
	else:
		inventory.equipped_gear.erase(slot)

	# Place unequipped item at the target slot
	inventory.equipment[target_index] = item
	inventory_changed.emit(inventory)

## Swap items between two gear slots directly (e.g., Accessory 1 to Accessory 2).
## Avoids routing through the grid which can match the wrong instance with duplicates.
func swap_gear_slots(from_slot: EquipmentDefinitionData.EquipmentSlot, to_slot: EquipmentDefinitionData.EquipmentSlot) -> void:
	var inventory = get_inventory()
	var from_item: ItemInstanceData = inventory.equipped_gear.get(from_slot, null)
	var to_item: ItemInstanceData = inventory.equipped_gear.get(to_slot, null)

	if from_item == null:
		Log.error("InventoryManager: swap_gear_slots called with empty from_slot")
		return

	# Place from_item into the target gear slot
	inventory.equipped_gear[to_slot] = from_item

	# Place to_item (if any) into the source gear slot, otherwise clear it
	if to_item:
		inventory.equipped_gear[from_slot] = to_item
	else:
		inventory.equipped_gear.erase(from_slot)

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

func _award_quest_item(item: ItemDefinitionData, quantity: int) -> void:
	if live_save_data.inventory.quest_items.has(item):
		live_save_data.inventory.quest_items[item] += quantity
	else:
		live_save_data.inventory.quest_items[item] = quantity
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
