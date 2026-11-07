class_name CyclingPresenter
extends ZoneActionPresenter
## Presenter for CYCLING cards: two icons in the card's icon column and no words,
## the Madra drop, the pool cycling refills, then the Spiritual side's icon
## (StatDisplay.side_icon()), the side cycling trains. The card reads the same
## whatever techniques the player knows: the technique drawers name what each
## technique trains (the user's playtest note on #145). The equipped technique is
## the cycling board's and the technique drawers' to name, not the card's (the
## user's review, 2026-10-24).

@onready var _icons: HBoxContainer = %Icons
@onready var _side_icon: TextureRect = %SideIcon

## Moves the icons into the card's icon column and shows the side's icon.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_icons.reparent(button.get_icon_column(), false)
	_side_icon.texture = StatDisplay.side_icon(StatDisplay.StatSide.SPIRITUAL)
	button.relayout()

## Nothing to undo: the icons never change.
func teardown() -> void:
	pass
