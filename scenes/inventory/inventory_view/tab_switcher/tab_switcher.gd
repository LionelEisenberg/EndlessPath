extends Control

## Side tabs of a menu book: the tab buttons that are this node's children, in
## order. Opening one slides it out, slides the others in and reports its
## index. Locked tabs never open.

signal tab_changed(index: int)

var current_tab_index: int = 0
var tab_buttons: Array[Control] = []

func _ready() -> void:
	for child: Node in get_children():
		if child.has_signal("tab_opened"):
			tab_buttons.append(child as Control)
	for i in range(tab_buttons.size()):
		tab_buttons[i].tab_opened.connect(_on_tab_button_opened.bind(tab_buttons[i]))
		if i == 0:
			tab_buttons[0].open()
			current_tab_index = 0
		else:
			tab_buttons[i].close()

## Opens the tab at index without reporting tab_changed, for a book that picks
## its own opening page.
func select_tab(index: int) -> void:
	if index < 0 or index >= tab_buttons.size() or index == current_tab_index:
		return
	tab_buttons[current_tab_index].close()
	tab_buttons[index].open()
	current_tab_index = index

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
