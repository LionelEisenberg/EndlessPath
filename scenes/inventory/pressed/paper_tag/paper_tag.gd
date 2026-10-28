class_name PaperTag
extends Label

## PaperTag
## A count on a paper tag stuck on a slot ("×7", LabelBookTag): the paper hugs
## its text with 5 px either side. The tag keeps an even width, the text's
## width rounded up, so a tag anchored to a slot's right edge starts on an even
## x and its art stays on the 2 px grid, as the mockup draws it. The text sits
## at the tag's right, so the odd pixel goes to its left, as in the mockup.
##
## The width comes from the text, so the script sets the tag's minimum width:
## the even-pixel exception FilterWords also takes.

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Prints `amount` on the tag ("×7") and keeps the tag's width even.
func set_count(amount: int) -> void:
	text = BookText.count(amount)
	_fit_to_grid()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _notification(what: int) -> void:
	# A new theme can change the font, and with it the text's width.
	if what == NOTIFICATION_THEME_CHANGED:
		_fit_to_grid()

## Rounds the tag's width up to an even number of pixels.
func _fit_to_grid() -> void:
	custom_minimum_size.x = ceilf(get_minimum_size().x / 2.0) * 2.0
