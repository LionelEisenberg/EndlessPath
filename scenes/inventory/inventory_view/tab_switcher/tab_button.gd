extends Control

## A side tab on a menu book's left edge: the inventory's categories and the
## path book's stages. Slides out when opened, through the eight frames of its
## strip. The icon keeps one size, 16 units (32 px, so a 64 px icon shows one
## art pixel a screen pixel), and steps on the same frames, in whole units, to
## stay centred on the part of the tab outside the page. A locked tab shows a
## padlock, dims its icon, explains itself in a tooltip and ignores clicks.

@export var icon_texture: Texture2D
@onready var icon: TextureRect = %Icon
@onready var button: Button = %Button
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

signal tab_opened()

const _LOCKED_ICON_TINT: Color = Color(1, 1, 1, 0.55)

var _locked: bool = false

func _ready() -> void:
	icon.texture = icon_texture
	button.pressed.connect(_on_button_pressed)
	_apply_lock()

## Slides the tab out (selected).
func open() -> void:
	_animation_player.play_backwards("TabButtonAnimation")

## Slides the tab back in.
func close() -> void:
	_animation_player.play("TabButtonAnimation")

## Locks or unlocks the tab. While locked it shows the hint as its tooltip.
func set_locked(is_locked: bool, hint: String = "") -> void:
	_locked = is_locked
	button.tooltip_text = hint if is_locked else ""
	_apply_lock()

## True while the tab is locked.
func is_locked() -> bool:
	return _locked

func _apply_lock() -> void:
	if not is_node_ready():
		return
	_lock_icon.visible = _locked
	icon.self_modulate = _LOCKED_ICON_TINT if _locked else Color.WHITE

func _on_button_pressed() -> void:
	if not _locked:
		tab_opened.emit()
