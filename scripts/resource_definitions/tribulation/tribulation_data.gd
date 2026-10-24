class_name TribulationData
extends Resource

## TribulationData
## One stage's Tribulation: the trial a full core faces to break through to the
## next stage. It holds the trial's copy, its schedule of phases, the spheres'
## geometry, the judging windows and the penalty for a failure. Each stage's
## breakthrough reads its own file; Foundation's is
## resources/tribulation/foundation_tribulation.tres, and the defaults below
## are its numbers.
##
## Durations are in seconds at tempo 1.0. A ratio is a multiple of R, the
## radius of the brass ring a beat is judged on.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How far past the good window an early press still counts as a miss, when
## that reaches farther than early_reach_min.
const EARLY_REACH_PAST_GOOD: float = 0.10

#-----------------------------------------------------------------------------
# TARGET
#-----------------------------------------------------------------------------

@export_group("Target")
## The stage a passed trial leads to.
@export var target_stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.COPPER

#-----------------------------------------------------------------------------
# COPY
#-----------------------------------------------------------------------------

@export_group("Copy")
## The trial's name, the heading of its intro panel.
@export var title: String = "The Tribulation"

## The intro panel's text.
@export var intro_text: String = "Your core is full. Breathe with the aura as it gathers, and let it pour into you."

## The intro panel's rules line, as a template: {cracks} stands for
## cracks_to_fail and {levels} for failure_level_loss. get_rules_line() fills it.
@export var rules_text: String = "{cracks} cracks end the trial and cost {levels} levels of Core Density."

## The last breath's name. The last breath is not one of the phases, so its
## name and tip live here instead of on a TribulationPhaseData.
@export var last_breath_name: String = "The last breath"

## The tip the board shows during the last breath.
@export var last_breath_tip: String = "Press as it crosses the ring, then hold while it pours into your core"

## The heading of the result panel when the trial is passed.
@export var pass_title: String = "Breakthrough"

## The result panel's text when the trial is passed.
@export var pass_text: String = "Your core condenses into Copper."

## The heading of the result panel when the trial is failed.
@export var fail_title: String = "Your core cracks"

## The result panel's text when the trial is failed, as a template: {before} and
## {after} stand for the Core Density before and after the penalty.
## get_fail_line() fills it.
@export var fail_text: String = "Core Density falls from {before} to {after}."

#-----------------------------------------------------------------------------
# TIMING
#-----------------------------------------------------------------------------

@export_group("Timing")
## The speed of the whole trial: every duration is divided by it.
@export var tempo: float = 1.0

## Seconds of stillness before the first phase.
@export var lead_in: float = 1.2

## The phases before the last breath, in the order they play.
@export var phases: Array[TribulationPhaseData] = []

## Seconds of stillness between the last phase and the last breath.
@export var last_breath_gap: float = 0.5

## Seconds the last breath takes to grow to last_breath_max_ratio.
@export var last_breath_in: float = 1.8

## Seconds the last breath takes to shrink back to the core.
@export var last_breath_out: float = 4.5

## How far the last breath grows, as a ratio of R.
@export var last_breath_max_ratio: float = 2.54

## Seconds of stillness after the last breath, before the result.
@export var end_pause: float = 1.2

#-----------------------------------------------------------------------------
# GEOMETRY
#-----------------------------------------------------------------------------

@export_group("Geometry")
## A sphere's smallest radius, as a ratio of R.
@export var sphere_min_ratio: float = 0.42

## A sphere's largest radius in the phases, as a ratio of R. The last breath
## grows to last_breath_max_ratio instead.
@export var sphere_max_ratio: float = 1.88

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

@export_group("Judging")
## Seconds either side of a beat within which a press is perfect.
@export var perfect_window: float = 0.07

## Seconds either side of a beat within which a press is a hit: good, or
## perfect inside perfect_window.
@export var good_window: float = 0.14

## The least reach, in seconds before a beat, of an early miss: a press earlier
## than good_window but within get_early_reach() of the beat is a miss for it.
@export var early_reach_min: float = 0.30

## Seconds before the sphere reaches the core by which the last breath's hold
## may end early without cracking.
@export var release_tolerance: float = 0.05

## How many cracks end the trial in a failure.
@export var cracks_to_fail: int = 4

#-----------------------------------------------------------------------------
# PENALTY
#-----------------------------------------------------------------------------

@export_group("Penalty")
## How many levels of Core Density a failure costs.
@export var failure_level_loss: int = 5

#-----------------------------------------------------------------------------
# DERIVED VALUES
#-----------------------------------------------------------------------------

## How far before a beat, in seconds, a press still counts as an early miss for
## it: early_reach_min, or the good window plus EARLY_REACH_PAST_GOOD when that
## reaches farther.
func get_early_reach() -> float:
	return maxf(early_reach_min, good_window + EARLY_REACH_PAST_GOOD)

## The intro panel's rules line: rules_text with {cracks} and {levels} filled in.
func get_rules_line() -> String:
	return rules_text.format({"cracks": cracks_to_fail, "levels": failure_level_loss})

## The fail panel's line: fail_text with {before} and {after} filled in.
func get_fail_line(before: int, after: int) -> String:
	return fail_text.format({"before": before, "after": after})
