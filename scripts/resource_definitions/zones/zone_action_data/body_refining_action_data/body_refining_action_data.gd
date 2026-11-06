class_name BodyRefiningActionData
extends ZoneActionData

## BodyRefiningActionData
## A zone action that opens the body refining board, where the player plays sets
## of the equipped drill (BodyRefiningManager's). It is a session action, not an
## idle one: it stands in for the zone's idle action while its board is up, and
## stays current until the board closes it through ActionManager.stop_action(),
## the way cycling does. The drill and what each rep pays are BodyRefiningManager's
## and DrillRules', so the action holds nothing of its own.

func _init() -> void:
	action_type = ActionType.BODY_REFINING
