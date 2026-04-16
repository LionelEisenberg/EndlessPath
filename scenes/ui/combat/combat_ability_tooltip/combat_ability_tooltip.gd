class_name CombatAbilityTooltip
extends PanelContainer

## CombatAbilityTooltip
## Compact ability info popup for combat view.
## Shows icon, name, total damage, cooldown, cast time, and costs.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const TOOLTIP_WIDTH: float = 280.0
const CARD_BG: Color = Color(0.239, 0.18, 0.133, 1.0) # #3D2E22
const CARD_BORDER: Color = Color(0.549, 0.4, 0.278, 1.0) # #8C6647

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

const AbilityStatsDisplayScene: PackedScene = preload("res://scenes/abilities/ability_stats_display/ability_stats_display.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _icon_rect: TextureRect
var _name_label: Label
var _damage_display: AbilityStatsDisplay
var _timing_display: AbilityStatsDisplay

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = TOOLTIP_WIDTH

	# Panel style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", style)

	_build_layout()

func _build_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header row: icon + name
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(40, 40)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"LabelAbilityBody"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_name_label)

	# Stats rows
	_damage_display = AbilityStatsDisplayScene.instantiate()
	_damage_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_damage_display)

	_timing_display = AbilityStatsDisplayScene.instantiate()
	_timing_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_timing_display)

## Populates the tooltip with ability data.
func show_for_ability(ability_data: AbilityData) -> void:
	_icon_rect.texture = ability_data.icon
	_name_label.text = ability_data.ability_name
	_damage_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.DAMAGE_TOTAL)
	_timing_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.TIMING_COSTS)

	# Hide damage row if ability has no damage (e.g., Enforce is a self-buff)
	_damage_display.visible = not ability_data.effects.is_empty()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false

## Positions the tooltip above the given control, centered horizontally.
func position_above(control: Control) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	var tooltip_size: Vector2 = size
	var x: float = control_rect.position.x + (control_rect.size.x - tooltip_size.x) / 2.0
	var y: float = control_rect.position.y - tooltip_size.y - 8.0

	# Flip below if would overflow top
	if y < 0:
		y = control_rect.position.y + control_rect.size.y + 8.0

	# Clamp horizontal
	x = clampf(x, 4.0, get_viewport_rect().size.x - tooltip_size.x - 4.0)

	global_position = Vector2(x, y)
