class_name CombatantVisual
extends Node2D

## CombatantVisual
## On-stage body of a combatant. The node origin is the combatant's feet.
## Normalizes any sprite to a common on-screen height and plays the
## enter / attack / hit / buff reactions plus floating damage numbers.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/combat/combatant/combatant_visual/damage_number.tscn")

const COLOR_DAMAGE: Color = Color("#f2ece0")
const COLOR_DAMAGE_TAKEN_PLAYER: Color = Color("#e86a5c")
const COLOR_HEAL: Color = Color("#7fd18b")
const COLOR_BUFF_FLASH: Color = Color("#d4a84a")
const SHADOW_TEXTURE_SIZE: float = 128.0

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

## Slides the combatant in from off-screen on its own side.
func play_enter() -> void:
	var from_x: float = -_facing * 420.0
	_body.position.x = from_x
	_sprite.modulate.a = 0.0
	_shadow.modulate.a = 0.0
	_kill(_body_tween)
	_body_tween = create_tween().set_parallel(true)
	_body_tween.tween_property(_body, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_sprite, "modulate:a", 1.0, 0.3)
	_body_tween.tween_property(_shadow, "modulate:a", 1.0, 0.45)

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

## Gold pulse used when the combatant empowers itself.
func play_buff() -> void:
	_flash(COLOR_BUFF_FLASH, 0.55, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 1.06, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", _base_sprite_scale, 0.2).set_ease(Tween.EASE_IN_OUT)

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

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
