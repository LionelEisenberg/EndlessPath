class_name TitleMenuButton
extends Button

## TitleMenuButton
## One button of the title menu: a lacquer drawer face (lacquer_drawer9_ai.png, the
## choice drawer's 9-slice) with its words centred in LabelLacquerName, and the
## hover frame shown while the pointer is over it or it has the keyboard focus. The
## Button's own text stays empty: set `words` instead.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## What the button says.
@export var words: String = "":
	set(value):
		words = value
		if is_node_ready():
			_words_label.text = value

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _words_label: Label = %WordsLabel
@onready var _hover_frame: Panel = %HoverFrame

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Whether the pointer is over the button. Kept here rather than read from
## is_hovered(), which mouse_exited can still find true.
var _pointer_over: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_words_label.text = words
	mouse_entered.connect(_on_pointer_changed.bind(true))
	mouse_exited.connect(_on_pointer_changed.bind(false))
	focus_entered.connect(_update_frame)
	focus_exited.connect(_update_frame)

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

func _on_pointer_changed(over: bool) -> void:
	_pointer_over = over
	_update_frame()

func _update_frame() -> void:
	_hover_frame.visible = _pointer_over or has_focus()
