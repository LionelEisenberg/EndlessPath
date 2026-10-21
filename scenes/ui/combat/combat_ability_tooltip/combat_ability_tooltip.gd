class_name CombatAbilityTooltip
extends PanelContainer

## CombatAbilityTooltip
## Compact ability info popup for combat view.
## Shows icon, name, total damage, cooldown, cast time, and costs.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _ability_icon: TextureRect = %AbilityIcon
@onready var _ability_name: Label = %AbilityName
@onready var _damage_display: AbilityStatsDisplay = %DamageDisplay
@onready var _timing_display: AbilityStatsDisplay = %TimingDisplay

## Control the tooltip is anchored above; re-applied whenever the tooltip resizes.
var _anchor_control: Control

func _ready() -> void:
	resized.connect(_reposition)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populates the tooltip with ability data and shows it.
func show_for_ability(ability_data: AbilityData) -> void:
	_ability_icon.texture = ability_data.icon
	_ability_name.text = ability_data.ability_name
	_damage_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.DAMAGE_TOTAL)
	_timing_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.TIMING_COSTS)

	# Hide damage row if ability has no effects on an enemy target (e.g., Enforce is a self-buff).
	_damage_display.visible = not ability_data.effects_on_target.is_empty()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false
	_anchor_control = null

## Positions the tooltip just above the given control, centered horizontally.
## Flips below the control if there isn't room above, and clamps to the viewport.
## Stays anchored if the tooltip resizes after its content finishes laying out.
func position_above(control: Control) -> void:
	_anchor_control = control
	reset_size()
	_reposition()

func _reposition() -> void:
	if not visible or not is_instance_valid(_anchor_control):
		return
	var control_rect: Rect2 = _anchor_control.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var x: float = control_rect.position.x + (control_rect.size.x - size.x) / 2.0
	var y: float = control_rect.position.y - size.y - 12.0
	if y < 4.0:
		y = control_rect.end.y + 12.0

	x = clampf(x, 4.0, viewport_size.x - size.x - 4.0)
	y = clampf(y, 4.0, viewport_size.y - size.y - 4.0)
	global_position = Vector2(x, y)
