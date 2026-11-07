class_name LastCycleCard
extends Control

## LastCycleCard
## The zone chest's card for the last finished cycle, under the Now tray while
## the player cycles: the Now tray's frame with a brass "Last cycle" tag, a chip
## for each thing the cycle paid (the Madra's mini icon or the stat's icon at
## 32 px, then "+80", or "capped" in brass for a stat the cap took XP from), and
## on the right the cycle's score: a stud for each zone (PERFECT, GOOD, OK or
## missed) or each seal node (opened or missed), the board's sockets at half
## size. A technique with neither shows how much of the cycle was followed in
## the score's place ("Followed 93%", or "Followed all"). A row too crowded for
## one line wraps its chips onto another rather than trim them, and the card
## grows with it: ONE_LINE_HEIGHT tall with one line, as much taller as the row
## grows. It emits height_changed when its height changes, for the chest to lay
## out again.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the card's height changes: its chips wrapped onto another line,
## or came back to one.
signal height_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The card's height while its row is one line: the row stands ROW_TOP px down,
## its chips are CHIP_HEIGHT px tall, and ROOM_UNDER_ROW px of tray are left
## under them.
const ONE_LINE_HEIGHT: float = 64.0
const ROW_TOP: float = 20.0
const CHIP_HEIGHT: float = 32.0
const ROOM_UNDER_ROW: float = 12.0

## A chip's figure: the amount, rounded to a whole number, or CAPPED_TEXT.
const AMOUNT_FORMAT: String = "+%d"
const CAPPED_TEXT: String = "capped"

## A followed share, floored to a whole percent so it never reads 100% short of
## all of the cycle, and the whole cycle followed.
const FOLLOWED_FORMAT: String = "Followed %d%%"
const FOLLOWED_ALL_TEXT: String = "Followed all"

## The studs strip's frames: a zone's PERFECT, GOOD and OK studs, a zone the
## ball left unscored, an opened seal node and one the ball got to first.
const STUD_PERFECT: int = 0
const STUD_GOOD: int = 1
const STUD_OK: int = 2
const STUD_MISSED_ZONE: int = 3
const STUD_OPEN_SEAL: int = 4
const STUD_MISSED_SEAL: int = 5

const _MADRA_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_madra_ai.png")
const _STUD_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/last_cycle_card/last_cycle_stud.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _row: HBoxContainer = %Row
@onready var _madra_chip: Control = %MadraChip
@onready var _stat_chips: Dictionary = {
	CharacterAttributesData.AttributeType.SPIRIT: %SpiritChip,
	CharacterAttributesData.AttributeType.MIND: %MindChip,
	CharacterAttributesData.AttributeType.CONTROL: %ControlChip,
}
@onready var _score: HBoxContainer = %Score
@onready var _followed: Label = %Followed

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_row.minimum_size_changed.connect(_fit_height)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows `result`: the Madra's chip, a chip for each stat the cycle paid
## (CycleResult.get_paid_stats()), the others hidden, and the score's studs, or
## for a cycle with no zones or seals how much of it was followed.
func show_result(result: CycleResult) -> void:
	_show_chip(_madra_chip, _MADRA_ICON, AMOUNT_FORMAT % roundi(result.madra_added), false)
	var paid: Array[CharacterAttributesData.AttributeType] = result.get_paid_stats()
	for stat: CharacterAttributesData.AttributeType in _stat_chips:
		var chip: Control = _stat_chips[stat]
		chip.visible = paid.has(stat)
		if not chip.visible:
			continue
		var capped: bool = result.is_stat_capped(stat)
		var amount: String = CAPPED_TEXT if capped else AMOUNT_FORMAT % roundi(result.get_stat_xp(stat))
		_show_chip(chip, StatDisplay.icon_of(stat), amount, capped)
	_show_score(result)
	_followed.visible = not _score.visible
	_followed.text = followed_text(result.followed_ratio)
	_fit_height()

## Returns the followed label's text for a cycle followed for `ratio` of its
## time: FOLLOWED_ALL_TEXT for all of it, else FOLLOWED_FORMAT with the share
## floored to a whole percent.
static func followed_text(ratio: float) -> String:
	if ratio >= 1.0 - 0.000001:
		return FOLLOWED_ALL_TEXT
	return FOLLOWED_FORMAT % floori(ratio * 100.0)

## Returns the studs strip's frame for a zone's state as the cycle ended
## (CyclingZone.State): its stud, or a missed zone.
static func stud_frame(zone_state: int) -> int:
	match zone_state:
		CyclingZone.State.PERFECT:
			return STUD_PERFECT
		CyclingZone.State.GOOD:
			return STUD_GOOD
		CyclingZone.State.OK:
			return STUD_OK
		_:
			return STUD_MISSED_ZONE

## Returns the studs strip's frame for a seal node's state as the cycle ended
## (SealNode.State): opened, or missed.
static func seal_frame(seal_state: int) -> int:
	return STUD_OPEN_SEAL if seal_state == SealNode.State.OPEN else STUD_MISSED_SEAL

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Shows `icon` and `amount` on `chip`, the amount in brass when `capped`.
func _show_chip(chip: Control, icon: Texture2D, amount: String, capped: bool) -> void:
	(chip.get_node("%Icon") as TextureRect).texture = icon
	var label: Label = chip.get_node("%Amount") as Label
	label.text = amount
	if capped:
		label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_BRASS)
	else:
		label.remove_theme_color_override(&"font_color")

## Replaces the score's studs with one for each of the result's zones, else
## one for each of its seal nodes, else none; the score hides with none.
func _show_score(result: CycleResult) -> void:
	for stud: Node in _score.get_children():
		_score.remove_child(stud)
		stud.queue_free()
	var frames: Array[int] = []
	for state: int in result.zone_states:
		frames.append(stud_frame(state))
	if frames.is_empty():
		for state: int in result.seal_states:
			frames.append(seal_frame(state))
	for frame: int in frames:
		var stud: LacquerStripRect = _STUD_SCENE.instantiate() as LacquerStripRect
		_score.add_child(stud)
		stud.set_frame(frame)
	_score.visible = not frames.is_empty()

## Sizes the row to its lines and the card to the row, and emits
## height_changed when the card's height changes.
func _fit_height() -> void:
	_row.size.y = _row.get_combined_minimum_size().y
	var height: float = ROW_TOP + maxf(_row.size.y, CHIP_HEIGHT) + ROOM_UNDER_ROW
	if is_equal_approx(height, size.y):
		return
	size.y = height
	height_changed.emit()
