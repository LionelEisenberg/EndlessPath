extends GutTest

## Content checks on Spirit Valley's body refining action, Riverbank Training:
## its file writes out the values it would otherwise leave to its script's
## defaults (Godot's text saver drops a value equal to the default, and a
## changed default would then silently change the action), it unlocks when First
## Steps Out ends or a fight is lost, and the valley lists it under Cultivate
## right after Wilderness Cycling.

const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/body_refining_action.tres"
const ZONE_PATH: String = "res://resources/zones/spirit_valley_zone/spirit_valley_zone.tres"
const ACTION_ID: String = "riverbank_training_action"
const CYCLING_ID: String = "wilderness_cycling_action"
const CONDITION_LIST_PATH: String = "res://resources/unlocks/unlock_condition_list.tres"
const UNLOCK_ID: String = "riverbank_training_opened"
const FIRST_STEPS_PATH: String = "res://resources/quests/q_first_steps.tres"

func test_the_file_writes_out_its_values() -> void:
	var text: String = FileAccess.get_file_as_string(ACTION_PATH)
	for field: String in ["action_type = 8", "max_completions = 0"]:
		assert_true(text.contains("\n%s\n" % field), "the file writes out %s" % field)

func test_it_is_the_body_refining_action() -> void:
	var action: ZoneActionData = load(ACTION_PATH)
	assert_true(action is BodyRefiningActionData, "a BodyRefiningActionData")
	assert_eq(action.action_id, ACTION_ID)
	assert_eq(action.action_name, "Riverbank Training")
	assert_not_null(action.icon, "it has a card icon")

## Not with the adventure: before the first fight nothing has spent Health.
func test_it_unlocks_on_its_own_event() -> void:
	var action: ZoneActionData = load(ACTION_PATH)
	assert_eq(action.unlock_conditions.size(), 1, "one condition")
	if action.unlock_conditions.size() == 1:
		assert_eq(action.unlock_conditions[0].condition_id, UNLOCK_ID, "its own moment")
		assert_eq(action.unlock_conditions[0].condition_type, UnlockConditionData.ConditionType.EVENT_TRIGGERED, "an event")
		assert_eq(action.unlock_conditions[0].target_value, UNLOCK_ID, "that shares its id")

## UnlockManager latches only registered conditions, and the zone lists an action
## only once its conditions have latched.
func test_its_condition_is_registered() -> void:
	var registered: Array[String] = []
	for condition: UnlockConditionData in (load(CONDITION_LIST_PATH) as UnlockConditionList).list:
		registered.append(condition.condition_id)
	assert_has(registered, UNLOCK_ID)

## First Steps Out's end, at NPC 3's talk, opens it: the talk sends the player
## to the river.
func test_first_steps_out_opens_it() -> void:
	var events: Array[String] = []
	for effect: EffectData in (load(FIRST_STEPS_PATH) as QuestData).completion_effects:
		if effect is TriggerEventEffectData:
			events.append((effect as TriggerEventEffectData).event_id)
	assert_has(events, UNLOCK_ID)

func test_spirit_valley_lists_it_after_cycling() -> void:
	var zone: ZoneData = load(ZONE_PATH)
	var ids: Array[String] = []
	for action: ZoneActionData in zone.all_actions:
		ids.append(action.action_id)
	assert_has(ids, ACTION_ID, "Spirit Valley lists the action")
	assert_eq(ids.find(ACTION_ID), ids.find(CYCLING_ID) + 1, "right after Wilderness Cycling")
	assert_eq(ZoneActionGroups.group_of(ZoneActionData.ActionType.BODY_REFINING), ZoneActionGroups.Group.CULTIVATE, "under Cultivate")
