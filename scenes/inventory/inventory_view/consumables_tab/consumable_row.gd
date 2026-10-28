class_name ConsumableRow
extends VBoxContainer

## ConsumableRow
## One row of the Consumables list, pressed into the page: the item in a deep
## slot, its name with what it does under it, how many the player has at the
## right, and a pressed rule under the row (4 px under the slot). The name and
## what it does wrap, and the row grows with them. A row whose rule is hidden,
## the last, takes no room for it.
##
## Printer's marks sit round the row while the details show it, as the mockup
## draws them: 8 px out at the top and left and 6 px past the right end. At
## the bottom they take in the rule, ending 10 px under the slot, or 6 px under
## it when the rule is hidden. They frame the slot area with %RuleGap, the 4 px
## over the rule, which hides with the rule.
##
## Drag a row onto a combat hotbar slot to equip it. The row emits hovered
## when the pointer enters it, and clicked on a left release that does not end
## a drag.

signal clicked(row: ConsumableRow, event: InputEvent)
## Emitted when the pointer enters the row.
signal hovered(row: ConsumableRow)

const _DRAG_PREVIEW_SCENE: PackedScene = preload("res://scenes/inventory/pressed/item_drag_preview/item_drag_preview.tscn")

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _effect: RichTextLabel = %Effect
@onready var _count: Label = %Count
@onready var _marks: Panel = %Marks
@onready var _rule_gap: Control = %RuleGap
@onready var _rule: HSeparator = %Rule

var _def: ConsumableDefinitionData = null
var _qty: int = 0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
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

## Shows or hides the printer's marks round the row.
func set_marked(marked: bool) -> void:
	_marks.visible = marked

## True while the printer's marks sit round the row.
func is_marked() -> bool:
	return _marks.visible

## Shows or hides the pressed rule under the row. Hidden, the rule and the gap
## over it take no room, so the row and its marks end at its slot.
func set_rule_visible(rule_visible: bool) -> void:
	_rule_gap.visible = rule_visible
	_rule.visible = rule_visible

#-----------------------------------------------------------------------------
# DRAG AND DROP
#-----------------------------------------------------------------------------

## Drag the consumable onto a combat hotbar slot to equip it (native Godot
## drag-and-drop, mirroring the abilities loadout). The row stays as it is
## while its icon follows the cursor. Empty rows aren't draggable.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if _def == null:
		return null
	var preview: ItemDragPreview = _DRAG_PREVIEW_SCENE.instantiate() as ItemDragPreview
	preview.set_icon(_def.icon)
	set_drag_preview(preview)
	return {"consumable": _def}

## Left-click on release (when not finishing a drag) emits clicked. Click on
## release keeps the press free for drag detection.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_is_dragging():
			return
		clicked.emit(self, event)

func _on_mouse_entered() -> void:
	hovered.emit(self)

func _refresh() -> void:
	if _def == null:
		_icon.texture = null
		_name.text = ""
		_effect.text = ""
		_count.text = ""
		return
	_icon.texture = _def.icon
	_name.text = _def.item_name
	_effect.text = BookText.effect_line(_def)
	_count.text = BookText.count(_qty)
