extends Control

signal tab_changed(index: int)

var current_tab_index: int = 0
@onready var equipment_tab_button: Control = %EquipmentTabButton
@onready var materials_tab_button: Control = %MaterialsTabButton
@onready var tab_buttons: Array[Control] = [
	equipment_tab_button, 
	materials_tab_button
]

func _ready() -> void:
	for i in range(tab_buttons.size()):
		print(tab_buttons[i])
		tab_buttons[i].tab_opened.connect(_on_tab_button_opened.bind(tab_buttons[i]))
		if i == 0:
			tab_buttons[0].open()
			current_tab_index = 0
		else:
			tab_buttons[i].close()

func _on_tab_button_opened(button: Node) -> void:
	var new_index = tab_buttons.find(button)
	
	# If clicking the already selected tab, do nothing
	if new_index == current_tab_index:
		return
		
	# Close the previously selected tab
	if current_tab_index >= 0 and current_tab_index < tab_buttons.size():
		tab_buttons[current_tab_index].close()
	
	button.open()
	
	current_tab_index = new_index
	tab_changed.emit(current_tab_index)
