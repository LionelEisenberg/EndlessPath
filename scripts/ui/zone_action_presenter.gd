@abstract class_name ZoneActionPresenter
extends Node
## Base class for ZoneActionButton presenters. A presenter owns the type-specific
## visual content and behavior for one ZoneActionData subtype, while the button
## owns the shell (card styling, click routing, hover feedback, slot layout).
##
## A presenter is a utility Node — its scene root has no layout. The presenter's
## visible children get reparented into the button's slots on setup().

var action_data: ZoneActionData
var button: Control

#-----------------------------------------------------------------------------
# ABSTRACT
#-----------------------------------------------------------------------------

## Called when the button's action_data is assigned. The presenter should:
##   1. Store references (action_data, button, slots it cares about)
##   2. Reparent its own child content into the appropriate slots
##   3. Connect to any game-state signals it needs
@abstract
func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, inline_slot: Control, footer_slot: Control) -> void

## Called from the button's _exit_tree. The presenter should disconnect signals
## and kill any running tweens.
@abstract
func teardown() -> void

#-----------------------------------------------------------------------------
# LIFECYCLE HOOKS (safe defaults, subclasses override as needed)
#-----------------------------------------------------------------------------

## Called when the button's is_current_action flips. Default: no-op.
func set_is_current(_is_current: bool) -> void:
	pass

## Gate for click activation. Return false to veto activation (e.g. adventure
## with insufficient Madra). Default: always allow.
func can_activate() -> bool:
	return true

## Called when can_activate() returned false. Default: no-op.
func on_activation_rejected() -> void:
	pass
