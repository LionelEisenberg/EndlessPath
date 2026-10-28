class_name BoardTransitionSpec
extends RefCounted

## BoardTransitionSpec
## What a board in the zone view's map gap tells BoardTransition about itself:
## its view, where its board stands on the screen, whether it swaps the zone
## chest's rows (cycling turns the activities to the techniques) and whether it
## moves the HUD boards (the Tribulation steps the Goals board and the log off
## the left edge). A new board gets the open and close by filling one in.

#-----------------------------------------------------------------------------
# FIELDS
#-----------------------------------------------------------------------------

## The board's view, which the transition shows and scales about the point the
## camera brings the cultivator to.
var view: Control
## The board's rectangle on the screen at full size. The camera brings the
## cultivator to its horizontal centre, a little under its vertical centre.
var board_rect: Rect2
## True when the board swaps the zone chest from the activities to the
## techniques (cycling).
var swaps_chest: bool = false
## True when the board steps the Goals board and the log off the left edge of
## the screen (the Tribulation).
var moves_hud_boards: bool = false
## The state that holds the board. MainView's instant open and close, used
## when it has no transition, hides the HUD boards on its behalf.
var holder: MainViewState = null
