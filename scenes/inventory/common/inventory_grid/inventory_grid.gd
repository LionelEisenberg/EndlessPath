class_name InventoryGrid
extends InventoryScrollHost

## InventoryGrid
## A scrollable grid host. The shared add_slot/clear_slots/get_slots API and
## ScrollRail binding live in InventoryScrollHost; this subclass only adds the
## column count for its GridContainer content.

@export var columns: int = 6:
	set(value):
		columns = value
		if is_node_ready():
			(_content as GridContainer).columns = value

func _ready() -> void:
	super._ready()
	(_content as GridContainer).columns = columns
