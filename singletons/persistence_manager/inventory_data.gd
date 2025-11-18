class_name InventoryData
extends Resource

## Dictionary of Material -> Quantity of Material Owned
@export var materials : Dictionary[MaterialDefinitionData, int] = {}

func _to_string() -> String:
	return "InventoryData(materials: %s)" % materials
