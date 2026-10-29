extends GutTest

## Integration tests for the zone chest (ZonePanel, lacquer kit §5.5 and §0):
## the header, the Now strip for each idle action and for the cycle (read from
## CyclingManager's session snapshot, which the tests drive directly), the
## grouped activity list and its rebuilds, the rail, scrolling to a card, the
## lore panel and who takes Esc, the techniques mode a cycling session turns
## the chest to, and what the chest tells MainView's slide. The panel is built
## on a fresh save, as the zone view builds it. No text in the Now strip, the
## lore or the last cycle's line is cut off: a long one wraps, its board grows,
## and the Activities header and the list move down with it.

const PANEL_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/zone_panel.tscn")

const SPIRIT_VALLEY_ID: String = "SpiritValley"
const TEST_ZONE_ID: String = "TestZone"

const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const MERCHANT_ID: String = "spirit_valley_merchant"
const TRIBULATION_ID: String = "spirit_valley_tribulation"

## The unlock condition that reveals the Tribulation's card.
const FULL_CORE_CONDITION: String = "core_density_full"

const AURA_WELL_EVENT: String = "aura_well_discovered"
const FORAGING_EVENT: String = "q_fill_core_completed"

## The three cycling techniques the catalog ships, in unlock order.
const FOUNDATION_ID: String = "foundation_technique"
const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"

const THUMB_RIVER: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_ai.png")
const THUMB_BASIC: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_basic_ai.png")

## Chest layout, local to the chest (kit §0, §5.5). The Now tray always
## keeps its space, so the header and the list never move up.
const HEADER_TOP: float = 177.0
const LIST_TOP: float = 208.0
## A finished cycle's line sits under the Now tray and pushes the rest down this far.
const LAST_CYCLE_PUSH: float = 26.0
## The lore board's 264 tall at least (it grows with its text), and the 12 px
## under it before the header.
const LORE_MIN_HEIGHT: float = 264.0
const LORE_GAP_UNDER: float = 12.0
## The Now strip: the kit's 88 tall, with each extra line of a name 22 px.
const STRIP_HEIGHT: float = 88.0
const NAME_LINE: float = 22.0
## Long enough to need three lines in the strip's name (about 210 px beside the
## rate).
const LONG_NAME: String = "The Aura Well of the Endless Misty Bamboo Hollow, Lit By The Cold Moon And A Hundred Silent Stars"
## A lore of three long paragraphs: many more lines than the shipped one, which takes
## about ten.
const LONG_LORE: String = "The old road climbs out of the valley between two shoulders of grey stone, and every pilgrim who walks it says each step is paid for in breath. Those who reach the first ridge look back at a sea of mist and understand why the cradle was built where it was.\n\nBeyond the ridge the aura thins and then thickens again, pooling in hollows where the bamboo grows thicker than a man can reach around. Sacred artists have sat in those hollows for ten thousand years, and the stones remember every one of them.\n\nOnly the patient are shown the third path, the one that leaves no footprints and ends where it began."
const NO_TRIMMING: TextServer.OverrunBehavior = TextServer.OVERRUN_NO_TRIMMING
## A technique drawer is 72 tall, with 8 between drawers (kit §5.5).
const DRAWER_HEIGHT: float = 72.0
const DRAWER_GAP: float = 8.0

## GUT's output window's canvas layer.
const GUT_LAYER: int = 128

## One 60 FPS frame, for stepping the tweens by hand.
const FRAME: float = 1.0 / 60.0

var _panel: ZonePanel = null

## The lore and action names a test changed, restored after it.
var _relored_zone: ZoneData = null
var _original_description: String = ""
var _renamed_actions: Dictionary[ZoneActionData, String] = {}

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	# The Esc tests parse a ui_cancel press; leave the action released for the
	# tests that run after this file (TESTING.md: parsed input actions).
	Input.action_release(&"ui_cancel")
	# A test that held the action timer lets it go, or no later haul or tick
	# would ever come.
	ActionManager.action_timer.paused = false
	# The tray tests start a cycle session by hand: end it, so none leaks into
	# the next test.
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	if _relored_zone != null:
		_relored_zone.description = _original_description
		_relored_zone = null
	for action: ZoneActionData in _renamed_actions:
		action.action_name = _renamed_actions[action]
	_renamed_actions.clear()
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

## Waits a frame, so the drawers a technique list rebuild took out of the tree and
## queue-freed are gone before GUT counts orphans.
func _await_queued_frees() -> void:
	await wait_process_frames(1)

## Holds the action timer `elapsed` seconds into its interval, so the strip
## reads a time left that no frame moves on. start() sets the time left;
## putting the interval back as wait_time leaves the time left be.
func _hold_action_timer_at(elapsed: float) -> void:
	var timer: Timer = ActionManager.action_timer
	var interval: float = timer.wait_time
	timer.paused = true
	timer.start(interval - elapsed)
	timer.wait_time = interval

## Moves every running tween in the tree on by `seconds`, a 60 FPS frame at a
## time, as frames would: the rail's scroll steps and the card's flash.
func _run_tweens(seconds: float) -> void:
	for _frame: int in roundi(seconds / FRAME):
		for tween: Tween in get_tree().get_processed_tweens():
			if tween.is_valid() and tween.is_running():
				tween.custom_step(FRAME)

func _list() -> Control:
	return _node("ActivityList") as Control

func _list_node(unique_name: String) -> Node:
	return _list().get_node("%" + unique_name)

func _strip() -> NowStrip:
	return _node("NowStrip") as NowStrip

func _strip_node(unique_name: String) -> Node:
	return _strip().get_node("%" + unique_name)

## What opening the lore pushes the header and the list down by: its board and
## the 12 px under it.
func _lore_push() -> float:
	return (_node("LorePanel") as Control).size.y + LORE_GAP_UNDER

## Gives Spirit Valley another lore for the test, restored after it.
func _set_lore(description: String) -> void:
	_relored_zone = ZoneManager.get_zone_by_id(SPIRIT_VALLEY_ID)
	_original_description = _relored_zone.description
	_relored_zone.description = description

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## Latches every unlock condition of every Spirit Valley action, so all ten
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

#-----------------------------------------------------------------------------
# ROOT AND HEADER
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# NOW STRIP
#-----------------------------------------------------------------------------

## Asserts the tray shows its empty state: the ring dark, no action icon,
## and only the line (and the Now legend) among its texts, so no name,
## rate, level line, figure, yields, haul or rod.
func _assert_empty_tray(line: String) -> void:
	assert_true(_strip().is_visible_in_tree(), "the tray always shows")
	assert_eq(_texts(_strip()), [line, "Now"] as Array[String], "one line and the Now legend")
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark")
	assert_null((_strip_node("ActionIcon") as TextureRect).texture, "no action icon")
	assert_false((_strip_node("WellRod") as Control).is_visible_in_tree(), "no rod")

func test_fresh_save_shows_an_empty_tray() -> void:
	await _add_panel()
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs on a fresh save")
	_assert_empty_tray("Nothing running")

func test_strip_shows_for_aura_well() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")
	await wait_process_frames(2)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Aura Well")
	assert_has(texts, "+1.5 / s")
	assert_has(texts, "+1 Spirit at Lv 1")
	assert_has(texts, "0 / 60")
	assert_does_not_have(texts, "Nothing running")
	assert_eq((_strip_node("ActionIcon") as TextureRect).texture, ZoneManager.get_action_by_id(AURA_WELL_ID).icon)

func test_strip_follows_training_ticks() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	var well: TrainingActionData = ZoneManager.get_action_by_id(AURA_WELL_ID) as TrainingActionData
	var ticks: int = ZoneManager.increment_training_ticks(AURA_WELL_ID, SPIRIT_VALLEY_ID, 75)
	ActionManager.training_tick_processed.emit(well, ticks)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "+1 Spirit at Lv 2")
	assert_has(texts, "15 / 300")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), roundi(15.0 / 300.0 * 144.0))

func test_strip_shows_for_foraging() -> void:
	await _add_panel()
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Spring Forest Foraging")
	assert_has(texts, "1–5")
	assert_has(texts, "2–6")
	assert_has(texts, "haul in 5 s")
	assert_false((_strip_node("TrainingContent") as Control).visible)

func test_strip_haul_counts_down() -> void:
	# "haul in N s" follows the foraging timer's time left, not its interval:
	# 1.2 s into a 5 s haul it reads 4.
	await _add_panel()
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	assert_has(_texts(_strip()), "haul in 5 s", "precondition: a fresh haul")
	_hold_action_timer_at(1.2)
	await wait_process_frames(2)
	assert_eq(ActionManager.action_timer.wait_time, 5.0, "precondition: still the 5 s interval")
	assert_has(_texts(_strip()), "haul in 4 s")

func test_tray_shows_the_cycle_ready() -> void:
	# Cycling is a session action, but the tray shows it instead of pausing: the
	# action, the rate, the equipped technique and its cycle time, with the ring
	# dark, the rod empty and the rate at +0 until a cycle draws Madra. The
	# cycling card is not in the list while the player cycles, so the tray takes
	# no clicks.
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	assert_eq(_texts(_strip()), ["Wilderness Cycling", "+0 / s", "Foundational Technique", "8 s cycle", "Now"] as Array[String])
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark")
	assert_eq((_strip_node("ActionIcon") as TextureRect).texture, ZoneManager.get_action_by_id(CYCLING_ID).icon, "the action's icon")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 0, "the rod is empty")
	assert_eq(_strip().mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_tray_follows_the_running_cycle() -> void:
	# 9 s into a 15 s cycle: the ring lights floor(0.6 x 13) = 7 beads, the rod
	# (the strip's, 144 steps) stands at round(0.6 x 144) = 86, and the rate is
	# the one drawn.
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(9.0, 13.3)
	await wait_process_frames(1)
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i(7, 0), "seven beads")
	assert_eq((_strip_node("TicksLabel") as Label).text, "9 / 15 s")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 86)
	assert_true((_strip_node("RateGroup") as Control).is_visible_in_tree())
	assert_eq((_strip_node("RateText") as RichTextLabel).get_parsed_text(), "+13.3 / s")
	assert_has(_texts(_strip()), "Foundational Technique", "the detail stays the technique's name")

func test_tray_goes_back_to_ready_when_the_cycle_ends() -> void:
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(8.0)
	CyclingManager.update_cycle_session(6.0, 13.3)
	await wait_process_frames(1)
	assert_gt((_strip_node("Ring") as LacquerStripRect).get_frame().x, 0, "precondition: the ring is lit")
	CyclingManager.end_cycle_session()
	await wait_process_frames(1)
	assert_eq(_texts(_strip()), ["Wilderness Cycling", "+0 / s", "Foundational Technique", "8 s cycle", "Now"] as Array[String], "the rate back at +0")
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark again")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 0, "and the rod empty")

func test_tray_names_the_equipped_technique() -> void:
	# The detail line and the ready figure follow the equipped technique at once,
	# without waiting for a frame: Smooth Flow is the 15 s one.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	assert_has(_texts(_strip()), "Foundational Technique", "precondition: the foundation technique is equipped")
	CyclingManager.equip_technique(SMOOTH_ID)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Smooth Flow Technique")
	assert_has(texts, "15 s cycle")
	assert_does_not_have(texts, "Foundational Technique")
	assert_does_not_have(texts, "8 s cycle")

func test_cycling_tray_takes_no_clicks() -> void:
	# A press on the running tray scrolls the chest to its card; the cycling card
	# is not in the list, so while cycling the press does nothing.
	await _add_panel_above_gut()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	watch_signals(_strip())
	_click(_strip().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_signal_emit_count(_strip(), "strip_pressed", 1, "precondition: the running Aura Well's tray takes the press")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	_click(_strip().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_signal_emit_count(_strip(), "strip_pressed", 1, "the cycling tray takes no press")

func test_tray_gives_the_cycle_back_to_the_aura_well() -> void:
	# The cycle and the Aura Well share the tray's name, detail, figure, rod and
	# rate: when the cycle ends and the Aura Well resumes, the Aura Well's own
	# texts, rod and rate come back, and the tray takes clicks again.
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(8.0)
	CyclingManager.update_cycle_session(4.0, 13.3)
	await wait_process_frames(2)
	assert_has(_texts(_strip()), "Wilderness Cycling", "precondition: the cycle shows")
	CyclingManager.end_cycle_session()
	ActionManager.stop_action()
	await wait_process_frames(2)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well resumed")
	assert_eq(_texts(_strip()), ["Aura Well", "+1.5 / s", "+1 Spirit at Lv 1", "0 / 60", "Now"] as Array[String])
	assert_eq((_strip_node("ActionIcon") as TextureRect).texture, ZoneManager.get_action_by_id(AURA_WELL_ID).icon)
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 0, "the rod is the well's, empty")
	assert_eq(_strip().mouse_filter, Control.MOUSE_FILTER_STOP, "the running tray takes clicks again")

func test_tray_reads_paused_with_the_shop_open() -> void:
	# The paused name is the idle action that resumes when the shop closes:
	# the zone's last idle action (foraging), not the first idle card (the
	# Aura Well).
	await _add_panel()
	_unlock_everything()
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	ActionManager.action_timer.start(1.0)
	_hold_action_timer_at(0.5)
	await wait_process_frames(2)
	assert_gt((_strip_node("Ring") as LacquerStripRect).get_frame().x, 0, "precondition: the ring is lit")
	ActionManager.select_action(ZoneManager.get_action_by_id(MERCHANT_ID))
	await wait_process_frames(2)
	assert_eq(_current_id(), MERCHANT_ID, "precondition: the shop is open")
	_assert_empty_tray("Spring Forest Foraging · paused")
	ActionManager.stop_action()
	await wait_process_frames(2)
	assert_has(_texts(_strip()), "haul in 5 s", "closing the shop resumes foraging in the tray")
	assert_eq(_strip().mouse_filter, Control.MOUSE_FILTER_STOP, "the running tray takes clicks again")

func test_tray_reads_paused_when_an_idle_action_unlocks_mid_session() -> void:
	# The shop opens on a save with no idle action; the Aura Well unlocks while
	# it is open, so it does not start, and the tray names it as the action that
	# resumes after the shop.
	var shop: ZoneActionData = ZoneManager.get_action_by_id(MERCHANT_ID)
	for condition: UnlockConditionData in shop.unlock_conditions:
		UnlockManager.force_unlock_condition(condition.condition_id)
	await _add_panel()
	ActionManager.select_action(shop)
	await wait_process_frames(2)
	_assert_empty_tray("Nothing running")
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	assert_eq(_current_id(), MERCHANT_ID, "precondition: the shop is still open")
	_assert_empty_tray("Aura Well · paused")

func test_strip_press_flashes_the_running_card() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	_strip().strip_pressed.emit()
	assert_true(_card_flashing(AURA_WELL_ID))

#-----------------------------------------------------------------------------
# NOW STRIP: NO TEXT IS CUT OFF
#-----------------------------------------------------------------------------

func _rename_action(action_id: String, new_name: String) -> ZoneActionData:
	var action: ZoneActionData = ZoneManager.get_action_by_id(action_id)
	_renamed_actions[action] = action.action_name
	action.action_name = new_name
	return action

## The header, the list and the lore stand where the strip's bottom puts them: 10,
## 38 and 12 px under it.
func _assert_chest_follows_the_strip() -> void:
	var bottom: float = _strip().position.y + _strip().size.y
	assert_eq((_node("ActivitiesHeader") as Control).position.y, bottom + 10.0 - 3.0, "the header 10 px under the strip (its text 3 px up)")
	assert_eq(_list().position.y, bottom + 38.0, "the list 38 px under it")
	assert_eq((_node("LorePanel") as Control).position.y, bottom + 12.0, "and the lore 12")

func test_a_long_training_name_wraps_and_grows_the_strip() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	var name_label := _strip_node("TrainingName") as Label
	assert_gt(name_label.get_line_count(), 2, "precondition: the name needs three lines beside the rate")
	assert_eq(name_label.text_overrun_behavior, NO_TRIMMING, "wrapped, never trimmed")
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(_strip().size.y, STRIP_HEIGHT + NAME_LINE * (name_label.get_line_count() - 1), "every line after the first adds the name's 22 px")
	_assert_chest_follows_the_strip()

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
	assert_eq((_node("CountLabel") as Label).text, "10 here")

func test_rebuilds_on_unlock() -> void:
	await _add_panel()
	assert_null(_panel.get_card(AURA_WELL_ID), "precondition: the Aura Well is locked")
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	assert_not_null(_panel.get_card(AURA_WELL_ID))

## The Tribulation's card hides once the breakthrough has moved the stage on,
## so the chest rebuilds when the stage changes.
func test_rebuilds_on_stage_change() -> void:
	await _add_panel()
	UnlockManager.force_unlock_condition(FULL_CORE_CONDITION)
	CultivationManager.live_save_data.core_density_level = 100.0
	await wait_process_frames(2)
	assert_not_null(_panel.get_card(TRIBULATION_ID), "precondition: a full core lists the Tribulation")
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: the breakthrough moves the stage on")
	await wait_process_frames(2)
	assert_null(_panel.get_card(TRIBULATION_ID), "the passed Tribulation is no longer listed")

func test_empty_zone_shows_nothing_to_do() -> void:
	await _add_panel()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	var empty: Label = _list_node("EmptyLabel") as Label
	assert_true(empty.is_visible_in_tree())
	assert_eq((_node("CountLabel") as Label).text, "0 here")
	assert_eq(_group_names(), [] as Array[String])

#-----------------------------------------------------------------------------
# RAIL
#-----------------------------------------------------------------------------

func test_down_cap_steps_one_drawer() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var rail: Control = _list_node("Rail") as Control
	(rail.get_node("%DownCap") as BaseButton).pressed.emit()
	_run_tweens(0.4)
	assert_eq(_scroll().scroll_vertical, 80, "one drawer and its gap")

#-----------------------------------------------------------------------------
# SCROLL TO A CARD
#-----------------------------------------------------------------------------

func test_focus_request_scrolls() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	assert_false(_card_fully_visible(ADVENTURE_ID), "precondition: the adventure is below the fold")
	ZoneManager.request_action_focus(ADVENTURE_ID)
	_run_tweens(0.4)
	# The scroll container lays the cards out at the end of a frame.
	await wait_process_frames(2)
	assert_true(_card_fully_visible(ADVENTURE_ID))
	assert_true(_card_flashing(ADVENTURE_ID))

#-----------------------------------------------------------------------------
# LORE
#-----------------------------------------------------------------------------

func test_lore_toggles() -> void:
	await _add_panel()
	var lore: Control = _node("LorePanel") as Control
	var about: BaseButton = _node("AboutButton") as BaseButton
	assert_false(lore.visible)

	about.button_pressed = true
	await wait_process_frames(1)
	assert_true(lore.visible)
	assert_string_contains((_node("LoreText") as Label).text, "Deep at the heart of the world")

	about.button_pressed = false
	await wait_process_frames(1)
	assert_false(lore.visible)

## A lore that needs more than the board's 264 px grows it: the board is as tall as
## the text asks (16 px under the last line), and the header and the list stand
## under it.
func test_a_long_lore_grows_the_board_and_pushes_the_chest() -> void:
	_set_lore(LONG_LORE)
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var board := _node("LorePanel") as Control
	var text := _node("LoreText") as Label
	assert_gt(text.get_line_count(), 14, "precondition: many more lines than the shipped lore")
	assert_gt(board.size.y, LORE_MIN_HEIGHT, "the board grew")
	assert_gte(board.size.y - (text.position.y + text.size.y), 16.0, "with 16 px of board under its last line")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + _lore_push(), "the header stands under the grown board")
	assert_eq(_list().position.y, LIST_TOP + _lore_push(), "and the list")
	assert_gte(_panel.size.y, _list().position.y + _list().size.y, "the chest holds the list")

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
	# Closing the lore moves the list up by the lore's height. The click must
	# reach the card the player saw under the cursor, not the one that slides there.
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
	# and its rail up by the lore's height. A cap that acted on release would miss a click
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
	await wait_process_frames(1)
	_run_tweens(0.4)
	assert_false((_node("LorePanel") as Control).visible, "the click closed the lore")
	assert_eq(_scroll().scroll_vertical, 80, "and stepped the list one drawer")

func test_mouse_wheel_keeps_lore_open() -> void:
	await _add_panel_above_gut()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(1)
	_push_mouse_button(_scroll().get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, false)
	await wait_process_frames(1)
	assert_true((_node("LorePanel") as Control).visible, "scrolling is not a click")

## A board in the map gap (cycling, the Tribulation) hides About and closes the lore;
## About comes back when the board goes, with the lore still shut.
func test_board_mode_hides_about_and_closes_the_lore() -> void:
	await _add_panel()
	var about: BaseButton = _node("AboutButton") as BaseButton
	var lore: Control = _node("LorePanel") as Control
	about.button_pressed = true
	assert_true(lore.visible, "precondition: the lore is open")
	_panel.set_board_mode(true)
	assert_false(about.visible, "About hides")
	assert_false(about.button_pressed, "About is no longer pressed in")
	assert_false(lore.visible, "the lore closes")
	_panel.set_board_mode(false)
	assert_true(about.visible, "About is back")
	assert_false(lore.visible, "the lore stays shut")

## A rebuild while the board stands (here a technique unlocking) leaves About hidden.
func test_a_rebuild_in_board_mode_keeps_about_hidden() -> void:
	await _add_panel()
	_panel.set_board_mode(true)
	CyclingManager.unlock_technique(SMOOTH_ID)
	await wait_process_frames(2)
	assert_false((_node("AboutButton") as Control).visible)

func test_leaving_board_mode_keeps_about_hidden_without_lore() -> void:
	await _add_panel()
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	_panel.set_board_mode(true)
	_panel.set_board_mode(false)
	assert_false((_node("AboutButton") as Control).visible, "Test Zone has no lore")

#-----------------------------------------------------------------------------
# TECHNIQUES MODE
#-----------------------------------------------------------------------------

func _technique_list() -> TechniqueList:
	return _node("TechniqueList") as TechniqueList

## The technique ids of the drawers in the list's column, top to bottom.
func _drawer_ids() -> Array[String]:
	var ids: Array[String] = []
	for drawer: Node in _technique_list().get_node("%Drawers").get_children():
		ids.append((drawer as TechniqueDrawer).technique.id)
	return ids

## Unlocks the two techniques the foundation one starts without.
func _unlock_all_techniques() -> void:
	CyclingManager.unlock_technique(SMOOTH_ID)
	CyclingManager.unlock_technique(TORRENTIAL_ID)

func _header_text() -> String:
	return (_node("HeaderLabel") as Label).text

func _count_text() -> String:
	return (_node("CountLabel") as Label).text

func test_techniques_mode_lists_unlocked_techniques() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(1)
	assert_true(_panel.is_techniques_mode())
	assert_true(_technique_list().is_visible_in_tree(), "the techniques show")
	assert_false(_list().is_visible_in_tree(), "the activities step aside")
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "one drawer each, in unlock order")
	assert_eq(_header_text(), "Techniques")
	assert_eq(_count_text(), "3 learned")

## A finished cycle's result, as the board records it on CyclingManager.
func _last_cycle(madra: float, scored: int, total: int, perfect: int, xp: int) -> CycleResult:
	var result := CycleResult.new()
	result.madra_added = madra
	result.zones_scored = scored
	result.zones_total = total
	result.perfect_count = perfect
	result.xp = xp
	return result

func _last_cycle_label() -> Label:
	return _node("LastCycleLabel") as Label

func test_the_last_cycle_line_shows_the_result() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	assert_false(_last_cycle_label().visible, "no line before a cycle ends")
	CyclingManager.set_last_cycle_result(_last_cycle(199.47, 3, 4, 1, 75))
	assert_true(_last_cycle_label().visible)
	assert_eq(_last_cycle_label().text, "Last cycle · +199 Madra · 3 / 4 zones · 1 PERFECT · +75 XP")

func test_a_long_last_cycle_line_wraps_and_pushes_the_rest_down() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	CyclingManager.set_last_cycle_result(_last_cycle(12345.0, 10, 12, 10, 99999))
	var label: Label = _last_cycle_label()
	assert_eq(label.text, "Last cycle · +12345 Madra · 10 / 12 zones · 10 PERFECT · +99999 XP", "the whole line")
	assert_eq(label.get_line_count(), 2, "wider than the tray, it wraps")
	assert_eq(label.get_visible_line_count(), 2, "and both lines show")
	assert_gte(label.size.y, label.get_minimum_size().y, "its box holds both lines")
	var push: float = label.size.y + 8.0
	assert_gt(push, LAST_CYCLE_PUSH, "precondition: two lines push further than one")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + push, "the header moves down under both lines")
	assert_eq(_technique_list().position.y, LIST_TOP + push, "and the drawers with it")

func test_the_last_cycle_line_shows_only_while_cycling() -> void:
	await _add_panel()
	CyclingManager.set_last_cycle_result(_last_cycle(50.0, 0, 0, 0, 0))
	assert_false(_last_cycle_label().visible, "the activities never show it")
	_panel.set_techniques_mode(true)
	assert_true(_last_cycle_label().visible)
	_panel.set_techniques_mode(false)
	assert_false(_last_cycle_label().visible)

func test_clearing_the_last_cycle_hides_the_line() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	CyclingManager.set_last_cycle_result(_last_cycle(50.0, 0, 0, 0, 0))
	CyclingManager.clear_last_cycle_result()
	assert_false(_last_cycle_label().visible)

func test_leaving_techniques_mode_restores_activities() -> void:
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	_panel.set_techniques_mode(false)
	await wait_process_frames(2)
	assert_false(_panel.is_techniques_mode())
	assert_true(_list().is_visible_in_tree(), "the activities are back")
	assert_false(_technique_list().is_visible_in_tree(), "the techniques are gone")
	assert_eq(_header_text(), "Activities")
	assert_eq(_count_text(), "1 here")

func test_setting_the_mode_twice_changes_nothing() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "still one drawer each")
	assert_eq(_count_text(), "3 learned")
	_panel.set_techniques_mode(false)
	_panel.set_techniques_mode(false)
	await wait_process_frames(2)
	assert_eq(_header_text(), "Activities")
	assert_eq(_count_text(), "1 here")

func test_unlock_in_techniques_mode_adds_a_drawer() -> void:
	# Review Focus 4: a technique unlocked while the chest lists them joins the
	# list, NEW.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	assert_eq(_technique_list().get_drawer_count(), 2, "precondition: foundation and smooth")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	await wait_process_frames(2)
	assert_eq(_technique_list().get_drawer_count(), 3)
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "the old drawers are replaced, not stacked")
	assert_eq(_count_text(), "3 learned")
	assert_true(_technique_list().get_drawer(TORRENTIAL_ID).is_new_shown(), "the new technique shows NEW")

func test_a_rebuild_in_techniques_mode_keeps_the_header() -> void:
	# UnlockManager re-evaluates its conditions as Madra changes, so a rebuild can
	# land mid-cycle: it must neither bring "Activities" back nor measure the
	# hidden activity list.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	UnlockManager.condition_unlocked.emit("test")
	await wait_process_frames(2)
	assert_eq(_header_text(), "Techniques")
	assert_eq(_count_text(), "2 learned")
	assert_eq(_panel.size.y, LIST_TOP + 2.0 * DRAWER_HEIGHT + DRAWER_GAP + 24.0, "the chest still hugs the techniques")

func test_activity_count_follows_unlocks_made_in_techniques_mode() -> void:
	await _add_panel()
	_panel.set_techniques_mode(true)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	assert_eq(_count_text(), "1 learned", "the header keeps to the techniques")
	_panel.set_techniques_mode(false)
	assert_eq(_count_text(), "2 here", "and the activities count the Aura Well")

func test_cycling_card_shows_new_after_a_technique_unlock() -> void:
	# ZoneManager marks the cycling action unseen when a technique unlocks; the
	# chest's rebuild is what shows the card's NEW seal again.
	var cycling: ZoneActionData = ZoneManager.get_action_by_id(CYCLING_ID)
	for condition: UnlockConditionData in cycling.unlock_conditions:
		UnlockManager.force_unlock_condition(condition.condition_id)
	ZoneManager.mark_action_seen(CYCLING_ID)
	await _add_panel()
	var card: ZoneActionButton = _panel.get_card(CYCLING_ID) as ZoneActionButton
	assert_not_null(card, "precondition: the cycling card is listed")
	assert_false(card.is_new_shown(), "precondition: the card counts as seen")
	CyclingManager.unlock_technique(SMOOTH_ID)
	await wait_process_frames(2)
	assert_true((_panel.get_card(CYCLING_ID) as ZoneActionButton).is_new_shown())

func test_a_hidden_technique_list_stays_current() -> void:
	await _add_panel()
	var chest_height: float = _panel.size.y
	watch_signals(_technique_list())
	_unlock_all_techniques()
	await wait_process_frames(2)
	assert_eq(_technique_list().get_drawer_count(), 3, "it rebuilt although it is hidden")
	assert_signal_emit_count(_technique_list(), "layout_changed", 2, "one new layout per unlock")
	assert_eq(_header_text(), "Activities", "the header is still the activities'")
	assert_eq(_count_text(), "1 here")
	assert_eq(_panel.size.y, chest_height, "the chest still hugs the activities")
	_panel.set_techniques_mode(true)
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "current the moment the mode turns on")
	await _await_queued_frees()

func test_equipping_a_technique_refreshes_every_drawer() -> void:
	# The drawers do not listen to CyclingManager: the list refreshes them all,
	# or the drawer that was in use would stay pulled out.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(1)
	var foundation: TechniqueDrawer = _technique_list().get_drawer(FOUNDATION_ID)
	var smooth: TechniqueDrawer = _technique_list().get_drawer(SMOOTH_ID)
	CyclingManager.equip_technique(SMOOTH_ID)
	assert_true((smooth.get_node("%Tag") as Control).visible, "smooth is tagged")
	assert_false((foundation.get_node("%Tag") as Control).visible, "foundation loses its tag")

func test_clicking_a_drawer_equips_its_technique() -> void:
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel_above_gut()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	var smooth: TechniqueDrawer = _technique_list().get_drawer(SMOOTH_ID)
	_click(smooth.get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(PersistenceManager.save_game_data.equipped_cycling_technique_id, SMOOTH_ID, "the press reached the drawer")
	assert_true(smooth.is_in_use())

func test_the_chest_grows_with_a_drawer_whose_name_wraps() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	var list: TechniqueList = _technique_list()
	var chest_height: float = _panel.size.y
	watch_signals(list)
	var drawer: TechniqueDrawer = list.get_drawer(SMOOTH_ID)
	var long_named := CyclingTechniqueData.new()
	long_named.id = "test_zone_panel_long_named_technique"
	long_named.technique_name = "The Exceedingly Long and Winding Name of a Technique"
	drawer.setup(long_named)
	var grown: float = drawer.size.y - DRAWER_HEIGHT
	assert_gt(grown, 0.0, "precondition: the long name wraps and the drawer grows")
	assert_signal_emitted(list, "layout_changed", "the list tells the chest")
	assert_eq(list.get_content_height(), 3.0 * DRAWER_HEIGHT + 2.0 * DRAWER_GAP + grown, "it measures the taller drawer")
	assert_eq(_panel.size.y, chest_height + grown, "the chest grows with the drawer")

func test_a_rebuild_takes_the_old_drawers_out_of_the_column_at_once() -> void:
	# queue_free alone leaves the old drawers in the column until the end of the
	# frame, and the column would measure them with the new ones.
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	var list: TechniqueList = _technique_list()
	var column := list.get_node("%Drawers") as VBoxContainer
	list.build()
	assert_eq(column.get_child_count(), 3, "one drawer each, none left over")
	assert_eq(column.get_combined_minimum_size().y, list.get_content_height(), "the column measures only the new drawers")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# SLIDE SUPPORT
#-----------------------------------------------------------------------------

## The label row of an activity group: the row that holds its name and its groove.
func _label_row_of(group: Node) -> Control:
	return group.get_node("%GroupLabel").get_parent() as Control

## True when every row's top is lower than the one before it.
func _tops_increase(rows: Array[Control]) -> bool:
	for index: int in range(1, rows.size()):
		if rows[index].global_position.y <= rows[index - 1].global_position.y:
			return false
	return true

func test_chest_height_for_matches_each_mode() -> void:
	_unlock_all_techniques()
	await _add_panel()
	var activities_height: float = _panel.size.y
	assert_eq(_panel.chest_height_for(false), _panel.size.y, "the activities mode, which shows")
	var untouched: Array = [_panel.size.y, _list().position.y, _list().size.y, _panel.is_techniques_mode()]
	var technique_height: float = _panel.chest_height_for(true)
	assert_eq([_panel.size.y, _list().position.y, _list().size.y, _panel.is_techniques_mode()], untouched,
		"asking for the other mode's height changes nothing")
	await _await_queued_frees()
	_panel.set_techniques_mode(true)
	assert_ne(_panel.size.y, activities_height, "precondition: the two modes differ")
	assert_eq(_panel.chest_height_for(true), _panel.size.y, "the techniques mode, once the chest is there")
	assert_eq(technique_height, _panel.size.y, "and what it was asked before it got there")
	assert_eq(_panel.chest_height_for(false), activities_height, "the activities height again, from the techniques mode")
	await _await_queued_frees()

func test_height_override_sizes_the_frame_and_clears() -> void:
	await _add_panel()
	var natural: float = _panel.size.y
	var list_top: float = _list().position.y
	var list_height: float = _list().size.y
	_panel.set_height_override(400.0)
	assert_eq(_panel.size.y, 400.0, "the chest takes the height")
	assert_eq(_list().position.y, list_top, "the list keeps its place")
	assert_eq(_list().size.y, list_height, "and its height")
	_panel.clear_height_override()
	assert_eq(_panel.size.y, natural, "the chest hugs the list again")

## A list that scrolls offers the rows that show at least partly in its window.
func test_activity_slide_rows_are_the_ones_in_the_scroll_window() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var cycling_card: Control = _panel.get_card(CYCLING_ID)
	var merchant_card: Control = _panel.get_card(MERCHANT_ID)
	var first_group: Node = _list_node("Content").get_child(0)
	var first_label_row: Control = _label_row_of(first_group)
	var first_card: Control = first_group.get_node("%Cards").get_child(0) as Control
	var window: Rect2 = _scroll().get_global_rect()
	var rows: Array[Control] = (_list() as ActivityList).get_slide_rows()
	assert_has(rows, cycling_card, "the cycling card shows at the top")
	assert_does_not_have(rows, merchant_card, "the last card is below the window")
	assert_same(rows[0], first_label_row, "the first group's label row leads")
	assert_true(_tops_increase(rows), "top to bottom")
	for row: Control in rows:
		var rect: Rect2 = row.get_global_rect()
		assert_true(rect.end.y > window.position.y and rect.position.y < window.end.y, "%s shows in the window" % row.name)
	var scroll: ScrollContainer = _scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value - scroll.size.y)
	await wait_process_frames(2)
	rows = (_list() as ActivityList).get_slide_rows()
	assert_has(rows, merchant_card, "scrolled to the bottom, the last card shows")
	assert_does_not_have(rows, first_card, "and the first group's card has gone above the window")
	assert_does_not_have(rows, first_label_row, "with its label row")
