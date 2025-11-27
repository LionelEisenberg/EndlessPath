class_name AbilitiesPanel
extends Panel

@onready var ability_container: HBoxContainer = $MarginContainer/HBoxContainer

## Adds an ability button to the panel.
func add_button(button: AbilityButton) -> void:
	ability_container.add_child(button)

## Resets the panel by removing all buttons.
func reset() -> void:
	for child in ability_container.get_children():
		child.queue_free()
