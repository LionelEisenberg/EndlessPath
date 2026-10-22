class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE cards: each loot entry's 16 px icon and "min–max",
## then "every <interval> s · free" ("· <n> Madra / s" when foraging costs
## Madra), e.g. [dewdrop] 1–5  [fern] 2–6 · every 5 s · free (lacquer kit §5.5).
## One ForageYield scene is instanced per loot entry. The haul timer and the
## haul text live in the Now strip and on the map, not on the card.

const FORAGE_YIELD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield.tscn")

## The kit's 16 px mini icons for the materials it drew them for. They win over
## the item's own icon: both Spirit Valley materials still point at the shared
## placeholder icon.
const MINI_ICONS: Dictionary = {
	"DewdropTear": preload("res://assets/ui/lacquer/lacquer_mini_dewdrop_ai.png"),
	"SpiritFern": preload("res://assets/ui/lacquer/lacquer_mini_fern_ai.png"),
}

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
## range, or stands alone when the table is empty.
func _fill() -> void:
	var forage := action_data as ForageActionData
	if forage == null:
		return
	var range_labels: Array[RichTextLabel] = []
	var ranges: Array[String] = []
	if forage.loot_table != null:
		for entry: LootTableEntry in forage.loot_table.entries:
			if entry == null or entry.item == null:
				continue
			var yield_row: HBoxContainer = FORAGE_YIELD_SCENE.instantiate() as HBoxContainer
			_yield_row.add_child(yield_row)
			_yield_row.move_child(yield_row, _tail_text.get_index())
			var icon_rect: TextureRect = yield_row.get_node("%Icon") as TextureRect
			icon_rect.texture = _icon_for(entry.item)
			icon_rect.visible = icon_rect.texture != null
			range_labels.append(yield_row.get_node("%RangeText") as RichTextLabel)
			ranges.append(_range_text(entry))

	var tail: String = _tail_line(forage)
	_tail_text.visible = ranges.is_empty()
	if ranges.is_empty():
		_tail_text.text = LacquerText.decimal_bbcode(tail)
		return
	ranges[-1] += SEPARATOR + tail
	for i: int in range_labels.size():
		range_labels[i].text = LacquerText.decimal_bbcode(ranges[i])

func _tail_line(forage: ForageActionData) -> String:
	var cost: String = "free"
	if forage.madra_cost_per_second > 0.0:
		cost = "%s Madra / s" % _number(forage.madra_cost_per_second)
	return "every %s s%s%s" % [_number(forage.foraging_interval_in_sec), SEPARATOR, cost]

func _range_text(entry: LootTableEntry) -> String:
	if entry.min_quantity == entry.max_quantity:
		return str(entry.min_quantity)
	return "%d–%d" % [entry.min_quantity, entry.max_quantity]

func _icon_for(item: ItemDefinitionData) -> Texture2D:
	if MINI_ICONS.has(item.item_id):
		return MINI_ICONS[item.item_id] as Texture2D
	return item.icon

## A number with no sign and no trailing zeros: 5.0 → "5", 2.5 → "2.5".
func _number(value: float) -> String:
	return LacquerText.rate(value).trim_prefix("+")
