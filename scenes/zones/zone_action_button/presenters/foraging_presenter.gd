class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE cards: what foraging finds, each loot entry's 16 px
## icon and item name ([dewdrop] Dewdrop Tear  [fern] Spirit Fern), and, only
## when foraging costs Madra, "costs <n> Madra / s" in the right column. One
## ForageYield scene is instanced per loot entry, with the item's mini icon
## (ItemDefinitionData.get_mini_icon). A line wider than its room ends in an
## ellipsis. The ranges, the haul timer and the haul text live in the Now strip
## and on the map, not on the card (the user's review, 2026-10-24).

const FORAGE_YIELD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield.tscn")

@onready var _yield_row: HBoxContainer = %YieldRow

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_yield_row.reparent(button.get_detail_slot(), false)
	_fill()

## Nothing to undo: the detail line never changes.
func teardown() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## One yield per loot entry. Each name gets what is left of the line's room
## after the pieces before it, so the end of a long line, not its start, gives
## way to the ellipsis. A cut name ends the line: its ellipsis stands for the
## finds after it, and a yield left no room for its name does not show.
func _fill() -> void:
	var forage := action_data as ForageActionData
	if forage == null:
		return
	if forage.madra_cost_per_second > 0.0:
		button.set_detail_right("costs %s Madra / s" % _number(forage.madra_cost_per_second))
	if forage.loot_table == null:
		return
	var x: float = 0.0
	for entry: LootTableEntry in forage.loot_table.entries:
		if entry == null or entry.item == null:
			continue
		var yield_row: HBoxContainer = FORAGE_YIELD_SCENE.instantiate() as HBoxContainer
		_yield_row.add_child(yield_row)
		var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
		icon_rect.texture = entry.item.get_mini_icon()
		icon_rect.visible = icon_rect.texture != null
		x += _icon_width(yield_row)
		var yield_text: RichTextLabel = yield_row.get_node("%YieldText") as RichTextLabel
		x += button.fit_detail_rich_text(yield_text, entry.item.item_name, maxf(button.get_detail_room() - x, 0.0))
		x += _yield_row.get_theme_constant(&"separation")
		yield_row.visible = yield_text.text != ""
		if yield_text.text != LacquerText.decimal_bbcode(entry.item.item_name):
			break

## The icon and the gap after it, when the yield shows an icon.
func _icon_width(yield_row: HBoxContainer) -> float:
	var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
	if not icon_rect.visible:
		return 0.0
	return icon_rect.get_combined_minimum_size().x + yield_row.get_theme_constant(&"separation")

## A number with no sign and no trailing zeros: 5.0 → "5", 2.5 → "2.5".
func _number(value: float) -> String:
	return LacquerText.rate(value).trim_prefix("+")
