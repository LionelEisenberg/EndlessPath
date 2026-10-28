class_name JournalRow
extends VBoxContainer

## JournalRow
## One row of the Journal's list, pressed into the page like a Consumables row:
## the quest item in a deep slot, its name, and under it the name of the quest
## it belongs to, or where it came from when it belongs to none. At the right, a
## DONE seal once that quest is finished, or the step the player is on
## ("Step 2 of 3") while it is under way. A pressed rule runs under the row, 4 px
## under the slot. The name and the line under it wrap, and the row grows with
## them by an even number of px: the line under the name is padded 1 px
## underneath (wrap_pad.tres), so its first line takes 18 px and each more 20,
## and the rows under a grown one keep their slots on even pixels. A row whose
## rule is hidden, the last, takes no room for it.
##
## The seal sits 22 px down the row and the step's baseline 46 px down, both
## ending 4 px short of the row's right edge, as the mockup prints them.
##
## Printer's marks sit round the row while the details show it, as the mockup
## draws them: 8 px out at the top and left and 6 px past the right end. At the
## bottom they take in the rule, ending 10 px under the slot, or 6 px under it
## when the rule is hidden. They frame the slot area with %RuleGap, the 4 px
## over the rule, which hides with the rule.
##
## The row emits hovered when the pointer enters it, and clicked on a left press.

## Emitted on a left press on the row.
signal clicked(row: JournalRow)
## Emitted when the pointer enters the row.
signal hovered(row: JournalRow)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _second_line: Label = %SecondLine
@onready var _seal_box: Control = %SealBox
@onready var _step_box: Control = %StepBox
@onready var _step_label: Label = %StepLabel
@onready var _marks: Panel = %Marks
@onready var _rule_gap: Control = %RuleGap
@onready var _rule: HSeparator = %Rule

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _item: ItemDefinitionData = null
var _second_line_text: String = ""
var _done: bool = false
var _step_text: String = ""

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows a quest item with `second_line` under its name (its quest's name, or
## where it came from). At the right, the DONE seal when `done`, else
## `step_text` ("Step 2 of 3"), or nothing when that is "".
func setup(item: ItemDefinitionData, second_line: String, done: bool, step_text: String) -> void:
	_item = item
	_second_line_text = second_line
	_done = done
	_step_text = step_text
	if is_node_ready():
		_refresh()

## Returns the quest item the row shows.
func get_item() -> ItemDefinitionData:
	return _item

## Shows or hides the printer's marks round the row.
func set_marked(marked: bool) -> void:
	_marks.visible = marked

## True while the printer's marks sit round the row.
func is_marked() -> bool:
	return _marks.visible

## Shows or hides the pressed rule under the row. Hidden, the rule and the gap
## over it take no room, so the row and its marks end at its slot.
func set_rule_visible(rule_visible: bool) -> void:
	_rule_gap.visible = rule_visible
	_rule.visible = rule_visible

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_mouse_entered() -> void:
	hovered.emit(self)

## Prints the row. The seal and the step are each in a box that sets them in
## place, so the box shows or hides with them and a hidden one takes no room.
func _refresh() -> void:
	_icon.texture = _item.icon if _item != null else null
	_name.text = _item.item_name if _item != null else ""
	_second_line.text = _second_line_text
	_second_line.visible = not _second_line_text.is_empty()
	_seal_box.visible = _done
	_step_label.text = _step_text
	_step_box.visible = not _done and not _step_text.is_empty()
