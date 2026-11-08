class_name CombatantVisual
extends Node2D

## CombatantVisual
## On-stage body of a combatant. The node origin is the combatant's feet.
## Normalizes any sprite to a common on-screen height and plays the
## attack / hit / dodge / buff reactions plus floating damage numbers.
## A fighter comes into its fight and falls out of it in the look's whole steps
## (#138): it waits ENTER_DISTANCE px out on its own side, shown outright, and
## slides to its spot at a steady speed in even px; beaten, it is knocked
## KNOCKBACK_DISTANCE px back, away from its opponent, then blinks out. Both move
## the node itself, so the hit's recoil on the Body plays on untouched.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/combat/combatant/combatant_visual/damage_number.tscn")

const COLOR_DAMAGE: Color = Color("#f2ece0")
const COLOR_DAMAGE_TAKEN_PLAYER: Color = Color("#e86a5c")
const COLOR_HEAL: Color = Color("#7fd18b")
const COLOR_BUFF_FLASH: Color = Color("#d4a84a")
## A dodge is Agility's, so its floater is Agility's Stamina green.
const COLOR_DODGE: Color = ThemeConstants.LACQUER_STAMINA
const DODGED_TEXT: String = "Dodged"
const SHADOW_TEXTURE_SIZE: float = 128.0

## A fighter waits this far (px) out on its own side, and slides in over
## ENTER_SECONDS.
const ENTER_DISTANCE: int = 420
const ENTER_SECONDS: float = 0.4
## A beaten fighter is knocked this far (px) back over KNOCKBACK_SECONDS...
const KNOCKBACK_DISTANCE: int = 48
const KNOCKBACK_SECONDS: float = 0.16
## ...then blinks out: hidden, shown, hidden, shown, BLINK_STEP_SECONDS each, and
## gone.
const BLINK_STEP_SECONDS: float = 0.08
const BLINK_STEPS: int = 4
## How long a fall takes, from the knock to gone.
const DEFEAT_SECONDS: float = KNOCKBACK_SECONDS + BLINK_STEP_SECONDS * BLINK_STEPS

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## On-screen height (px) of a combatant with data scale 1.0.
@export var display_height: float = 280.0
## How far (px) the body lunges toward its target when attacking.
@export var lunge_distance: float = 70.0
## Idle bob amplitude (px).
@export var bob_amplitude: float = 4.0

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _body: Node2D = %Body
@onready var _sprite: Sprite2D = %Sprite
@onready var _shadow: Sprite2D = %Shadow
@onready var _number_anchor: Marker2D = %NumberAnchor
## Numbers live on their own canvas layer so the atmosphere (mist, motes,
## vignette) drifts behind them rather than over them.
@onready var _number_layer: CanvasLayer = %NumberLayer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _facing: float = 1.0 ## +1 faces right, -1 faces left
var _height: float = 0.0
var _is_player: bool = false
var _base_sprite_scale: Vector2 = Vector2.ONE
var _body_tween: Tween
var _flash_tween: Tween
var _bob_tween: Tween
## The entrance or the fall under way.
var _motion_tween: Tween
var _fallen: bool = false

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Configures the sprite. `face_left` mirrors art that faces right by default.
func setup(texture: Texture2D, scale_multiplier: float, sprite_offset: Vector2, face_left: bool, is_player: bool) -> void:
	_facing = -1.0 if face_left else 1.0
	_is_player = is_player
	_height = display_height * maxf(scale_multiplier, 0.1)

	_sprite.texture = texture
	_sprite.flip_h = face_left
	if texture:
		var tex_size: Vector2 = texture.get_size()
		var s: float = _height / tex_size.y
		_base_sprite_scale = Vector2(s, s)
		_sprite.scale = _base_sprite_scale
		_sprite.offset = Vector2(0.0, -tex_size.y / 2.0)
		var shadow_width: float = tex_size.x * s * 0.75
		_shadow.scale = Vector2(shadow_width / SHADOW_TEXTURE_SIZE, shadow_width * 0.22 / SHADOW_TEXTURE_SIZE)
	_body.position = sprite_offset
	_number_anchor.position = Vector2(0.0, -_height * 0.85)
	_start_idle()

## Returns the on-screen height (px) of the sprite above the feet.
func get_visual_height() -> float:
	return _height

## Returns how far (px) a fighter `elapsed` seconds into its entrance still stands
## from its spot: ENTER_DISTANCE at first, down at a steady speed to 0 at
## ENTER_SECONDS, always an even px.
static func enter_offset_at(elapsed: float) -> int:
	return _even_px(ENTER_DISTANCE * (1.0 - clampf(elapsed / ENTER_SECONDS, 0.0, 1.0)))

## Returns how far (px) a beaten fighter `elapsed` seconds into its fall has been
## knocked back: 0 at first, up at a steady speed to KNOCKBACK_DISTANCE at
## KNOCKBACK_SECONDS, always an even px.
static func knockback_offset_at(elapsed: float) -> int:
	return _even_px(KNOCKBACK_DISTANCE * clampf(elapsed / KNOCKBACK_SECONDS, 0.0, 1.0))

## Whether a beaten fighter `elapsed` seconds into its fall shows: through the
## knock, then hidden and shown by turns for BLINK_STEPS steps, then never again.
static func shown_while_falling_at(elapsed: float) -> bool:
	if elapsed < KNOCKBACK_SECONDS:
		return true
	# The nudge keeps a step's first instant in that step, whatever the float error.
	var step: int = floori((elapsed - KNOCKBACK_SECONDS) / BLINK_STEP_SECONDS + 1e-4)
	return step < BLINK_STEPS and step % 2 == 1

## Puts the fighter where its entrance starts, ENTER_DISTANCE out on its own side,
## shown outright.
func place_for_entrance() -> void:
	_kill(_motion_tween)
	_fallen = false
	_set_shown(true)
	_set_entrance(0.0)

## Slides the fighter from where place_for_entrance() put it to its spot, at a
## steady speed in even px, over ENTER_SECONDS.
func play_enter() -> void:
	_kill(_motion_tween)
	_motion_tween = create_tween()
	_motion_tween.tween_method(_set_entrance, 0.0, ENTER_SECONDS, ENTER_SECONDS)

## The beaten fighter's fall: knocked back, away from its opponent, then blinked
## out. It ends hidden (is_fallen()) DEFEAT_SECONDS later.
func play_defeat() -> void:
	_kill(_motion_tween)
	_motion_tween = create_tween()
	_motion_tween.tween_method(_set_fall, 0.0, DEFEAT_SECONDS, DEFEAT_SECONDS)

## Whether the fighter has blinked out at the end of its fall.
func is_fallen() -> bool:
	return _fallen

## Quick lunge toward the opponent and back.
func play_attack() -> void:
	_kill(_body_tween)
	_body_tween = create_tween()
	_body_tween.tween_property(_body, "position:x", -_facing * 14.0, 0.08).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_body, "position:x", _facing * lunge_distance, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_body_tween.tween_property(_body, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Flash, recoil and show a damage number.
func play_hit(amount: float) -> void:
	_flash(Color.WHITE, 0.85, 0.22)
	_kill(_body_tween)
	_body_tween = create_tween()
	_body_tween.tween_property(_body, "position:x", -_facing * 22.0, 0.05).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_body, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var color: Color = COLOR_DAMAGE_TAKEN_PLAYER if _is_player else COLOR_DAMAGE
	_spawn_number("%d" % roundi(amount), color)

## Shows a heal number with a soft green flash.
func play_heal(amount: float) -> void:
	_flash(COLOR_HEAL, 0.45, 0.3)
	_spawn_number("+%d" % roundi(amount), COLOR_HEAL)

## Floats "Dodged" as the numbers float, with no flash and no recoil: the hit
## never landed.
func play_dodge() -> void:
	_spawn_number(DODGED_TEXT, COLOR_DODGE)

## Gold pulse used when the combatant empowers itself.
func play_buff() -> void:
	_flash(COLOR_BUFF_FLASH, 0.55, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 1.06, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", _base_sprite_scale, 0.2).set_ease(Tween.EASE_IN_OUT)

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _set_entrance(elapsed: float) -> void:
	position.x = -_facing * enter_offset_at(elapsed)

func _set_fall(elapsed: float) -> void:
	position.x = -_facing * knockback_offset_at(elapsed)
	_set_shown(shown_while_falling_at(elapsed))
	_fallen = elapsed >= DEFEAT_SECONDS

## Shows or hides the fighter's body and shadow outright. Its numbers float on.
func _set_shown(shown: bool) -> void:
	_body.visible = shown
	_shadow.visible = shown

## The even number of px nearest `value`.
static func _even_px(value: float) -> int:
	return roundi(value / 2.0) * 2

func _start_idle() -> void:
	_kill(_bob_tween)
	_sprite.position.y = 0.0
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_sprite, "position:y", -bob_amplitude, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(_sprite, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _flash(color: Color, strength: float, duration: float) -> void:
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("flash_color", color)
	_kill(_flash_tween)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, strength, 0.0, duration).set_ease(Tween.EASE_OUT)

func _set_flash_amount(value: float) -> void:
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash_amount", value)

func _spawn_number(value_text: String, color: Color) -> void:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	_number_layer.add_child(number)
	number.show_value(value_text, color, _number_anchor.global_position)

func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
