class_name MapGlyph
extends Control

## MapGlyph
## The glyph over a veiled hex on the zone map (kit §0, §6.4): the brass
## padlock over a locked zone, or the tan "?" over an uncharted one with its
## pixel twinkle beside it. Every 4 s the twinkle plays frames 1, 2, 1 for
## 0.1, 0.2 and 0.1 s; the rest of the time it shows frame 0 (empty).
## MapMarkers places and scales the glyph over its hex every frame, so the
## lock shake (a click on the locked hex) moves %Icon instead: 0, -8, 8, -6, 4
## and 0 px over 0.44 s, each step held until the next (kit §6.4).

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

## The lock shake's x offsets (px at zoom 2), one every SHAKE_STEP_SECONDS,
## each held until the next: 0.44 s in all.
const SHAKE_KEYFRAMES: Array[int] = [0, -8, 8, -6, 4, 0]
const SHAKE_STEP_SECONDS: float = 0.088

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
var _shake_tween: Tween = null

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

## Shakes the padlock side to side in whole steps; a new shake restarts it.
## The glyph itself stays on its hex.
func shake() -> void:
	_stop_shake()
	if not is_inside_tree():
		return
	_shake_tween = create_tween()
	for index: int in range(1, SHAKE_KEYFRAMES.size()):
		_shake_tween.tween_interval(SHAKE_STEP_SECONDS)
		_shake_tween.tween_callback(_set_icon_offset.bind(SHAKE_KEYFRAMES[index]))

## True while the padlock is shaking.
func is_shaking() -> bool:
	return _shake_tween != null and _shake_tween.is_valid() and _shake_tween.is_running()

## The padlock's x offset (px at zoom 2) at elapsed seconds into a shake.
static func shake_offset_at(elapsed: float) -> int:
	if elapsed <= 0.0:
		return SHAKE_KEYFRAMES[0]
	# The small bias keeps a time on a keyframe (0.44 s) from flooring short.
	var index: int = floori(elapsed / SHAKE_STEP_SECONDS + 0.0001)
	return SHAKE_KEYFRAMES[mini(index, SHAKE_KEYFRAMES.size() - 1)]

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

func _set_icon_offset(offset_x: int) -> void:
	_icon.position.x = offset_x

func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if is_node_ready():
		_set_icon_offset(SHAKE_KEYFRAMES[0])

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
