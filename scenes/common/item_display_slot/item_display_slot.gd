class_name ItemDisplaySlot
extends Control

## ItemDisplaySlot
## A reusable read-only item display component with hover tooltip.
## Shows an item icon and displays item details on mouse hover.
## Used in the end card loot section and anywhere items need to be displayed.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ITEM_INSTANCE_SCENE := preload("res://scenes/inventory/item_instance/item_instance.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var _description_panel: ItemDescriptionPanel = %ItemDescriptionPanel

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Assign an item definition in the editor to preview this slot.
@export var item_definition: ItemDefinitionData:
	set(value):
		item_definition = value
		if is_node_ready() and item_definition:
			setup_from_definition(item_definition)

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var _item_instance: ItemInstance = null
var _item_data: ItemInstanceData = null

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	tooltip_panel.visible = false

	# If an item was assigned in the editor, set it up
	if item_definition:
		setup_from_definition(item_definition)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Set up the slot with an ItemInstanceData. Displays the item icon.
func setup_from_instance(data: ItemInstanceData) -> void:
	_item_data = data
	_create_icon()

## Set up the slot with an ItemDefinitionData. Creates a wrapper ItemInstanceData.
func setup_from_definition(definition: ItemDefinitionData, quantity: int = 1) -> void:
	var instance_data := ItemInstanceData.new()
	instance_data.item_definition = definition
	instance_data.quantity = quantity
	setup_from_instance(instance_data)

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _create_icon() -> void:
	if _item_instance:
		_item_instance.queue_free()

	_item_instance = ITEM_INSTANCE_SCENE.instantiate()
	_item_instance.use_full_rect = true
	add_child(_item_instance)
	move_child(_item_instance, 0)
	if not _item_instance.is_node_ready():
		await _item_instance.ready
	_item_instance.setup(_item_data)

func _on_mouse_entered() -> void:
	if not _item_data:
		return
	_description_panel.setup(_item_data)
	tooltip_panel.visible = true
	# Position tooltip above the slot
	tooltip_panel.position = Vector2(
		(size.x - tooltip_panel.size.x) / 2.0,
		-tooltip_panel.size.y - 8.0
	)

func _on_mouse_exited() -> void:
	tooltip_panel.visible = false
