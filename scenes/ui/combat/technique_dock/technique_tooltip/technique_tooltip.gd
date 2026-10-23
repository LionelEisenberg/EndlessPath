class_name TechniqueTooltip
extends PanelContainer

## The lacquer tooltip a hovered technique slot opens above the technique dock
## (spec: The technique dock, Tooltip): the plain board (board9.tres, 304 wide)
## holding the technique's name, its cast and cooldown ("Cast 0.5 s · Cooldown
## 2 s", or "Instant · Cooldown 3 s"), its cost after the resource's mini icon,
## roughly what it hits for when it deals damage (AbilityRow.format_damage()
## for the character's attributes), a divider and what it does. Numbers and
## costs go through AbilityRow's formatters, so the dock reads like the
## Abilities book.
## The board is as tall as its text, rounded up to an even height: the rows add
## up to an odd one (a 15 px BM Euljiro line is 17 px), and an odd height would
## put the board's 2x art 1 px off the 2 px grid the dock and the tray sit on.
## No text is cut off: a name that needs more than the board's 268 px wraps, and
## the board grows to hold it.
## It is a child of the dock, shown and hidden, never instanced. It is
## top-level, so show_for_ability() places it by screen position: its bottom
## 8 px above the dock (y 912), or 8 px above the cast tray while the tray shows
## (y 860 over the tray's own 44 px, higher when a long name has grown it), and
## its left 8 px left of the hovered slot's, kept on screen. It stays there as it
## resizes, and it never takes the pointer.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Where the tooltip's bottom edge sits on screen: 8 px above the dock (at
## y 920), or above the cast tray (at y 868) while it shows (spec: Layout).
const BOTTOM_Y: float = 912.0
## How far the tooltip's bottom stands over the cast tray's top, and where that
## top is (y 868) while the tray is its 44 px.
const GAP_OVER_CAST_TRAY: float = 8.0
const CAST_TRAY_TOP_Y: float = 868.0
## How far left of the hovered slot's left edge the tooltip's starts.
const SLOT_INSET_X: float = 8.0
## The timing line of a technique with a cast time and of an instant one.
const CAST_TIMING_FORMAT: String = "Cast %s · Cooldown %s"
const INSTANT_TIMING_FORMAT: String = "Instant · Cooldown %s"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %NameLabel
@onready var _timing_text: RichTextLabel = %TimingText
@onready var _cost_row: Control = %CostRow
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_label: Label = %CostLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _description_label: Label = %DescriptionLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The slot the tooltip stands over, and where the bottom edge goes: 8 px over the
## dock, or over the cast tray's top while the tray shows.
var _slot: Control = null
var _bottom_y: float = BOTTOM_Y

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	resized.connect(_fit)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the tooltip for data over slot, above the cast tray when
## cast_tray_shown (its top is `cast_tray_top` on screen: y 868 for the kit's
## 44 px tray, higher for one a long name has grown). The board takes the height
## of the new text, rounded up to even.
func show_for_ability(data: AbilityData, slot: Control, cast_tray_shown: bool, cast_tray_top: float = CAST_TRAY_TOP_Y) -> void:
	_slot = slot
	_bottom_y = cast_tray_top - GAP_OVER_CAST_TRAY if cast_tray_shown else BOTTOM_Y
	_name_label.text = data.ability_name
	_timing_text.text = LacquerText.decimal_bbcode(_timing_line(data))
	var cost: String = AbilityRow.format_cost(data)
	_cost_label.text = cost
	_cost_icon.texture = TechniqueSlot.cost_icon(data)
	_cost_row.visible = cost != ""
	var damage: String = AbilityRow.format_damage(data, CharacterManager.get_total_attributes_data())
	_damage_label.text = damage
	_damage_label.visible = damage != ""
	_description_label.text = data.description
	show()
	_fit()

## Hides the tooltip and lets go of its slot.
func hide_tooltip() -> void:
	_slot = null
	hide()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## "Cast <t> s · Cooldown <c> s", or "Instant · Cooldown <c> s".
func _timing_line(data: AbilityData) -> String:
	var cooldown: String = AbilityRow.format_seconds(data.base_cooldown)
	if data.cast_time > 0.0:
		return CAST_TIMING_FORMAT % [AbilityRow.format_seconds(data.cast_time), cooldown]
	return INSTANT_TIMING_FORMAT % cooldown

## Hugs the content, the height rounded up to an even number of px, then places
## the board. Runs again whenever the board resizes (its content grew).
func _fit() -> void:
	if not visible or not is_instance_valid(_slot):
		return
	var minimum: Vector2 = get_combined_minimum_size()
	size = Vector2(minimum.x, ceilf(minimum.y / 2.0) * 2.0)
	_place()

## Puts the bottom edge on its line and the left edge by the slot, on screen.
## The height and both lines are even, so the top is too.
func _place() -> void:
	if not visible or not is_instance_valid(_slot):
		return
	var screen: Vector2 = get_viewport_rect().size
	var left: float = clampf(_slot.global_position.x - SLOT_INSET_X, 0.0, maxf(screen.x - size.x, 0.0))
	var top: float = clampf(_bottom_y - size.y, 0.0, maxf(screen.y - size.y, 0.0))
	global_position = Vector2(left, top)
