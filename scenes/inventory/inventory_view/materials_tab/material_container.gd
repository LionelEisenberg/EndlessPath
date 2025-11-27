extends MarginContainer

@export var material_data : MaterialDefinitionData = null
@export var material_quantity : int = 0

@onready var material_icon : TextureRect = %MaterialIcon
@onready var material_name : Label = %MaterialName
@onready var material_quantity_label: Label = %MaterialQuantity

func _ready() -> void:
	if material_data and material_quantity != 0:
		populate_material()

func populate_material() -> void:
	material_icon.texture = material_data.icon
	material_name.text = material_data.item_name
	material_quantity_label.text = str(material_quantity)
