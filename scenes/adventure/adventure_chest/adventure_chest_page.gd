class_name AdventureChestPage
extends Control

## A page of the adventure chest: the part under its header that changes with
## what the player is doing (the expedition on the map, the opponent in a
## fight). A page stands in the chest's page slot, 408 wide from the slot's
## top-left corner, and the chest hugs the visible one.
## The chest asks get_content_height() how tall the page's content is. A page
## whose content changes height overrides it and emits content_resized, so the
## chest follows. This base is only that signal and a default height.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when get_content_height() changed, so the chest lays itself out
## again.
signal content_resized

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns how tall the page's content is, in px; the chest hugs this height.
## The default is the page's own height. A page of flowing content overrides
## it and emits content_resized when the answer changes.
func get_content_height() -> float:
	return size.y
