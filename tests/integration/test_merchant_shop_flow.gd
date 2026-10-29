extends GutTest

## Integration tests for Merchant v1: the ActionManager route (the shop stays
## open until stop_action() closes it) and the shop view bound to real stock,
## including broken stock data and the gold preview while Buy is hovered.

const ZONE_ID: String = "SpiritValley"
const ACTION_ID: String = "spirit_valley_merchant"
const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres"
## The event whose unlock condition opens Spring Forest Foraging.
const FORAGING_UNLOCK_EVENT: String = "q_fill_core_completed"
const TEST_ZONE_ID: String = "TestZone"
## Test Zone's own unlock condition (zone_unlock_conditions in test_zone.tres).
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"

## An idle action added to Test Zone (which has none) for the travel test.
var _fixture_idle: ForageActionData = null

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
	if _fixture_idle != null:
		ZoneManager.get_zone_by_id(TEST_ZONE_ID).all_actions.erase(_fixture_idle)
		_fixture_idle = null

## Gives Test Zone an idle action and unlocks the zone, so travel there has
## something to resume.
func _add_fixture_idle_to_test_zone() -> void:
	_fixture_idle = ForageActionData.new()
	_fixture_idle.action_id = "test_merchant_flow_fixture_forage"
	_fixture_idle.action_name = "Fixture Foraging"
	_fixture_idle.action_type = ZoneActionData.ActionType.FORAGE
	ZoneManager.get_zone_by_id(TEST_ZONE_ID).all_actions.append(_fixture_idle)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)

## Foraging runs, then the shop replaces it, as when the player visits the
## merchant mid-forage.
func _open_shop_over_foraging() -> ZoneActionData:
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	var foraging := _foraging_action()
	ActionManager.select_action(foraging)
	ActionManager.select_action(_merchant_action())
	return foraging

## An Escape press, as MerchantViewState.handle_input receives it.
func _escape_event() -> InputEventAction:
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	return escape

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
	# Only an available idle action resumes, and a fresh save locks foraging.
	EventManager.trigger_event(FORAGING_UNLOCK_EVENT)
	var foraging := _foraging_action()
	ActionManager.select_action(foraging)
	ActionManager.select_action(_merchant_action())
	ActionManager.stop_action()
	assert_eq(ActionManager.get_current_action(), foraging, "leaving the shop resumes foraging, like closing a menu")

func test_zone_change_with_locked_idle_resumes_nothing() -> void:
	ActionManager.select_action(_foraging_action())
	ActionManager.select_action(_merchant_action())
	ZoneManager.zone_changed.emit(ZoneManager.get_current_zone())
	assert_null(ActionManager.get_current_action(), "foraging is locked on a fresh save, so nothing resumes")

func test_zone_change_during_shop_resumes_destination_idle() -> void:
	_open_shop_over_foraging()
	_add_fixture_idle_to_test_zone()
	watch_signals(ActionManager)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	assert_signal_emit_count(ActionManager, "stop_merchant", 1, "travel closes the shop")
	assert_eq(ActionManager.get_current_action(), _fixture_idle, "arriving starts the destination's idle action, not the old zone's foraging")

## Leave pressed twice during the shop's 0.2 s fade-out: the shop is still the
## top state, so the second press must not stop the idle action the first one
## resumed. A bare state (outside the tree) never connects to the view.
func test_second_leave_keeps_the_resumed_idle_running() -> void:
	var foraging := _open_shop_over_foraging()
	var state: MerchantViewState = autofree(MerchantViewState.new())
	state._on_close_requested()
	state._on_close_requested()
	assert_eq(ActionManager.get_current_action(), foraging, "the second Leave must not stop the resumed foraging")
	assert_false(ActionManager.action_timer.is_stopped(), "foraging keeps ticking")

func test_second_escape_keeps_the_resumed_idle_running() -> void:
	var foraging := _open_shop_over_foraging()
	var state: MerchantViewState = autofree(MerchantViewState.new())
	state.handle_input(_escape_event())
	state.handle_input(_escape_event())
	assert_eq(ActionManager.get_current_action(), foraging, "the second Escape must not stop the resumed foraging")
	assert_false(ActionManager.action_timer.is_stopped(), "foraging keeps ticking")

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
## Repeated to be longer than one line at any font size the header could use.
const GREETING_FILLER: String = "A long merchant greeting that goes on. "

func _make_view() -> MerchantView:
	var view: MerchantView = MerchantViewScene.instantiate()
	add_child_autofree(view)
	await get_tree().process_frame
	return view

## The Spirit Valley merchant, selling entries instead of its own stock.
func _action_selling(entries: Array[MerchantStockEntry]) -> MerchantActionData:
	var stock := MerchantStock.new()
	stock.merchant_id = "test_merchant"
	stock.entries = entries
	var action: MerchantActionData = _merchant_action().duplicate()
	action.stock = stock
	return action

func _fill_equipment() -> void:
	var inventory := InventoryManager.get_inventory()
	for i: int in inventory.equipment_capacity():
		inventory.equipment[i] = ItemInstanceData.new()

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
	assert_eq(scale_reason.text, MerchantStockRow.MSG_NEED_GOLD % 10)

func test_rows_refresh_when_gold_changes() -> void:
	ResourceManager.set_gold(0.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	view.show()
	ResourceManager.set_gold(1000.0)
	for row: MerchantStockRow in _visible_rows(view):
		assert_false(row.get_node("%BuyButton").disabled, "%s is affordable now" % row.get_entry().entry_id)
		assert_false(row.get_node("%BlockReasonLabel").visible)

func test_closed_shop_skips_refresh_until_setup() -> void:
	ResourceManager.set_gold(0.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	view.hide()
	ResourceManager.set_gold(1000.0)
	var dagger_buy: Button = _row_for(view, "makeshift_dagger").get_node("%BuyButton")
	assert_true(dagger_buy.disabled, "a closed shop ignores gold changes")
	view.setup(_merchant_action())
	assert_false(dagger_buy.disabled, "opening the shop refreshes every row")

func test_gear_rows_read_equipment_full() -> void:
	ResourceManager.set_gold(1000.0)
	_fill_equipment()
	var view := await _make_view()
	view.setup(_merchant_action())
	var dagger_row := _row_for(view, "makeshift_dagger")
	var reason: Label = dagger_row.get_node("%BlockReasonLabel")
	assert_true(reason.visible)
	assert_eq(reason.text, MerchantStockRow.MSG_EQUIPMENT_FULL)
	assert_true(dagger_row.get_node("%BuyButton").disabled, "gear can't be bought without a free slot")
	assert_false(_row_for(view, "crude_scale").get_node("%BuyButton").disabled, "Crude Scales don't take an equipment slot")

func test_buy_press_purchases_and_reports() -> void:
	ResourceManager.set_gold(100.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	var dagger_row := _row_for(view, "makeshift_dagger")
	dagger_row.get_node("%BuyButton").pressed.emit()
	assert_eq(ResourceManager.get_gold(), 40.0)
	assert_true(InventoryManager.has_item("makeshift_dagger"))
	assert_eq(view.get_node("%StatusLabel").text, MerchantView.MSG_BOUGHT % "Makeshift Dagger")
	assert_true(dagger_row.get_node("%SoldOutLabel").visible)
	assert_false(dagger_row.get_node("%BuyButton").visible)

func test_extra_entries_beyond_rows_are_ignored() -> void:
	var real_entries: Array[MerchantStockEntry] = _merchant_action().stock.entries
	var entries: Array[MerchantStockEntry] = real_entries.duplicate()
	entries.append(real_entries[0])
	entries.append(real_entries[1])
	var view := await _make_view()
	view.setup(_action_selling(entries))
	assert_eq(entries.size(), 9)
	var shown := _visible_rows(view)
	assert_eq(shown.size(), 8, "rows beyond the 8 pre-built ones are dropped")
	for i: int in shown.size():
		assert_same(shown[i].get_entry(), entries[i], "row %d shows entry %d, in stock order" % [i + 1, i + 1])

func test_merchant_without_stock_shows_no_rows() -> void:
	var stockless: MerchantActionData = _merchant_action().duplicate()
	stockless.stock = null
	var view := await _make_view()
	view.setup(stockless)
	assert_eq(_visible_rows(view).size(), 0)

func test_entries_without_item_hide_their_rows() -> void:
	var real_entries: Array[MerchantStockEntry] = _merchant_action().stock.entries
	var itemless := MerchantStockEntry.new()
	itemless.entry_id = "test_nothing"
	var entries: Array[MerchantStockEntry] = [real_entries[0], itemless, null, real_entries[1]]
	var view := await _make_view()
	view.setup(_action_selling(entries))
	var rows := _rows(view)
	assert_true(rows[0].visible)
	assert_false(rows[1].visible, "an entry with no item has nothing to show")
	assert_false(rows[2].visible, "an empty stock slot has nothing to show")
	assert_true(rows[3].visible)
	assert_same(rows[3].get_entry(), real_entries[1], "later rows still show their own entries")

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

func test_long_greeting_wraps() -> void:
	var view := await _make_view()
	var talkative: MerchantActionData = _merchant_action().duplicate()
	talkative.greeting = GREETING_FILLER.repeat(8)
	view.setup(talkative)
	view.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var greeting: Label = view.get_node("%GreetingLabel")
	assert_gt(greeting.get_line_count(), 1, "a long greeting wraps")

#-----------------------------------------------------------------------------
# GOLD PREVIEW WHILE BUY IS HOVERED
#-----------------------------------------------------------------------------

func _buy_button(view: MerchantView, entry_id: String) -> Button:
	return _row_for(view, entry_id).get_node("%BuyButton")

func test_hovering_buy_shows_the_gold_left_after() -> void:
	ResourceManager.set_gold(215.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	_buy_button(view, "crude_scale").mouse_entered.emit()
	var after: Label = view.get_node("%GoldAfterLabel")
	assert_true(after.visible)
	assert_eq(after.text, MerchantView.MSG_GOLD_LEFT % 205)
	assert_false((view.get_node("%GoldShortLabel") as Label).visible)

func test_hovering_a_disabled_buy_shows_the_shortfall() -> void:
	ResourceManager.set_gold(100.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	_buy_button(view, "reinforced_robes").mouse_entered.emit()
	var short: Label = view.get_node("%GoldShortLabel")
	assert_true(short.visible)
	assert_eq(short.text, MerchantView.MSG_GOLD_SHORT % 80)
	assert_false((view.get_node("%GoldAfterLabel") as Label).visible)

func test_leaving_buy_clears_the_preview() -> void:
	ResourceManager.set_gold(215.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	_buy_button(view, "crude_scale").mouse_entered.emit()
	_buy_button(view, "crude_scale").mouse_exited.emit()
	assert_false((view.get_node("%GoldAfterLabel") as Label).visible)
	assert_false((view.get_node("%GoldShortLabel") as Label).visible)

func test_preview_follows_a_purchase() -> void:
	ResourceManager.set_gold(215.0)
	var view := await _make_view()
	view.setup(_merchant_action())
	_buy_button(view, "crude_scale").mouse_entered.emit()
	_buy_button(view, "crude_scale").pressed.emit()
	assert_eq((view.get_node("%GoldAfterLabel") as Label).text, MerchantView.MSG_GOLD_LEFT % 195, "with 205 left, the next scale leaves 195")
