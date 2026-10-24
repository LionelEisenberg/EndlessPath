class_name EncounterCoin
extends Control

## EncounterCoin
## One coin on the adventure map (spec: The map, Coins): a 54x54 frame of the
## lacquer token strip (a 52 px coin and its 2 px shadow) with the encounter's
## glyph on it at 32x32. Its face is the strip's frame:
## - GLYPH (0): brass rim over a lacquer field, the encounter's glyph. A tile the
##   player has visited, or the dev override shows.
## - UNKNOWN (1): carved, with a tan "?" and no glyph. A revealed tile, which
##   keeps what it holds under its veil.
## - CLEARED (2): carved, the glyph in the kit's locked veil in lighter steps. A
##   resolved encounter.
## - BOSS (3): brass rim and a vermilion inner ring, the boss glyph. The boss
##   tile once it is revealed, through the fog.
## The statics decide which tiles get a coin and with what face and glyph, so the
## map layer (AdventureMapMarkers) and the tests ask the same code; setup()
## applies the answer. The rest and boss glyphs are strips whose frames step in
## _process. The layer places the coin every frame, so the shake (the boss coin
## when the boss comes into view) moves the token and its glyph inside it instead,
## in the zone map's lock-shake steps (MapGlyph.shake_offset_at()).

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## What the coin shows: each value is its frame in the token strip.
enum Face { GLYPH, UNKNOWN, CLEARED, BOSS }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The user's glyphs, by what the encounter is.
const GLYPH_COMBAT: Texture2D = preload("res://assets/sprites/ui/stat_icons/combat_icon.png")
const GLYPH_ELITE: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const GLYPH_REST: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/rest-sheet.png")
const GLYPH_BOSS: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/boss_spritesheet.png")
const GLYPH_TREASURE: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const GLYPH_TRAP: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")

## The kit's spent glyphs for a resolved encounter, in the same order.
const SPENT_COMBAT: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_combat_spent_light_ai.png")
const SPENT_ELITE: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_elite_spent_light_ai.png")
const SPENT_REST: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_rest_spent_light_ai.png")
const SPENT_BOSS: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_boss_spent_light_ai.png")
const SPENT_TREASURE: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_treasure_spent_light_ai.png")
const SPENT_TRAP: Texture2D = preload("res://assets/sprites/adventure/encounter_glyphs/adv_glyph_trap_spent_light_ai.png")

## One frame of a glyph's art: the trap's is 32 px native, the others' 64 px.
const GLYPH_FRAME_SIZE: Vector2i = Vector2i(64, 64)
const TRAP_FRAME_SIZE: Vector2i = Vector2i(32, 32)

## The animated strips: the boss's 7 frames show 0.2 s each (1.4 s a cycle), the
## rest site's 5 frames 0.4 s each (2 s a cycle), today's pace.
const BOSS_FRAMES: int = 7
const BOSS_FRAME_SECONDS: float = 0.2
const REST_FRAMES: int = 5
const REST_FRAME_SECONDS: float = 0.4

## Keeps a time that falls on a frame boundary (0.6 s of 0.2 s frames, which
## divides to 2.9999999999999996) from flooring to the frame before it.
const _FRAME_BIAS: float = 0.0001

## Where the token and the glyph sit when the coin is not shaking.
const _TOKEN_HOME: Vector2 = Vector2.ZERO
const _GLYPH_HOME: Vector2 = Vector2(10, 10)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _token: LacquerStripRect = %Token
@onready var _glyph: LacquerStripRect = %Glyph

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _face: Face = Face.GLYPH
var _glyph_texture: Texture2D = null
var _glyph_frame_size: Vector2i = Vector2i.ZERO
var _glyph_frames: int = 1
var _frame_seconds: float = 0.0
## Seconds since the glyph last started over, which picks its frame.
var _frame_elapsed: float = 0.0
## Seconds into the shake, or -1 while the coin is not shaking.
var _shake_elapsed: float = -1.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_refresh(true)

func _process(delta: float) -> void:
	if is_shaking():
		_step_shake(delta)
	if _is_animated():
		_step_glyph(delta)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the face, with the glyph at `glyph_frame_size` per frame, `glyph_frames`
## frames and `frame_seconds` for each. An UNKNOWN face shows no glyph, whatever
## is passed: nothing under a veil is drawn. Setting a coin up again with the
## same glyph and pace leaves its animation where it is.
func setup(face: Face, glyph: Texture2D, glyph_frame_size: Vector2i, glyph_frames: int, frame_seconds: float) -> void:
	if face == Face.UNKNOWN:
		glyph = null
	glyph_frames = maxi(glyph_frames, 1)
	var glyph_changed: bool = (glyph != _glyph_texture or glyph_frame_size != _glyph_frame_size
		or glyph_frames != _glyph_frames or not is_equal_approx(frame_seconds, _frame_seconds))
	_face = face
	_glyph_texture = glyph
	_glyph_frame_size = glyph_frame_size
	_glyph_frames = glyph_frames
	_frame_seconds = frame_seconds
	if glyph_changed:
		_frame_elapsed = 0.0
	_refresh(glyph_changed)

## The face the coin shows.
func get_face() -> Face:
	return _face

## The glyph strip the coin shows, or null while it shows none (the question mark).
func get_glyph_texture() -> Texture2D:
	return _glyph_texture

## Shakes the coin side to side in whole steps, the token and its glyph together;
## a new shake restarts it. The coin itself stays on its hex.
func shake() -> void:
	_shake_elapsed = 0.0
	_apply_shake_offset(MapGlyph.shake_offset_at(0.0))
	_update_processing()

## True while the coin is shaking.
func is_shaking() -> bool:
	return _shake_elapsed >= 0.0

## True when a coin is needed on a tile the player sees: whenever it holds
## something, and also on a revealed tile that holds nothing, which keeps its
## question mark, so a coin never gives away an empty tile. A tile that is
## visited, or shown by the dev override, with nothing on it needs none.
static func needs_coin(encounter: AdventureEncounter, visited: bool, dev_revealed: bool) -> bool:
	if visited or dev_revealed:
		return encounter != null and not (encounter is NoOpEncounter)
	return true

## The face of the tile's coin: carved once a visited encounter is resolved, its
## glyph while it is visited, the boss's own coin once revealed (also under the
## dev override), its glyph under the dev override, and otherwise the question mark.
static func face_for(encounter: AdventureEncounter, visited: bool, completed: bool, dev_revealed: bool) -> Face:
	if visited and completed:
		return Face.CLEARED
	if visited:
		return Face.GLYPH
	if encounter != null and encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
		return Face.BOSS
	if dev_revealed:
		return Face.GLYPH
	return Face.UNKNOWN

## The glyph strip for an encounter type (an ambush shows combat), or the kit's
## spent glyph once it is cleared. Null for a type with nothing to draw.
static func glyph_for(type: AdventureEncounter.EncounterType, cleared: bool) -> Texture2D:
	match type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			return SPENT_COMBAT if cleared else GLYPH_COMBAT
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			return SPENT_ELITE if cleared else GLYPH_ELITE
		AdventureEncounter.EncounterType.REST_SITE:
			return SPENT_REST if cleared else GLYPH_REST
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			return SPENT_BOSS if cleared else GLYPH_BOSS
		AdventureEncounter.EncounterType.TREASURE:
			return SPENT_TREASURE if cleared else GLYPH_TREASURE
		AdventureEncounter.EncounterType.TRAP:
			return SPENT_TRAP if cleared else GLYPH_TRAP
	return null

## The size of one frame of the type's glyph art, live or spent.
static func glyph_frame_size_for(type: AdventureEncounter.EncounterType) -> Vector2i:
	if type == AdventureEncounter.EncounterType.TRAP:
		return TRAP_FRAME_SIZE
	return GLYPH_FRAME_SIZE

## How many frames the type's glyph has: 5 for a rest site and 7 for the boss
## while they are live, one for a cleared glyph and every other type.
static func glyph_frames_for(type: AdventureEncounter.EncounterType, cleared: bool) -> int:
	if cleared:
		return 1
	match type:
		AdventureEncounter.EncounterType.REST_SITE:
			return REST_FRAMES
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			return BOSS_FRAMES
	return 1

## How long each frame of the type's glyph shows, in seconds: 0.4 for a rest
## site, 0.2 for the boss, 0 for a glyph that stays still.
static func frame_seconds_for(type: AdventureEncounter.EncounterType) -> float:
	match type:
		AdventureEncounter.EncounterType.REST_SITE:
			return REST_FRAME_SECONDS
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			return BOSS_FRAME_SECONDS
	return 0.0

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Puts the face and the glyph on the nodes. `glyph_changed` sets the glyph strip
## up again and starts it from its first frame; without it the glyph is left alone
## so a running animation carries on.
func _refresh(glyph_changed: bool) -> void:
	if not is_node_ready():
		return
	_token.set_frame(_face)
	_glyph.visible = _glyph_texture != null
	if glyph_changed:
		_glyph.strip = _glyph_texture
		_glyph.frame_size = _glyph_frame_size
		_glyph.set_frame(0)
	_update_processing()

## The coin only needs its frames while a glyph steps through them or it shakes.
func _update_processing() -> void:
	set_process(_is_animated() or is_shaking())

func _is_animated() -> bool:
	return _glyph_texture != null and _glyph_frames > 1 and _frame_seconds > 0.0

func _step_glyph(delta: float) -> void:
	_frame_elapsed += delta
	_glyph.set_frame(floori(_frame_elapsed / _frame_seconds + _FRAME_BIAS) % _glyph_frames)

func _step_shake(delta: float) -> void:
	_shake_elapsed += delta
	_apply_shake_offset(MapGlyph.shake_offset_at(_shake_elapsed))
	if _shake_elapsed >= MapGlyph.SHAKE_SECONDS:
		_shake_elapsed = -1.0
		_update_processing()

## Moves the token and the glyph `offset_x` px along x from where they sit at rest.
func _apply_shake_offset(offset_x: int) -> void:
	if not is_node_ready():
		return
	_token.position = _TOKEN_HOME + Vector2(offset_x, 0)
	_glyph.position = _GLYPH_HOME + Vector2(offset_x, 0)
