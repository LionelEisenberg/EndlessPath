class_name FilterWords
extends HBoxContainer

## FilterWords
## The Equipment page's category filter, printed in the caption row: up to four
## words in capitals. The word in use is printed in dark ink and pressed into a
## lozenge (LabelBookFilterOn), the others in muted ink (LabelBookFilter). The
## two variants are the same size, so selecting a word moves nothing. A left
## press on a word selects it.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The player pressed a word other than the one in use.
signal option_changed(index: int)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _WORD_OFF: StringName = &"LabelBookFilter"
const _WORD_ON: StringName = &"LabelBookFilterOn"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _words: Array[Label] = [%Word0, %Word1, %Word2, %Word3]

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _selected: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for index: int in _words.size():
		_words[index].gui_input.connect(_on_word_input.bind(index))

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints `labels` on the words in order, hides the words left over, and
## selects the first without emitting option_changed.
func set_options(labels: PackedStringArray) -> void:
	for index: int in _words.size():
		var used: bool = index < labels.size()
		_words[index].visible = used
		_words[index].text = labels[index] if used else ""
	select(0)

## Prints the word at `index` as the one in use, and the others as not.
func select(index: int) -> void:
	_selected = index
	for word_index: int in _words.size():
		_words[word_index].theme_type_variation = _WORD_ON if word_index == index else _WORD_OFF

## Returns the index of the word in use.
func get_selected() -> int:
	return _selected

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_word_input(event: InputEvent, index: int) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var changed: bool = index != _selected
	select(index)
	if changed:
		option_changed.emit(index)
