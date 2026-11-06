class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE cards: what foraging finds, each loot entry's 16 px
## icon and item name ([dewdrop] Dewdrop Tear  [fern] Spirit Fern), and, only
## when foraging costs Madra, "costs <n> Madra / s" in the right column. One
## ForageYield scene is instanced per loot entry, with the item's mini icon
## (ItemDefinitionData.get_mini_icon), into lines (ForageYieldLine) that step
## 18 px: a find that would pass the line's room moves to the next line whole,
## and a find too wide for a line of its own wraps its name. Nothing is cut off.
## The ranges, the haul timer and the haul text live in the Now strip and on
## the map, not on the card (the user's review, 2026-10-24).

const FORAGE_YIELD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield.tscn")
const FORAGE_YIELD_LINE_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield_line.tscn")

@onready var _yield_lines: VBoxContainer = %YieldLines

## Moves the finds into the card and fills them.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_yield_lines.reparent(button.get_detail_slot(), false)
	_fill()

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The cost first, so the finds know the room it leaves; then one yield per loot
## entry, each on the current line while it fits, else on a new one.
func _fill() -> void:
	var forage := action_data as ForageActionData
	if forage == null:
		return
	if forage.madra_cost_per_second > 0.0:
		button.set_detail_right("costs %s Madra / s" % _number(forage.madra_cost_per_second))
	if forage.loot_table == null:
		button.relayout()
		return
	var room: float = button.get_detail_room()
	var line: HBoxContainer = null
	var line_width: float = 0.0
	for entry: LootTableEntry in forage.loot_table.entries:
		if entry == null or entry.item == null:
			continue
		var yield_row: HBoxContainer = FORAGE_YIELD_SCENE.instantiate() as HBoxContainer
		var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
		icon_rect.texture = entry.item.get_mini_icon()
		var icon_box: Control = yield_row.get_node("%IconBox") as Control
		icon_box.visible = icon_rect.texture != null
		var yield_text: RichTextLabel = yield_row.get_node("%YieldText") as RichTextLabel
		yield_text.text = LacquerText.decimal_bbcode(entry.item.item_name)
		if line == null:
			line = _add_line()
		line.add_child(yield_row)
		var icon_width: float = icon_box.custom_minimum_size.x + yield_row.get_theme_constant(&"separation") if icon_box.visible else 0.0
		var yield_width: float = icon_width + yield_text.get_content_width()
		var gap: float = line.get_theme_constant(&"separation")
		if line_width > 0.0 and line_width + gap + yield_width > room:
			line.remove_child(yield_row)
			line = _add_line()
			line.add_child(yield_row)
			line_width = 0.0
		if yield_width > room:
			_wrap_name(yield_text, room - icon_width)
			yield_width = room
		line_width += (gap if line_width > 0.0 else 0.0) + yield_width
	button.relayout()

func _add_line() -> HBoxContainer:
	var line: HBoxContainer = FORAGE_YIELD_LINE_SCENE.instantiate() as HBoxContainer
	_yield_lines.add_child(line)
	return line

## A name too wide for a line of its own wraps by word at width.
func _wrap_name(yield_text: RichTextLabel, width: float) -> void:
	yield_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yield_text.custom_minimum_size.x = width
	yield_text.size = Vector2(width, yield_text.size.y)
	# The boxes above it measured its one long line: let them measure its lines.
	yield_text.update_minimum_size()

## A number with no sign and no trailing zeros: 5.0 → "5", 2.5 → "2.5".
func _number(value: float) -> String:
	return LacquerText.rate(value).trim_prefix("+")
