class_name DropTargetSlot
extends PanelContainer

## DropTargetSlot
## Base for slots that accept a payload via Godot's native drag-and-drop
## (the combat hotbar, the ability loadout). Centralizes the drop highlight and
## drop routing so each slot type only declares what it accepts and what to do
## on drop. Subclasses override _accepts() and _on_dropped(), and may override
## _set_drop_hover() to show the highlight their own way.

## Tint applied while an acceptable payload hovers over the slot.
const HOVER_TINT: Color = Color(1.2, 1.15, 1.0)

func _ready() -> void:
	# Clear the highlight when the cursor leaves the slot mid-drag; otherwise
	# every slot the drag passed over stays lit until the drag ends, since
	# _can_drop_data only fires for the slot currently under the cursor.
	mouse_exited.connect(_clear_drop_hover)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepts: bool = _accepts(data)
	_set_drop_hover(accepts)
	return accepts

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_clear_drop_hover()
	if _accepts(data):
		_on_dropped(data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_drop_hover()

func _clear_drop_hover() -> void:
	_set_drop_hover(false)

#-----------------------------------------------------------------------------
# OVERRIDES
#-----------------------------------------------------------------------------

## Whether this slot accepts the dragged payload. Override in subclasses.
func _accepts(_data: Variant) -> bool:
	return false

## Handle a payload dropped onto this slot. Override in subclasses.
func _on_dropped(_data: Variant) -> void:
	pass

## Shows the highlight while an acceptable payload hovers the slot, or clears
## it. The default tints the slot with HOVER_TINT. Override to highlight it
## another way.
func _set_drop_hover(hovered: bool) -> void:
	modulate = HOVER_TINT if hovered else Color.WHITE
