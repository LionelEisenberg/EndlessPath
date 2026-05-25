class_name SortSubBanner
extends HBoxContainer

## SortSubBanner
## Pill widget with left/right arrows over a list of named options, plus
## a row of position dots. Designed to be used as a sort/filter banner.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal option_changed(index: int)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DOT_SELECTED: Texture2D = preload("res://assets/sprites/inventory/equipment_grid/selected_option.png")
const DOT_UNSELECTED: Texture2D = preload("res://assets/sprites/inventory/equipment_grid/unselected_option.png")

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_disabled_visual()

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _label: Label = $Banner/Label
@onready var _left: TextureRect = $LeftArrow
@onready var _right: TextureRect = $RightArrow
@onready var _dots: HBoxContainer = $Dots

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _options: PackedStringArray = PackedStringArray()
var _index: int = 0

#-----------------------------------------------------------------------------
# PROPERTIES
#-----------------------------------------------------------------------------

var current_label: String:
	get: return _options[_index] if _index < _options.size() else ""

var current_index: int:
	get: return _index

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_left.gui_input.connect(_on_left_input)
	_right.gui_input.connect(_on_right_input)
	_refresh_disabled_visual()
	_redraw()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Configure the option list. Resets the current index to 0 and redraws
## label + dots. Accepts a PackedStringArray; plain Array[String] also works
## thanks to GDScript's automatic conversion.
func set_options(options: PackedStringArray) -> void:
	_options = options
	_index = 0
	_redraw()

## Advance to the next option, wrapping around. Emits option_changed.
## No-op when disabled or option list is empty.
func next() -> void:
	if not enabled or _options.is_empty():
		return
	_index = (_index + 1) % _options.size()
	_redraw()
	option_changed.emit(_index)

## Step back to the previous option, wrapping around. Emits option_changed.
## No-op when disabled or option list is empty.
func prev() -> void:
	if not enabled or _options.is_empty():
		return
	_index = (_index - 1 + _options.size()) % _options.size()
	_redraw()
	option_changed.emit(_index)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_left_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		prev()

func _on_right_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

func _redraw() -> void:
	if _label:
		_label.text = current_label
	if _dots == null:
		return
	for child in _dots.get_children():
		child.queue_free()
	for i in _options.size():
		var dot := TextureRect.new()
		dot.texture = DOT_SELECTED if i == _index else DOT_UNSELECTED
		dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_dots.add_child(dot)

func _refresh_disabled_visual() -> void:
	var a: float = 1.0 if enabled else 0.35
	if _left:
		_left.modulate.a = a
	if _right:
		_right.modulate.a = a
	if _dots:
		_dots.modulate.a = a
