class_name DefaultZoneActionPresenter
extends ZoneActionPresenter
## Presenter for action types that need no extra UI beyond the card's name+description.
## Used for CYCLING and NPC_DIALOGUE.

func setup(data: ZoneActionData, owner_button: Control, _overlay_slot: Control, _inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button

func teardown() -> void:
	pass
