class_name DrillStage
extends Control

## DrillStage
## One drill input's scene on the body refining board: its backdrop and the pieces
## its input moves, filling the figure box under the rep beads and the floaters.
## DrillPlay shows the stage whose input_kind is its drill's and drives it:
## show_rest() before a set and after one, show_run() every frame while a set runs,
## show_judgement() as each rep is judged, and tick() every frame, set or not, for
## motion that never stops (the falls streaming, the incense's smoke). A stage only
## draws: its run decides everything. get_floater_anchor() and get_pellet_origin()
## say where a judged rep's tier pops and where its pellets leave from, in the
## stage's space, which is DrillPlay's.

## The input this stage plays.
@export var input_kind: DrillData.InputKind = DrillData.InputKind.HOLD_RELEASE

## Readies the stage for `drill`: the length of its set, say.
func setup(_drill: DrillData) -> void:
	pass

## Shows the stage at rest, with no set running.
func show_rest() -> void:
	pass

## Shows `run` at `t_usec` on its set's clock.
func show_run(_run: DrillRun, _t_usec: int) -> void:
	pass

## Shows a rep just judged.
func show_judgement(_judgement: DrillRun.Judgement) -> void:
	pass

## Moves what moves whether or not a set runs, at `now_usec` on the play's clock.
func tick(_now_usec: int) -> void:
	pass

## Where a judged rep's tier pops.
func get_floater_anchor(_judgement: DrillRun.Judgement) -> Vector2:
	return size / 2.0

## Where a judged rep's pellets leave from.
func get_pellet_origin(_judgement: DrillRun.Judgement) -> Vector2:
	return size / 2.0
