class_name ConsumableRow
extends Control

## ConsumableRow
## One full-width row in the Consumables list: icon + name + stack count.
## Emits `clicked` (with the triggering event) so the tab can show the detail
## panel (left-click) or equip the consumable to the hotbar (right-click).

signal clicked(row: ConsumableRow, event: InputEvent)

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _count: Label = %Count

var _def: ConsumableDefinitionData = null
var _qty: int = 0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_refresh()

## Populate the row with a consumable definition + stack count.
func setup(def: ConsumableDefinitionData, qty: int) -> void:
	_def = def
	_qty = qty
	if is_inside_tree():
		_refresh()

## Returns the consumable definition currently shown.
func get_definition() -> ConsumableDefinitionData:
	return _def

## Returns the quantity currently shown.
func get_quantity() -> int:
	return _qty

#-----------------------------------------------------------------------------
# DRAG AND DROP
#-----------------------------------------------------------------------------

## Drag the consumable onto a combat hotbar slot to equip it (native Godot
## drag-and-drop, mirroring the abilities loadout). Empty rows aren't draggable.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if _def == null:
		return null
	var preview: TextureRect = TextureRect.new()
	preview.texture = _def.icon
	preview.custom_minimum_size = Vector2(36, 36)
	preview.size = Vector2(36, 36)
	preview.position = Vector2(-18, -18)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var holder: Control = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	# Grey out the source row while it is being dragged (the icon preview above
	# follows the cursor for the "picked up" feedback).
	modulate = Color(0.5, 0.5, 0.5, 0.5)
	return {"consumable": _def}

## Restore the row's appearance when the drag ends (dropped or cancelled).
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE

## Left-click on release (when not finishing a drag) selects the row for the
## detail panel. Click on release keeps the press free for drag detection.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_is_dragging():
			return
		clicked.emit(self, event)

func _refresh() -> void:
	if _def == null:
		_icon.texture = null
		_name.text = ""
		_count.text = ""
		return
	_icon.texture = _def.icon
	_name.text = _def.item_name
	_count.text = "x%d" % _qty if _qty > 1 else ""
