class_name TribulationActionData
extends ZoneActionData

## TribulationActionData
## A zone action that opens a stage's Tribulation, the trial the player faces to
## break through to the next stage. The trial needs a full core and both main
## stats, Strength and Spirit, at the stage's cap, counting their trained levels,
## never gear. The action stays current until the board closes it through
## ActionManager.stop_action(), the way the shop does.
##
## Its card shows once the core first fills (the unlock condition is latched, so
## the card stays after a failure) and until the player reaches the stage the
## trial leads to. The questions below read the live game state.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The main stats the trial needs at the stage's cap, in the order its
## requirements name them.
const _MAIN_STATS: Array[CharacterAttributesData.AttributeType] = [
	CharacterAttributesData.AttributeType.STRENGTH,
	CharacterAttributesData.AttributeType.SPIRIT,
]

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
## before its target, and nothing is missing (get_missing_requirements()): the
## core is full and Strength and Spirit are at the cap. A failure leaves the card
## listed but costs levels, so this stays false until the core fills again. False
## without a trial.
func can_attempt() -> bool:
	if tribulation == null:
		return false
	var in_stage_before_target: bool = CultivationManager.get_current_advancement_stage() == tribulation.target_stage - 1
	return in_stage_before_target and get_missing_requirements().is_empty()

## Every requirement of the trial still unmet, one line each, in the order Core
## Density, Strength, Spirit: "Core Density 95 / 100", "Strength Lv 3 / 10",
## "Spirit Lv 9 / 10". A stat counts its trained level, never a total that gear
## lifts. With include_core false the Core Density line is left out, for a screen
## whose rod already shows the core. Empty once nothing is missing.
static func get_missing_requirements(include_core: bool = true) -> Array[String]:
	var missing: Array[String] = []
	if include_core and not CultivationManager.is_core_full():
		missing.append("Core Density %d / %d" % [
			floori(CultivationManager.get_core_density_level()),
			CultivationManager.get_core_density_cap(),
		])
	for stat: CharacterAttributesData.AttributeType in _MAIN_STATS:
		if not CharacterManager.is_stat_capped(stat):
			missing.append("%s Lv %d / %d" % [
				CharacterManager.get_attribute_display_name(stat),
				CharacterManager.get_stat_level(stat),
				CharacterManager.get_stat_level_cap(),
			])
	return missing
