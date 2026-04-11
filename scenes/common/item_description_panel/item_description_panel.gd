class_name ItemDescriptionPanel
extends MarginContainer

## ItemDescriptionPanel
## A reusable item description display that shows icon, name, type,
## description, and effects for any item. Used anchored in the inventory
## sidebar and floating as a tooltip on the end card.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var item_type_label: Label = %ItemType
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var effects_label: RichTextLabel = %EffectsLabel

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populates the panel with data from an ItemInstanceData.
func setup(item_instance_data: ItemInstanceData) -> void:
	if not item_instance_data or not item_instance_data.item_definition:
		reset()
		return

	var def: ItemDefinitionData = item_instance_data.item_definition
	item_icon.texture = def.icon
	item_name_label.text = def.item_name

	var type_text: String = def._get_item_type()
	if def is EquipmentDefinitionData:
		var equip: EquipmentDefinitionData = def as EquipmentDefinitionData
		var slot_name: String = EquipmentDefinitionData.EquipmentSlot.keys()[equip.slot_type].replace("_", " ").capitalize()
		type_text = "%s - %s" % [type_text, slot_name]
	item_type_label.text = "[%s]" % type_text

	description_label.text = def.description

	var effects: Array[String] = def._get_item_effects()
	if effects.is_empty():
		effects_label.visible = false
	else:
		effects_label.visible = true
		effects_label.text = "\n".join(effects)

## Populates the panel directly from an ItemDefinitionData (convenience).
func setup_from_definition(definition: ItemDefinitionData) -> void:
	var instance_data := ItemInstanceData.new()
	instance_data.item_definition = definition
	setup(instance_data)

## Clears all fields to empty state.
func reset() -> void:
	item_icon.texture = null
	item_name_label.text = ""
	item_type_label.text = ""
	description_label.text = ""
	effects_label.text = ""
	effects_label.visible = false
