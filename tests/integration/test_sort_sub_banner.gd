extends GutTest

const Scene := preload("res://scenes/inventory/common/sort_sub_banner/sort_sub_banner.tscn")

func test_clicking_right_arrow_cycles_options_and_emits_signal() -> void:
	var sb := Scene.instantiate()
	add_child_autofree(sb)
	await get_tree().process_frame
	sb.set_options(["All", "Weapons", "Armor"])
	watch_signals(sb)
	sb.next()
	assert_eq(sb.current_label, "Weapons")
	assert_signal_emitted_with_parameters(sb, "option_changed", [1])

func test_disabled_arrows_dont_emit() -> void:
	var sb := Scene.instantiate()
	add_child_autofree(sb)
	await get_tree().process_frame
	sb.set_options(["All"])
	sb.enabled = false
	watch_signals(sb)
	sb.next()
	assert_signal_not_emitted(sb, "option_changed")
