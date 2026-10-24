class_name MapGlyph
extends Control

## MapGlyph
## The glyph over a veiled hex on the zone map (kit §0, §6.4): the brass
## padlock over a locked zone, or the tan "?" over an uncharted one with its
## pixel twinkle beside it. Every 4 s the twinkle plays frames 1, 2, 1 for
## 0.1, 0.2 and 0.1 s; the rest of the time it shows frame 0 (empty).
## MapMarkers places the glyph over its hex every frame, so the lock shake (a
## click on the locked hex) moves %Icon instead: 0, -8, 8, -6, 4 and 0 px
## over 0.44 s, each step held until the next (kit §6.4). The shake reads
## its steps from shake_offset_at(), the one function that steps through a
## keyframe set. There are two sets: SHAKE_KEYFRAMES (the lock shake, which the
## adventure's coins, Stamina row and Here tray share) and SOFT_SHAKE_KEYFRAMES,
## which the adventure's buttons shake by when a press is refused (TechniqueSlot).

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

## The lock shake's x offsets (px), one every SHAKE_STEP_SECONDS, each held
## until the next: SHAKE_SECONDS (0.44 s) in all.
const SHAKE_KEYFRAMES: Array[int] = [0, -8, 8, -6, 4, 0]
## The soft shake of a button that was pressed when it could not act: the lock
## shake's rhythm (six keyframes, so SHAKE_SECONDS ends it too) at half its
## travel, in whole even px (-2 where half of -6 would be the odd -3). Buttons
## get pressed again and again in a fight, and the lock shake's 8 px was too much.
const SOFT_SHAKE_KEYFRAMES: Array[int] = [0, -4, 4, -2, 2, 0]
const SHAKE_STEP_SECONDS: float = 0.088
## One step per keyframe after the first. Both sets have six keyframes.
const SHAKE_SECONDS: float = SHAKE_STEP_SECONDS * 5.0

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
	_shake_tween.tween_method(_apply_shake, 0.0, SHAKE_SECONDS, SHAKE_SECONDS)

## True while the padlock is shaking.
func is_shaking() -> bool:
	return _shake_tween != null and _shake_tween.is_valid() and _shake_tween.is_running()

## The x offset (px) at elapsed seconds into a shake over keyframes, each held
## for SHAKE_STEP_SECONDS: the lock shake (SHAKE_KEYFRAMES) by default, or
## SOFT_SHAKE_KEYFRAMES for a button. Shakes call this instead of stepping
## through a set themselves.
static func shake_offset_at(elapsed: float, keyframes: Array[int] = SHAKE_KEYFRAMES) -> int:
	if elapsed <= 0.0:
		return keyframes[0]
	# The small bias keeps a time on a keyframe (0.44 s) from flooring short.
	var index: int = floori(elapsed / SHAKE_STEP_SECONDS + 0.0001)
	return keyframes[mini(index, keyframes.size() - 1)]

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

func _apply_shake(elapsed: float) -> void:
	_set_icon_offset(shake_offset_at(elapsed))

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
