@abstract class_name ZoneActionPresenter
extends Node
## Base class for ZoneActionButton presenters. A presenter owns the type-specific
## content of one activity card: its detail line, any extra pieces (the
## adventure's Madra rod), and the mode tag when it differs from the type's
## (ENTER). The button owns the drawer: icon, title, NEW seal, tag, running
## state, hover, flash and click routing.
##
## A presenter is a utility Node: its scene root has no layout. On setup() it
## reparents its own children into the button's detail slot (get_detail_slot(),
## a VBoxContainer of rows at the detail line, x+64, 4 px under the title's last
## line), each row as wide as the button's get_detail_room(). Nothing on a card
## is cut off: text wraps at that width (fit_detail_label, set_detail_rich_text)
## and the card grows by the rows' lines. A presenter that changes what its rows
## show afterwards calls the button's relayout().

var action_data: ZoneActionData
var button: ZoneActionButton

#-----------------------------------------------------------------------------
# ABSTRACT
#-----------------------------------------------------------------------------

## Called when the button's action_data is assigned. The presenter should:
##   1. Store references (action_data, button)
##   2. Reparent its own child content into the button's slots
##   3. Connect to any game-state signals it needs
@abstract
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void

## Called from the button's _exit_tree and before a new presenter replaces this
## one. The presenter should disconnect signals and kill any running tweens.
@abstract
func teardown() -> void

#-----------------------------------------------------------------------------
# LIFECYCLE HOOKS (safe defaults, subclasses override as needed)
#-----------------------------------------------------------------------------

## Called when the card's idle action starts or stops running. Default: no-op.
func set_is_current(_is_current: bool) -> void:
	pass

## Gate for click activation. Return false to veto activation (e.g. adventure
## with insufficient Madra). Default: always allow.
func can_activate() -> bool:
	return true

## Called when can_activate() returned false. Default: no-op.
func on_activation_rejected() -> void:
	pass
