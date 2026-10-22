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

func test_chest_fills_for_nine_cards() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	assert_eq(_panel.size.y, FULL_CHEST_HEIGHT, "a scrolling list snaps the chest to the bottom line")
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
	assert_string_contains((_node("LoreText") as RichTextLabel).get_parsed_text(), "Deep at the heart of the world")

	about.button_pressed = false
	await wait_process_frames(1)
	assert_false(lore.visible)
	assert_eq(header.position.y, header_y)

func test_lore_paragraphs_are_one_break_apart() -> void:
	# The lore's paragraph gap is the label's own 10 px, so the blank line
	# between Spirit Valley's two paragraphs must not add a third, empty one.
	await _add_panel()
	var text: String = (_node("LoreText") as RichTextLabel).get_parsed_text()
	assert_false(text.contains("\n\n"), "no empty paragraph")
	assert_eq(text.split("\n").size(), 2, "two paragraphs")

func test_esc_closes_lore() -> void:
	await _add_panel()
	var about: BaseButton = _node("AboutButton") as BaseButton
	about.button_pressed = true
	Input.parse_input_event(_escape_event())
	await wait_process_frames(2)
	assert_false((_node("LorePanel") as Control).visible)
	assert_false(about.button_pressed, "About reads closed")

func test_zone_change_closes_lore() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	assert_false((_node("LorePanel") as Control).visible)
