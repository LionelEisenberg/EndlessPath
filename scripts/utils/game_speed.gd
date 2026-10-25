class_name GameSpeed extends RefCounted

## GameSpeed
## The speed the game runs at: the base Engine.time_scale, which a moment that
## slows time comes back to once it is over. It lives here, apart from the dev
## tools, so gameplay can read it without depending on them. A dev session switch
## sets the engine back to it, because it frees an adventure whose boss hit-stop
## may not have restored the time scale yet. Statics only.

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
