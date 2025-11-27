class_name ItemInstance
extends Control

@onready var item_icon : TextureRect = %ItemIcon

var item_instance_data: ItemInstanceData = null

func _ready() -> void:
	pass

func setup(d: ItemInstanceData):
	item_instance_data = d
	item_icon.texture = item_instance_data.item_definition.icon
