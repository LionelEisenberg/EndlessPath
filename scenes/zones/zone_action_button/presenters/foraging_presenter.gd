class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE cards: each loot entry's 16 px icon and "min–max",
## then "every <interval> s · free" ("· <n> Madra / s" when foraging costs
## Madra), e.g. [dewdrop] 1–5  [fern] 2–6 · every 5 s · free (lacquer kit §5.5).
## One ForageYield scene is instanced per loot entry, with the item's mini
## icon (ItemDefinitionData.get_mini_icon). A line wider than 316 px ends in
## an ellipsis. The haul timer and the haul text live in the Now strip and on
## the map, not on the card.

const FORAGE_YIELD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield.tscn")

const SEPARATOR: String = " · "

@onready var _yield_row: HBoxContainer = %YieldRow
@onready var _tail_text: RichTextLabel = %TailText

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

## One yield per loot entry; the tail ("every 5 s · free") follows the last
## range, or stands alone when the table is empty. Each text gets what is
## left of the 316 px line after the pieces before it, so the end of a long
## line, not its start, gives way to the ellipsis.
func _fill() -> void:
	var forage := action_data as ForageActionData
	if forage == null:
		return
	var yields: Array[HBoxContainer] = []
	var ranges: Array[String] = []
	if forage.loot_table != null:
		for entry: LootTableEntry in forage.loot_table.entries:
			if entry == null or entry.item == null:
				continue
			var yield_row: HBoxContainer = FORAGE_YIELD_SCENE.instantiate() as HBoxContainer
			_yield_row.add_child(yield_row)
			_yield_row.move_child(yield_row, _tail_text.get_index())
			var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
			icon_rect.texture = entry.item.get_mini_icon()
			icon_rect.visible = icon_rect.texture != null
			yields.append(yield_row)
			ranges.append(_range_text(entry))

	var tail: String = _tail_line(forage)
	_tail_text.visible = ranges.is_empty()
	if ranges.is_empty():
		button.fit_detail_rich_text(_tail_text, tail)
		return
	ranges[-1] += SEPARATOR + tail
	var x: float = 0.0
	for i: int in yields.size():
		x += _icon_width(yields[i])
		var range_text: RichTextLabel = yields[i].get_node("%RangeText") as RichTextLabel
		x += button.fit_detail_rich_text(range_text, ranges[i], ZoneActionButton.DETAIL_WIDTH - x)
		x += _yield_row.get_theme_constant(&"separation")

## The icon and the gap after it, when the yield shows an icon.
func _icon_width(yield_row: HBoxContainer) -> float:
	var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
	if not icon_rect.visible:
		return 0.0
	return icon_rect.get_combined_minimum_size().x + yield_row.get_theme_constant(&"separation")

func _tail_line(forage: ForageActionData) -> String:
	var cost: String = "free"
	if forage.madra_cost_per_second > 0.0:
		cost = "%s Madra / s" % _number(forage.madra_cost_per_second)
	return "every %s s%s%s" % [_number(forage.foraging_interval_in_sec), SEPARATOR, cost]

func _range_text(entry: LootTableEntry) -> String:
	if entry.min_quantity == entry.max_quantity:
		return str(entry.min_quantity)
	return "%d–%d" % [entry.min_quantity, entry.max_quantity]

## A number with no sign and no trailing zeros: 5.0 → "5", 2.5 → "2.5".
func _number(value: float) -> String:
	return LacquerText.rate(value).trim_prefix("+")
