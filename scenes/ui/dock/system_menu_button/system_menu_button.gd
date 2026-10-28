class_name SystemMenuButton
extends Button

## SystemMenuButton
## One lacquer dock button (lacquer kit §5.4): a 108x64 face with a 32 px icon,
## its label and its hotkey letter. Select a MenuType from the enum: it
## configures the label, hotkey, icon and input action.
## A notification swaps the face for the brass ring, and a count above zero
## adds the cinnabar count seal (LacquerCountSeal) over the top-left corner,
## widening rightward for a long count. Hover shows the
## hover face over either. The Dock decides who is notified.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum MenuType {
	INVENTORY,
	ABILITIES,
	CHARACTER,
	PATH
}

#-----------------------------------------------------------------------------
# MENU CONFIG
#-----------------------------------------------------------------------------

## Maps each MenuType to its display name, input action, shortcut hint, and icon.
## Every icon shows at 32x32: the inventory bag (16 px) at 2x, the 64 px
## character and star icons at half size, the lacquer abilities icon as is.
const MENU_CONFIG: Dictionary = {
	MenuType.INVENTORY: {
		"display_name": "Inventory",
		"input_action": &"open_inventory",
		"shortcut_hint": "I",
		"icon": preload("res://assets/sprites/ui/system_menu/inventory_icon.png"),
	},
	MenuType.ABILITIES: {
		"display_name": "Abilities",
		"input_action": &"open_abilities",
		"shortcut_hint": "A",
		"icon": preload("res://assets/ui/lacquer/lacquer_ic_abilities_ai.png"),
	},
	MenuType.CHARACTER: {
		"display_name": "Character",
		"input_action": &"open_character",
		"shortcut_hint": "C",
		"icon": preload("res://assets/sprites/ui/system_menu/character_icon.png"),
	},
	MenuType.PATH: {
		"display_name": "Path",
		"input_action": &"open_path",
		"shortcut_hint": "P",
		"icon": preload("res://assets/sprites/ui/system_menu/star_icon.png"),
	},
}

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var menu_type: MenuType = MenuType.INVENTORY:
	set(value):
		menu_type = value
		if is_node_ready():
			_apply_config()

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _face_normal: TextureRect = %FaceNormal
@onready var _face_ring: TextureRect = %FaceRing
@onready var _face_hover: TextureRect = %FaceHover
@onready var _icon_rect: TextureRect = %IconTexture
@onready var _name_label: Label = %NameLabel
@onready var _shortcut_label: Label = %ShortCutLabel
@onready var _count_seal: LacquerCountSeal = %CountSeal

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_notified: bool = false
var _notification_count: int = 0
var _is_hovered: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_config()
	_update_notification_display()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows or clears the notification: the brass ring while `active`, plus the
## count seal with `count` when it is above zero. An inactive notification
## shows no count.
func set_notification(active: bool, count: int = 0) -> void:
	_is_notified = active
	_notification_count = maxi(count, 0) if active else 0
	if is_node_ready():
		_update_notification_display()

## True while the button shows its notification ring.
func has_notification() -> bool:
	return _is_notified

## The count on the seal, or 0 when no seal shows.
func get_notification_count() -> int:
	return _notification_count

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _apply_config() -> void:
	var config: Dictionary = MENU_CONFIG.get(menu_type, {})
	if config.is_empty():
		Log.warn("SystemMenuButton: No config for MenuType %s" % menu_type)
		return

	_name_label.text = config.display_name
	_shortcut_label.text = config.shortcut_hint
	_shortcut_label.visible = not config.shortcut_hint.is_empty()

	_icon_rect.texture = config.icon
	_icon_rect.visible = config.icon != null

## Exactly one face shows: hover over everything, then the ring while
## notified, else the plain face. The seal shows with any count above zero.
func _update_notification_display() -> void:
	_face_hover.visible = _is_hovered
	_face_ring.visible = not _is_hovered and _is_notified
	_face_normal.visible = not _is_hovered and not _is_notified
	_count_seal.visible = _notification_count > 0
	_count_seal.show_count(_notification_count)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_notification_display()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_notification_display()

## Fires the button's input action as a key press would: pressed, then
## released, so the action is not left held after the click.
func _on_pressed() -> void:
	var config: Dictionary = MENU_CONFIG.get(menu_type, {})
	var action: StringName = config.get("input_action", &"")
	if action.is_empty():
		Log.warn("SystemMenuButton: No input_action for MenuType %s" % menu_type)
		return

	for is_pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = is_pressed
		Input.parse_input_event(event)
