class_name DevPresetRow
extends HBoxContainer

## One preset in the Saves tab's list: its title, its description and, when it is the
## pinned one, a line saying plain launches start in it, then Play and Pin (Unpin for
## the pinned one). The row only says which button was pressed; the tab plays or pins
## the preset.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when Play is pressed, with the row's preset.
signal play_pressed(preset: SavePresetData)

## Emitted when Pin or Unpin is pressed, with the row's preset.
signal pin_pressed(preset: SavePresetData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _pinned_label: Label = %PinnedLabel
@onready var _play_button: Button = %PlayButton
@onready var _pin_button: Button = %PinButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The preset the row shows, null until set_preset().
var _preset: SavePresetData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_pin_button.pressed.connect(_on_pin_pressed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the preset: its title, its description (hidden when it has none), and
## whether it is the pinned one, which the pin button then offers to undo. The row
## must be in the tree.
func set_preset(preset: SavePresetData, pinned: bool) -> void:
	_preset = preset
	_title_label.text = preset.title
	_description_label.text = preset.description
	_description_label.visible = preset.description != ""
	_pinned_label.visible = pinned
	_pin_button.text = "Unpin" if pinned else "Pin"

## The preset the row shows, or null before set_preset().
func get_preset() -> SavePresetData:
	return _preset

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_play_pressed() -> void:
	play_pressed.emit(_preset)

func _on_pin_pressed() -> void:
	pin_pressed.emit(_preset)
