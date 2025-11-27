extends SceneTree

func _init():
	print("Starting TabSwitcher Test")
	
	# Load the scene
	var inventory_view_scene = load("res://scenes/inventory/inventory_view/inventory_view.tscn")
	var inventory_view = inventory_view_scene.instantiate()
	
	# Add to tree to trigger _ready
	root.add_child(inventory_view)
	
	# Wait a frame for _ready to complete
	await process_frame
	
	var tab_switcher = inventory_view.tab_switcher
	var equipment_tab = inventory_view.get_node("BookBackground/EquipmentTab")
	var materials_tab = inventory_view.get_node("BookBackground/MaterialsTab")
	
	# Test Initial State
	print("Checking Initial State...")
	if tab_switcher.current_tab_index != 0:
		print("FAIL: Initial tab index is not 0. Got: ", tab_switcher.current_tab_index)
	else:
		print("PASS: Initial tab index is 0")
		
	if not equipment_tab.visible:
		print("FAIL: EquipmentTab should be visible initially.")
	else:
		print("PASS: EquipmentTab is visible")
		
	if materials_tab.visible:
		print("FAIL: MaterialsTab should be hidden initially.")
	else:
		print("PASS: MaterialsTab is hidden")
		
	# Test Switching to Tab 1
	print("\nSwitching to Tab 1...")
	var tab_button_1 = tab_switcher.tab_buttons[1]
	# Simulate click by emitting signal directly since we can't easily click in headless
	tab_button_1.tab_opened.emit()
	
	if tab_switcher.current_tab_index != 1:
		print("FAIL: Tab index is not 1 after switch. Got: ", tab_switcher.current_tab_index)
	else:
		print("PASS: Tab index is 1")
		
	if equipment_tab.visible:
		print("FAIL: EquipmentTab should be hidden after switch.")
	else:
		print("PASS: EquipmentTab is hidden")
		
	if not materials_tab.visible:
		print("FAIL: MaterialsTab should be visible after switch.")
	else:
		print("PASS: MaterialsTab is visible")

	# Test Switching back to Tab 0
	print("\nSwitching back to Tab 0...")
	var tab_button_0 = tab_switcher.tab_buttons[0]
	tab_button_0.tab_opened.emit()
	
	if tab_switcher.current_tab_index != 0:
		print("FAIL: Tab index is not 0 after switch back. Got: ", tab_switcher.current_tab_index)
	else:
		print("PASS: Tab index is 0")
		
	if not equipment_tab.visible:
		print("FAIL: EquipmentTab should be visible after switch back.")
	else:
		print("PASS: EquipmentTab is visible")
		
	if materials_tab.visible:
		print("FAIL: MaterialsTab should be hidden after switch back.")
	else:
		print("PASS: MaterialsTab is hidden")
		
	print("\nTest Complete")
	quit()
