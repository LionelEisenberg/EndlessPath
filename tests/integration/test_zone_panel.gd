extends GutTest

## Integration tests for the zone chest (ZonePanel, lacquer kit §5.5 and §0):
## the header, the Now strip for each idle action and for the cycle (read from
## CyclingManager's session snapshot, which the tests drive directly), the
## grouped activity list, the chest hugging its list or folding a long list
## under its last whole drawer, the rail and lips, scrolling to a card, the
## lore panel, the techniques mode a cycling session turns the chest to, and
## long text never widening the chest (Review Focus 4). The panel is built on
## a fresh save, as the zone view builds it. The Now strip is as wide as the
## cards beside the list's rail (392, so both edges line up), and no text in it
## is cut off: a name or line that needs more room wraps, the strip grows, and
## the Activities header, the list and the lore move down with its bottom.

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
## keeps its space, so the header, the list and the lore never move up.
const HEADER_TOP: float = 177.0
const LIST_TOP: float = 208.0
const LORE_TOP: float = 182.0
const LORE_PUSH: float = 276.0
## A finished cycle's line sits under the Now tray and pushes the rest down this far.
const LAST_CYCLE_PUSH: float = 26.0
## The lore board's 264 tall at least (it grows with its text), and the 12 px
## under it before the header.
const LORE_MIN_HEIGHT: float = 264.0
const LORE_GAP_UNDER: float = 12.0
## The art's baked shadow beyond the board's right and bottom edges.
const BOARD_SHADOW: float = 4.0
const FULL_CHEST_HEIGHT: float = 1032.0
## A scrolling list keeps 40 px under its fold, and the chest snaps to the
## bottom line when it would end within 64 px of it.
const SCROLLING_LIST_GAP: float = 40.0
const SNAP_DISTANCE: float = 64.0
## The Now strip: the kit's 88 tall and the cards' 392 wide, with each extra line
## of a name 22 px (18 in a detail line) and its contents ending 16 px short of
## the 408 it was.
const STRIP_HEIGHT: float = 88.0
const STRIP_WIDTH: float = 392.0
const NAME_LINE: float = 22.0
const DETAIL_LINE: float = 18.0
## Long enough to need three lines in the strip's name (about 150 px beside the
## rate) and its forage name (292 px), and two in its detail lines.
const LONG_NAME: String = "The Aura Well of the Endless Misty Bamboo Hollow, Lit By The Cold Moon And A Hundred Silent Stars"
## A lore of three long paragraphs: many more lines than the shipped one, which takes
## about ten.
const LONG_LORE: String = "The old road climbs out of the valley between two shoulders of grey stone, and every pilgrim who walks it says each step is paid for in breath. Those who reach the first ridge look back at a sea of mist and understand why the cradle was built where it was.\n\nBeyond the ridge the aura thins and then thickens again, pooling in hollows where the bamboo grows thicker than a man can reach around. Sacred artists have sat in those hollows for ten thousand years, and the stones remember every one of them.\n\nOnly the patient are shown the third path, the one that leaves no footprints and ends where it began."
const NO_TRIMMING: TextServer.OverrunBehavior = TextServer.OVERRUN_NO_TRIMMING
const FOLD_GAP: float = 8.0
const SCROLL_MARGIN: float = 24.0
## A technique drawer is 72 tall, with 8 between drawers (kit §5.5).
const DRAWER_HEIGHT: float = 72.0
const DRAWER_GAP: float = 8.0
## The chest's inner right edge, where the header's clip cuts a header that
## slides out (the chest art is 444 wide; its frame ends 8 px short of that).
const HEADER_CLIP_WIDTH: float = 436.0

## GUT's output window's canvas layer.
const GUT_LAYER: int = 128

## One 60 FPS frame, for stepping the tweens by hand.
const FRAME: float = 1.0 / 60.0

var _panel: ZonePanel = null

## Zone and action names a test changed, restored after it.
var _renamed_zone: ZoneData = null
var _original_zone_name: String = ""
var _relored_zone: ZoneData = null
var _original_description: String = ""
var _renamed_actions: Dictionary[ZoneActionData, String] = {}
var _renamed_techniques: Dictionary[CyclingTechniqueData, String] = {}

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
	if _renamed_zone != null:
		_renamed_zone.zone_name = _original_zone_name
		_renamed_zone = null
	if _relored_zone != null:
		_relored_zone.description = _original_description
		_relored_zone = null
	for action: ZoneActionData in _renamed_actions:
		action.action_name = _renamed_actions[action]
	_renamed_actions.clear()
	for technique: CyclingTechniqueData in _renamed_techniques:
		technique.technique_name = _renamed_techniques[technique]
	_renamed_techniques.clear()
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

## Asserts the tray shows its empty state: the ring dark, no action icon,
## and only the line (and the Now legend) among its texts, so no name,
## rate, level line, figure, yields, haul or rod.
func _assert_empty_tray(line: String) -> void:
	assert_true(_strip().is_visible_in_tree(), "the tray always shows")
	assert_eq(_texts(_strip()), [line, "Now"] as Array[String], "one line and the Now legend")
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark")
	assert_null((_strip_node("ActionIcon") as TextureRect).texture, "no action icon")
	assert_false((_strip_node("WellRod") as Control).is_visible_in_tree(), "no rod")

## Asserts the header and the list sit under the tray, as with an idle action.
func _assert_list_under_tray() -> void:
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP, "the header keeps its place")
	assert_eq(_list().position.y, LIST_TOP, "the list keeps its top")

func test_fresh_save_shows_an_empty_tray() -> void:
	await _add_panel()
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs on a fresh save")
	_assert_empty_tray("Nothing running")
	_assert_list_under_tray()
	assert_eq((_node("LorePanel") as Control).position.y, LORE_TOP, "the lore opens under the tray")

func test_strip_shows_for_aura_well() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")
	await wait_process_frames(2)
	var texts: Array[String] = _texts(_strip())
	assert_has(texts, "Aura Well")
	assert_has(texts, "+1.5 Madra / s")
	assert_has(texts, "+1 Spirit at Lv 1")
	assert_has(texts, "0 / 60")
	assert_does_not_have(texts, "Nothing running")
	assert_eq((_strip_node("ActionIcon") as TextureRect).texture, ZoneManager.get_action_by_id(AURA_WELL_ID).icon)
	_assert_list_under_tray()

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

func test_tray_shows_the_cycle_ready() -> void:
	# Cycling is a session action, but the tray shows it instead of pausing: the
	# action, the equipped technique and its cycle time, with the ring dark, the
	# rod empty and no rate until a cycle draws Madra. The cycling card is not in
	# the list while the player cycles, so the tray takes no clicks.
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	assert_eq(_texts(_strip()), ["Wilderness Cycling", "Foundational Technique", "8 s cycle", "Now"] as Array[String])
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark")
	assert_eq((_strip_node("ActionIcon") as TextureRect).texture, ZoneManager.get_action_by_id(CYCLING_ID).icon, "the action's icon")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 0, "the rod is empty")
	assert_false((_strip_node("RateGroup") as Control).is_visible_in_tree(), "no Madra is drawn yet")
	assert_eq(_strip().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_assert_list_under_tray()

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
	assert_eq((_strip_node("RateText") as RichTextLabel).get_parsed_text(), "+13.3 Madra / s")
	assert_has(_texts(_strip()), "Foundational Technique", "the detail stays the technique's name")

func test_tray_counts_whole_seconds_into_the_cycle() -> void:
	# The seconds into the cycle count whole ones (9.9 s reads 9), and the cycle's
	# length reads to the nearest second (14.6 s reads 15).
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(14.6)
	CyclingManager.update_cycle_session(9.9, 0.0)
	await wait_process_frames(1)
	assert_eq((_strip_node("TicksLabel") as Label).text, "9 / 15 s")

func test_tray_lights_the_whole_ring_at_the_end_of_the_cycle() -> void:
	# The strip has 13 frames: a finished cycle (progress 1) stops on the last
	# one instead of running off the strip.
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(8.0)
	CyclingManager.update_cycle_session(8.0, 5.0)
	await wait_process_frames(1)
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i(12, 0))
	assert_eq((_strip_node("TicksLabel") as Label).text, "8 / 8 s")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 144, "the rod is full")

func test_tray_goes_back_to_ready_when_the_cycle_ends() -> void:
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(8.0)
	CyclingManager.update_cycle_session(6.0, 13.3)
	await wait_process_frames(1)
	assert_gt((_strip_node("Ring") as LacquerStripRect).get_frame().x, 0, "precondition: the ring is lit")
	CyclingManager.end_cycle_session()
	await wait_process_frames(1)
	assert_eq(_texts(_strip()), ["Wilderness Cycling", "Foundational Technique", "8 s cycle", "Now"] as Array[String])
	assert_eq((_strip_node("Ring") as LacquerStripRect).get_frame(), Vector2i.ZERO, "the ring is dark again")
	assert_eq((_strip_node("WellRod") as LacquerRod).get_step(), 0, "and the rod empty")
	assert_false((_strip_node("RateGroup") as Control).is_visible_in_tree(), "no Madra is drawn")

func test_tray_shows_the_cycle_rate_from_a_twentieth() -> void:
	# The rate reads to a tenth, as on the cabinet: 0.049 reads +0 and hides, and
	# 0.05 reads +0.1.
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(8.0)
	var rate_group: Control = _strip_node("RateGroup") as Control
	CyclingManager.update_cycle_session(1.0, 0.049)
	await wait_process_frames(1)
	assert_false(rate_group.is_visible_in_tree(), "0.049 reads +0")
	CyclingManager.update_cycle_session(2.0, 0.05)
	await wait_process_frames(1)
	assert_true(rate_group.is_visible_in_tree(), "0.05 reads +0.1")
	assert_eq((_strip_node("RateText") as RichTextLabel).get_parsed_text(), "+0.1 Madra / s")

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

func test_cycling_drops_the_trays_hover_frame() -> void:
	# The tray stops taking the mouse while cycling, so it never hears the pointer
	# leave: the hover frame the Aura Well's tray was showing goes with the switch.
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	var hover: LacquerFrameOverlay = _strip_node("HoverFrame") as LacquerFrameOverlay
	hover.show()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	assert_false(hover.visible, "no hover frame while cycling")

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
	assert_eq(_texts(_strip()), ["Aura Well", "+1.5 Madra / s", "+1 Spirit at Lv 1", "0 / 60", "Now"] as Array[String])
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
	_assert_list_under_tray()
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

func test_test_zone_tray_reads_nothing_running() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(2)
	ZoneManager.set_current_zone_by_id(TEST_ZONE_ID)
	await wait_process_frames(2)
	assert_null(ActionManager.get_current_action(), "precondition: Test Zone has no idle action")
	_assert_empty_tray("Nothing running")
	_assert_list_under_tray()

func test_empty_tray_click_does_nothing() -> void:
	await _add_panel_above_gut()
	assert_true(_strip().is_visible_in_tree(), "precondition: the empty tray shows")
	watch_signals(_strip())
	_click(_strip().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_signal_not_emitted(_strip(), "strip_pressed")
	assert_eq(_strip().mouse_filter, Control.MOUSE_FILTER_IGNORE, "no hover frame and no pointing hand")

func test_ring_frame_follows_the_action_timer() -> void:
	await _add_panel()
	EventManager.trigger_event(AURA_WELL_EVENT)
	await wait_process_frames(1)
	var ring: LacquerStripRect = _strip_node("Ring") as LacquerStripRect
	var timer: Timer = ActionManager.action_timer
	timer.start(1.0)
	_hold_action_timer_at(0.0)
	await wait_process_frames(1)
	assert_lte(ring.get_frame().x, 1, "a fresh tick lights no more than one bead")
	_hold_action_timer_at(0.5)
	await wait_process_frames(1)
	# floor((1 - time_left / wait_time) x 13): 6 half way through the tick.
	assert_eq(ring.get_frame().x, 6, "the ring lights beads as the tick runs")

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
# NOW STRIP: LINING UP WITH THE CARDS
#-----------------------------------------------------------------------------

## The strip is 392 wide, as the cards are (they keep their width: the list's rail
## needs the room), so its edges and theirs line up: chest x 16 to 408.
func test_the_strip_lines_up_with_the_cards() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	var card: Control = _panel.get_card(AURA_WELL_ID)
	assert_not_null(card, "precondition: the Aura Well's card is listed")
	assert_eq(card.size.x, 392.0, "the cards keep their 392")
	assert_eq(_strip().size.x, STRIP_WIDTH, "the strip narrows to the same")
	assert_eq(_strip().get_global_rect().position.x, card.get_global_rect().position.x, "one left edge")
	assert_eq(_strip().get_global_rect().end.x, card.get_global_rect().end.x, "one right edge")
	var face := _strip_node("Tray") as NinePatchRect
	assert_eq(face.get_global_rect(), _strip().get_global_rect(), "the tray's face fills the strip")

## Its contents' right edges moved in with it: 16 px short of where they were.
func test_the_strips_contents_end_16_px_in() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	var right: float = _strip().get_global_rect().end.x - 16.0
	assert_eq((_strip_node("WellRod") as Control).get_global_rect().end.x, right, "the rod ends 16 px in")
	assert_eq((_strip_node("RateGroup") as Control).get_global_rect().end.x, right, "and the rate")
	assert_eq((_strip_node("TicksLabel") as Control).get_global_rect().end.x, right, "and the ticks")
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	assert_eq((_strip_node("HaulLabel") as Control).get_global_rect().end.x, right, "the haul line too")
	ActionManager.stop_action()
	await wait_process_frames(2)
	var empty := _strip_node("EmptyLabel") as Control
	assert_true(empty.is_visible_in_tree(), "precondition: the tray is empty")
	assert_eq(empty.get_global_rect().end.x, right, "and the empty line's box")

## The rod is the Aura Well's shortened by the same 16: 144 steps of 2 px.
func test_the_rod_is_16_px_shorter() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	var rod := _strip_node("WellRod") as LacquerRod
	assert_eq(rod.steps, 144)
	assert_eq(rod.size.x, 292.0)
	assert_eq(rod.empty_texture.resource_path, "res://assets/ui/lacquer/lacquer_rod_now_empty_ai.png")
	assert_eq(rod.full_texture.resource_path, "res://assets/ui/lacquer/lacquer_rod_now_full_ai.png")
	assert_eq(rod.end_texture.resource_path, "res://assets/ui/lacquer/lacquer_rod_now_end_ai.png")

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
	assert_lte(name_label.get_global_rect().end.x, (_strip_node("RateGroup") as Control).get_global_rect().position.x, "the name wraps before the rate")
	assert_eq(_strip().size.y, STRIP_HEIGHT + NAME_LINE * (name_label.get_line_count() - 1), "every line after the first adds the name's 22 px")
	assert_eq(fposmod(_strip().size.y, 2.0), 0.0, "an even height")
	assert_eq((_strip_node("Tray") as Control).size.y, _strip().size.y, "the tray's face follows")
	assert_eq((_strip_node("Ring") as Control).position, Vector2(14.0, 16.0), "the ring stays at the top")
	assert_eq((_strip_node("ActionIcon") as Control).position, Vector2(26.0, 28.0))
	_assert_chest_follows_the_strip()

func test_the_chest_grows_with_the_strip() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	var extra: float = _strip().size.y - STRIP_HEIGHT
	assert_gt(extra, 0.0, "precondition: the strip grew")
	assert_eq(_panel.size.y, LIST_TOP + extra + (_list() as ActivityList).get_content_height() + 24.0, "the chest hugs the list, which moved down")

func test_the_strip_takes_its_height_back() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	assert_gt(_strip().size.y, STRIP_HEIGHT, "precondition: grown")
	_renamed_actions.keys()[0].action_name = "Aura Well"
	ActionManager.stop_action()
	await wait_process_frames(2)
	assert_eq(_strip().size.y, STRIP_HEIGHT, "the empty tray is the kit's 88 again")
	_assert_list_under_tray()

func test_a_long_forage_name_wraps_and_grows_the_strip() -> void:
	_rename_action(FORAGING_ID, LONG_NAME)
	await _add_panel()
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(2)
	var name_label := _strip_node("ForageName") as Label
	assert_true(name_label.is_visible_in_tree(), "precondition: foraging runs")
	assert_gt(name_label.get_line_count(), 1, "precondition: the name needs more than a line")
	assert_eq(name_label.text_overrun_behavior, NO_TRIMMING)
	assert_eq(_strip().size.y, STRIP_HEIGHT + NAME_LINE * (name_label.get_line_count() - 1))
	assert_eq(fposmod(_strip().size.y, 2.0), 0.0)
	_assert_chest_follows_the_strip()

## A copy of the foraging action whose loot table holds one entry per range ([min,
## max]), the real table's items again and again, so the strip has as many yields
## as a wide table would give it.
func _forage_with_yields(ranges: Array[Vector2i]) -> ForageActionData:
	var real := ZoneManager.get_action_by_id(FORAGING_ID) as ForageActionData
	var forage := real.duplicate() as ForageActionData
	forage.loot_table = LootTable.new()
	for index: int in ranges.size():
		var entry := LootTableEntry.new()
		entry.item = real.loot_table.entries[index % real.loot_table.entries.size()].item
		entry.min_quantity = ranges[index].x
		entry.max_quantity = ranges[index].y
		forage.loot_table.entries.append(entry)
	return forage

## More yields than the row has room for wrap onto a second row, in the room the haul
## countdown leaves them, and the strip grows by the row: nothing passes its right
## edge, the countdown keeps its place, its height stays even and the chest follows.
func test_many_yields_wrap_and_grow_the_strip() -> void:
	await _add_panel()
	var forage := _forage_with_yields([
		Vector2i(1, 5), Vector2i(2, 6), Vector2i(10, 12), Vector2i(20, 40), Vector2i(100, 250), Vector2i(1, 3),
	] as Array[Vector2i])
	_strip()._show_action(forage)
	await wait_process_frames(3)
	var yields: Array[Node] = _strip_node("YieldRow").get_children()
	var haul := _strip_node("HaulLabel") as Control
	assert_eq(yields.size(), 6, "precondition: one yield per entry")
	assert_true(haul.is_visible_in_tree(), "precondition: foraging shows")
	var rows: Dictionary[float, bool] = {}
	var lowest: float = 0.0
	for node: Node in yields:
		var yield_rect: Rect2 = (node as Control).get_global_rect()
		rows[yield_rect.position.y] = true
		lowest = maxf(lowest, yield_rect.end.y)
		assert_lte(yield_rect.end.x, haul.get_global_rect().position.x, "every yield ends before the haul countdown")
		assert_lte(yield_rect.end.x, _strip().get_global_rect().end.x - 16.0, "and 16 px short of the strip's right edge")
	assert_gt(rows.size(), 1, "precondition: they do not all fit on one row")
	assert_eq(_strip().size.y, STRIP_HEIGHT + 20.0 * (rows.size() - 1), "every row after the first adds the yields' 20 px")
	assert_eq(fposmod(_strip().size.y, 2.0), 0.0, "an even height")
	assert_eq(_strip().get_global_rect().end.y - lowest, 20.0, "20 px of tray under the last row, as under the only row of two yields")
	assert_eq(haul.get_global_rect().end.x, _strip().get_global_rect().end.x - 16.0, "the countdown keeps its place")
	assert_eq((_strip_node("Tray") as Control).size.y, _strip().size.y, "the tray's face follows")
	_assert_chest_follows_the_strip()

## The countdown is as wide as its widest reading, so the room the yields wrap in
## does not change as the digits do (a digit is 1 or 2 px wider than another, and a
## yield that fits by less would jump between rows every second, with the whole
## chest moving under it). A cycle of 12 s has a two-digit reading, 8 px wider.
func test_the_haul_countdown_keeps_the_yields_room_as_its_digits_change() -> void:
	await _add_panel()
	var haul := _strip_node("HaulLabel") as Label
	var room := _strip_node("YieldRow") as Control
	for interval: float in [5.0, 12.0]:
		var forage := _forage_with_yields([Vector2i(1, 5), Vector2i(2, 6)] as Array[Vector2i])
		forage.foraging_interval_in_sec = interval
		_strip()._show_action(forage)
		_strip().set_process(false)  # so the countdown shows what the test sets, not the timer's
		await wait_process_frames(3)
		var widths: Dictionary[float, bool] = {}
		for seconds: int in range(1, int(interval) + 1):
			haul.text = "haul in %d s" % seconds
			await wait_process_frames(2)
			widths[room.size.x] = true
		assert_eq(widths.size(), 1, "the yields' room is one width for every reading of a %d s cycle" % int(interval))
		assert_eq(haul.get_global_rect().end.x, _strip().get_global_rect().end.x - 16.0, "the countdown still ends 16 px in")

## A strip that grew for its yields takes its height back for a table of two.
func test_the_strip_takes_its_height_back_from_many_yields() -> void:
	await _add_panel()
	var many := _forage_with_yields([
		Vector2i(1, 5), Vector2i(2, 6), Vector2i(10, 12), Vector2i(20, 40), Vector2i(100, 250), Vector2i(1, 3),
	] as Array[Vector2i])
	_strip()._show_action(many)
	await wait_process_frames(3)
	assert_gt(_strip().size.y, STRIP_HEIGHT, "precondition: grown")
	_strip()._show_action(ZoneManager.get_action_by_id(FORAGING_ID))
	await wait_process_frames(3)
	assert_eq(_strip().size.y, STRIP_HEIGHT, "the kit's 88 again")
	_assert_chest_follows_the_strip()

## The shop pauses the idle action (cycling shows itself in the tray instead).
func test_a_long_paused_line_wraps_and_grows_the_strip() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	var shop: ZoneActionData = ZoneManager.get_action_by_id(MERCHANT_ID)
	for condition: UnlockConditionData in shop.unlock_conditions:
		UnlockManager.force_unlock_condition(condition.condition_id)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	ActionManager.select_action(shop)
	await wait_process_frames(2)
	var line := _strip_node("EmptyLabel") as Label
	assert_true(line.is_visible_in_tree(), "precondition: the tray is empty and reads paused")
	assert_gt(line.get_line_count(), 1, "precondition: the line needs more than one line in its 292 px")
	assert_eq(line.text_overrun_behavior, NO_TRIMMING)
	assert_eq(_strip().size.y, STRIP_HEIGHT + DETAIL_LINE * (line.get_line_count() - 1), "every line after the first adds the detail's 18 px")
	assert_eq(fposmod(_strip().size.y, 2.0), 0.0)
	_assert_chest_follows_the_strip()

## While cycling, the equipped technique stands where the Aura Well's level line
## goes: a long name wraps in what the cycle's figure leaves and grows the strip,
## and the header, the list and the lore move down with it. (The techniques mode
## is MainView's to turn on, so the panel alone keeps its activity list.)
func test_a_long_technique_name_wraps_and_grows_the_cycling_strip() -> void:
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	_renamed_techniques[technique] = technique.technique_name
	technique.technique_name = "The Foundational Technique of the Endless Misty Bamboo Hollow, Breathed Under A Cold Moon"
	await _add_panel()
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	await wait_process_frames(2)
	var line := _strip_node("LevelLabel") as Label
	assert_gt(line.get_line_count(), 1, "precondition: the name needs more than one line")
	assert_eq(line.text_overrun_behavior, NO_TRIMMING)
	assert_lte(line.get_global_rect().end.x, (_strip_node("TicksLabel") as Control).get_global_rect().position.x, "before the cycle's figure")
	assert_eq(_strip().size.y, STRIP_HEIGHT + DETAIL_LINE * (line.get_line_count() - 1), "every line after the first adds the detail's 18 px")
	assert_eq(fposmod(_strip().size.y, 2.0), 0.0)
	_assert_chest_follows_the_strip()

## The level line beside the ticks: wraps in what the ticks leave and grows the
## strip. (The line is made of the level and its reward, which are never long,
## so a long one is put on the label and the strip asked to fit again.)
func test_a_long_level_line_wraps_and_grows_the_strip() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	await wait_process_frames(2)
	var level := _strip_node("LevelLabel") as Label
	level.text = "Lv 123456 → 123457 · +1 Spirit and a very long reward line that has to wrap around"
	_strip()._fit()
	await wait_process_frames(2)
	assert_gt(level.get_line_count(), 1, "precondition: the line wraps")
	assert_eq(level.text_overrun_behavior, NO_TRIMMING)
	assert_lte(level.get_global_rect().end.x, (_strip_node("TicksLabel") as Control).get_global_rect().position.x, "before the ticks")
	assert_eq(_strip().size.y, STRIP_HEIGHT + DETAIL_LINE * (level.get_line_count() - 1))
	var rod := _strip_node("WellRod") as Control
	assert_lt(rod.get_global_rect().end.y, _strip().get_global_rect().end.y, "the rod stays inside the strip")
	_assert_chest_follows_the_strip()

func test_a_grown_strip_pushes_the_open_lore_down() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var extra: float = _strip().size.y - STRIP_HEIGHT
	assert_gt(extra, 0.0, "precondition: the strip grew")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + _lore_push() + extra, "the lore and the strip both push the header")
	assert_eq(_list().position.y, LIST_TOP + _lore_push() + extra)
	assert_eq((_node("LorePanel") as Control).position.y, LORE_TOP + extra, "the lore opens under the grown strip")

## No Label of the strip ellipsizes.
func test_nothing_in_the_strip_keeps_an_ellipsis() -> void:
	await _add_panel()
	var checked: int = 0
	for node: Node in _strip().find_children("*", "Label", true, false):
		assert_eq((node as Label).text_overrun_behavior, NO_TRIMMING, "%s does not trim its text" % node.name)
		checked += 1
	assert_gt(checked, 5, "precondition: the walk met the strip's labels")

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

func test_chest_height_on_a_fresh_save() -> void:
	# The empty tray keeps its space: the one Talk card starts at the list's
	# usual top, 208, and the chest ends 24 px under it.
	await _add_panel()
	var content: float = (_list() as ActivityList).get_content_height()
	assert_gt(content, 0.0, "precondition: the Talk card is listed")
	assert_eq(_list().position.y, LIST_TOP)
	assert_eq(_panel.size.y, LIST_TOP + content + 24.0, "the list top under the tray, then 24 px")

func test_chest_folds_for_ten_cards() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var list: Control = _list()
	var under_list: float = list.position.y + list.size.y + SCROLLING_LIST_GAP
	assert_gt((list as ActivityList).get_content_height(), list.size.y, "precondition: the ten cards scroll")
	assert_gt(FULL_CHEST_HEIGHT - under_list, SNAP_DISTANCE, "precondition: the fold ends too far above the bottom line to snap")
	assert_eq(_panel.size.y, under_list, "a scrolling list keeps 40 px under its fold")
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

## A long Aura Well name grows the Now strip and moves the list down, so the
## fold of the ten cards ends within 64 px of the bottom line.
func test_chest_snaps_to_the_bottom_line() -> void:
	_rename_action(AURA_WELL_ID, LONG_NAME)
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	var list: Control = _list()
	var under_list: float = list.position.y + list.size.y + SCROLLING_LIST_GAP
	assert_gt((list as ActivityList).get_content_height(), list.size.y, "precondition: the list scrolls")
	assert_lte(FULL_CHEST_HEIGHT - under_list, SNAP_DISTANCE, "precondition: the fold ends within 64 px of the bottom line")
	assert_eq(_panel.size.y, FULL_CHEST_HEIGHT, "the chest snaps to the bottom line")

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
	_run_tweens(0.4)
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
	_run_tweens(0.4)
	# The scroll container lays the cards out at the end of a frame.
	await wait_process_frames(2)
	assert_true(_card_fully_visible(MERCHANT_ID))
	assert_true(_card_flashing(MERCHANT_ID))

func test_scroll_to_visible_card_does_not_scroll() -> void:
	await _add_panel()
	_unlock_everything()
	await wait_process_frames(2)
	_panel.scroll_to_action(CYCLING_ID)
	_run_tweens(0.4)
	assert_eq(_scroll().scroll_vertical, 0)
	assert_true(_card_flashing(CYCLING_ID))

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
	assert_eq(header.position.y, header_y + _lore_push(), "the lore pushes the header down by its board and 12")
	assert_eq(_list().position.y, list_y + _lore_push(), "and the list")
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

func test_lore_paragraphs_end_their_sentences() -> void:
	# The mock's Spirit Valley lore ends "...the strength to shake the
	# heavens." with its full stop, and so does every paragraph before it.
	await _add_panel()
	var text: String = (_node("LoreText") as Label).text
	for paragraph: String in text.split("\n"):
		assert_true(paragraph.right(1) in [".", "!", "?"], "'%s' ends its sentence" % paragraph.right(24))

func test_lore_text_is_a_lore_label() -> void:
	# The lore has no decimal point, so it needs no RichTextLabel: the theme's
	# LabelLacquerLore (16/22 cream) sets it, with one override for the kit's
	# 10 px between paragraphs (kit §5.5: text 16/22 cream, width 364 in its 408
	# board, 348 in the 392 one the lore has now).
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
	# The kit's 348 px (the board is 392 wide now, 22 px of margin each side) plus 2:
	# Godot counts the space at a line break against the width and the browser does
	# not.
	assert_eq(lore_text.size.x, 350.0, "the kit's 348 px, as Godot wraps it")
	assert_ne(lore_text.autowrap_mode, TextServer.AUTOWRAP_OFF, "it wraps")

func test_lore_fits_its_panel() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(1)
	var lore_text: Control = _node("LoreText") as Control
	var board: Rect2 = (_node("LorePanel") as Control).get_global_rect()
	assert_lte(lore_text.get_minimum_size().y, lore_text.size.y, "Spirit Valley's lore shows whole")
	assert_lte(lore_text.get_global_rect().end.y, board.end.y, "inside the lore board")

## The lore board is as wide as the Now strip and the cards, so their edges line up:
## chest x 16 to 408. (The board's art carries a 4 px shadow beyond its right and
## bottom edges, which is no part of the edge.)
func test_the_lore_board_lines_up_with_the_strip_and_the_cards() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var board: Rect2 = (_node("LoreBoard") as Control).get_global_rect()
	var strip: Rect2 = _strip().get_global_rect()
	var card: Rect2 = _panel.get_card(AURA_WELL_ID).get_global_rect()
	assert_eq(board.position.x, strip.position.x, "one left edge with the strip")
	assert_eq(board.end.x - BOARD_SHADOW, strip.end.x, "one right edge with the strip")
	assert_eq(board.position.x, card.position.x, "one left edge with the cards")
	assert_eq(board.end.x - BOARD_SHADOW, card.end.x, "one right edge with the cards")
	assert_eq((_node("LorePanel") as Control).size.x, STRIP_WIDTH, "the panel (what a click on the lore hits) is the strip's 392")

## The lore board's face is a NinePatchRect on the art it always had, tiling its
## middle (the gloss dashes) instead of stretching it, so the board grows in either
## direction with the dashes at their size.
func test_the_lore_board_tiles_its_art() -> void:
	await _add_panel()
	var face := _node("LoreBoard") as NinePatchRect
	assert_not_null(face, "the lore board's face is a NinePatchRect")
	if face == null:
		return
	assert_eq(face.texture.resource_path, "res://assets/ui/lacquer/lacquer_lore_ai.png")
	assert_eq([face.patch_margin_left, face.patch_margin_top, face.patch_margin_right, face.patch_margin_bottom], [8, 8, 10, 10], "the corners in 8 px, the shadow in the right and bottom margins")
	assert_eq(face.axis_stretch_horizontal, NinePatchRect.AXIS_STRETCH_MODE_TILE)
	assert_eq(face.axis_stretch_vertical, NinePatchRect.AXIS_STRETCH_MODE_TILE)
	assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the face takes no clicks")

## The lore wraps inside its board, 22 px from the left edge and 20 from the right
## (the kit's 22 each side, 2 of them for the space Godot counts at a line break),
## and nothing is cut off.
func test_the_lore_wraps_inside_its_board() -> void:
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var text := _node("LoreText") as Label
	var board: Rect2 = (_node("LorePanel") as Control).get_global_rect()
	assert_eq(text.text_overrun_behavior, NO_TRIMMING, "wrapped, never trimmed")
	assert_eq(text.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gt(text.get_line_count(), 8, "precondition: the shipped lore takes many lines at that width")
	assert_eq(text.get_global_rect().position.x - board.position.x, 22.0, "22 px in from the left edge")
	assert_eq(board.end.x - text.get_global_rect().end.x, 20.0, "20 px in from the right edge")
	assert_eq(text.size.y, text.get_combined_minimum_size().y, "the label is as tall as its lines")
	assert_lte(text.get_global_rect().end.y, board.end.y, "inside the board")

## A lore that needs more than the board's 264 px grows it: the board is as tall as
## the text asks (an even height, 16 px under the last line), its art covers it and
## its shadow, and the header and the list stand under it.
func test_a_long_lore_grows_the_board_and_pushes_the_chest() -> void:
	_set_lore(LONG_LORE)
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var board := _node("LorePanel") as Control
	var text := _node("LoreText") as Label
	assert_gt(text.get_line_count(), 14, "precondition: many more lines than the shipped lore")
	assert_gt(board.size.y, LORE_MIN_HEIGHT, "the board grew")
	assert_eq(fposmod(board.size.y, 2.0), 0.0, "an even height")
	assert_eq(text.position.y, 20.0, "the text stays 20 px under the top")
	assert_gte(board.size.y - (text.position.y + text.size.y), 16.0, "with 16 px of board under its last line")
	assert_eq((_node("LoreBoard") as Control).size, board.size + Vector2(BOARD_SHADOW, BOARD_SHADOW), "the art covers the board and its shadow")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + _lore_push(), "the header stands under the grown board")
	assert_eq(_list().position.y, LIST_TOP + _lore_push(), "and the list")
	assert_gte(_panel.size.y, _list().position.y + _list().size.y, "the chest holds the list")

## The board takes its 264 back when the lore gets short again.
func test_the_lore_board_takes_its_height_back() -> void:
	_set_lore(LONG_LORE)
	await _add_panel()
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var board := _node("LorePanel") as Control
	assert_gt(board.size.y, LORE_MIN_HEIGHT, "precondition: grown")
	_relored_zone.description = "A short lore."
	_panel._rebuild()
	await wait_process_frames(2)
	assert_eq(board.size.y, LORE_MIN_HEIGHT, "the kit's 264 again")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + LORE_MIN_HEIGHT + LORE_GAP_UNDER, "the header is back under it")

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

func test_techniques_mode_is_off_until_asked() -> void:
	await _add_panel()
	assert_false(_panel.is_techniques_mode())
	assert_eq(_panel.get_technique_list(), _technique_list(), "the chest hands out its list")
	assert_false(_technique_list().is_visible_in_tree(), "the techniques start hidden")
	assert_true(_list().is_visible_in_tree(), "the activities show")
	assert_eq(_header_text(), "Activities")
	assert_eq(_count_text(), "1 here")

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

func test_techniques_mode_chest_hugs_the_list() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	assert_eq(_technique_list().position, Vector2(16.0, LIST_TOP), "the list sits where the activities did")
	assert_eq(_technique_list().size, Vector2(392.0, 232.0), "and is as tall as its three drawers")
	assert_eq(_panel.size.y, 464.0, "208, three drawers (232) and 24 under them")
	assert_eq((_node("ChestBottom") as Control).position.y, 464.0 - 48.0, "the bottom cap closes the chest")

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

func test_the_last_cycle_shows_under_the_now_tray_while_cycling() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	assert_false(_last_cycle_label().visible, "no line before a cycle ends")
	CyclingManager.set_last_cycle_result(_last_cycle(199.47, 3, 4, 1, 75))
	assert_true(_last_cycle_label().visible)
	assert_eq(_last_cycle_label().text, "Last cycle · +199 Madra · 3 / 4 zones · 1 PERFECT · +75 XP")
	assert_eq(_last_cycle_label().position, Vector2(16.0, 180.0), "right under the Now tray")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + LAST_CYCLE_PUSH, "the header moves down to make room")
	assert_eq(_technique_list().position.y, LIST_TOP + LAST_CYCLE_PUSH, "and the drawers with it")
	assert_eq(_panel.size.y, 464.0 + LAST_CYCLE_PUSH, "the chest grows by the line")

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
	assert_eq(fposmod(label.size.y, 2.0), 0.0, "on even px")
	var push: float = label.size.y + 8.0
	assert_gt(push, LAST_CYCLE_PUSH, "precondition: two lines push further than one")
	assert_eq((_node("ActivitiesHeader") as Control).position.y, HEADER_TOP + push, "the header moves down under both lines")
	assert_eq(_technique_list().position.y, LIST_TOP + push, "and the drawers with it")
	assert_eq(_panel.size.y, 464.0 + push, "the chest grows by both lines")

func test_the_last_cycle_line_is_tan_detail_text_across_the_tray() -> void:
	await _add_panel()
	var label: Label = _last_cycle_label()
	assert_eq(label.theme_type_variation, &"LabelLacquerDetail")
	assert_eq(label.size.x, 408.0, "as wide as the Now tray")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "it never ends in an ellipsis")
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "a long line wraps instead")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_the_last_cycle_line_shows_only_while_cycling() -> void:
	await _add_panel()
	var chest_height: float = _panel.size.y
	CyclingManager.set_last_cycle_result(_last_cycle(50.0, 0, 0, 0, 0))
	assert_false(_last_cycle_label().visible, "the activities never show it")
	assert_eq(_panel.size.y, chest_height, "and keep their layout")
	_panel.set_techniques_mode(true)
	assert_true(_last_cycle_label().visible)
	_panel.set_techniques_mode(false)
	assert_false(_last_cycle_label().visible)
	assert_eq(_panel.size.y, chest_height)

func test_clearing_the_last_cycle_closes_the_gap() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	CyclingManager.set_last_cycle_result(_last_cycle(50.0, 0, 0, 0, 0))
	CyclingManager.clear_last_cycle_result()
	assert_false(_last_cycle_label().visible)
	assert_eq(_technique_list().position.y, LIST_TOP)
	assert_eq(_panel.size.y, 464.0)

func test_the_lore_opens_under_the_last_cycle_line() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	CyclingManager.set_last_cycle_result(_last_cycle(50.0, 0, 0, 0, 0))
	(_node("AboutButton") as TextureButton).button_pressed = true
	assert_true((_node("LorePanel") as Control).visible, "precondition: the lore is open")
	assert_eq((_node("LorePanel") as Control).position.y, LORE_TOP + LAST_CYCLE_PUSH)
	assert_eq(_technique_list().position.y, LIST_TOP + LAST_CYCLE_PUSH + LORE_PUSH)

func test_leaving_techniques_mode_restores_activities() -> void:
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	var chest_height: float = _panel.size.y
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	assert_ne(_panel.size.y, chest_height, "precondition: the chest hugged the techniques instead")
	_panel.set_techniques_mode(false)
	await wait_process_frames(2)
	assert_false(_panel.is_techniques_mode())
	assert_true(_list().is_visible_in_tree(), "the activities are back")
	assert_false(_technique_list().is_visible_in_tree(), "the techniques are gone")
	assert_eq(_header_text(), "Activities")
	assert_eq(_count_text(), "1 here")
	assert_eq(_list().position.y, LIST_TOP)
	assert_eq(_panel.size.y, chest_height, "the chest hugs the activities again")

func test_setting_the_mode_twice_changes_nothing() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "still one drawer each")
	assert_eq(_count_text(), "3 learned")
	assert_eq(_panel.size.y, 464.0)
	_panel.set_techniques_mode(false)
	_panel.set_techniques_mode(false)
	await wait_process_frames(2)
	assert_eq(_header_text(), "Activities")
	assert_eq(_count_text(), "1 here")

func test_unlock_in_techniques_mode_adds_a_drawer() -> void:
	# Review Focus 4: a technique unlocked while the chest lists them joins the
	# list, NEW, and the chest grows by a drawer and its gap.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	var chest_height: float = _panel.size.y
	assert_eq(_technique_list().get_drawer_count(), 2, "precondition: foundation and smooth")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	await wait_process_frames(2)
	assert_eq(_technique_list().get_drawer_count(), 3)
	assert_eq(_drawer_ids(), [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID] as Array[String], "the old drawers are replaced, not stacked")
	assert_eq(_count_text(), "3 learned")
	assert_true(_technique_list().get_drawer(TORRENTIAL_ID).is_new_shown(), "the new technique shows NEW")
	assert_eq(_panel.size.y, chest_height + 80.0, "the chest grew a drawer and its 8 px gap")

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
	assert_eq(_technique_list().position.y, LIST_TOP)
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

func test_the_lore_pushes_the_technique_list_down() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(1)
	assert_eq(_technique_list().position.y, LIST_TOP + LORE_PUSH, "the list goes under the lore")
	assert_eq(_panel.size.y, 464.0 + LORE_PUSH, "and the chest grows by as much")

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
	assert_eq((foundation.get_node("%Drawer") as Control).position, Vector2(-2, -2), "precondition: foundation is pulled out")
	CyclingManager.equip_technique(SMOOTH_ID)
	assert_eq((smooth.get_node("%Drawer") as Control).position, Vector2(-2, -2), "smooth is pulled out")
	assert_true((smooth.get_node("%Tag") as Control).visible, "and tagged")
	assert_eq((foundation.get_node("%Drawer") as Control).position, Vector2.ZERO, "foundation goes back in")
	assert_false((foundation.get_node("%Tag") as Control).visible, "and loses its tag")

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
	var foundation: TechniqueDrawer = _technique_list().get_drawer(FOUNDATION_ID)
	assert_eq((foundation.get_node("%Drawer") as Control).position, Vector2.ZERO, "the drawer that was in use goes back in")

func test_technique_list_height_is_what_the_column_lays_out() -> void:
	# As with ActivityList's flow: the height the zone panel reads must be the
	# one the containers lay out, or the chest drifts from its drawers.
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	var list: TechniqueList = _technique_list()
	assert_eq(list.get_content_height(), 232.0, "three drawers and two gaps")
	assert_eq((list.get_node("%Drawers") as Control).size.y, list.get_content_height(), "the column lays out the same height")
	var tops: Array[float] = []
	for technique_id: String in [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID]:
		tops.append(list.get_drawer(technique_id).position.y)
	var pitch: float = DRAWER_HEIGHT + DRAWER_GAP
	assert_eq(tops, [0.0, pitch, 2.0 * pitch] as Array[float], "a drawer and a gap apart")
	assert_eq(list.get_drawer(SMOOTH_ID).size, Vector2(392.0, DRAWER_HEIGHT))

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
	await wait_process_frames(1)
	assert_eq((list.get_node("%Drawers") as Control).size.y, list.get_content_height(), "the column lays out the same height")

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

func test_an_empty_technique_list_has_no_height() -> void:
	await _add_panel()
	PersistenceManager.save_game_data.unlocked_cycling_technique_ids.clear()
	_panel.set_techniques_mode(true)
	assert_eq(_technique_list().get_drawer_count(), 0)
	assert_eq(_technique_list().get_content_height(), 0.0)
	assert_eq(_count_text(), "0 learned")
	assert_eq(_panel.size.y, LIST_TOP + 24.0, "the chest keeps its 24 px under the list top")

func test_get_drawer_finds_a_drawer_by_technique_id() -> void:
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	var drawer: TechniqueDrawer = _technique_list().get_drawer(SMOOTH_ID)
	assert_not_null(drawer)
	assert_eq(drawer.technique.id, SMOOTH_ID)
	assert_null(_technique_list().get_drawer(TORRENTIAL_ID), "a technique not unlocked has no drawer")
	assert_null(_technique_list().get_drawer("no_such_technique"))

func test_technique_list_and_its_column_pass_the_mouse() -> void:
	# Each drawer keeps its own press and hand cursor; the list and the column
	# around the drawers take nothing.
	CyclingManager.unlock_technique(SMOOTH_ID)
	await _add_panel()
	_panel.set_techniques_mode(true)
	assert_eq(_technique_list().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_technique_list().get_node("%Drawers") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for technique_id: String in [FOUNDATION_ID, SMOOTH_ID]:
		var drawer: TechniqueDrawer = _technique_list().get_drawer(technique_id)
		assert_eq(drawer.mouse_filter, Control.MOUSE_FILTER_STOP, "%s takes the press" % technique_id)
		assert_eq(drawer.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)

func test_a_new_layout_from_the_technique_list_resizes_the_chest() -> void:
	await _add_panel()
	_panel.set_techniques_mode(true)
	# Unlocked behind the manager's back, so that only the list's own
	# layout_changed can tell the chest.
	PersistenceManager.save_game_data.unlocked_cycling_technique_ids.append(SMOOTH_ID)
	_technique_list().build()
	assert_eq(_panel.size.y, LIST_TOP + 2.0 * DRAWER_HEIGHT + DRAWER_GAP + 24.0)
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# SLIDE SUPPORT
#-----------------------------------------------------------------------------

## The Control the Activities header sits in, which clips it.
func _header_clip() -> Control:
	return (_node("ActivitiesHeader") as Control).get_parent() as Control

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

## The techniques unlocked before the chest was built have no drawers yet (the list
## builds when the chest turns to it, or when a technique unlocks), but the height
## the chest will have there is still asked for before it turns.
func test_chest_height_for_counts_drawers_that_were_never_built() -> void:
	_unlock_all_techniques()
	await _add_panel()
	assert_eq(_technique_list().get_drawer_count(), 0, "precondition: the list has not built its drawers")
	assert_eq(_panel.chest_height_for(true), LIST_TOP + 3.0 * DRAWER_HEIGHT + 2.0 * DRAWER_GAP + 24.0, "three drawers, two gaps")
	await _await_queued_frees()

## The last cycle's line counts only in the techniques mode, and the lore as it is now.
func test_chest_height_for_counts_the_last_cycle_line_and_the_lore() -> void:
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	_renamed_techniques[technique] = technique.technique_name
	technique.technique_name = "The Foundational Technique of the Endless Misty Bamboo Hollow, Breathed Under A Cold Moon"
	_unlock_all_techniques()
	await _add_panel()
	CyclingManager.set_last_cycle_result(_last_cycle(199.47, 3, 4, 1, 75))
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	var activities_height: float = _panel.size.y
	assert_eq(_panel.chest_height_for(false), activities_height, "the activities never count the line")
	var technique_height: float = _panel.chest_height_for(true)
	await _await_queued_frees()
	_panel.set_techniques_mode(true)
	assert_eq(technique_height, _panel.size.y, "the line, the lore and the wrapped drawer are all in")
	assert_gt(_panel.size.y, 464.0 + LORE_PUSH + LAST_CYCLE_PUSH, "precondition: the long name made a drawer taller")
	assert_eq(_panel.chest_height_for(false), activities_height)
	await _await_queued_frees()

func test_height_override_sizes_the_frame_and_clears() -> void:
	await _add_panel()
	var natural: float = _panel.size.y
	var list_top: float = _list().position.y
	var list_height: float = _list().size.y
	_panel.set_height_override(400.0)
	assert_eq(_panel.size.y, 400.0, "the chest takes the height")
	assert_eq((_node("ChestBottom") as Control).position.y, 400.0 - ZonePanel.CHEST_BOTTOM_HEIGHT, "the bottom slice goes with it")
	assert_eq((_node("ChestMid") as Control).size.y, 400.0 - ZonePanel.CHEST_TOP_HEIGHT - ZonePanel.CHEST_BOTTOM_HEIGHT, "and the middle tiles between")
	assert_eq(_list().position.y, list_top, "the list keeps its place")
	assert_eq(_list().size.y, list_height, "and its height")
	_panel.clear_height_override()
	assert_eq(_panel.size.y, natural, "the chest hugs the list again")
	assert_eq((_node("ChestBottom") as Control).position.y, natural - ZonePanel.CHEST_BOTTOM_HEIGHT)
	assert_eq((_node("ChestMid") as Control).size.y, natural - ZonePanel.CHEST_TOP_HEIGHT - ZonePanel.CHEST_BOTTOM_HEIGHT)

## A layout change while the override is set (the lore opening, say) moves the
## lists but not the frame.
func test_a_relayout_keeps_the_height_override() -> void:
	await _add_panel()
	_panel.set_height_override(400.0)
	(_node("AboutButton") as BaseButton).button_pressed = true
	await wait_process_frames(2)
	assert_eq(_list().position.y, LIST_TOP + _lore_push(), "the list moved down under the lore")
	assert_eq(_panel.size.y, 400.0, "the frame stays where it was held")
	_panel.clear_height_override()
	assert_eq(_panel.size.y, _panel.chest_height_for(false), "and once let go it hugs the list under the lore")
	assert_gt(_panel.size.y, 400.0, "precondition: the lore pushed the natural height past the override")

func test_slide_rows_start_with_the_header() -> void:
	await _add_panel()
	var rows: Array[Control] = _panel.get_slide_rows()
	assert_eq(rows.size(), 3, "the header, the Talk group's label row and its one card on a fresh save")
	assert_same(rows[0], _node("ActivitiesHeader"), "the header comes first")
	assert_same(rows[1], _label_row_of(_list_node("Content").get_child(0)), "then the group's label row")
	assert_true(rows[2] is ZoneActionButton, "then its card")
	assert_true(_tops_increase(rows), "top to bottom")

func test_slide_rows_in_the_techniques_mode_are_the_drawers() -> void:
	_unlock_all_techniques()
	await _add_panel()
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	var rows: Array[Control] = _panel.get_slide_rows()
	assert_eq(rows.size(), 4, "the header and a drawer each")
	assert_same(rows[0], _node("ActivitiesHeader"))
	var technique_ids: Array[String] = [FOUNDATION_ID, SMOOTH_ID, TORRENTIAL_ID]
	for index: int in technique_ids.size():
		assert_same(rows[index + 1], _technique_list().get_drawer(technique_ids[index]), "%s's drawer, in unlock order" % technique_ids[index])
	assert_true(_tops_increase(rows), "top to bottom")
	_panel.set_techniques_mode(false)
	assert_same(_panel.get_slide_rows()[1], _label_row_of(_list_node("Content").get_child(0)), "and the activities' rows are back")

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

func test_technique_slide_rows_are_the_drawers_top_to_bottom() -> void:
	_unlock_all_techniques()
	await _add_panel()
	assert_eq(_technique_list().get_slide_rows().size(), 0, "no drawers before the list builds them")
	_panel.set_techniques_mode(true)
	await wait_process_frames(2)
	var rows: Array[Control] = _technique_list().get_slide_rows()
	assert_eq(rows.size(), 3)
	assert_true(_tops_increase(rows), "top to bottom")
	for drawer: Node in _technique_list().get_node("%Drawers").get_children():
		assert_has(rows, drawer, "every drawer of the column")

func test_the_header_and_technique_list_clip() -> void:
	await _add_panel()
	var clip: Control = _header_clip()
	assert_ne(clip, _panel, "the header sits in a clip of its own, not directly in the chest")
	assert_eq(clip.name, &"HeaderClip")
	assert_true(clip.clip_contents, "the header's clip cuts what slides past it")
	assert_eq(clip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(clip.position, Vector2.ZERO)
	assert_eq(clip.size, Vector2(HEADER_CLIP_WIDTH, FULL_CHEST_HEIGHT), "it ends at the chest's inner right edge")
	assert_eq(clip.get_parent(), _panel)
	assert_true(_technique_list().clip_contents, "the technique list cuts its drawers at its edge")

## At rest, the header's whole text (the count at its right too) lies inside the clip.
func test_the_header_text_fits_its_clip_at_rest() -> void:
	_unlock_all_techniques()
	await _add_panel()
	var clip: Control = _header_clip()
	for mode_on: bool in [false, true]:
		_panel.set_techniques_mode(mode_on)
		await wait_process_frames(2)
		var window: Rect2 = clip.get_global_rect()
		for label_name: String in ["HeaderLabel", "CountLabel"]:
			var label: Label = _node(label_name) as Label
			assert_true(window.encloses(label.get_global_rect()), "%s ('%s') lies inside the clip" % [label_name, label.text])
		assert_true(window.encloses((_node("ActivitiesHeader") as Control).get_global_rect()), "so does the whole row")
	await _await_queued_frees()
