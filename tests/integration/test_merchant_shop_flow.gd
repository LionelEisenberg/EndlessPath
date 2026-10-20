extends GutTest

## Integration tests for Merchant v1: the ActionManager route (the shop stays
## open until stop_action() closes it) and the shop view bound to real stock.

const ZONE_ID: String = "SpiritValley"
const ACTION_ID: String = "spirit_valley_merchant"
const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	# Never leave an action running for the next test. Closing the shop can
	# resume the idle action it replaced, so stop until nothing is left.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _merchant_action() -> MerchantActionData:
	return load(ACTION_PATH) as MerchantActionData

func _foraging_action() -> ZoneActionData:
	return ZoneManager.get_action_by_id("sprint_forest_foraging_action")

func _cycling_action() -> ZoneActionData:
	return ZoneManager.get_action_by_id("wilderness_cycling_action")

func _completion_count() -> int:
	return ZoneManager.get_zone_progression(ZONE_ID).action_completion_count.get(ACTION_ID, 0)

#-----------------------------------------------------------------------------
# ACTION MANAGER ROUTE
#-----------------------------------------------------------------------------

func test_select_merchant_emits_start_and_stays_current() -> void:
	var action := _merchant_action()
	watch_signals(ActionManager)
	ActionManager.select_action(action)
	assert_signal_emitted_with_parameters(ActionManager, "start_merchant", [action])
	assert_eq(ActionManager.get_current_action(), action, "the shop stays open until something stops it")

func test_stop_action_emits_stop_and_clears() -> void:
	ActionManager.select_action(_merchant_action())
	var count_before := _completion_count()
	watch_signals(ActionManager)
	ActionManager.stop_action()
	assert_signal_emit_count(ActionManager, "stop_merchant", 1)
	assert_null(ActionManager.get_current_action())
	assert_eq(_completion_count(), count_before + 1)

func test_second_stop_is_noop() -> void:
	ActionManager.select_action(_merchant_action())
	watch_signals(ActionManager)
	ActionManager.stop_action()
	ActionManager.stop_action()
	assert_signal_emit_count(ActionManager, "stop_merchant", 1, "Escape during the fade-out must not close twice")

func test_shop_resumes_the_idle_action_it_replaced() -> void:
	var foraging := _foraging_action()
	ActionManager.select_action(foraging)
	ActionManager.select_action(_merchant_action())
	ActionManager.stop_action()
	assert_eq(ActionManager.get_current_action(), foraging, "leaving the shop resumes foraging, like closing a menu")

func test_zone_change_does_not_resume_the_idle_action() -> void:
	ActionManager.select_action(_foraging_action())
	ActionManager.select_action(_merchant_action())
	ZoneManager.zone_changed.emit(ZoneManager.get_current_zone())
	assert_null(ActionManager.get_current_action(), "a zone change ends the visit without restarting the old zone's action")

func test_shop_does_not_resume_cycling() -> void:
	ActionManager.select_action(_cycling_action())
	ActionManager.select_action(_merchant_action())
	ActionManager.stop_action()
	assert_null(ActionManager.get_current_action(), "only idle actions (foraging, training) resume")

#-----------------------------------------------------------------------------
# SHOP VIEW
#-----------------------------------------------------------------------------

const MerchantViewScene := preload("res://scenes/merchant/merchant_view.tscn")
const DEFAULT_THEME_PATH: String = "res://assets/themes/merchant/spirit_valley_merchant_theme.tres"

func _make_view() -> MerchantView:
	var view: MerchantView = MerchantViewScene.instantiate()
	add_child_autofree(view)
	await get_tree().process_frame
	return view

func _rows(view: MerchantView) -> Array[MerchantStockRow]:
	var rows: Array[MerchantStockRow] = []
	for child: Node in view.get_node("%StockList").get_children():
		if child is MerchantStockRow:
			rows.append(child as MerchantStockRow)
	return rows

func _visible_rows(view: MerchantView) -> Array[MerchantStockRow]:
	return _rows(view).filter(func(row: MerchantStockRow) -> bool: return row.visible)

func _row_for(view: MerchantView, entry_id: String) -> MerchantStockRow:
	for row: MerchantStockRow in _visible_rows(view):
		if row.get_entry() and row.get_entry().entry_id == entry_id:
			return row
	return null

func test_setup_binds_real_stock() -> void:
	var view := await _make_view()
	view.setup(_merchant_action())
	assert_eq(_rows(view).size(), 8, "the shop scene pre-builds 8 rows")
	assert_eq(_visible_rows(view).size(), 7, "Spirit Valley sells 7 entries")
	assert_eq(_visible_rows(view)[0].get_node("%NameLabel").text, "Crude Scale")

func test_buy_disabled_when_gold_short() -> void:
	ResourceManager.set_gold(0.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	for row: MerchantStockRow in _visible_rows(view):
		assert_true(row.get_node("%BuyButton").disabled, "%s needs gold" % row.get_entry().entry_id)
	var scale_reason: Label = _row_for(view, "crude_scale").get_node("%BlockReasonLabel")
	assert_true(scale_reason.visible)
	assert_eq(scale_reason.text, "Need 10 more gold")

func test_rows_refresh_when_gold_changes() -> void:
	ResourceManager.set_gold(0.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	ResourceManager.set_gold(1000.0)
	for row: MerchantStockRow in _visible_rows(view):
		assert_false(row.get_node("%BuyButton").disabled, "%s is affordable now" % row.get_entry().entry_id)
		assert_false(row.get_node("%BlockReasonLabel").visible)

func test_buy_press_purchases_and_reports() -> void:
	ResourceManager.set_gold(100.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	var dagger_row := _row_for(view, "makeshift_dagger")
	dagger_row.get_node("%BuyButton").pressed.emit()
	assert_eq(ResourceManager.get_gold(), 40.0)
	assert_true(InventoryManager.has_item("makeshift_dagger"))
	assert_eq(view.get_node("%StatusLabel").text, "Bought Makeshift Dagger.")
	assert_true(dagger_row.get_node("%SoldOutLabel").visible)
	assert_false(dagger_row.get_node("%BuyButton").visible)

func test_extra_entries_beyond_rows_are_ignored() -> void:
	var action: MerchantActionData = _merchant_action().duplicate()
	var stock := MerchantStock.new()
	stock.merchant_id = "test_overflow"
	var entries: Array[MerchantStockEntry] = _merchant_action().stock.entries.duplicate()
	entries.append(entries[0])
	entries.append(entries[1])
	stock.entries = entries
	action.stock = stock
	var view := await _make_view()
	view.setup(action)
	assert_eq(stock.entries.size(), 9)
	assert_eq(_visible_rows(view).size(), 8, "rows beyond the 8 pre-built ones are dropped")

func test_buy_button_never_takes_keyboard_focus() -> void:
	var view := await _make_view()
	view.setup(_merchant_action())
	for row: MerchantStockRow in _visible_rows(view):
		assert_eq(row.get_node("%BuyButton").focus_mode, Control.FOCUS_NONE,
			"Space or Enter after a click must not buy %s again" % row.get_entry().entry_id)

func test_leave_button_emits_close_requested() -> void:
	var view := await _make_view()
	view.setup(_merchant_action())
	watch_signals(view)
	view.get_node("%LeaveButton").pressed.emit()
	assert_signal_emitted(view, "close_requested")

func test_setup_applies_shop_theme() -> void:
	var view := await _make_view()
	var custom := Theme.new()
	var themed: MerchantActionData = _merchant_action().duplicate()
	themed.shop_theme = custom
	view.setup(themed)
	assert_same(view.theme, custom, "a merchant's shop_theme replaces the look")

	var plain: MerchantActionData = _merchant_action().duplicate()
	plain.shop_theme = null
	view.setup(plain)
	assert_not_null(view.theme)
	assert_eq(view.theme.resource_path, DEFAULT_THEME_PATH, "no shop_theme falls back to the scene default")

func test_atmosphere_reads_theme_colours() -> void:
	var view := await _make_view()
	var red_mist := Theme.new()
	red_mist.set_color("mist", "MerchantAtmosphere", Color.RED)
	var themed: MerchantActionData = _merchant_action().duplicate()
	themed.shop_theme = red_mist
	view.setup(themed)
	await get_tree().process_frame
	var atmosphere: MerchantAtmosphere = view.get_node("%MerchantAtmosphere")
	assert_eq(atmosphere.get_node("%MistA").modulate, Color.RED)
