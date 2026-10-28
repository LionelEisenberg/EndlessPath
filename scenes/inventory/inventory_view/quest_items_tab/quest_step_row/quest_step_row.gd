class_name QuestStepRow
extends HBoxContainer

## QuestStepRow
## One step of a quest in the Journal's quest panel, the way the Goals board
## shows a step: a pressed tick box, ticked once the step is finished, the
## step's text, which wraps and grows the row, and its progress figure
## ("7 / 10") at the right, left out when the step measures nothing.
##
## The text and the figure share a baseline 20 px down the row, 2 px under the
## 22 px tick box's foot, and the figure ends 2 px short of the row's right
## edge, as the mockup prints them. A one-line row is 26 px tall.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The tick box of a step still to do, and of a finished one.
const TICK_BOX_TEXTURE: Texture2D = preload("res://assets/sprites/ui/book/pressed/tick_box_ai.png")
const TICKED_TEXTURE: Texture2D = preload("res://assets/sprites/ui/book/pressed/tick_box_ticked_ai.png")

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _tick: TextureRect = %Tick
@onready var _text: Label = %Text
@onready var _figure_block: Control = %FigureBlock
@onready var _figure: Label = %Figure

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the step once the row is in the tree: `text` beside a tick box,
## ticked when `ticked`, and `figure`, its progress, at the right ("" leaves
## the figure out and gives the text its room).
func setup(text: String, ticked: bool, figure: String) -> void:
	_tick.texture = TICKED_TEXTURE if ticked else TICK_BOX_TEXTURE
	_text.text = text
	_figure.text = figure
	_figure_block.visible = not figure.is_empty()
