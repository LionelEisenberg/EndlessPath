class_name SystemMenuButton
extends Button

## SystemMenuButton
## A compact navigation button for the SystemMenu grid.
## Select a MenuType from the enum — it auto-configures the label, shortcut, and input action.

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
## Icon textures are null until pixel art is created — add paths here later.
const MENU_CONFIG: Dictionary = {
	MenuType.INVENTORY: {
		"display_name": "INVENTORY",
		"input_action": &"open_inventory",
		"shortcut_hint": "I",
		"icon": preload("res://assets/ui_images/system_menu/inventory_icon.png"),
	},
	MenuType.ABILITIES: {
		"display_name": "ABILITIES",
		"input_action": &"open_abilities",
		"shortcut_hint": "A",
		"icon": null,
	},
	MenuType.CHARACTER: {
		"display_name": "CHARACTER",
		"input_action": &"open_character",
		"shortcut_hint": "C",
		"icon": null,
	},
	MenuType.PATH: {
		"display_name": "PATH",
		"input_action": &"open_path",
		"shortcut_hint": "P",
		"icon": preload("res://assets/ui_images/system_menu/star_icon.png"),
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

@onready var _icon_rect: TextureRect = %IconTexture
@onready var _name_label: Label = %NameLabel
@onready var _shortcut_label: Label = %ShortCutLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_config()

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

func _on_mouse_entered() -> void:
	_name_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
	_shortcut_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)

func _on_mouse_exited() -> void:
	_name_label.remove_theme_color_override("font_color")
	_shortcut_label.remove_theme_color_override("font_color")

func _on_pressed() -> void:
	var config: Dictionary = MENU_CONFIG.get(menu_type, {})
	var action: StringName = config.get("input_action", &"")
	if action.is_empty():
		Log.warn("SystemMenuButton: No input_action for MenuType %s" % menu_type)
		return

	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
