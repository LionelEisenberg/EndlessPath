class_name AbilitiesPanel
extends Panel

@onready var ability_container : HBoxContainer = $MarginContainer/HBoxContainer

func add_button(button : AbilityButton) -> void:
	ability_container.add_child(button)

func reset() -> void:
	for child in ability_container.get_children():
		child.queue_free()
