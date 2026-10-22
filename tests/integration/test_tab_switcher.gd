extends GutTest

## Integration tests for the menu books' side tabs: locked tabs and the
## switcher that opens them.

const TabButtonScene := preload("res://scenes/inventory/inventory_view/tab_switcher/tab_button.tscn")
const TabSwitcherScript := preload("res://scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd")

func _button_of(tab: Control) -> Button:
	return tab.find_child("Button", true, false) as Button

func _switcher_with_tabs(count: int) -> Control:
	var switcher := Control.new()
	switcher.set_script(TabSwitcherScript)
	for i: int in range(count):
		switcher.add_child(TabButtonScene.instantiate())
	add_child_autofree(switcher)
	return switcher

#-----------------------------------------------------------------------------
# TAB BUTTON
#-----------------------------------------------------------------------------

func test_locked_button_ignores_press() -> void:
	var tab: Control = add_child_autofree(TabButtonScene.instantiate())
	tab.set_locked(true, "Reach Copper to open this chapter.")
	watch_signals(tab)
	_button_of(tab).pressed.emit()
	assert_signal_not_emitted(tab, "tab_opened")
	assert_eq(_button_of(tab).tooltip_text, "Reach Copper to open this chapter.")
	assert_true((tab.find_child("LockIcon", true, false) as CanvasItem).visible)

func test_unlocked_button_opens() -> void:
	var tab: Control = add_child_autofree(TabButtonScene.instantiate())
	tab.set_locked(true, "hint")
	tab.set_locked(false)
	watch_signals(tab)
	_button_of(tab).pressed.emit()
	assert_signal_emitted(tab, "tab_opened")
	assert_eq(_button_of(tab).tooltip_text, "")
	assert_false((tab.find_child("LockIcon", true, false) as CanvasItem).visible)

#-----------------------------------------------------------------------------
# SWITCHER
#-----------------------------------------------------------------------------

func test_switcher_collects_its_child_tabs() -> void:
	var switcher: Control = _switcher_with_tabs(3)
	assert_eq(switcher.tab_buttons.size(), 3)

func test_pressing_a_tab_reports_it() -> void:
	var switcher: Control = _switcher_with_tabs(3)
	watch_signals(switcher)
	_button_of(switcher.tab_buttons[2]).pressed.emit()
	assert_signal_emitted_with_parameters(switcher, "tab_changed", [2])

func test_select_tab_does_not_report() -> void:
	var switcher: Control = _switcher_with_tabs(3)
	watch_signals(switcher)
	switcher.select_tab(1)
	assert_eq(switcher.current_tab_index, 1)
	assert_signal_not_emitted(switcher, "tab_changed")
