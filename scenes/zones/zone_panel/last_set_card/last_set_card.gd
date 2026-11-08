class_name LastSetCard
extends Control

## LastSetCard
## The zone chest's card for the last finished set of a drill, under the Now tray
## while the body refining board is up (#149), the Last cycle card's twin: the Now
## tray's frame with a brass "Last set" tag, a chip for what the set restored (the
## Health pool heart at 32 px, then "+32", or "full" in brass when the pool was
## full), a chip for Strength's XP and, for a set played by hand of a drill with
## another stat, one for that stat's ("capped" in brass for a stat the cap took XP
## from). Body shows its heart in steel, apart from the Health heart. Under the
## chips, the set's beads in bead order as the board lit them: a perfect set reads
## ten brass beads, an Auto set ten dimmed ones. The chips wrap onto another line
## rather than trim, and the card grows with them: ONE_LINE_HEIGHT tall with one
## line. It emits height_changed when its height changes, for the chest to lay out
## again.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the card's height changes: its chips wrapped onto another line,
## or came back to one.
signal height_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AttributeType = CharacterAttributesData.AttributeType

## The card's height while its chips are one line: the chips stand ROW_TOP px
## down and are CHIP_HEIGHT px tall, the beads BEADS_GAP under them and BEAD_HEIGHT
## tall, and ROOM_UNDER_BEADS px of tray are left under them.
const ONE_LINE_HEIGHT: float = 98.0
const ROW_TOP: float = 20.0
const CHIP_HEIGHT: float = 32.0
const BEADS_GAP: float = 8.0
const BEAD_HEIGHT: float = 24.0
const ROOM_UNDER_BEADS: float = 14.0

## A chip's figure: the amount, rounded to a whole number, or the brass word.
const AMOUNT_FORMAT: String = "+%d"
const CAPPED_TEXT: String = "capped"
const FULL_TEXT: String = "full"

const _HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_pool_health_ai.png")
## Body's heart in steel, as its mini is, so it reads apart from the Health heart.
const _BODY_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_body_steel_ai.png")
const _BEAD_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/last_set_card/last_set_bead.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _chips: HFlowContainer = %Chips
@onready var _health_chip: Control = %HealthChip
@onready var _strength_chip: Control = %StrengthChip
@onready var _minor_chip: Control = %MinorChip
@onready var _beads: HBoxContainer = %Beads

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_chips.minimum_size_changed.connect(_fit_height)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows `result`: what it restored, Strength's XP, the drill's other stat's XP for
## a set played by hand, and its beads.
func show_result(result: DrillSetResult) -> void:
	var full: bool = result.is_health_full()
	_show_chip(_health_chip, _HEALTH_ICON, FULL_TEXT if full else AMOUNT_FORMAT % roundi(result.get_health_restored()), full)
	_show_stat_chip(_strength_chip, result, AttributeType.STRENGTH)
	var drill: DrillData = result.drill
	_minor_chip.visible = drill != null and drill.has_minor_stat() and not result.is_auto()
	if _minor_chip.visible:
		_show_stat_chip(_minor_chip, result, drill.minor_stat as AttributeType)
	_show_beads(result)
	_fit_height()

## Returns the icon a stat's chip shows: Body's heart in steel, else the stat's own.
static func chip_icon(stat: AttributeType) -> Texture2D:
	return _BODY_ICON if stat == AttributeType.BODY else StatDisplay.icon_of(stat)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Shows `stat`'s chip: its XP, or "capped" in brass.
func _show_stat_chip(chip: Control, result: DrillSetResult, stat: AttributeType) -> void:
	var capped: bool = result.is_stat_capped(stat)
	_show_chip(chip, chip_icon(stat), CAPPED_TEXT if capped else AMOUNT_FORMAT % roundi(result.get_stat_xp(stat)), capped)

## Shows `icon` and `amount` on `chip`, the amount in brass when `brass`.
func _show_chip(chip: Control, icon: Texture2D, amount: String, brass: bool) -> void:
	(chip.get_node("%Icon") as TextureRect).texture = icon
	var label: Label = chip.get_node("%Amount") as Label
	label.text = amount
	if brass:
		label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_BRASS)
	else:
		label.remove_theme_color_override(&"font_color")

## Replaces the beads with one for each of the result's reps, in bead order, each
## in its tier's frame, an Auto rep's dimmed as the board dims it.
func _show_beads(result: DrillSetResult) -> void:
	for bead: Node in _beads.get_children():
		_beads.remove_child(bead)
		bead.queue_free()
	for tier: DrillRules.Tier in result.get_bead_tiers():
		var bead: LacquerStripRect = _BEAD_SCENE.instantiate() as LacquerStripRect
		_beads.add_child(bead)
		bead.set_frame(DrillPlay.BEAD_FRAMES[tier])
		bead.self_modulate = DrillPlay.AUTO_BEAD_TINT if tier == DrillRules.Tier.AUTO else Color.WHITE

## Sizes the chips to their lines, stands the beads under them and the card round
## both, and emits height_changed when the card's height changes.
func _fit_height() -> void:
	_chips.size.y = _chips.get_combined_minimum_size().y
	var chips_height: float = maxf(_chips.size.y, CHIP_HEIGHT)
	_beads.position.y = ROW_TOP + chips_height + BEADS_GAP
	var height: float = _beads.position.y + BEAD_HEIGHT + ROOM_UNDER_BEADS
	if is_equal_approx(height, size.y):
		return
	size.y = height
	height_changed.emit()
