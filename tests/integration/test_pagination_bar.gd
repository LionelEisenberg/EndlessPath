extends GutTest

const BarScene := preload("res://scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.tscn")

func _bar() -> PaginationBar:
	var bar := BarScene.instantiate()
	add_child_autofree(bar)
	return bar

func test_setup_creates_one_button_per_page() -> void:
	var bar := _bar()
	await get_tree().process_frame
	bar.setup(3, 0)
	assert_eq(bar.page_buttons.get_child_count(), 3)
	bar.setup(1, 0)
	assert_eq(bar.page_buttons.get_child_count(), 1)

func test_clicking_button_emits_page_selected() -> void:
	var bar := _bar()
	await get_tree().process_frame
	bar.setup(3, 0)
	watch_signals(bar)
	var third_btn: BaseButton = bar.page_buttons.get_child(2)
	third_btn.pressed.emit()
	assert_signal_emitted_with_parameters(bar, "page_selected", [2])

func test_hovering_button_emits_page_hovered() -> void:
	var bar := _bar()
	await get_tree().process_frame
	bar.setup(2, 0)
	watch_signals(bar)
	var second_btn: BaseButton = bar.page_buttons.get_child(1)
	second_btn.mouse_entered.emit()
	assert_signal_emitted_with_parameters(bar, "page_hovered", [1])

func test_has_trash_slot() -> void:
	var bar := _bar()
	await get_tree().process_frame
	assert_not_null(bar.trash_slot)
	assert_true(bar.trash_slot is TrashSlot)
