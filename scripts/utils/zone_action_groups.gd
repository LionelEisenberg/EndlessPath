class_name ZoneActionGroups

## ZoneActionGroups
## How the zone panel's activity list groups and tags its cards. Groups run
## Talk, Cultivate, Gather, Venture, Visit (Talk first, so a new story step is
## never below the fold). Statics only.

#-----------------------------------------------------------------------------
# ENUMS & CONSTANTS
#-----------------------------------------------------------------------------

## Activity list groups, in display order.
enum Group { TALK, CULTIVATE, GATHER, VENTURE, VISIT }

const ActionType = ZoneActionData.ActionType

const _GROUP_LABELS: Dictionary = {
	Group.TALK: "Talk",
	Group.CULTIVATE: "Cultivate",
	Group.GATHER: "Gather",
	Group.VENTURE: "Venture",
	Group.VISIT: "Visit",
}

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## The group an action type is listed under. The Tribulation is cultivation, so
## it goes in Cultivate; ZONE_EVENT goes in Visit.
static func group_of(action_type: ZoneActionData.ActionType) -> Group:
	match action_type:
		ActionType.NPC_DIALOGUE:
			return Group.TALK
		ActionType.CYCLING, ActionType.TRAIN_STATS, ActionType.TRIBULATION:
			return Group.CULTIVATE
		ActionType.FORAGE:
			return Group.GATHER
		ActionType.ADVENTURE:
			return Group.VENTURE
	return Group.VISIT

## The group's header text, in title case ("Talk").
static func label(group: Group) -> String:
	return _GROUP_LABELS.get(group, "")

## A new array of the actions ordered by group, keeping the input order within
## a group. The input array is left as it was.
static func sort_actions(actions: Array[ZoneActionData]) -> Array[ZoneActionData]:
	var sorted: Array[ZoneActionData] = []
	for group: int in Group.values():
		for action: ZoneActionData in actions:
			if group_of(action.action_type) == group:
				sorted.append(action)
	return sorted

## The card's mode tag: IDLE, ACTIVE, SHOP, TRIAL or STORY. The card swaps in
## RUNNING or ENTER itself, since those depend on live state.
static func mode_tag(action: ZoneActionData) -> String:
	match action.action_type:
		ActionType.FORAGE, ActionType.TRAIN_STATS:
			return "IDLE"
		ActionType.CYCLING, ActionType.ADVENTURE:
			return "ACTIVE"
		ActionType.MERCHANT:
			return "SHOP"
		ActionType.TRIBULATION:
			return "TRIAL"
	return "STORY"
