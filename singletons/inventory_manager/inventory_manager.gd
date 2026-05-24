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

## Returns the quest items dict from live save data (definition → quantity).
func get_quest_items() -> Dictionary[ItemDefinitionData, int]:
	return live_save_data.inventory.quest_items

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
		ItemDefinitionData.ItemType.CONSUMABLE:
			if item is ConsumableDefinitionData:
				_award_consumable(item as ConsumableDefinitionData, quantity)
				if LogManager:
					LogManager.log_message("[color=cyan]Obtained %dx %s[/color]" % [quantity, item.item_name])
			else:
				Log.error("InventoryManager: Item type not supported: %s" % item.item_type)
		_:
			Log.error("InventoryManager: Item type not supported: %s" % item.item_type)

## Equip an item to the given slot. For ACCESSORY slots, accessory_index (0 or 1)
## selects which of the two physical accessory slots receives the item.
func equip_item(instance: ItemInstanceData, slot: EquipmentDefinitionData.EquipmentSlot, from_index: int = -1, accessory_index: int = -1) -> void:
	var inventory = get_inventory()

	# Check if something is already equipped in that slot
	var has_equipped = _has_equipped(inventory, slot, accessory_index)
	if has_equipped:
		var currently_equipped: ItemInstanceData = _get_equipped(inventory, slot, accessory_index)
		# Swap: move currently equipped to where the dragged item came from
		if from_index != -1:
			inventory.equipment[from_index] = currently_equipped
		else:
			_add_to_first_available_slot(inventory, currently_equipped)
		_erase_equipped(inventory, slot, accessory_index)

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
	_set_equipped(inventory, slot, accessory_index, instance)
	inventory_changed.emit(inventory)

func unequip_item(slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int = -1) -> void:
	var inventory = get_inventory()

	if _has_equipped(inventory, slot, accessory_index):
		var item: ItemInstanceData = _get_equipped(inventory, slot, accessory_index)
		_erase_equipped(inventory, slot, accessory_index)
		_add_to_first_available_slot(inventory, item)
		inventory_changed.emit(inventory)

func unequip_item_to_slot(slot: EquipmentDefinitionData.EquipmentSlot, target_index: int, accessory_index: int = -1) -> void:
	var inventory = get_inventory()

	if not _has_equipped(inventory, slot, accessory_index):
		return

	var item: ItemInstanceData = _get_equipped(inventory, slot, accessory_index)

	# If target slot has a compatible item, swap it into the gear slot
	if inventory.equipment.has(target_index):
		var existing_item = inventory.equipment[target_index]
		if existing_item.item_definition is EquipmentDefinitionData and existing_item.item_definition.slot_type == slot:
			_set_equipped(inventory, slot, accessory_index, existing_item)
		else:
			_erase_equipped(inventory, slot, accessory_index)
	else:
		_erase_equipped(inventory, slot, accessory_index)

	# Place unequipped item at the target slot
	inventory.equipment[target_index] = item
	inventory_changed.emit(inventory)

## Swap the items in the two physical accessory slots (indices 0 and 1).
## Avoids routing through the grid which can match the wrong instance with duplicates.
func swap_accessory_slots(from_index: int, to_index: int) -> void:
	var inventory = get_inventory()
	var from_item: ItemInstanceData = inventory.equipped_accessories.get(from_index, null)
	var to_item: ItemInstanceData = inventory.equipped_accessories.get(to_index, null)

	if from_item == null:
		Log.error("InventoryManager: swap_accessory_slots called with empty from_index")
		return

	# Place from_item into the target accessory slot
	inventory.equipped_accessories[to_index] = from_item

	# Place to_item (if any) into the source accessory slot, otherwise clear it
	if to_item:
		inventory.equipped_accessories[from_index] = to_item
	else:
		inventory.equipped_accessories.erase(from_index)

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

func get_equipped_item(slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int = -1) -> ItemInstanceData:
	var inventory = get_inventory()
	return _get_equipped(inventory, slot, accessory_index)

## Returns true if the player owns at least one item with the given item_id
## across materials, unequipped gear, equipped gear, equipped accessories,
## quest items, or consumables.
func has_item(item_id: String) -> bool:
	var inv := get_inventory()
	for material in inv.materials:
		if material and material.item_id == item_id and inv.materials[material] > 0:
			return true
	for slot_idx in inv.equipment:
		var instance: ItemInstanceData = inv.equipment[slot_idx]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for slot in inv.equipped_gear:
		var instance: ItemInstanceData = inv.equipped_gear[slot]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for acc_idx in inv.equipped_accessories:
		var instance: ItemInstanceData = inv.equipped_accessories[acc_idx]
		if instance and instance.item_definition and instance.item_definition.item_id == item_id:
			return true
	for quest_item in inv.quest_items:
		if quest_item and quest_item.item_id == item_id and inv.quest_items[quest_item] > 0:
			return true
	for consumable in inv.consumables:
		if consumable and consumable.item_id == item_id and inv.consumables[consumable] > 0:
			return true
	return false

## Fire the consumable's effects and decrement the player's stack by one.
## Returns true on success, false if the definition is null or the player
## has none in stock. Does NOT check cooldown — that's the caller's job
## (the future CombatConsumableInstance handles it).
func use_consumable(def: ConsumableDefinitionData) -> bool:
	if def == null:
		Log.error("InventoryManager.use_consumable: null definition")
		return false

	var inventory := get_inventory()
	var count: int = inventory.consumables.get(def, 0)
	if count <= 0:
		Log.warn("InventoryManager.use_consumable: no %s available" % def.item_id)
		return false

	def.use()
	if count == 1:
		inventory.consumables.erase(def)
	else:
		inventory.consumables[def] = count - 1
	inventory_changed.emit(inventory)
	return true

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

func _award_consumable(consumable: ConsumableDefinitionData, quantity: int) -> void:
	if live_save_data.inventory.consumables.has(consumable):
		live_save_data.inventory.consumables[consumable] += quantity
	else:
		live_save_data.inventory.consumables[consumable] = quantity
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

#-----------------------------------------------------------------------------
# EQUIPPED-SLOT ROUTING HELPERS
#-----------------------------------------------------------------------------
# Pick the right backing dict based on slot type. Accessories live in
# equipped_accessories keyed by physical slot index (0/1); everything else
# lives in equipped_gear keyed by EquipmentSlot enum.

func _is_accessory(slot: EquipmentDefinitionData.EquipmentSlot) -> bool:
	return slot == EquipmentDefinitionData.EquipmentSlot.ACCESSORY

func _has_equipped(inventory: InventoryData, slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int) -> bool:
	if _is_accessory(slot):
		return inventory.equipped_accessories.has(accessory_index)
	return inventory.equipped_gear.has(slot)

func _get_equipped(inventory: InventoryData, slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int) -> ItemInstanceData:
	if _is_accessory(slot):
		return inventory.equipped_accessories.get(accessory_index, null)
	return inventory.equipped_gear.get(slot, null)

func _set_equipped(inventory: InventoryData, slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int, item: ItemInstanceData) -> void:
	if _is_accessory(slot):
		inventory.equipped_accessories[accessory_index] = item
	else:
		inventory.equipped_gear[slot] = item

func _erase_equipped(inventory: InventoryData, slot: EquipmentDefinitionData.EquipmentSlot, accessory_index: int) -> void:
	if _is_accessory(slot):
		inventory.equipped_accessories.erase(accessory_index)
	else:
		inventory.equipped_gear.erase(slot)
