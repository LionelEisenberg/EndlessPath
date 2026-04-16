class_name CombatBuffTooltip
extends PanelContainer

## CombatBuffTooltip
## Shows buff details on hover: name, description, duration, stacks.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const TOOLTIP_WIDTH: float = 220.0
const CARD_BG: Color = Color(0.239, 0.18, 0.133, 1.0)
const CARD_BORDER: Color = Color(0.549, 0.4, 0.278, 1.0)
const COLOR_GOLD: Color = Color("#D4A84A")
const COLOR_BEIGE: Color = Color("#F0E5D8")
const COLOR_TAN: Color = Color("#A89070")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _icon_rect: TextureRect
var _name_label: Label
var _desc_label: Label
var _duration_label: Label
var _stacks_label: Label
var _active_buff: ActiveBuff

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = TOOLTIP_WIDTH

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

	# Header: icon + name
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(32, 32)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", COLOR_BEIGE)
	_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03, 1))
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_name_label)

	# Description
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", COLOR_TAN)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_desc_label)

	# Meta row: duration + stacks
	var meta: HBoxContainer = HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 12)
	vbox.add_child(meta)

	_duration_label = Label.new()
	_duration_label.add_theme_font_size_override("font_size", 12)
	_duration_label.add_theme_color_override("font_color", COLOR_GOLD)
	_duration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(_duration_label)

	_stacks_label = Label.new()
	_stacks_label.add_theme_font_size_override("font_size", 12)
	_stacks_label.add_theme_color_override("font_color", COLOR_BEIGE)
	_stacks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(_stacks_label)

## Shows the tooltip for the given active buff.
func show_for_buff(buff: ActiveBuff) -> void:
	_active_buff = buff
	var data: BuffEffectData = buff.buff_data

	_icon_rect.texture = data.buff_icon
	_name_label.text = data.buff_id.capitalize()
	_desc_label.text = _build_description(data)
	_update_meta()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	_active_buff = null
	visible = false

## Updates duration in real time while visible.
func _process(_delta: float) -> void:
	if visible and _active_buff:
		_update_meta()

func _update_meta() -> void:
	if _active_buff:
		_duration_label.text = "%.1fs remaining" % _active_buff.time_remaining
		if _active_buff.stack_count > 1:
			_stacks_label.text = "x%d stacks" % _active_buff.stack_count
			_stacks_label.visible = true
		else:
			_stacks_label.visible = false

## Positions to the right of the given control.
func position_beside(control: Control) -> void:
	var rect: Rect2 = control.get_global_rect()
	var x: float = rect.position.x + rect.size.x + 8.0
	var y: float = rect.position.y

	# Flip left if would overflow right
	if x + size.x > get_viewport_rect().size.x:
		x = rect.position.x - size.x - 8.0

	global_position = Vector2(x, y)

func _build_description(data: BuffEffectData) -> String:
	match data.buff_type:
		BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE:
			var parts: PackedStringArray = []
			for attr_type: CharacterAttributesData.AttributeType in data.attribute_modifiers:
				var mult: float = data.attribute_modifiers[attr_type]
				var attr_name: String = CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()
				parts.append("%s x%.1f" % [attr_name, mult])
			return ", ".join(parts)
		BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			return "%.1f damage per second" % data.dot_damage_per_tick
		BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER:
			return "Outgoing damage x%.1f" % data.damage_multiplier
		BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER:
			return "Incoming damage x%.1f" % data.damage_multiplier
	return ""
