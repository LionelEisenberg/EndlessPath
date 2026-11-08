class_name GameSpeed extends RefCounted

## GameSpeed
## The speed the game runs at: the base Engine.time_scale, which a moment that
## slows time comes back to once it is over: a hit-stop (hit_stop()), at the boss's
## reveal and at the hit that decides a fight. It lives here, apart from the dev
## tools, so gameplay can read it without depending on them. A dev session switch
## sets the engine back to it, because it frees an adventure whose hit-stop may
## not have restored the time scale yet. Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## A hit-stop runs time at this share of the base speed...
const HIT_STOP_SCALE: float = 0.25
## ...for this long in real time.
const HIT_STOP_SECONDS: float = 0.15

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The base time scale. 1.0 is normal speed.
static var base_scale: float = 1.0

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Makes `scale` the base time scale and runs the engine at it.
static func set_base_scale(scale: float) -> void:
	base_scale = scale
	Engine.time_scale = scale

## Slows time to HIT_STOP_SCALE of the base speed for HIT_STOP_SECONDS of real
## time, then runs it at the base speed again. The timer ignores the time scale, so
## the stop lasts its real seconds at any speed, and it reads the base speed when it
## fires, so a speed set meanwhile is the one time returns to.
static func hit_stop(tree: SceneTree) -> void:
	Engine.time_scale = HIT_STOP_SCALE * base_scale
	tree.create_timer(HIT_STOP_SECONDS, true, false, true).timeout.connect(func() -> void: Engine.time_scale = GameSpeed.base_scale)
