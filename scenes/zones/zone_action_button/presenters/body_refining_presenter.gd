class_name BodyRefiningPresenter
extends ZoneActionPresenter
## Presenter for BODY_REFINING cards: two icons in the card's icon column and no
## words, the Health heart, the pool body refining refills, then the Physical
## side's icon (StatDisplay.side_icon()), the side every drill trains. The card
## reads the same whatever drills the player knows (the user's playtest note on
## #145). The drill, what a rep pays and the set's progress are the board's and
## the Now strip's to show, not the card's (the user's review, 2026-10-24).

@onready var _icons: HBoxContainer = %Icons
@onready var _side_icon: TextureRect = %SideIcon

## Moves the icons into the card's icon column and shows the side's icon.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_icons.reparent(button.get_icon_column(), false)
	_side_icon.texture = StatDisplay.side_icon(StatDisplay.StatSide.PHYSICAL)
	button.relayout()

## Nothing to undo: the icons never change.
func teardown() -> void:
	pass
