class_name CyclingPresenter
extends ZoneActionPresenter
## Presenter for CYCLING cards: what cycling gives, "Madra and Core Density
## XP". The equipped technique is the cycling board's and the technique
## drawers' to name, not the card's (the user's review, 2026-10-24).

const REWARD_TEXT: String = "Madra and Core Density XP"

@onready var _detail_label: Label = %DetailLabel

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_label.reparent(button.get_detail_slot(), false)
	_detail_label.text = REWARD_TEXT
	button.fit_detail_label(_detail_label)

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass
