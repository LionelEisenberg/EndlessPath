class_name MapGlyph
extends Control

## MapGlyph
## The glyph over a veiled hex on the zone map (kit §0, §6.4): the brass
## padlock over a locked zone, or the tan "?" over an uncharted one with its
## pixel twinkle beside it. Every 4 s the twinkle plays frames 1, 2, 1 for
## 0.1, 0.2 and 0.1 s; the rest of the time it shows frame 0 (empty).
## MapMarkers places and scales the glyph over its hex every frame, so an
## animation of the glyph itself (Task 13's lock shake) moves %Icon instead.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The brass padlock (its hard shadow baked in).
@export var lock_texture: Texture2D
## The tan "?".
@export var unknown_texture: Texture2D

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## One twinkle cycle, and when its frames 1, 2 and 1 start within it.
const TWINKLE_PERIOD: float = 4.0
const _TWINKLE_FRAME_1_START: float = 3.6
const _TWINKLE_FRAME_2_START: float = 3.7
const _TWINKLE_FRAME_1_AGAIN_START: float = 3.9

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _twinkle: LacquerStripRect = %Twinkle

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.LOCKED
var _twinkle_elapsed: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_refresh()

func _process(delta: float) -> void:
	_twinkle_elapsed += delta
	_twinkle.set_frame(twinkle_frame(_twinkle_elapsed))

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the glyph for the zone's map state: LOCKED (padlock) or UNCHARTED
## ("?" and twinkle).
func setup(state: ZoneManager.ZoneMapState) -> void:
	_state = state
	_refresh()

## The map state the glyph was set up with.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## The glyph texture drawn: the padlock or the "?".
func get_texture() -> Texture2D:
	return unknown_texture if _state == ZoneManager.ZoneMapState.UNCHARTED else lock_texture

## True for the uncharted "?", which twinkles.
func has_twinkle() -> bool:
	return _state == ZoneManager.ZoneMapState.UNCHARTED

## The twinkle strip frame (0-2) at elapsed seconds into its 4 s cycle.
static func twinkle_frame(elapsed: float) -> int:
	var t: float = fposmod(elapsed, TWINKLE_PERIOD)
	if t < _TWINKLE_FRAME_1_START:
		return 0
	if t < _TWINKLE_FRAME_2_START:
		return 1
	if t < _TWINKLE_FRAME_1_AGAIN_START:
		return 2
	return 1

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _refresh() -> void:
	if not is_node_ready():
		return
	var texture: Texture2D = get_texture()
	_icon.texture = texture
	if texture != null:
		_icon.size = texture.get_size()
		size = texture.get_size()
	_twinkle.visible = has_twinkle()
	_twinkle_elapsed = 0.0
	_twinkle.set_frame(0)
	set_process(has_twinkle())
