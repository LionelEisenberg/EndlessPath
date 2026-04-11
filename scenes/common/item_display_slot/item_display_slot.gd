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
@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_type: Label = %TooltipType
@onready var tooltip_description: RichTextLabel = %TooltipDescription
@onready var tooltip_effects: RichTextLabel = %TooltipEffects

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
	add_child(_item_instance)
	move_child(_item_instance, 0)
	_item_instance.setup(_item_data)

func _populate_tooltip() -> void:
	if not _item_data or not _item_data.item_definition:
		return

	var def: ItemDefinitionData = _item_data.item_definition
	tooltip_icon.texture = def.icon
	tooltip_name.text = def.item_name

	var type_text: String = def._get_item_type()
	if def is EquipmentDefinitionData:
		var equip: EquipmentDefinitionData = def as EquipmentDefinitionData
		var slot_name: String = EquipmentDefinitionData.EquipmentSlot.keys()[equip.slot_type].replace("_", " ").capitalize()
		type_text = "%s - %s" % [type_text, slot_name]
	tooltip_type.text = "[%s]" % type_text

	tooltip_description.text = def.description

	var effects: Array[String] = def._get_item_effects()
	if effects.is_empty():
		tooltip_effects.visible = false
	else:
		tooltip_effects.visible = true
		tooltip_effects.text = "\n".join(effects)

func _on_mouse_entered() -> void:
	if not _item_data:
		return
	_populate_tooltip()
	tooltip_panel.visible = true
	# Position tooltip above the slot
	tooltip_panel.position = Vector2(
		(size.x - tooltip_panel.size.x) / 2.0,
		-tooltip_panel.size.y - 8.0
	)

func _on_mouse_exited() -> void:
	tooltip_panel.visible = false
