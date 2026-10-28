class_name DevActionRow
extends HBoxContainer

## One action in the Story tab's list: its name and id (three actions of Spirit Valley
## share a name), its status, and Complete, which is on only while the action is
## available. The row only says which action's Complete was pressed; the tab runs the
## command and says why it refused.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when Complete is pressed, with the id of the row's action.
signal complete_pressed(action_id: String)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _complete_button: Button = %CompleteButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The action the row shows, null until set_action().
var _action: ZoneActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_complete_button.pressed.connect(_on_complete_pressed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the action: its name and id, the status text, and Complete, which is on only
## when the action is available. The row must be in the tree.
func set_action(action: ZoneActionData, status: String, available: bool) -> void:
	_action = action
	_name_label.text = "%s (%s)" % [action.action_name, action.action_id]
	_status_label.text = status
	_complete_button.disabled = not available

## The action the row shows, or null before set_action().
func get_action() -> ZoneActionData:
	return _action

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_complete_pressed() -> void:
	if _action != null:
		complete_pressed.emit(_action.action_id)
