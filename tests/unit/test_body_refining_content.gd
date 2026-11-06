extends GutTest

## Content checks on Spirit Valley's body refining action, Riverbank Training:
## its file writes out the values it would otherwise leave to its script's
## defaults (Godot's text saver drops a value equal to the default, and a
## changed default would then silently change the action), it unlocks with the
## adventure when "Awaken Your Core" is done, and the valley lists it under
## Cultivate right after Wilderness Cycling.

const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/body_refining_action.tres"
const ZONE_PATH: String = "res://resources/zones/spirit_valley_zone/spirit_valley_zone.tres"
const ACTION_ID: String = "riverbank_training_action"
const CYCLING_ID: String = "wilderness_cycling_action"
const UNLOCK_ID: String = "q_fill_core_completed"

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

func test_it_unlocks_with_the_adventure() -> void:
	var action: ZoneActionData = load(ACTION_PATH)
	assert_eq(action.unlock_conditions.size(), 1, "one condition")
	if action.unlock_conditions.size() == 1:
		assert_eq(action.unlock_conditions[0].condition_id, UNLOCK_ID, "Awaken Your Core done, as the adventure")

func test_spirit_valley_lists_it_after_cycling() -> void:
	var zone: ZoneData = load(ZONE_PATH)
	var ids: Array[String] = []
	for action: ZoneActionData in zone.all_actions:
		ids.append(action.action_id)
	assert_has(ids, ACTION_ID, "Spirit Valley lists the action")
	assert_eq(ids.find(ACTION_ID), ids.find(CYCLING_ID) + 1, "right after Wilderness Cycling")
	assert_eq(ZoneActionGroups.group_of(ZoneActionData.ActionType.BODY_REFINING), ZoneActionGroups.Group.CULTIVATE, "under Cultivate")
