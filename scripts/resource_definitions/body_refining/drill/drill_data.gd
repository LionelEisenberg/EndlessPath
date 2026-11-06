class_name DrillData
extends Resource

## One body refining drill: what each rep trains and restores, and how its reps
## are played. Every drill trains Strength and refills Health, and trains at most
## one other Physical stat. DrillRules turns a judged rep into XP and Health, and
## BodyRefiningManager pays it. BodyRefiningManager loads the catalog from
## resources/body_refining/drills/drill_list.tres.

## How a drill's reps are played. Drill files store it as an int, so values
## only ever grow at the end.
enum InputKind {
	HOLD_RELEASE = 0,  ## Hold to lift, let go in the band
	HOLD_STEADY = 1,   ## Hold steady in a drifting band
	CATCH = 2,         ## Click as the target crosses the catch line
	BEAT = 3,          ## Press on the beat
}

@export var id: String = ""
@export var drill_name: String = ""
## The drill's icon, for its card and picker (#100, #106).
@export var icon: Texture2D
## The one other stat the drill trains: an AttributeType (BODY or AGILITY), or
## -1 for none.
@export var minor_stat: int = -1
## The Strength XP a PERFECT rep pays. Every drill pays some.
@export var strength_xp_per_rep: float = 0.0
## The minor stat's XP a PERFECT rep pays. Unused when minor_stat is -1.
@export var minor_xp_per_rep: float = 0.0
## The Health a PERFECT rep restores at Strength Lv 1.
@export var health_per_rep: float = 0.0
@export var input_kind: InputKind = InputKind.HOLD_RELEASE
## How long one rep takes to play, in seconds.
@export var rep_seconds: float = 0.0
## How many reps make a set.
@export var reps_per_set: int = 0

## True when the drill has a minor stat.
func has_minor_stat() -> bool:
	return minor_stat >= 0
