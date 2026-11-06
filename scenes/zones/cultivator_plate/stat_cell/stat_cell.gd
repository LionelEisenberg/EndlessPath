class_name StatCell
extends Control

## One stat on the cultivator cabinet: its icon in a ring of XP beads, with its
## name and "Lv N" under the ring. The beads light toward the next level, each
## only once its share of the XP is earned. At the stage's cap the beads join
## into one channel with brass glints flowing round it (a strip stepped
## CAPPED_FPS frames a second) and the level turns brass.
## Two looks play on demand, in whole steps: play_level_up() flashes the ring's
## beads in brass and a brass frame round the cell together, and hop() lifts the
## ring and its icon 4 px and back as a pellet lands. The cell takes the pointer
## only to say it is hovered (hover_changed); what the hover shows is the
## cabinet's.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted as the pointer comes onto the cell (true) and leaves it (false).
signal hover_changed(hovering: bool)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ring's side (px): it stands at the cell's top left.
const RING_SIZE: float = 80.0
## The ring's beads: the bead strip's frame n lights n of them, 0 to 24.
const RING_BEADS: int = 24
## The capped strip's frames, and how many it steps through a second.
const CAPPED_FRAMES: int = 24
const CAPPED_FPS: float = 10.0
## The level-up flash: the brass beads and frame show for a phase, hide for a
## phase, FLASH_TIMES times, the kit's flash timing.
const FLASH_PHASE_SECONDS: float = LacquerFrameOverlay.FLASH_PHASE_SECONDS
const FLASH_TIMES: int = 2
## The hop's y offsets (px), one every HOP_STEP_SECONDS, each held.
const HOP_KEYFRAMES: Array[int] = [0, -2, -4, -2, 0]
const HOP_STEP_SECONDS: float = 0.04

const _BEADS_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_ring_strip_ai.png")
const _CAPPED_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_ring_capped_strip_ai.png")

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The stat the cell shows.
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _xp_ring: LacquerStripRect = %XpRing
@onready var _flash_ring: TextureRect = %FlashRing
@onready var _level_frame: LacquerFrameOverlay = %LevelFrame
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## What the cell shows, as set_stat() last gave it.
var _level: int = 1
var _xp: float = 0.0
var _xp_to_next: float = 0.0
var _capped: bool = false

## Seconds into the capped strip's loop, the flash and the hop; a negative time
## means the look is not playing.
var _capped_elapsed: float = 0.0
var _flash_elapsed: float = -1.0
var _hop_elapsed: float = -1.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_name_label.text = StatDisplay.name_of(attribute_type)
	_icon.texture = StatDisplay.icon_of(attribute_type)
	mouse_entered.connect(hover_changed.emit.bind(true))
	mouse_exited.connect(hover_changed.emit.bind(false))
	_refresh_processing()

func _process(delta: float) -> void:
	if _capped:
		_capped_elapsed += delta
		_xp_ring.set_frame(capped_frame_at(_capped_elapsed))
	if _flash_elapsed >= 0.0:
		_flash_elapsed += delta
		if _flash_elapsed >= FLASH_TIMES * 2 * FLASH_PHASE_SECONDS:
			_flash_elapsed = -1.0
		_show_flash()
	if _hop_elapsed >= 0.0:
		_hop_elapsed += delta
		if _hop_elapsed >= HOP_KEYFRAMES.size() * HOP_STEP_SECONDS:
			_hop_elapsed = -1.0
		_xp_ring.position.y = hop_offset_at(maxf(_hop_elapsed, 0.0))
	_refresh_processing()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the stat's level and its XP toward the next level: of the ring's
## RING_BEADS beads, floor(xp × RING_BEADS / xp_to_next) are lit (none when
## xp_to_next is 0), so a bead lights only once its share is earned. A capped
## stat shows the flowing channel and its level in brass.
func set_stat(level: int, xp: float, xp_to_next: float, capped: bool) -> void:
	_level = level
	_xp = xp
	_xp_to_next = xp_to_next
	_level_label.text = "Lv %d" % level
	if capped != _capped:
		_capped_elapsed = 0.0
	_capped = capped
	if capped:
		_xp_ring.strip = _CAPPED_STRIP
		_xp_ring.set_frame(capped_frame_at(_capped_elapsed))
	else:
		_xp_ring.strip = _BEADS_STRIP
		var lit_beads: int = floori(xp * RING_BEADS / xp_to_next) if xp_to_next > 0.0 else 0
		_xp_ring.set_frame(clampi(lit_beads, 0, RING_BEADS))
	_show_level_colour()
	_refresh_processing()

## Flashes the level-up look from its start: the ring's beads in brass and the
## brass frame round the cell, the level in brass, FLASH_PHASE_SECONDS on and
## off, FLASH_TIMES times. It ends on what set_stat() last gave.
func play_level_up() -> void:
	_flash_elapsed = 0.0
	_show_flash()
	_refresh_processing()

## Lifts the ring and its icon through HOP_KEYFRAMES. A hop already running runs
## on: a burst of landings bobs the ring once per hop, never holding it up.
func hop() -> void:
	if _hop_elapsed >= 0.0:
		return
	_hop_elapsed = 0.0
	_xp_ring.position.y = hop_offset_at(0.0)
	_refresh_processing()

## The global position of the ring's centre, where the stat's pellets land. A
## hop does not move it.
func get_ring_global_center() -> Vector2:
	return global_position + Vector2(RING_SIZE, RING_SIZE) * 0.5

## True while the level-up look plays, its last hidden phase included.
func is_flashing() -> bool:
	return _flash_elapsed >= 0.0

## True while a hop runs.
func is_hopping() -> bool:
	return _hop_elapsed >= 0.0

## The level, XP, XP to the next level and cap the cell shows: the figure a
## hover reads, so it always matches the ring.
func get_shown_level() -> int:
	return _level

func get_shown_xp() -> float:
	return _xp

func get_shown_xp_to_next() -> float:
	return _xp_to_next

func is_shown_capped() -> bool:
	return _capped

## Whether the level-up look shows its brass at `elapsed` seconds into it: on for
## a phase, off for a phase, FLASH_TIMES times, then off.
static func is_flash_on_at(elapsed: float) -> bool:
	if elapsed < 0.0 or elapsed >= FLASH_TIMES * 2 * FLASH_PHASE_SECONDS:
		return false
	return floori(elapsed / FLASH_PHASE_SECONDS + 0.0001) % 2 == 0

## The ring's y offset (px) at `elapsed` seconds into a hop, each keyframe held
## HOP_STEP_SECONDS.
static func hop_offset_at(elapsed: float) -> int:
	# The small bias keeps a time on a keyframe from flooring short.
	var index: int = floori(maxf(elapsed, 0.0) / HOP_STEP_SECONDS + 0.0001)
	return HOP_KEYFRAMES[mini(index, HOP_KEYFRAMES.size() - 1)]

## The capped strip's frame at `elapsed` seconds into its loop.
static func capped_frame_at(elapsed: float) -> int:
	return floori(maxf(elapsed, 0.0) * CAPPED_FPS + 0.0001) % CAPPED_FRAMES

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _show_flash() -> void:
	var on: bool = is_flash_on_at(_flash_elapsed)
	_flash_ring.visible = on
	_level_frame.visible = on
	_show_level_colour()

## The level reads brass at the cap and while the flash is on, cream otherwise.
func _show_level_colour() -> void:
	var brass: bool = _capped or is_flash_on_at(_flash_elapsed)
	_level_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_BRASS if brass else ThemeConstants.LACQUER_CREAM)

## Runs _process only while a look moves: the capped glints, the flash, the hop.
func _refresh_processing() -> void:
	set_process(_capped or is_flashing() or is_hopping())
