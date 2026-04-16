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

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populates the tooltip with ability data and shows it.
func show_for_ability(ability_data: AbilityData) -> void:
	_ability_icon.texture = ability_data.icon
	_ability_name.text = ability_data.ability_name
	_damage_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.DAMAGE_TOTAL)
	_timing_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.TIMING_COSTS)

	# Hide damage row if ability has no damage (e.g., Enforce is a self-buff)
	_damage_display.visible = not ability_data.effects.is_empty()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false

## Positions the tooltip above the given control, centered horizontally.
func position_below(control: Control) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	var tooltip_size: Vector2 = size
	var x: float = control_rect.position.x + (control_rect.size.x - tooltip_size.x) / 2.0
	var y: float = control_rect.position.y + tooltip_size.y + 25.0

	# Flip below if would overflow top
	if y > 1920:
		y = control_rect.position.y - control_rect.size.y - 8.0

	# Clamp horizontal
	x = clampf(x, 4.0, get_viewport_rect().size.x - tooltip_size.x - 4.0)

	global_position = Vector2(x, y)
