extends GutTest

## DropTargetSlot routes its drop highlight through _set_drop_hover(). Its
## default tints the slot as before, so the Abilities loadout keeps its look;
## a slot that overrides it shows the highlight its own way.

class AcceptingSlot extends DropTargetSlot:
	func _accepts(_data: Variant) -> bool:
		return true

## Accepts a payload with an "ok" key, and records each highlight change
## instead of tinting.
class RecordingSlot extends DropTargetSlot:
	var highlights: Array[bool] = []

	func _accepts(data: Variant) -> bool:
		return data is Dictionary and data.has("ok")

	func _set_drop_hover(hovered: bool) -> void:
		highlights.append(hovered)

func test_default_drop_hover_still_tints() -> void:
	var slot := AcceptingSlot.new()
	add_child_autofree(slot)
	slot._can_drop_data(Vector2.ZERO, {})
	assert_eq(slot.modulate, DropTargetSlot.HOVER_TINT)
	slot._clear_drop_hover()
	assert_eq(slot.modulate, Color.WHITE)

func test_every_highlight_change_goes_through_set_drop_hover() -> void:
	var slot := RecordingSlot.new()
	add_child_autofree(slot)
	slot._can_drop_data(Vector2.ZERO, {"ok": true})
	slot._can_drop_data(Vector2.ZERO, {})
	slot._clear_drop_hover()
	slot._notification(NOTIFICATION_DRAG_END)
	assert_eq(slot.highlights, [true, false, false, false] as Array[bool], "accepted, refused, cleared, drag ended")
	assert_eq(slot.modulate, Color.WHITE, "an override replaces the tint")
