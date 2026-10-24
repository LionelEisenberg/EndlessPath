extends GutTest

## Pins the Tribulation's real data wiring: the shipped .tres files, not test
## stand-ins. Foundation leads to Copper, Copper has the designed XP curve,
## Madra and cap, a full Foundation core holds as much Madra as an empty Copper
## one (the breakthrough never costs Madra), Copper is registered in
## CultivationManager's stages and in the stage list, the Foundation
## Tribulation holds the designed phases, timing, judging windows, penalty and
## copy, and Spirit Valley lists The Tribulation as an action: the action's
## type and wiring, the "core_density_full" condition that reveals it, and that
## condition's place in the unlock list.
##
## A change to one of these numbers is a design change: edit it here too.

const Stage := CultivationManager.AdvancementStage
const FOUNDATION_PATH: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_PATH: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"
const STAGE_LIST_PATH: String = "res://resources/cycling/advancement_stages/advancement_stage_list.tres"
const FOUNDATION_TRIBULATION_PATH: String = "res://resources/tribulation/foundation_tribulation.tres"
const TRIBULATION_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres"
const CORE_DENSITY_FULL_PATH: String = "res://resources/unlocks/core_density_full.tres"
const UNLOCK_LIST_PATH: String = "res://resources/unlocks/unlock_condition_list.tres"
const SPIRIT_VALLEY_PATH: String = "res://resources/zones/spirit_valley_zone/spirit_valley_zone.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The shipped stage at `path`. Fails the test and returns null when it won't load.
func _load_stage(path: String) -> AdvancementStageResource:
	var stage: AdvancementStageResource = load(path) as AdvancementStageResource
	assert_not_null(stage, "%s loads as an AdvancementStageResource" % path)
	return stage

## The stage of `stage_id` among `stages`, or null when none is listed.
func _find_stage(stages: Array[AdvancementStageResource], stage_id: Stage) -> AdvancementStageResource:
	for stage: AdvancementStageResource in stages:
		if stage.stage_id == stage_id:
			return stage
	return null

## The shipped Foundation Tribulation. Fails the test and returns null when it won't load.
func _load_tribulation() -> TribulationData:
	var tribulation: TribulationData = load(FOUNDATION_TRIBULATION_PATH) as TribulationData
	assert_not_null(tribulation, "%s loads as a TribulationData" % FOUNDATION_TRIBULATION_PATH)
	return tribulation

## The shipped Tribulation's four phases in play order (Steady breath,
## Heartbeat, Echo, Quickening). Fails the test and returns an empty array when
## the file won't load or doesn't list four.
func _load_phases() -> Array[TribulationPhaseData]:
	var phases: Array[TribulationPhaseData] = []
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return phases
	assert_eq(tribulation.phases.size(), 4, "the Foundation Tribulation lists four phases")
	if tribulation.phases.size() == 4:
		phases = tribulation.phases
	return phases

## The shipped Spirit Valley action. Fails the test and returns null when it won't load.
func _load_action() -> TribulationActionData:
	var action: TribulationActionData = load(TRIBULATION_ACTION_PATH) as TribulationActionData
	assert_not_null(action, "%s loads as a TribulationActionData" % TRIBULATION_ACTION_PATH)
	return action

## The shipped "core_density_full" condition. Fails the test and returns null
## when it won't load.
func _load_condition() -> UnlockConditionData:
	var condition: UnlockConditionData = load(CORE_DENSITY_FULL_PATH) as UnlockConditionData
	assert_not_null(condition, "%s loads as an UnlockConditionData" % CORE_DENSITY_FULL_PATH)
	return condition

#-----------------------------------------------------------------------------
# FOUNDATION TO COPPER
#-----------------------------------------------------------------------------

func test_foundation_leads_to_copper() -> void:
	var foundation: AdvancementStageResource = _load_stage(FOUNDATION_PATH)
	if foundation == null:
		return
	assert_eq(foundation.max_core_density_level, 100, "Foundation's core fills at 100")
	assert_not_null(foundation.next_stage, "Foundation leads to a next stage")
	if foundation.next_stage == null:
		return
	assert_eq(foundation.next_stage.stage_id, Stage.COPPER)
	assert_eq(foundation.next_stage.stage_name, "Copper")

func test_the_madra_cap_does_not_drop_at_the_breakthrough() -> void:
	var foundation: AdvancementStageResource = _load_stage(FOUNDATION_PATH)
	var copper: AdvancementStageResource = _load_stage(COPPER_PATH)
	if foundation == null or copper == null:
		return
	assert_eq(foundation.get_max_madra(foundation.max_core_density_level), 600.0, "a full Foundation core holds 600 Madra")
	assert_eq(copper.get_max_madra(0), 600.0, "and an empty Copper core starts at the same 600")

#-----------------------------------------------------------------------------
# COPPER
#-----------------------------------------------------------------------------

func test_copper_values() -> void:
	var copper: AdvancementStageResource = _load_stage(COPPER_PATH)
	if copper == null:
		return
	assert_eq(copper.stage_id, Stage.COPPER)
	assert_eq(copper.stage_name, "Copper")
	assert_eq(copper.core_density_base_xp_cost, 20.0)
	assert_eq(copper.core_xp_scaling_factor, 1.02)
	assert_eq(copper.get_xp_for_level(1), 20.0, "level 1 costs the base XP")
	assert_eq(copper.max_madra_base, 600.0)
	assert_eq(copper.max_madra_per_core_density_level, 10.0)
	assert_eq(copper.max_core_density_level, 100)
	assert_null(copper.next_stage, "Copper is the last stage there is data for")

#-----------------------------------------------------------------------------
# REGISTRATION
#-----------------------------------------------------------------------------

func test_copper_is_registered() -> void:
	var loaded: AdvancementStageResource = _find_stage(CultivationManager.advancement_stage_resources, Stage.COPPER)
	assert_not_null(loaded, "CultivationManager loads a Copper stage")
	if loaded != null:
		assert_eq(loaded.resource_path, COPPER_PATH, "and it is the shipped file")

	var stage_list: AdvancementStageList = load(STAGE_LIST_PATH) as AdvancementStageList
	assert_not_null(stage_list, "the stage list loads")
	if stage_list == null:
		return
	var listed: AdvancementStageResource = _find_stage(stage_list.advancement_stages, Stage.COPPER)
	assert_not_null(listed, "the stage list names a Copper stage")
	if listed != null:
		assert_eq(listed.resource_path, COPPER_PATH, "and it is the shipped file")

#-----------------------------------------------------------------------------
# FOUNDATION TRIBULATION
#-----------------------------------------------------------------------------

func test_targets_copper() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.target_stage, Stage.COPPER, "passing the Foundation Tribulation leads to Copper")

func test_phases_in_order() -> void:
	var phases: Array[TribulationPhaseData] = _load_phases()
	if phases.is_empty():
		return
	var names: Array[String] = ["Steady breath", "Heartbeat", "Echo", "Quickening"]
	var tips: Array[String] = [
		"Press as the bright aura crosses the brass ring",
		"The rhythm breaks. Follow it.",
		"A second breath answers the first. Catch both.",
		"The breaths come faster. Keep up.",
	]
	for i: int in phases.size():
		assert_eq(phases[i].phase_name, names[i], "phase %d's name" % (i + 1))
		assert_eq(phases[i].tip, tips[i], "phase %d's tip" % (i + 1))

func test_breaths() -> void:
	var phases: Array[TribulationPhaseData] = _load_phases()
	if phases.is_empty():
		return
	var steady: TribulationPhaseData = phases[0]
	var heartbeat: TribulationPhaseData = phases[1]
	var echo: TribulationPhaseData = phases[2]
	var quickening: TribulationPhaseData = phases[3]

	# The arrays hold 32-bit floats, so each is compared with a packed literal.
	assert_eq(steady.breath_periods, PackedFloat32Array([1.7, 1.7, 1.7, 1.7, 1.7, 1.7]), "Steady breath: six breaths of 1.7 s")
	assert_eq(heartbeat.breath_periods, PackedFloat32Array([1.45, 0.95, 1.4, 0.9, 1.25, 0.85]), "Heartbeat: the broken rhythm")
	assert_eq(echo.breath_periods, PackedFloat32Array([1.6, 1.6, 1.6]), "Echo: the first sphere breathes three times, 1.6 s each")
	assert_eq(echo.echo_periods, PackedFloat32Array([1.5, 1.5, 1.5]), "Echo: the second sphere answers three times, 1.5 s each")
	assert_eq(quickening.breath_periods, PackedFloat32Array([1.3, 1.15, 1.0, 0.9, 0.8, 0.72]), "Quickening: the breaths speed up")

	assert_eq(echo.echo_offset, 0.6, "Echo: the second sphere starts 0.6 s after the first")
	assert_eq(quickening.gap_before, 0.8, "Quickening starts 0.8 s after Echo")

	for phase: TribulationPhaseData in [steady, heartbeat, quickening]:
		assert_true(phase.echo_periods.is_empty(), "%s has no second sphere" % phase.phase_name)
		assert_eq(phase.echo_offset, 0.0, "%s has no second sphere to offset" % phase.phase_name)
	for phase: TribulationPhaseData in [steady, heartbeat, echo]:
		assert_eq(phase.gap_before, 0.0, "%s follows the phase before it at once" % phase.phase_name)

	assert_false(steady.aura_rush, "Steady breath has no aura rush")
	assert_false(heartbeat.aura_rush, "Heartbeat has no aura rush")
	assert_false(echo.aura_rush, "Echo has no aura rush")
	assert_true(quickening.aura_rush, "Quickening is the one phase where Madra streams into the core")

func test_timing_and_geometry() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.tempo, 1.0, "tempo 1.0")
	assert_eq(tribulation.lead_in, 1.2, "1.2 s of stillness before the first breath")
	assert_eq(tribulation.last_breath_gap, 0.5, "0.5 s between Quickening and the last breath")
	assert_eq(tribulation.last_breath_in, 1.8, "the last breath grows over 1.8 s")
	assert_eq(tribulation.last_breath_out, 4.5, "and shrinks over 4.5 s")
	assert_eq(tribulation.last_breath_max_ratio, 2.54, "growing to 2.54 R")
	assert_eq(tribulation.end_pause, 1.2, "1.2 s of stillness after the last breath")
	assert_eq(tribulation.sphere_min_ratio, 0.42, "a sphere is smallest at 0.42 R")
	assert_eq(tribulation.sphere_max_ratio, 1.88, "and largest at 1.88 R")

func test_judging_and_penalty() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.perfect_window, 0.07, "perfect within 0.07 s of a beat")
	assert_eq(tribulation.good_window, 0.14, "good within 0.14 s")
	assert_eq(tribulation.early_reach_min, 0.30, "an early press is a miss from at least 0.30 s before the beat")
	assert_eq(tribulation.release_tolerance, 0.05, "a hold may end 0.05 s early")
	assert_eq(tribulation.cracks_to_fail, 4, "four cracks fail the trial")
	assert_eq(tribulation.failure_level_loss, 5, "and a failure costs five levels")
	assert_almost_eq(tribulation.get_early_reach(), 0.30, 0.0001, "the early reach is the 0.30 s minimum, since good + 0.10 s is only 0.24 s")

## The shipped numbers never reach the second branch of the early reach (the
## good window plus 0.10 s stays under the 0.30 s minimum), so a wider window on
## a fresh TribulationData does.
func test_a_wide_good_window_stretches_the_early_reach() -> void:
	var tribulation: TribulationData = TribulationData.new()
	tribulation.good_window = 0.25
	assert_almost_eq(tribulation.get_early_reach(), 0.35, 0.0001, "a 0.25 s good window reaches 0.10 s further, past the 0.30 s minimum")

func test_copy() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.title, "The Tribulation")
	assert_eq(tribulation.intro_text, "Your core is full. Breathe with the aura as it gathers, and let it pour into you.")
	assert_eq(tribulation.get_rules_line(), "4 cracks end the trial and cost 5 levels of Core Density.")
	assert_eq(tribulation.last_breath_name, "The last breath")
	assert_eq(tribulation.last_breath_tip, "Press as it crosses the ring, then hold while it pours into your core")
	assert_eq(tribulation.pass_title, "Breakthrough")
	assert_eq(tribulation.pass_text, "Your core condenses into Copper.")
	assert_eq(tribulation.fail_title, "Your core cracks")
	assert_eq(tribulation.get_fail_line(100, 95), "Core Density falls from 100 to 95.")

#-----------------------------------------------------------------------------
# THE SPIRIT VALLEY ACTION
#-----------------------------------------------------------------------------

## A saved .tres stores the enum number, so TRIBULATION is appended after
## ZONE_EVENT and never inserted: every number before it keeps its meaning.
func test_tribulation_type_is_seven() -> void:
	assert_eq(ZoneActionData.ActionType.TRIBULATION, 7, "appended after ZONE_EVENT, which is 6")
	assert_eq(ZoneActionData.ActionType.ZONE_EVENT, 6, "and the types before it keep their numbers")

func test_tribulation_action_is_wired() -> void:
	var action: TribulationActionData = _load_action()
	if action == null:
		return
	assert_eq(action.action_id, "spirit_valley_tribulation")
	assert_eq(action.action_name, "The Tribulation")
	assert_eq(action.action_type, ZoneActionData.ActionType.TRIBULATION, "the type is the Tribulation's")
	assert_eq(action.description, "Your core is full. Face the Tribulation and break through to Copper.")
	assert_eq(action.max_completions, 0, "a failed trial can be faced again: the card hides by stage, not by a completion count")

	assert_not_null(action.icon, "the card has an icon")
	if action.icon != null:
		assert_eq(action.icon.resource_path, "res://assets/ui/lacquer/lacquer_ic_core_ai.png", "the core icon")

	assert_not_null(action.tribulation, "the action leads into a Tribulation")
	if action.tribulation != null:
		assert_eq(action.tribulation.resource_path, FOUNDATION_TRIBULATION_PATH, "the Foundation one")

	assert_eq(action.unlock_conditions.size(), 1, "one condition reveals the card")
	if action.unlock_conditions.size() == 1:
		assert_eq(action.unlock_conditions[0].condition_id, "core_density_full")

func test_core_density_full_condition() -> void:
	var condition: UnlockConditionData = _load_condition()
	if condition == null:
		return
	assert_eq(condition.condition_id, "core_density_full")
	assert_eq(condition.condition_type, UnlockConditionData.ConditionType.CULTIVATION_LEVEL, "it reads Core Density")
	assert_eq(condition.target_value, 100, "a full Foundation core")
	assert_eq(condition.comparison_op, ">=")

## UnlockManager only evaluates the conditions the list names, so a condition
## missing from it would never unlock and the card would never show.
func test_the_condition_is_registered() -> void:
	var list: UnlockConditionList = load(UNLOCK_LIST_PATH) as UnlockConditionList
	assert_not_null(list, "the unlock list loads")
	if list == null:
		return
	var listed: UnlockConditionData = null
	for condition: UnlockConditionData in list.list:
		if condition.condition_id == "core_density_full":
			listed = condition
	assert_not_null(listed, "the unlock list names core_density_full")
	if listed != null:
		assert_eq(listed.resource_path, CORE_DENSITY_FULL_PATH, "and it is the shipped file")

func test_spirit_valley_lists_the_tribulation() -> void:
	var valley: ZoneData = load(SPIRIT_VALLEY_PATH) as ZoneData
	assert_not_null(valley, "Spirit Valley loads")
	if valley == null:
		return
	var listed: ZoneActionData = null
	for action: ZoneActionData in valley.all_actions:
		if action.action_id == "spirit_valley_tribulation":
			listed = action
	assert_not_null(listed, "Spirit Valley lists The Tribulation")
	if listed != null:
		assert_eq(listed.resource_path, TRIBULATION_ACTION_PATH, "and it is the shipped file")
