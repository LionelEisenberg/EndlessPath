class_name ItemDetailCard
extends PanelContainer

## Reusable item detail card. Shows icon, name, type, description, effects
## for any ItemDefinitionData / ItemInstanceData. The existing
## ItemDescriptionPanel stays in place for Equipment for now; this newer
## card lives in scenes/inventory/common/ so Materials, Consumables, and
## the Journal can all share one look.

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

## Populate from an ItemDefinitionData.
func setup_from_definition(def: ItemDefinitionData) -> void:
	if def == null:
		reset()
		return
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
	effects_label.visible = not effects.is_empty()
	if effects_label.visible:
		effects_label.text = "\n".join(effects)

## Populate from an ItemInstanceData (delegates to the definition).
func setup(instance: ItemInstanceData) -> void:
	if instance == null or instance.item_definition == null:
		reset()
		return
	setup_from_definition(instance.item_definition)

## Clear everything.
func reset() -> void:
	item_icon.texture = null
	item_name_label.text = ""
	item_type_label.text = ""
	description_label.text = ""
	effects_label.text = ""
	effects_label.visible = false
