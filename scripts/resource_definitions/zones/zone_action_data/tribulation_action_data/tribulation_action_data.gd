class_name TribulationActionData
extends ZoneActionData

## TribulationActionData
## A zone action that opens a stage's Tribulation, the trial a full core faces
## to break through to the next stage. The action stays current until the board
## closes it through ActionManager.stop_action(), the way the shop does.
##
## Its card shows once the core first fills (the unlock condition is latched, so
## the card stays after a failure) and until the player reaches the stage the
## trial leads to. Both questions below read the live game state.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## The trial this action opens.
@export var tribulation: TribulationData

func _init() -> void:
	action_type = ZoneActionData.ActionType.TRIBULATION

#-----------------------------------------------------------------------------
# STATE QUERIES
#-----------------------------------------------------------------------------

## True when the player's stage is at or past the stage the trial leads to: the
## trial is won, and its card is not offered again. False without a trial.
func is_passed() -> bool:
	if tribulation == null:
		return false
	return CultivationManager.get_current_advancement_stage() >= tribulation.target_stage

## True when the player may face the trial now: they stand in the stage just
## before its target, and the core is full. A failure leaves the card listed but
## costs levels, so this stays false until the core fills again. False without a
## trial.
func can_attempt() -> bool:
	if tribulation == null:
		return false
	var in_stage_before_target: bool = CultivationManager.get_current_advancement_stage() == tribulation.target_stage - 1
	return in_stage_before_target and CultivationManager.is_core_full()
