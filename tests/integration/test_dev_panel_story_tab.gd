extends GutTest

## The dev panel's Story tab, against the real managers. The tab jumps the story to a
## beat of the route (a fresh preset session played through it), shows each active
## quest with its step and the quests done, fires any event the content listens to,
## lists the current zone's actions with their status (available, used up, passed or
## locked, naming the unmet conditions) and completes an available one, and shows the
## events fired and the conditions latched. It refreshes as the game changes and when
## it is shown. A refusal shows in a status line pinned under the part that scrolls,
## so any control's refusal is in view, and the next command that works clears it.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it. Each test
## binds a fresh in-memory save and gives back everything it changed: the save, the
## player's log, DevManager's session and panel fields, and the preset folder and pin
## file, which point at paths nothing is written to.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")
const ACTION_ROW_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/rows/dev_action_row.tscn")

const SessionKind = DevManager.SessionKind

## The size MainView gives the panel in the game.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

## A switch runs on the next frame. Two frames leave it done.
const SWITCH_FRAMES: int = 2

## The prefix of every [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## Where the preset folder and the pin file point, so the Saves tab of the panel reads
## neither the repository's presets nor the checkout's pin. Nothing is written there.
const PRESET_DIR: String = "user://__test_dev_panel_story_tab_presets/"
const PIN_PATH: String = "user://__test_dev_panel_story_tab_pin.cfg"

const ZONE_ID: String = "SpiritValley"
## The zone the map hides. It has no actions, and it is locked until NPC 1's event fires.
const OTHER_ZONE_ID: String = "TestZone"

## NPC 1: available on a fresh save and used up after one completion. Its success
## effects fire the event of the same name and start q_fill_core.
const NPC_1: String = "celestial_intervener_dialogue_1"
## NPC 2 unlocks once q_fill_core's Madra goal is met: locked on a fresh save.
const NPC_2: String = "celestial_intervener_dialogue_2"
## Locked on a fresh save: it needs Core Density 10. A preset that completes it fails
## midway through its build.
const NPC_4: String = "celestial_intervener_dialogue_4"
## Locked until NPC 1's event fires, and never used up.
const CYCLING_ACTION: String = "wilderness_cycling_action"
const TRIBULATION: String = "spirit_valley_tribulation"
const FILL_CORE: String = "q_fill_core"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_history: Array[String]
var _original_session_kind: DevManager.SessionKind
var _original_session_preset: SavePresetData
var _original_last_switch_failure: String
var _original_preset_dir_override: String
var _original_pin_path_override: String
var _original_panel_open: bool
var _original_panel_position: Vector2
var _original_panel_tab: int

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_history = LogManager._history.duplicate()
	_original_session_kind = DevManager._session_kind
	_original_session_preset = DevManager._session_preset
	_original_last_switch_failure = DevManager._last_switch_failure
	_original_preset_dir_override = DevManager.preset_dir_override
	_original_pin_path_override = LaunchOptions.pin_path_override
	_original_panel_open = DevManager.panel_open
	_original_panel_position = DevManager.panel_position
	_original_panel_tab = DevManager.panel_tab
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	DevManager.preset_dir_override = PRESET_DIR
	LaunchOptions.pin_path_override = PIN_PATH
	DevManager._session_kind = SessionKind.YOUR_SAVE
	DevManager._session_preset = null
	DevManager._last_switch_failure = ""
	DevManager.panel_open = false
	DevManager.panel_position = Vector2(24, 24)
	DevManager.panel_tab = 0

func after_each() -> void:
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(_original_save, _original_save_path)
	LogManager._history = _original_history
	DevManager._session_kind = _original_session_kind
	DevManager._session_preset = _original_session_preset
	DevManager._last_switch_failure = _original_last_switch_failure
	DevManager.preset_dir_override = _original_preset_dir_override
	LaunchOptions.pin_path_override = _original_pin_path_override
	DevManager.panel_open = _original_panel_open
	DevManager.panel_position = _original_panel_position
	DevManager.panel_tab = _original_panel_tab
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the panel inside a Control the size of the screen, as MainView holds it.
## It starts closed, as a launch's does.
func _add_panel() -> DevPanel:
	var host := Control.new()
	host.size = SCREEN_SIZE
	add_child_autofree(host)
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	host.add_child(panel)
	return panel

## Opens the panel on the Story tab and returns the tab.
func _show_story_tab(panel: DevPanel) -> DevStoryTab:
	panel.set_open(true)
	var tab: DevStoryTab = panel.get_node("%StoryTab")
	var tabs: TabContainer = panel.get_node("%Tabs")
	tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	return tab

## Builds the panel and opens it on the Story tab, as a developer finds it.
func _open_story_tab() -> DevStoryTab:
	return _show_story_tab(_add_panel())

## Presses a button the way a click does: it says it was pressed.
func _press(node: Node, button_name: String) -> void:
	(node.get_node("%" + button_name) as BaseButton).pressed.emit()

func _label(node: Node, label_name: String) -> Label:
	return node.get_node("%" + label_name) as Label

func _button(node: Node, button_name: String) -> Button:
	return node.get_node("%" + button_name) as Button

## The status line at the foot of the tab.
func _status(tab: Node) -> Label:
	return _label(tab, "StoryStatus")

## The action rows, in the order the tab lists them.
func _rows(tab: Node) -> Array[Node]:
	return (tab.get_node("%ActionList") as Node).get_children()

## The row that shows the action.
func _row(tab: Node, action_id: String) -> DevActionRow:
	for node: Node in _rows(tab):
		var row := node as DevActionRow
		if row.get_action().action_id == action_id:
			return row
	fail_test("the tab has no row for %s" % action_id)
	return null

func _status_of(tab: Node, action_id: String) -> String:
	return _label(_row(tab, action_id), "StatusLabel").text

func _action(action_id: String) -> ZoneActionData:
	return ZoneManager.get_action_by_id(action_id)

## The completions counted for the action in Spirit Valley.
func _completions(action_id: String) -> int:
	return ZoneManager.get_zone_progression(ZONE_ID).action_completion_count.get(action_id, 0)

## The picker's item texts, in order.
func _item_texts(option: OptionButton) -> Array[String]:
	var texts: Array[String] = []
	for index: int in option.item_count:
		texts.append(option.get_item_text(index))
	return texts

## The picker's item metadata, in order, as strings.
func _item_metadata(option: OptionButton) -> Array[String]:
	var values: Array[String] = []
	for index: int in option.item_count:
		values.append(str(option.get_item_metadata(index)))
	return values

func _strings(packed: PackedStringArray) -> Array[String]:
	var strings: Array[String] = []
	strings.assign(packed)
	return strings

## Picks the item whose metadata is `metadata`, the way a player picks it from the list.
func _pick_metadata(option: OptionButton, metadata: String) -> void:
	for index: int in option.item_count:
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return
	fail_test("the picker has no item for %s" % metadata)

## Picks the item that reads `text`.
func _pick_text(option: OptionButton, text: String) -> void:
	for index: int in option.item_count:
		if option.get_item_text(index) == text:
			option.select(index)
			return
	fail_test("the picker has no item reading %s" % text)

## The [DEV] lines the player's log got since watch_signals(LogManager).
func _dev_lines() -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		if line.begins_with(DEV_LINE):
			lines.append(line)
	return lines

## A preset that fails midway through its build: NPC 4 is not available on a fresh save.
func _failing_preset() -> SavePresetData:
	var step := DevStepData.new()
	step.kind = DevStepData.Kind.COMPLETE_ACTION
	step.target_id = NPC_4
	var steps: Array[DevStepData] = [step]
	var preset := SavePresetData.new()
	preset.preset_id = "story_tab_fails_midway"
	preset.title = "Failing"
	preset.steps = steps
	return preset

#-----------------------------------------------------------------------------
# THE TAB
#-----------------------------------------------------------------------------

func test_the_story_tab_comes_right_after_player() -> void:
	var panel: DevPanel = _add_panel()
	var tabs: TabContainer = panel.get_node("%Tabs")
	var story: int = tabs.get_tab_idx_from_control(panel.get_node("%StoryTab"))
	var player: int = tabs.get_tab_idx_from_control(panel.get_node("%PlayerTab"))
	assert_ne(story, -1, "precondition: the Story tab is one of the tabs")
	assert_eq(tabs.get_tab_title(story), "Story")
	assert_eq(story, player + 1, "it follows the Player tab")

## No text is cut off: every label that can run long wraps, and is told how wide it
## may be.
func test_the_long_labels_wrap() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var row: Node = _rows(tab)[0]
	var labels: Array[Label] = [
		_label(tab, "QuestsLabel"), _label(tab, "EventsLabel"), _status(tab),
		_label(row, "NameLabel"), _label(row, "StatusLabel"),
	]
	for label: Label in labels:
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s wraps by word" % label.name)
		assert_gt(label.custom_minimum_size.x, 0.0, "%s has a width to wrap in" % label.name)
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s does not trim its text" % label.name)
		assert_false(label.clip_text, "%s does not clip its text" % label.name)

## A refusal can come from the Jump or Trigger button or from any row's Complete, which
## may be far down a scrolled tab. The status stands outside the part that scrolls, so
## it is in view wherever the tab is scrolled to.
func test_the_status_stands_outside_the_part_that_scrolls() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var scrolling: ScrollContainer = tab.get_node("%Scroll")
	assert_true(scrolling.is_ancestor_of(tab.get_node("%ActionList")), "precondition: the rows scroll")
	assert_true(tab.is_ancestor_of(_status(tab)), "the status belongs to the tab")
	assert_false(scrolling.is_ancestor_of(_status(tab)), "and does not scroll with the rows")

## The status shows nothing, and takes no room, until something is refused.
func test_the_status_starts_hidden() -> void:
	assert_false(_status(_open_story_tab()).visible)

#-----------------------------------------------------------------------------
# JUMP
#-----------------------------------------------------------------------------

func test_the_jump_picker_lists_the_beats_of_the_route() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var option: OptionButton = tab.get_node("%JumpOption")
	var texts: Array[String] = []
	var ids: Array[String] = []
	for beat: StoryBeatData in DevManager.get_route().beats:
		texts.append("%s (%s)" % [beat.title, beat.beat_id])
		ids.append(beat.beat_id)
	assert_gt(texts.size(), 0, "precondition: the route has beats")
	assert_eq(_item_texts(option), texts, "each beat reads its title and its id")
	assert_eq(_item_metadata(option), ids, "and the item carries the id")
	assert_has(texts, "Awakening (beat_1)", "a beat the Saves tab also names")

func test_jump_plays_story_through_the_beat() -> void:
	var tab: DevStoryTab = _open_story_tab()
	_pick_metadata(tab.get_node("%JumpOption"), "beat_2")
	_press(tab, "JumpButton")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "the switch waits for the next frame")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "the jump started a preset session")
	var preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(preset)
	if preset != null:
		assert_eq(preset.preset_id, "story_through_beat_2", "an unnamed preset through the picked beat")
		assert_eq(preset.story_through, "beat_2")
	assert_true(EventManager.has_event_triggered("celestial_intervener_dialogue_3"), "beat 2 was played")
	assert_false(EventManager.has_event_triggered("aura_well_discovered"), "and no beat after it")
	assert_false(_status(tab).visible, "a jump that works shows no refusal")

## The tab is still there after the switch under GUT (a real run frees the panel and
## builds it again), and shows the story the jump played.
func test_the_tab_shows_the_story_a_jump_played() -> void:
	var tab: DevStoryTab = _open_story_tab()
	_pick_metadata(tab.get_node("%JumpOption"), "beat_2")
	_press(tab, "JumpButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(_label(tab, "QuestsLabel").text, "Harden Your Core — step 1: Reach Core Density level 10\nDone: Awaken Your Core, First Steps Out")
	assert_string_contains(_label(tab, "EventsLabel").text, "celestial_intervener_dialogue_3", "the events fired by the jump")
	assert_eq(_status_of(tab, NPC_1), "Used up (1/1)", "the actions the route completed")

## A second jump asked for while the first is pending is refused by DevManager, and
## the tab shows why. The first then runs, which clears the refusal.
func test_a_refused_jump_shows_its_reason() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var status: Label = _status(tab)
	_press(tab, "JumpButton")
	_press(tab, "JumpButton")
	assert_true(status.is_visible_in_tree(), "the refusal shows")
	assert_eq(status.text, DevManager.SWITCH_UNDER_WAY)
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "the first jump ran")
	assert_false(status.visible, "and a switch that works clears the refusal")

## In a real run a switch frees the panel and builds it again, and a failure midway is
## emitted while no panel is there to hear it: the tab built next shows it.
func test_a_failed_switch_shows_in_the_tab_built_after_it() -> void:
	var panel: DevPanel = _add_panel()
	var tab: DevStoryTab = _show_story_tab(panel)
	DevManager.play_preset(_failing_preset())
	await wait_process_frames(SWITCH_FRAMES)
	var failure: String = DevManager.get_last_switch_failure()
	assert_string_contains(failure, NPC_4, "precondition: the build failed midway")
	assert_eq(_status(tab).text, failure, "the tab shows why")
	panel.free()
	var rebuilt: DevStoryTab = _open_story_tab()
	assert_true(_status(rebuilt).visible, "a tab built after the failure shows it")
	assert_eq(_status(rebuilt).text, failure)
	DevManager.play_story_through("beat_1")
	await wait_process_frames(SWITCH_FRAMES)
	assert_false(_status(rebuilt).visible, "a switch that works clears it")

#-----------------------------------------------------------------------------
# QUESTS
#-----------------------------------------------------------------------------

func test_quests_label_shows_the_current_step() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var quests: Label = _label(tab, "QuestsLabel")
	assert_eq(quests.text, "No quests started yet", "precondition: a fresh save has none")
	QuestManager.start_quest(FILL_CORE)
	assert_eq(quests.text, "Awaken Your Core — step 1: Fill your Madra by cycling", "the quest, its step and what the step asks")
	DevCommands.set_madra(100.0)
	assert_eq(quests.text, "Awaken Your Core — step 2: Return to the Celestial [INTERVENER]", "the next step once the first is done")

func test_quests_label_lists_every_active_quest_then_the_quests_done() -> void:
	DevCommands.complete_action(NPC_1)
	DevCommands.set_madra(100.0)
	DevCommands.complete_action(NPC_2)
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(_label(tab, "QuestsLabel").text, "First Steps Out — step 1: Defeat an enemy in combat\nDone: Awaken Your Core", "NPC 2 finished the first quest and started the second")

#-----------------------------------------------------------------------------
# EVENTS
#-----------------------------------------------------------------------------

func test_the_event_picker_lists_the_events_the_content_listens_to() -> void:
	var option: OptionButton = _open_story_tab().get_node("%EventOption")
	assert_gt(option.item_count, 0, "precondition: the content listens to events")
	assert_eq(_item_texts(option), _strings(DevCommands.known_event_ids()), "the same ids, in the same order")

func test_trigger_fires_the_event() -> void:
	var tab: DevStoryTab = _open_story_tab()
	_pick_text(tab.get_node("%EventOption"), NPC_1)
	assert_false(EventManager.has_event_triggered(NPC_1), "precondition")
	watch_signals(LogManager)
	_press(tab, "TriggerButton")
	assert_true(EventManager.has_event_triggered(NPC_1), "the event fired")
	assert_eq(_dev_lines(), [DEV_LINE + "Triggered event %s" % NPC_1] as Array[String], "through the command, which logs it")
	assert_false(_status(tab).visible, "a command that works shows no refusal")

## The picker offers only events the content listens to, so the tab is handed one it does
## not to see the command's refusal.
func test_a_refused_trigger_shows_its_reason_and_a_good_one_clears_it() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var option: OptionButton = tab.get_node("%EventOption")
	option.add_item("not_an_event")
	option.select(option.item_count - 1)
	_press(tab, "TriggerButton")
	assert_true(_status(tab).is_visible_in_tree(), "a refusal shows")
	assert_eq(_status(tab).text, DevCommands.trigger_event("not_an_event"), "and it is the command's reason")
	assert_false(EventManager.has_event_triggered("not_an_event"), "nothing fired")
	_pick_text(option, NPC_1)
	_press(tab, "TriggerButton")
	assert_false(_status(tab).visible, "a command that works clears the refusal")

func test_the_events_label_lists_the_events_fired_and_the_conditions_latched() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var events: Label = _label(tab, "EventsLabel")
	assert_eq(events.text, "Events: none\nConditions: none", "precondition: a fresh save")
	DevCommands.trigger_event(NPC_1)
	assert_eq(events.text, "Events: %s\nConditions: %s" % [NPC_1, NPC_1], "NPC 1's event fired and latched the condition that waits for it")
	DevCommands.set_madra(100.0)
	assert_string_contains(events.text, "Conditions: %s, q_fill_core_madra_full" % NPC_1, "conditions list in the order they latched")

#-----------------------------------------------------------------------------
# ACTIONS
#-----------------------------------------------------------------------------

func test_every_action_of_the_current_zone_has_a_row() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var expected: Array[String] = []
	for action: ZoneActionData in ZoneManager.get_current_zone().all_actions:
		expected.append(action.action_id)
	var shown: Array[String] = []
	for node: Node in _rows(tab):
		shown.append((node as DevActionRow).get_action().action_id)
	assert_gt(expected.size(), 0, "precondition: Spirit Valley has actions")
	assert_eq(shown, expected, "one row per action, in the zone's order")
	assert_string_contains(_label(tab, "ActionsHeader").text, "Spirit Valley", "under a header naming the zone")

func test_the_rows_follow_the_current_zone() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var header: Label = _label(tab, "ActionsHeader")
	var rows: int = _rows(tab).size()
	assert_gt(rows, 0, "precondition: Spirit Valley has actions")
	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "")
	assert_eq(_rows(tab).size(), 0, "the Test Zone has none")
	assert_string_contains(header.text, "Test Zone", "and the header names it")
	# The rows the list lost are freed a frame later: let them go, so none is left orphaned.
	await wait_process_frames(1)
	assert_eq(DevCommands.travel_to_zone(ZONE_ID), "")
	assert_eq(_rows(tab).size(), rows, "back in Spirit Valley, its rows return")
	assert_string_contains(header.text, "Spirit Valley")

func test_a_locked_action_names_its_conditions() -> void:
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(DevStoryTab.action_status(_action(NPC_2), ZONE_ID), "Locked: needs q_fill_core_madra_full")
	var row: DevActionRow = _row(tab, NPC_2)
	assert_eq(_label(row, "StatusLabel").text, "Locked: needs q_fill_core_madra_full", "and its row says so")
	assert_true(_button(row, "CompleteButton").disabled, "with nothing to complete")

func test_an_available_action_can_be_completed() -> void:
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(DevStoryTab.action_status(_action(NPC_1), ZONE_ID), "Available")
	var row: DevActionRow = _row(tab, NPC_1)
	assert_eq(_label(row, "StatusLabel").text, "Available")
	assert_false(_button(row, "CompleteButton").disabled, "Complete is on for an available action only")

## Every status the tab can give an action, as the game moves from a fresh save to a
## passed Tribulation: the rule is ZoneManager's, so the tab reads what it offers.
func test_action_status_follows_the_game() -> void:
	var npc_1: ZoneActionData = _action(NPC_1)
	var tribulation: ZoneActionData = _action(TRIBULATION)
	assert_eq(DevStoryTab.action_status(npc_1, ZONE_ID), "Available")
	assert_eq(DevCommands.complete_action(NPC_1), "")
	assert_eq(DevStoryTab.action_status(npc_1, ZONE_ID), "Used up (1/1)", "NPC 1 can be completed once")
	assert_eq(DevStoryTab.action_status(tribulation, ZONE_ID), "Locked: needs core_density_full")
	assert_eq(DevCommands.reach_core_density(100), "")
	assert_eq(DevStoryTab.action_status(tribulation, ZONE_ID), "Available", "the full core opens the Tribulation")
	assert_eq(DevCommands.advance_stage(), "")
	assert_eq(DevStoryTab.action_status(tribulation, ZONE_ID), "Passed", "and passing it ends it")

## The count is the real one, not the limit: an action completed three times of three.
func test_a_used_up_action_shows_its_completions_of_its_limit() -> void:
	var action := ZoneActionData.new()
	action.action_id = "story_tab_triple"
	action.max_completions = 3
	ZoneManager.increment_zone_progression_for_action(action.action_id, ZONE_ID, 3)
	assert_eq(DevStoryTab.action_status(action, ZONE_ID), "Used up (3/3)")

## The ids that are named are the conditions the rule finds unmet, so one that has latched
## drops off the list.
func test_action_status_lists_every_unmet_condition() -> void:
	var conditions: Array[UnlockConditionData] = [_action(NPC_2).unlock_conditions[0], _action(TRIBULATION).unlock_conditions[0]]
	var action := ZoneActionData.new()
	action.action_id = "story_tab_two_conditions"
	action.unlock_conditions = conditions
	assert_eq(DevStoryTab.action_status(action, ZONE_ID), "Locked: needs q_fill_core_madra_full, core_density_full")
	DevCommands.set_madra(100.0)
	assert_eq(DevStoryTab.action_status(action, ZONE_ID), "Locked: needs core_density_full", "q_fill_core_madra_full latched")

## ZoneManager offers nothing in a zone that is locked, whatever the action's own
## conditions say, so the zone's conditions are among those named.
func test_action_status_names_the_conditions_of_a_locked_zone() -> void:
	var action := ZoneActionData.new()
	action.action_id = "story_tab_no_conditions"
	assert_eq(DevStoryTab.action_status(action, OTHER_ZONE_ID), "Locked: needs %s" % NPC_1, "the Test Zone waits for NPC 1's event")

func test_complete_on_a_row_completes_it() -> void:
	var tab: DevStoryTab = _open_story_tab()
	var row: DevActionRow = _row(tab, NPC_1)
	assert_false(_button(row, "CompleteButton").disabled, "precondition: NPC 1 is available on a fresh save")
	watch_signals(LogManager)
	_press(row, "CompleteButton")
	assert_eq(_completions(NPC_1), 1, "one completion counted")
	assert_true(QuestManager.has_active_quest(FILL_CORE), "and its success effects ran")
	assert_null(ActionManager.get_current_action(), "nothing was played")
	assert_eq(_dev_lines(), [DEV_LINE + "Completed action %s" % NPC_1] as Array[String], "through the command, which logs it")
	assert_eq(_label(row, "StatusLabel").text, "Used up (1/1)", "the row follows")
	assert_true(_button(row, "CompleteButton").disabled, "with nothing left to complete")
	assert_false(_status(tab).visible, "a command that works shows no refusal")

## A button that is off cannot be clicked, so the row's signal is what reaches the
## command here: the tab shows its refusal, and the next command that works clears it.
func test_a_refused_complete_shows_its_reason_and_a_good_one_clears_it() -> void:
	var tab: DevStoryTab = _open_story_tab()
	_press(_row(tab, NPC_2), "CompleteButton")
	assert_true(_status(tab).is_visible_in_tree(), "a refusal shows")
	assert_eq(_status(tab).text, DevCommands.complete_action(NPC_2), "and it is the command's reason")
	assert_eq(_completions(NPC_2), 0, "nothing was completed")
	_press(_row(tab, NPC_1), "CompleteButton")
	assert_false(_status(tab).visible, "a command that works clears the refusal")

#-----------------------------------------------------------------------------
# REFRESH
#-----------------------------------------------------------------------------

## A condition latching opens the action behind it, and an event firing opens the one
## that waits for it.
func test_the_rows_refresh_as_the_story_moves() -> void:
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(_status_of(tab, NPC_2), "Locked: needs q_fill_core_madra_full", "precondition")
	assert_eq(_status_of(tab, CYCLING_ACTION), "Locked: needs %s" % NPC_1, "precondition")
	DevCommands.set_madra(100.0)
	assert_eq(_status_of(tab, NPC_2), "Available", "a condition latched")
	assert_false(_button(_row(tab, NPC_2), "CompleteButton").disabled)
	DevCommands.trigger_event(NPC_1)
	assert_eq(_status_of(tab, CYCLING_ACTION), "Available", "an event fired")

## Passing the Tribulation moves the player to the next stage, which ends its card.
func test_the_tribulation_row_reads_passed_after_the_breakthrough() -> void:
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(_status_of(tab, TRIBULATION), "Locked: needs core_density_full", "precondition")
	DevCommands.reach_core_density(100)
	assert_eq(_status_of(tab, TRIBULATION), "Available")
	DevCommands.advance_stage()
	assert_eq(_status_of(tab, TRIBULATION), "Passed")
	assert_true(_button(_row(tab, TRIBULATION), "CompleteButton").disabled)

## A switch binds another save, which can differ from the last in ways no signal reports
## one by one, so the tab refreshes when DevManager says the session changed.
func test_the_tab_refreshes_when_the_session_changes() -> void:
	var tab: DevStoryTab = _open_story_tab()
	assert_eq(_status_of(tab, NPC_1), "Available", "precondition")
	# The save's own counter: it reports nothing, where ZoneManager's emits action_completed.
	PersistenceManager.save_game_data.increment_zone_progression_for_action(NPC_1, ZONE_ID, 1)
	assert_eq(_status_of(tab, NPC_1), "Available", "precondition: nothing told the tab")
	DevManager.session_changed.emit()
	assert_eq(_status_of(tab, NPC_1), "Used up (1/1)")

## Built while the panel is closed, or changed in a way no signal reports, the tab shows
## what has changed since when it is opened.
func test_the_tab_refreshes_when_shown() -> void:
	var panel: DevPanel = _add_panel()
	var tab: DevStoryTab = panel.get_node("%StoryTab")
	assert_eq(_status_of(tab, NPC_1), "Available", "precondition")
	# The save's own counter: it reports nothing, where ZoneManager's emits action_completed.
	PersistenceManager.save_game_data.increment_zone_progression_for_action(NPC_1, ZONE_ID, 1)
	assert_eq(_status_of(tab, NPC_1), "Available", "the closed panel's tab has not heard of it")
	_show_story_tab(panel)
	assert_eq(_status_of(tab, NPC_1), "Used up (1/1)", "and shows it when opened")

#-----------------------------------------------------------------------------
# THE ACTION ROW
#-----------------------------------------------------------------------------

func test_a_row_shows_its_action_and_status() -> void:
	var row: DevActionRow = ACTION_ROW_SCENE.instantiate()
	add_child_autofree(row)
	var action: ZoneActionData = _action(NPC_2)
	assert_null(row.get_action(), "precondition: a new row shows no action")
	row.set_action(action, "Locked: needs q_fill_core_madra_full", false)
	assert_eq(row.get_action(), action)
	assert_string_contains(_label(row, "NameLabel").text, action.action_name, "the name")
	assert_string_contains(_label(row, "NameLabel").text, action.action_id, "and the id, which three actions' names share")
	assert_eq(_label(row, "StatusLabel").text, "Locked: needs q_fill_core_madra_full")
	assert_true(_button(row, "CompleteButton").disabled, "Complete is off for an action that is not available")
	row.set_action(action, "Available", true)
	assert_eq(_label(row, "StatusLabel").text, "Available")
	assert_false(_button(row, "CompleteButton").disabled, "and on for one that is")

func test_a_row_says_which_action_was_completed() -> void:
	var row: DevActionRow = ACTION_ROW_SCENE.instantiate()
	add_child_autofree(row)
	row.set_action(_action(NPC_1), "Available", true)
	watch_signals(row)
	_press(row, "CompleteButton")
	assert_signal_emitted_with_parameters(row, "complete_pressed", [NPC_1])
