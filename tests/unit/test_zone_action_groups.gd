extends GutTest

## Unit tests for ZoneActionGroups, the activity list's grouping (Talk,
## Cultivate, Gather, Venture, Visit; Talk first so a new story step is never
## below the fold) and the cards' mode tags.

const ActionType = ZoneActionData.ActionType

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
	assert_eq(ZoneActionGroups.group_of(ActionType.TRIBULATION), ZoneActionGroups.Group.CULTIVATE)

#-----------------------------------------------------------------------------
# SORTING
#-----------------------------------------------------------------------------

## The groups run Talk, Cultivate, Gather, Venture, Visit, Talk first even when
## it comes last, and each group keeps its actions' input order.
func test_sort_keeps_input_order_within_a_group() -> void:
	var actions: Array[ZoneActionData] = [
		_action("event", ActionType.ZONE_EVENT),
		_action("well", ActionType.TRAIN_STATS),
		_action("venture", ActionType.ADVENTURE),
		_action("shop", ActionType.MERCHANT),
		_action("forage", ActionType.FORAGE),
		_action("cycle", ActionType.CYCLING),
		_action("talk", ActionType.NPC_DIALOGUE),
	]
	assert_eq(_ids(ZoneActionGroups.sort_actions(actions)),
		["talk", "well", "cycle", "forage", "venture", "event", "shop"] as Array[String])

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
	assert_eq(ZoneActionGroups.mode_tag(_action("h", ActionType.TRIBULATION)), "TRIAL")
