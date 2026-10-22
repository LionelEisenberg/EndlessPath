extends GutTest

## Unit tests for ZoneActionGroups, the activity list's grouping (Talk,
## Cultivate, Gather, Venture, Visit; Talk first so a new story step is never
## below the fold) and the cards' mode tags.

const ActionType = ZoneActionData.ActionType
const SPIRIT_VALLEY_PATH: String = "res://resources/zones/spirit_valley_zone/spirit_valley_zone.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _action(action_id: String, type: ActionType) -> ZoneActionData:
	var action := ZoneActionData.new()
	action.action_id = action_id
	action.action_type = type
	return action

func _ids(actions: Array[ZoneActionData]) -> Array[String]:
	var ids: Array[String] = []
	for action: ZoneActionData in actions:
		ids.append(action.action_id)
	return ids

#-----------------------------------------------------------------------------
# GROUPS
#-----------------------------------------------------------------------------

func test_group_of_each_type() -> void:
	assert_eq(ZoneActionGroups.group_of(ActionType.NPC_DIALOGUE), ZoneActionGroups.Group.TALK)
	assert_eq(ZoneActionGroups.group_of(ActionType.CYCLING), ZoneActionGroups.Group.CULTIVATE)
	assert_eq(ZoneActionGroups.group_of(ActionType.TRAIN_STATS), ZoneActionGroups.Group.CULTIVATE)
	assert_eq(ZoneActionGroups.group_of(ActionType.FORAGE), ZoneActionGroups.Group.GATHER)
	assert_eq(ZoneActionGroups.group_of(ActionType.ADVENTURE), ZoneActionGroups.Group.VENTURE)
	assert_eq(ZoneActionGroups.group_of(ActionType.MERCHANT), ZoneActionGroups.Group.VISIT)
	assert_eq(ZoneActionGroups.group_of(ActionType.ZONE_EVENT), ZoneActionGroups.Group.VISIT)

func test_labels() -> void:
	assert_eq(ZoneActionGroups.label(ZoneActionGroups.Group.TALK), "Talk")
	assert_eq(ZoneActionGroups.label(ZoneActionGroups.Group.CULTIVATE), "Cultivate")
	assert_eq(ZoneActionGroups.label(ZoneActionGroups.Group.GATHER), "Gather")
	assert_eq(ZoneActionGroups.label(ZoneActionGroups.Group.VENTURE), "Venture")
	assert_eq(ZoneActionGroups.label(ZoneActionGroups.Group.VISIT), "Visit")

#-----------------------------------------------------------------------------
# SORTING
#-----------------------------------------------------------------------------

func test_sort_puts_talk_first_and_keeps_order() -> void:
	var spirit_valley: ZoneData = load(SPIRIT_VALLEY_PATH)
	var sorted: Array[ZoneActionData] = ZoneActionGroups.sort_actions(spirit_valley.all_actions)
	assert_eq(_ids(sorted), [
		"celestial_intervener_dialogue_1",
		"celestial_intervener_dialogue_2",
		"celestial_intervener_dialogue_3",
		"celestial_intervener_dialogue_4",
		"wilderness_cycling_action",
		"aura_well_training",
		"sprint_forest_foraging_action",
		"shallow_woods_adventure_action",
		"spirit_valley_merchant",
	] as Array[String])

func test_sort_keeps_input_order_within_a_group() -> void:
	var actions: Array[ZoneActionData] = [
		_action("event", ActionType.ZONE_EVENT),
		_action("well", ActionType.TRAIN_STATS),
		_action("shop", ActionType.MERCHANT),
		_action("cycle", ActionType.CYCLING),
	]
	assert_eq(_ids(ZoneActionGroups.sort_actions(actions)),
		["well", "cycle", "event", "shop"] as Array[String])

func test_sort_leaves_the_input_untouched() -> void:
	var actions: Array[ZoneActionData] = [
		_action("shop", ActionType.MERCHANT),
		_action("talk", ActionType.NPC_DIALOGUE),
	]
	ZoneActionGroups.sort_actions(actions)
	assert_eq(_ids(actions), ["shop", "talk"] as Array[String])

func test_sort_of_nothing_is_empty() -> void:
	var actions: Array[ZoneActionData] = []
	assert_eq(ZoneActionGroups.sort_actions(actions).size(), 0)

#-----------------------------------------------------------------------------
# MODE TAGS
#-----------------------------------------------------------------------------

func test_mode_tags() -> void:
	assert_eq(ZoneActionGroups.mode_tag(_action("a", ActionType.FORAGE)), "IDLE")
	assert_eq(ZoneActionGroups.mode_tag(_action("b", ActionType.TRAIN_STATS)), "IDLE")
	assert_eq(ZoneActionGroups.mode_tag(_action("c", ActionType.CYCLING)), "ACTIVE")
	assert_eq(ZoneActionGroups.mode_tag(_action("d", ActionType.ADVENTURE)), "ACTIVE")
	assert_eq(ZoneActionGroups.mode_tag(_action("e", ActionType.MERCHANT)), "SHOP")
	assert_eq(ZoneActionGroups.mode_tag(_action("f", ActionType.NPC_DIALOGUE)), "STORY")
	assert_eq(ZoneActionGroups.mode_tag(_action("g", ActionType.ZONE_EVENT)), "STORY")
