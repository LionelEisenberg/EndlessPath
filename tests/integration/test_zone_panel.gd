extends GutTest

## Integration tests for the zone chest (ZonePanel, lacquer kit §5.5 and §0):
## the header, the Now strip for each idle action, the grouped activity list,
## the chest hugging its list or folding a long list under its last whole
## drawer, the rail and lips, scrolling to a card, the lore panel, and long
## text never widening the chest (Review Focus 4). The panel is built on a
## fresh save, as the zone view builds it.

const PANEL_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/zone_panel.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"

const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const MERCHANT_ID: String = "spirit_valley_merchant"

const AURA_WELL_EVENT: String = "aura_well_discovered"
const FORAGING_EVENT: String = "q_fill_core_completed"

const THUMB_RIVER: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_ai.png")
const THUMB_BASIC: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_basic_ai.png")

## Chest layout, local to the chest (kit §0, §5.5).
const LIST_TOP_WITH_STRIP: float = 208.0
const LIST_TOP_COLLAPSED: float = 108.0
const LORE_PUSH: float = 276.0
const FULL_CHEST_HEIGHT: float = 1032.0
const FOLD_GAP: float = 8.0
const SCROLL_MARGIN: float = 24.0

## GUT's output window's canvas layer.
const GUT_LAYER: int = 128

var _panel: ZonePanel = null

## Zone names a test changed, restored after it.
var _renamed_zone: ZoneData = null
var _original_zone_name: String = ""

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	if _renamed_zone != null:
		_renamed_zone.zone_name = _original_zone_name
		_renamed_zone = null
	_panel = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Adds the panel and waits two frames for its layout.
func _add_panel() -> ZonePanel:
	_panel = PANEL_SCENE.instantiate() as ZonePanel
	add_child_autofree(_panel)
	await wait_process_frames(2)
	return _panel

## Adds the panel on a canvas layer above GUT's output window, which covers
## the screen on layer 128 and would take the clicks a test pushes.
func _add_panel_above_gut() -> ZonePanel:
	var layer := CanvasLayer.new()
	layer.layer = GUT_LAYER + 1
	add_child_autofree(layer)
	_panel = PANEL_SCENE.instantiate() as ZonePanel
	layer.add_child(_panel)
	await wait_process_frames(2)
	return _panel

func _node(unique_name: String) -> Node:
	return _panel.get_node("%" + unique_name)

func _list() -> Control:
	return _node("ActivityList") as Control

func _list_node(unique_name: String) -> Node:
	return _list().get_node("%" + unique_name)

func _strip() -> NowStrip:
	return _node("NowStrip") as NowStrip

func _strip_node(unique_name: String) -> Node:
	return _strip().get_node("%" + unique_name)

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## Latches every unlock condition of every Spirit Valley action, so all nine
## of its actions are listed, then runs the Aura Well.
func _unlock_everything() -> void:
	var valley: ZoneData = ZoneManager.get_zone_by_id(SPIRIT_VALLEY_ID)
	for action: ZoneActionData in valley.all_actions:
		for condition: UnlockConditionData in action.unlock_conditions:
			UnlockManager.force_unlock_condition(condition.condition_id)
	ActionManager.select_action(ZoneManager.get_action_by_id(AURA_WELL_ID))

## Every visible Label and RichTextLabel text under the node.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if child is Label:
			texts.append((child as Label).text)
		elif child is RichTextLabel:
			texts.append((child as RichTextLabel).get_parsed_text())
		texts.append_array(_texts(child))
	return texts

## The group label texts of the activity list, top to bottom.
func _group_names() -> Array[String]:
	var names: Array[String] = []
	for group: Node in _list_node("Content").get_children():
		var label: Label = group.find_child("GroupLabel", true, false) as Label
		if label != null and label.is_visible_in_tree():
			names.append(label.text)
	return names

func _scroll() -> ScrollContainer:
	return _list_node("Scroll") as ScrollContainer

## True when the whole card shows inside the list's viewport.
func _card_fully_visible(action_id: String) -> bool:
	var card: Control = _panel.get_card(action_id)
	if card == null:
		return false
	var view: Rect2 = _scroll().get_global_rect()
	var rect: Rect2 = card.get_global_rect()
	return rect.position.y >= view.position.y and rect.end.y <= view.end.y

func _card_flashing(action_id: String) -> bool:
	var card: Control = _panel.get_card(action_id)
	return (card.get_node("%FlashFrame") as LacquerFrameOverlay).is_flashing()

func _escape_event() -> InputEventAction:
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	return escape

## Pushes a mouse button press (and, for a click, its release) at a point in
## the viewport's own 1920x1080 space: the headless window is scaled down, so
## the event goes in local coordinates.
func _push_mouse_button(point: Vector2, button: MouseButton, with_release: bool) -> void:
	var states: Array[bool] = [true]
	if with_release:
		states.append(false)
	for pressed: bool in states:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

func _click(point: Vector2) -> void:
	_push_mouse_button(point, MOUSE_BUTTON_LEFT, true)

## The flow ActivityList computes from its constants must be the height the
## scenes' containers lay out, or the folds and scroll targets drift.
func _assert_flow_matches_scenes() -> void:
	var list: ActivityList = _list() as ActivityList
	assert_eq(list.get_content_height(), _scroll().get_v_scroll_bar().max_value,
		"the computed flow matches the laid-out content")

#-----------------------------------------------------------------------------
# ROOT AND HEADER
#-----------------------------------------------------------------------------

func test_root_is_the_chest_and_stops_clicks() -> void:
	await _add_panel()
	assert_eq(_panel.position, Vector2(1456.0, 24.0))
	assert_eq(_panel.size.x, 440.0)
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_panel.theme, load("res://assets/themes/lacquer/lacquer_theme.tres"))

func test_header_shows_zone_name() -> void:
	await _add_panel()
	assert_eq((_node("ZoneNameLabel") as Label).text, "Spirit Valley")
	assert_eq((_node("Thumb") as TextureRect).texture, THUMB_RIVER, "Spirit Valley's river tile")
	assert_true((_node("AboutButton") as Control).visible, "Spirit Valley has lore")

func test_buttons_take_no_keyboard_focus() -> void:
	# A clicked About or rail cap must not keep focus: Space or Enter
	# (ui_accept) would then toggle the lore or step the list unseen.
	await _add_panel()
	var rail: Control = _list_node("Rail") as Control
	for button: Control in [_node("AboutButton"), rail.get_node("%UpCap"), rail.get_node("%DownCap")]:
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "%s takes no focus" % button.name)

func test_header_follows_zone_change() -> void:
	await _add_panel()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	assert_eq((_node("ZoneNameLabel") as Label).text, "Test Zone")
	assert_eq((_node("Thumb") as TextureRect).texture, THUMB_BASIC)
	assert_false((_node("AboutButton") as Control).visible, "Test Zone has no lore")

func test_long_zone_name_ellipsizes() -> void:
	_renamed_zone = ZoneManager.get_zone_by_id(SPIRIT_VALLEY_ID)
	_original_zone_name = _renamed_zone.zone_name
	_renamed_zone.zone_name = "The Exceedingly Long Valley of Many Names ".repeat(3)
	await _add_panel()
	var name_label: Label = _node("ZoneNameLabel") as Label
	assert_eq(_panel.size.x, 440.0, "the chest stays 440 wide")
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_lte(name_label.get_global_rect().end.x, (_node("AboutButton") as Control).get_global_rect().position.x,
		"the name stops before About")

#-----------------------------------------------------------------------------
# NOW STRIP
#-----------------------------------------------------------------------------

func test_fresh_save_collapses_strip_and_moves_list() -> void:
	await _add_panel()
	assert_false(_panel.is_now_strip_shown(), "nothing idle runs on a fresh save")
	assert_false(_strip().visible)
	assert_eq(_list().position.y, LIST_TOP_COLLAPSED, "the list moves up to the strip's space")

func test_strip_shows_for_aura_well() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")
	await wait_process_frames(2)
	assert_true(_panel.is_now_strip_shown())
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Aura Well")
	assert_has(texts, "+1.5 Madra / s")
	assert_has(texts, "Lv 0 → 1 · +1 Spirit")
	assert_has(texts, "0 / 60")
	assert_eq(_list().position.y, LIST_TOP_WITH_STRIP, "the list sits under the strip")

func test_strip_follows_training_ticks() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	var well: TrainingActionData = ZoneManager.get_action_by_id(AURA_WELL_ID) as TrainingActionData
	var ticks: int = ZoneManager.increment_training_ticks(AURA_WELL_ID, SPIRIT_VALLEY_ID, 75)
	ActionManager.training_tick_processed.emit(well, ticks)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Lv 1 → 2 · +1 Spirit")
	assert_has(texts, "15 / 300")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), roundi(15.0 / 300.0 * 152.0))

func test_strip_shows_for_foraging() -> void:
	await _add_panel()
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	assert_true(_panel.is_now_strip_shown())
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Spring Forest Foraging")
	assert_has(texts, "1–5")
	assert_has(texts, "2–6")
	assert_has(texts, "haul in 5 s")
	assert_false((_strip_node("TrainingContent") as Control).visible)

func test_strip_shows_each_items_mini_icon() -> void:
	await _add_panel()
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	var icons: Array[Texture2D] = []
	for node: Node in _strip().find_children("Icon", "TextureRect", true, false):
		if (node as TextureRect).is_visible_in_tree():
			icons.append((node as TextureRect).texture)
	var expected: Array[Texture2D] = []
	for entry: LootTableEntry in (ZoneManager.get_action_by_id(FORAGING_ID) as ForageActionData).loot_table.entries:
		expected.append(entry.item.get_mini_icon())
	assert_eq(icons, expected, "the kit's mini dewdrop and fern, from the item data")

func test_strip_hidden_while_cycling() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	_unlock_everything()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	assert_false(_panel.is_now_strip_shown(), "cycling is not an idle action")
	assert_eq(_list().position.y, LIST_TOP_COLLAPSED)

func test_ring_frame_follows_the_action_timer() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(1)
	var ring: LacquerStripRect = _strip_node("Ring") as LacquerStripRect
	var timer: Timer = ActionManager.action_timer
	timer.start(1.0)
	await wait_process_frames(1)
	assert_lte(ring.get_frame().x, 1, "a fresh tick lights no more than one bead")
	await wait_seconds(0.5)
	# floor((1 - time_left / wait_time) x 13), about 6 or 7 half way through the tick.
	assert_between(ring.get_frame().x, 3, 10, "the ring lights beads as the tick runs")

func test_strip_press_flashes_the_running_card() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	_strip().strip_pressed.emit()
	assert_true(_card_flashing(AURA_WELL_ID))

func test_running_card_press_flashes_the_strip() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	var card: ZoneActionButton = _panel.get_card(AURA_WELL_ID) as ZoneActionButton
	card.card_pressed_while_running.emit()
	assert_true((_strip_node("FlashFrame") as LacquerFrameOverlay).is_flashing())

#-----------------------------------------------------------------------------
# ACTIVITY LIST
#-----------------------------------------------------------------------------

func test_groups_in_order_with_labels() -> void:
	await _add_panel()
	assert_eq(_group_names(), ["Talk"] as Array[String], "a fresh save lists only the first dialogue")
	_unlock_everything()
	await wait_process_frames(2)
	assert_eq(_group_names(), ["Talk", "Cultivate", "Gather", "Venture", "Visit"] as Array[String])

func test_count_label() -> void:
	await _add_panel()
	assert_eq((_node("CountLabel") as Label).text, "1 here")
	_unlock_everything()
	await wait_process_frames(2)
	assert_eq((_node("CountLabel") as Label).text, "9 here")

func test_rebuilds_on_unlock() -> void:
	await _add_panel()
	assert_null(_panel.get_card(AURA_WELL_ID), "precondition: the Aura Well is locked")
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	assert_not_null(_panel.get_card(AURA_WELL_ID))

func test_empty_zone_shows_nothing_to_do() -> void:
	await _add_panel()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	var empty: Label = _list_node("EmptyLabel") as Label
	assert_true(empty.is_visible_in_tree())
	assert_eq(empty.text, "Nothing to do here yet.")
	assert_eq((_node("CountLabel") as Label).text, "0 here")
	assert_eq(_group_names(), [] as Array[String])
	_assert_flow_matches_scenes()

func test_rail_hidden_when_content_fits() -> void:
	await _add_panel()
	assert_false((_list_node("Rail") as Control).visible)
	assert_false((_list_node("LipTop") as Control).visible)
	assert_false((_list_node("LipBottom") as Control).visible)

#-----------------------------------------------------------------------------
# CHEST HEIGHT
#-----------------------------------------------------------------------------

func test_chest_hugs_short_list() -> void:
	await _add_panel()
	assert_lt(_panel.size.y, 400.0)
	var list: Control = _list()
	assert_eq(_panel.size.y, maxf(176.0, list.position.y + list.size.y + 24.0), "24 px under the list")
	_assert_flow_matches_scenes()

func test_chest_fills_for_nine_cards() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	assert_eq(_panel.size.y, FULL_CHEST_HEIGHT, "a scrolling list snaps the chest to the bottom line")
	_assert_flow_matches_scenes()
	# The list folds 8 px under its last whole drawer: no drawer is cut.
	var view: Rect2 = _scroll().get_global_rect()
	var last_bottom: float = -1.0
	for action: ZoneActionData in ZoneManager.get_available_actions(SPIRIT_VALLEY_ID):
		var rect: Rect2 = _panel.get_card(action.action_id).get_global_rect()
		if rect.position.y < view.end.y:
			assert_lte(rect.end.y, view.end.y, "%s is not cut by the fold" % action.action_id)
			last_bottom = maxf(last_bottom, rect.end.y)
	assert_eq(view.end.y - last_bottom, FOLD_GAP)

func test_rail_and_lips_follow_scroll() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var rail: Control = _list_node("Rail") as Control
	assert_true(rail.visible, "the list scrolls")
	assert_false((_list_node("LipTop") as Control).visible, "at the top: no top lip")
	assert_true((_list_node("LipBottom") as Control).visible, "more below")
	assert_true((rail.get_node("%UpCap") as BaseButton).disabled, "the up cap is dark at the top")
	assert_false((rail.get_node("%DownCap") as BaseButton).disabled)

	var scroll: ScrollContainer = _scroll()
	var view: float = scroll.size.y
	var content: float = scroll.get_v_scroll_bar().max_value
	var thumb: Control = rail.get_node("%Thumb") as Control
	var expected_height: float = maxf(32.0, 2.0 * roundf((view - 28.0) * view / content / 2.0))
	assert_eq(thumb.size.y, expected_height, "thumb height (kit §5.5)")
	assert_eq(thumb.position.y, 14.0)

	scroll.scroll_vertical = int(content - view)
	await wait_process_frames(1)
	assert_true((_list_node("LipTop") as Control).visible)
	assert_false((_list_node("LipBottom") as Control).visible, "at the bottom")
	assert_eq(thumb.position.y, 14.0 + view - 28.0 - expected_height, "the thumb reaches the down cap")
	assert_false((rail.get_node("%UpCap") as BaseButton).disabled)
	assert_true((rail.get_node("%DownCap") as BaseButton).disabled)

func test_down_cap_steps_one_drawer() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var rail: Control = _list_node("Rail") as Control
	(rail.get_node("%DownCap") as BaseButton).pressed.emit()
	await wait_seconds(0.4)
	assert_eq(_scroll().scroll_vertical, 80, "one drawer and its gap")

#-----------------------------------------------------------------------------
# SCROLL TO A CARD
#-----------------------------------------------------------------------------

func test_scroll_to_action_makes_card_visible() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	assert_false(_card_fully_visible(MERCHANT_ID), "precondition: the last card is below the fold")
	_panel.scroll_to_action(MERCHANT_ID)
	await wait_seconds(0.4)
	assert_true(_card_fully_visible(MERCHANT_ID))
	assert_true(_card_flashing(MERCHANT_ID))

func test_scroll_to_visible_card_does_not_scroll() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	_panel.scroll_to_action(CYCLING_ID)
	await wait_seconds(0.4)
	assert_eq(_scroll().scroll_vertical, 0)
	assert_true(_card_flashing(CYCLING_ID))

func test_focus_request_scrolls() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	assert_false(_card_fully_visible(ADVENTURE_ID), "precondition: the adventure is below the fold")
	ZoneManager.request_action_focus(ADVENTURE_ID)
	await wait_seconds(0.4)
	assert_true(_card_fully_visible(ADVENTURE_ID))
	assert_true(_card_flashing(ADVENTURE_ID))
	# The adventure sits mid-list, so its scroll is not clamped: it ends
	# exactly 24 px above the viewport's bottom.
	var view: Rect2 = _scroll().get_global_rect()
	var card_rect: Rect2 = _panel.get_card(ADVENTURE_ID).get_global_rect()
	assert_eq(view.end.y - card_rect.end.y, SCROLL_MARGIN, "24 px under the card")

#-----------------------------------------------------------------------------
# LORE
#-----------------------------------------------------------------------------

func test_lore_toggles() -> void:
	await _add_panel()
	var header: Control = _node("ActivitiesHeader") as Control
	var lore: Control = _node("LorePanel") as Control
	var about: BaseButton = _node("AboutButton") as BaseButton
	var header_y: float = header.position.y
	var list_y: float = _list().position.y
	assert_false(lore.visible)

	about.button_pressed = true
	await wait_process_frames(1)
	assert_true(lore.visible)
	assert_eq(header.position.y, header_y + LORE_PUSH, "the lore pushes the header down")
	assert_eq(_list().position.y, list_y + LORE_PUSH, "and the list")
	assert_string_contains((_node("LoreText") as Label).text, "Deep at the heart of the world")

	about.button_pressed = false
	await wait_process_frames(1)
	assert_false(lore.visible)
	assert_eq(header.position.y, header_y)

func test_lore_paragraphs_are_one_break_apart() -> void:
	# The lore's paragraph gap is the label's own 10 px, so the blank line
	# between Spirit Valley's two paragraphs must not add a third, empty one.
	await _add_panel()
	var text: String = (_node("LoreText") as Label).text
	assert_false(text.contains("\n\n"), "no empty paragraph")
	assert_eq(text.split("\n").size(), 2, "two paragraphs")

func test_lore_text_is_a_lore_label() -> void:
	# The lore has no decimal point, so it needs no RichTextLabel: the theme's
	# LabelLacquerLore (16/22 cream) sets it, with one override for the kit's
	# 10 px between paragraphs (kit §5.5: text 16/22 cream, width 364).
	await _add_panel()
	var lore_text: Label = _node("LoreText") as Label
	assert_not_null(lore_text, "LoreText is a Label")
	if lore_text == null:
		return
	assert_eq(lore_text.theme_type_variation, &"LabelLacquerLore")
	assert_eq(lore_text.get_theme_constant(&"paragraph_spacing"), 10)
	assert_false(lore_text.has_theme_constant_override(&"line_spacing"), "the variant's 22 px pitch")
	assert_false(lore_text.has_theme_color_override(&"font_color"), "no colour override")
	assert_false(lore_text.has_theme_font_size_override(&"font_size"), "no size override")
	assert_eq(lore_text.size.x, 364.0, "364 px wide")
	assert_ne(lore_text.autowrap_mode, TextServer.AUTOWRAP_OFF, "it wraps")

func test_lore_fits_its_panel() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(1)
	var lore_text: Control = _node("LoreText") as Control
	var board: Rect2 = (_node("LorePanel") as Control).get_global_rect()
	assert_lte(lore_text.get_minimum_size().y, lore_text.size.y, "Spirit Valley's lore shows whole")
	assert_lte(lore_text.get_global_rect().end.y, board.end.y, "inside the lore board")

func test_esc_closes_lore() -> void:
	await _add_panel()
	var about: BaseButton = _node("AboutButton") as BaseButton
	about.button_pressed = true
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_false((_node("LorePanel") as Control).visible)
	assert_false(about.button_pressed, "About reads closed")

## A MainView with the zone view as its base state, not in the tree, as
## test_view_state_hud_positions.gd builds one.
func _main_view_on_the_zone_view() -> MainView:
	var main_view: MainView = autofree(MainView.new())
	main_view.zone_view_state = autofree(ZoneViewState.new())
	main_view.base_current_state = main_view.zone_view_state
	main_view.state_stack = [] as Array[MainViewState]
	return main_view

func test_esc_reaches_an_overlay_over_the_zone_view_first() -> void:
	# ZonePanel sits deeper than MainView, so it sees Esc first. With an
	# overlay pushed over the zone view (the inventory opened with I), Esc
	# belongs to the overlay, not to a lore the player cannot see.
	await _add_panel()
	var main_view: MainView = _main_view_on_the_zone_view()
	_panel.main_view = main_view
	var about: BaseButton = _node("AboutButton") as BaseButton
	about.button_pressed = true
	main_view.state_stack.append(autofree(MainViewState.new()))
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_true((_node("LorePanel") as Control).visible, "the overlay gets Esc; the lore stays open")
	main_view.state_stack.clear()
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_false((_node("LorePanel") as Control).visible, "with the overlay gone, Esc closes the lore")
	assert_false(about.button_pressed)

func test_esc_leaves_the_lore_while_another_base_view_shows() -> void:
	await _add_panel()
	var main_view: MainView = _main_view_on_the_zone_view()
	main_view.base_current_state = autofree(MainViewState.new())
	_panel.main_view = main_view
	(_node("AboutButton") as BaseButton).button_pressed = true
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_true((_node("LorePanel") as Control).visible, "the zone view is not the active state")

func test_esc_leaves_the_lore_while_the_chest_is_hidden() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	_panel.visible = false
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_true((_node("LorePanel") as Control).visible, "a hidden chest does not take Esc")

func test_finds_main_view_among_its_ancestors() -> void:
	var main_view: MainView = autofree(MainView.new())
	var holder: Control = autofree(Control.new())
	main_view.add_child(holder)
	_panel = PANEL_SCENE.instantiate() as ZonePanel
	holder.add_child(_panel)
	# Out of the tree the panel's _ready never runs, so ask the lookup it uses.
	assert_eq(_panel.find_main_view(), main_view)

func test_zone_change_closes_lore() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	assert_false((_node("LorePanel") as Control).visible)

func test_click_outside_closes_lore() -> void:
	await _add_panel_above_gut()
	var about: BaseButton = _node("AboutButton") as BaseButton
	about.button_pressed = true
	await wait_process_frames(1)
	_click(Vector2(400.0, 500.0))
	await wait_process_frames(1)
	assert_false((_node("LorePanel") as Control).visible)
	assert_false(about.button_pressed, "About reads closed")

func test_click_on_card_with_lore_open_starts_that_card() -> void:
	# Closing the lore moves the list up 276 px. The click must reach the
	# card the player saw under the cursor, not the one that slides there.
	EventManager.trigger_event(AURA_WELL_EVENT)
	EventManager.trigger_event(FORAGING_EVENT)
	await _add_panel_above_gut()
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var center: Vector2 = _panel.get_card(FORAGING_ID).get_global_rect().get_center()
	assert_true(_scroll().get_global_rect().has_point(center), "precondition: the foraging card shows under the lore")
	_click(center)
	await wait_process_frames(1)
	assert_eq(_current_id(), FORAGING_ID, "the clicked card's action runs")
	assert_false((_node("LorePanel") as Control).visible, "and the lore closes")

func test_rail_cap_click_lands_while_the_lore_closes() -> void:
	# The press closes the lore at the end of the frame, which moves the list
	# and its rail up 276 px. A cap that acted on release would miss a click
	# whose mouse moved 1 px before the release: the caps act on the press.
	await _add_panel_above_gut()
	_unlock_everything()
	await wait_process_frames(2)
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var down_cap: BaseButton = (_list_node("Rail") as Control).get_node("%DownCap") as BaseButton
	assert_true(down_cap.is_visible_in_tree(), "precondition: the list scrolls under the lore")
	var point: Vector2 = down_cap.get_global_rect().get_center()
	_push_mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await wait_process_frames(1)
	var moved: Vector2 = point + Vector2(1.0, 0.0)
	var motion := InputEventMouseMotion.new()
	motion.position = moved
	motion.global_position = moved
	motion.relative = Vector2(1.0, 0.0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = moved
	release.global_position = moved
	get_viewport().push_input(release, true)
	await wait_seconds(0.4)
	assert_false((_node("LorePanel") as Control).visible, "the click closed the lore")
	assert_eq(_scroll().scroll_vertical, 80, "and stepped the list one drawer")

func test_rail_caps_act_on_press() -> void:
	await _add_panel()
	var rail: Control = _list_node("Rail") as Control
	for cap_name: String in ["%UpCap", "%DownCap"]:
		var cap: BaseButton = rail.get_node(cap_name) as BaseButton
		assert_eq(cap.action_mode, BaseButton.ACTION_MODE_BUTTON_PRESS, "%s acts on the press" % cap_name)

func test_mouse_wheel_keeps_lore_open() -> void:
	await _add_panel_above_gut()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(1)
	_push_mouse_button(_scroll().get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, false)
	await wait_process_frames(1)
	assert_true((_node("LorePanel") as Control).visible, "scrolling is not a click")
