class_name DefaultZoneActionPresenter
extends ZoneActionPresenter
## Presenter for story cards (NPC_DIALOGUE, ZONE_EVENT) and any type without a
## presenter of its own: the detail line is the action's description, and the
## tag is the type's (STORY). A long description wraps in the tall drawer.

@onready var _detail_label: Label = %DetailLabel

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_label.reparent(button.get_detail_slot(), false)
	_detail_label.text = action_data.description
	button.fit_detail_label(_detail_label)

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass
