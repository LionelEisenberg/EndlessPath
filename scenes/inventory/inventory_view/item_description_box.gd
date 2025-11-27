extends TextureRect

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_type: Label = %ItemType
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var effects_label: RichTextLabel = %EffectsLabel

func _ready() -> void:
	pass

func _setup(item_instance_data: ItemInstanceData) -> void:
	item_icon.texture = item_instance_data.item_definition.icon
	item_name.text = item_instance_data.item_definition.item_name
	var type = item_instance_data.item_definition._get_item_type()
	if item_instance_data.item_definition is EquipmentDefinitionData:
		type = "%s - %s" % [type, (item_instance_data.item_definition as EquipmentDefinitionData)._get_equipment_type()]
	item_type.text = "[%s]" % type
	description_label.text = item_instance_data.item_definition.description
	effects_label.text = "\n".join(item_instance_data.item_definition._get_item_effects())
