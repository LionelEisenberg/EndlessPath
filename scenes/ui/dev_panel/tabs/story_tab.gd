class_name DevStoryTab
extends VBoxContainer

## The dev panel's Story tab: where the story stands, and the controls that move it.
##
## Jump story to starts a fresh preset session played through a beat of the story route
## (DevManager.play_story_through()). Quests shows each active quest with its step and
## what the step asks, then the quests done. Trigger event fires any event the content
## listens to. Actions lists the current zone's actions, each as available, used up,
## passed (a Tribulation the player has passed) or locked, naming the conditions still
## unmet, and Complete on a row completes an available action without playing it.
## Events and conditions lists the events fired and the unlock conditions latched.
## Trigger and Complete go through DevCommands, which logs them and says why one refused.
##
## A refusal shows in a status line that stands under the part that scrolls, so it is in
## view whichever control it came from and wherever the tab is scrolled to, and the next
## command that works clears it. A jump is refused at once while another switch is
## pending, and a switch that fails midway reports while the panel it was asked from is
## freed: the tab listens for both while it lives, and shows the last failure
## DevManager kept when it is built, as the Saves tab does.
##
## The tab refreshes whenever something it shows can have changed: an event fires, a
## condition latches, a quest starts, advances or completes, an action is used up, the
## current zone or the stage changes, or the session does. It refreshes when it is
## shown too, for what moves without a signal.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ACTION_ROW_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/rows/dev_action_row.tscn")

## What action_status() reads for an action ZoneManager offers. The row's Complete is on
## for exactly this status.
const _AVAILABLE: String = "Available"

## What action_status() reads for a Tribulation the player has passed.
const _PASSED: String = "Passed"

## What the quests line reads while no quest is active or done.
const _NO_QUESTS: String = "No quests started yet"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _jump_option: OptionButton = %JumpOption
@onready var _jump_button: Button = %JumpButton
@onready var _quests_label: Label = %QuestsLabel
@onready var _event_option: OptionButton = %EventOption
@onready var _trigger_button: Button = %TriggerButton
@onready var _actions_header: Label = %ActionsHeader
@onready var _action_list: VBoxContainer = %ActionList
@onready var _events_label: Label = %EventsLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status: Label = %StoryStatus

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Lists the route's beats and the events the content listens to in their pickers, shows
## the story as it stands, and keeps it showing as it moves. A switch that failed while
## no tab was there to hear it shows too.
func _ready() -> void:
	_fill_beats()
	_fill_events()
	_jump_button.pressed.connect(_on_jump_pressed)
	_trigger_button.pressed.connect(_on_trigger_pressed)
	visibility_changed.connect(_on_visibility_changed)
	EventManager.event_triggered.connect(_refresh.unbind(1))
	UnlockManager.condition_unlocked.connect(_refresh.unbind(1))
	QuestManager.quest_started.connect(_refresh.unbind(1))
	QuestManager.quest_step_advanced.connect(_refresh.unbind(2))
	QuestManager.quest_completed.connect(_refresh.unbind(1))
	ZoneManager.action_completed.connect(_refresh.unbind(1))
	ZoneManager.zone_changed.connect(_refresh.unbind(1))
	CultivationManager.advancement_stage_changed.connect(_refresh.unbind(1))
	DevManager.session_changed.connect(_on_session_changed)
	DevManager.session_switch_failed.connect(_show_status)
	_refresh()
	_show_status(DevManager.get_last_switch_failure())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## How the action stands in the zone, as the Actions list reads it, in this order:
## "Available" when ZoneManager offers it; "Used up (n/n)" when it has been completed
## as often as it may be; "Passed" for a Tribulation the player has passed; otherwise
## "Locked: needs <ids>", the ids of the unlock conditions that are not latched,
## comma-separated. Each is the manager's own answer, never a copy of its rule:
## ZoneManager says what it offers and what is used up, the Tribulation says whether it
## is passed, and UnlockManager's check, the one ZoneManager gates with, says which
## conditions are unmet. ZoneManager offers nothing in a locked zone, so the zone's
## unmet conditions are named before the action's own.
static func action_status(action: ZoneActionData, zone_id: String) -> String:
	for offered: ZoneActionData in ZoneManager.get_available_actions(zone_id):
		if offered.action_id == action.action_id:
			return _AVAILABLE
	if ZoneManager.is_action_used_up(action, zone_id):
		var completions: int = ZoneManager.get_zone_progression(zone_id).action_completion_count.get(action.action_id, 0)
		return "Used up (%d/%d)" % [completions, action.max_completions]
	var tribulation := action as TribulationActionData
	if tribulation != null and tribulation.is_passed():
		return _PASSED
	var unmet := PackedStringArray()
	var zone: ZoneData = ZoneManager.get_zone_by_id(zone_id)
	if zone != null:
		_add_unmet_ids(unmet, zone.zone_unlock_conditions)
	_add_unmet_ids(unmet, action.unlock_conditions)
	return "Locked: needs %s" % ", ".join(unmet)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Plays the story through the picked beat on a fresh preset session. A jump DevManager
## refuses comes back through session_switch_failed, which shows its reason.
func _on_jump_pressed() -> void:
	if _jump_option.selected < 0:
		return
	var beat_id: String = _jump_option.get_item_metadata(_jump_option.selected)
	DevManager.play_story_through(beat_id)

## Fires the picked event. A refusal shows in the status line until a command works.
func _on_trigger_pressed() -> void:
	if _event_option.selected < 0:
		return
	_show_status(DevCommands.trigger_event(_event_option.get_item_text(_event_option.selected)))

## Completes the action of the row whose Complete was pressed. A refusal shows in the
## status line until a command works.
func _on_complete_pressed(action_id: String) -> void:
	_show_status(DevCommands.complete_action(action_id))

## A switch has run: the tab shows the session it brought, and why the switch failed if
## it did ("" once one works, which clears the line).
func _on_session_changed() -> void:
	_refresh()
	_show_status(DevManager.get_last_switch_failure())

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Lists each beat of the route in the jump picker as "<title> (<beat_id>)", the item's
## metadata its id.
func _fill_beats() -> void:
	var route: StoryRouteData = DevManager.get_route()
	if route == null:
		return
	for beat: StoryBeatData in route.beats:
		_jump_option.add_item("%s (%s)" % [beat.title, beat.beat_id])
		_jump_option.set_item_metadata(_jump_option.item_count - 1, beat.beat_id)

## Lists each event the content listens to in the trigger picker, by its id.
func _fill_events() -> void:
	for event_id: String in DevCommands.known_event_ids():
		_event_option.add_item(event_id)

## Shows the story as it stands: the quests, the events and conditions, and the actions.
func _refresh() -> void:
	_quests_label.text = _quests_text()
	_events_label.text = _events_text()
	_fill_actions()

## One line per active quest, "<quest title> — step N: <what the step asks>", with N
## counting from 1, then "Done: <titles>" for the quests done, or a line saying there
## are none to show.
func _quests_text() -> String:
	var lines := PackedStringArray()
	for quest_id: String in QuestManager.get_active_quest_ids():
		lines.append(_active_quest_line(quest_id))
	var done := PackedStringArray()
	for quest_id: String in QuestManager.get_completed_quest_ids():
		done.append(_quest_title(quest_id))
	if not done.is_empty():
		lines.append("Done: %s" % ", ".join(done))
	if lines.is_empty():
		return _NO_QUESTS
	return "\n".join(lines)

## An active quest's line: its title, the step it is on and what that step asks.
func _active_quest_line(quest_id: String) -> String:
	var step_index: int = QuestManager.get_current_step_index(quest_id)
	var line: String = "%s — step %d" % [_quest_title(quest_id), step_index + 1]
	var quest: QuestData = QuestManager.get_quest_data(quest_id)
	if quest != null and step_index >= 0 and step_index < quest.steps.size():
		line += ": %s" % quest.steps[step_index].description
	return line

## The quest's title, or its id for a quest the catalog has no name for.
func _quest_title(quest_id: String) -> String:
	var quest: QuestData = QuestManager.get_quest_data(quest_id)
	if quest == null or quest.quest_name == "":
		return quest_id
	return quest.quest_name

## "Events: <ids>" and "Conditions: <ids>", in the order they fired and latched.
func _events_text() -> String:
	return "Events: %s\nConditions: %s" % [
		_id_list(EventManager.get_triggered_events()),
		_id_list(UnlockManager.get_unlocked_condition_ids()),
	]

## The ids, comma-separated, or "none".
func _id_list(ids: Array[String]) -> String:
	if ids.is_empty():
		return "none"
	return ", ".join(PackedStringArray(ids))

## Shows a row per action of the current zone, in the zone's order, under a header that
## names the zone. The rows already there are kept and given the actions in order; a
## row is added for each action the list gained and removed for each it lost, so a
## refresh inside a row's own press never frees the row.
func _fill_actions() -> void:
	var zone: ZoneData = ZoneManager.get_current_zone()
	var actions: Array[ZoneActionData] = []
	_actions_header.text = "ACTIONS"
	if zone != null:
		actions = zone.all_actions
		_actions_header.text = "ACTIONS · %s" % zone.zone_name
	while _action_list.get_child_count() > actions.size():
		var extra: Node = _action_list.get_child(_action_list.get_child_count() - 1)
		_action_list.remove_child(extra)
		extra.queue_free()
	while _action_list.get_child_count() < actions.size():
		var added: DevActionRow = ACTION_ROW_SCENE.instantiate()
		_action_list.add_child(added)
		added.complete_pressed.connect(_on_complete_pressed)
	for index: int in actions.size():
		var row: DevActionRow = _action_list.get_child(index)
		var status: String = action_status(actions[index], zone.zone_id)
		row.set_action(actions[index], status, status == _AVAILABLE)

## Shows the text in the status line under the tab, and hides the line, and the panel it
## stands in, while the text is empty.
func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""
	_status_panel.visible = text != ""

## Adds to `ids` the id of each condition UnlockManager's own check finds unmet, each
## once. The check is run on the condition alone, so the answer is the rule's, however
## it decides one condition.
static func _add_unmet_ids(ids: PackedStringArray, conditions: Array[UnlockConditionData]) -> void:
	for condition: UnlockConditionData in conditions:
		var alone: Array[UnlockConditionData] = [condition]
		if not UnlockManager.are_unlock_conditions_met(alone) and not ids.has(condition.condition_id):
			ids.append(condition.condition_id)
