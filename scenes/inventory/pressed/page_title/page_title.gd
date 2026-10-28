@tool
class_name PageTitle
extends VBoxContainer

## PageTitle
## The title at the head of a pressed page: the text in Yatra One, centred, with
## the pressed ornament under it. Set `title` per instance. It is a root export,
## so it survives editor saves and applies at runtime. A long title wraps inside
## the width the page gives it; the PageTitle never widens its page.
##
## The ornament's line sits 16 px under the title's baseline. Yatra One at the
## title's 38 px is 38 px above its baseline and 19 px below it (a 57 px line),
## and the line is row 6 of title_ornament_ai.png, so the VBox separation is
## 16 - 6 - 19 = -9. Change the title's font size and the separation changes
## with it.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The text printed as the page's title.
@export var title: String = "":
	set(value):
		title = value
		_apply()

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Pushes the exported title onto the label once the node is ready.
func _apply() -> void:
	if not is_node_ready():
		return
	_title_label.text = title
