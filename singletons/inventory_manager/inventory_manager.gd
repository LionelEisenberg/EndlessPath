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
		printerr("InventoryManager: PersistenceManager or save data missing on ready()")
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
			else:
				printerr("InventoryManager: Item type not supported: %s" % item.item_type)
		_:
			printerr("InventoryManager: Item type not supported: %s" % item.item_type)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _award_material(material: MaterialDefinitionData, quantity: int) -> void:
	if live_save_data.inventory.materials.has(material):
		live_save_data.inventory.materials[material] += quantity
	else:
		live_save_data.inventory.materials[material] = quantity
	inventory_changed.emit(get_inventory())
