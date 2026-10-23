class_name BuffTooltip
extends PanelContainer

## BuffTooltip
## The lacquer tooltip a hovered buff socket opens (the vitals cabinet's; the
## opponent page's in PR 2): the plain board (board9.tres, 304 wide, as tall as
## its text) holding the buff's name, the time it has left, a divider and what
## the buff does. It is top-level and never takes the pointer, so
## show_for_buff() places it by screen position. The time counts down while
## the tooltip is shown, in whole seconds rounded up (a buff with 0.4 s left
## reads "1 s left"), and a stacked buff adds " · ×<stacks>".
## The tooltip cannot see a buff end (a stripped or cleared buff keeps its
## time), so its owner calls hide_tooltip() when the pointer leaves the socket
## or the buff is removed.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %NameLabel
@onready var _time_label: Label = %TimeLabel
@onready var _description_label: Label = %DescriptionLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _buff: ActiveBuff = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	set_process(false)

## Only runs while a buff is shown: keeps its time left current.
func _process(_delta: float) -> void:
	_update_time()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the tooltip for buff, its top-left corner at top_left (screen px).
## The board takes the height of the new text.
func show_for_buff(buff: ActiveBuff, top_left: Vector2) -> void:
	_buff = buff
	_name_label.text = buff.buff_data.buff_id.capitalize()
	_description_label.text = buff.buff_data.describe()
	_update_time()
	reset_size()
	global_position = top_left
	show()
	set_process(true)

## Hides the tooltip and lets go of its buff.
func hide_tooltip() -> void:
	_buff = null
	hide()
	set_process(false)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## "<n> s left" in whole seconds rounded up, then " · ×<stacks>" when stacked.
func _update_time() -> void:
	if _buff == null:
		return
	var text: String = "%d s left" % ceili(_buff.time_remaining)
	if _buff.stack_count > 1:
		text += " · ×%d" % _buff.stack_count
	_time_label.text = text
