class_name AbilityCard
extends PanelContainer

## Expandable ability card for the AbilitiesView.
## Shows a collapsed summary row; click to expand for details and equip/unequip.
## Supports drag-and-drop to loadout slots.

signal equip_requested(ability_id: String)
signal unequip_requested(ability_id: String)
signal card_selected(card: AbilityCard)

var _ability_data: AbilityData = null
var _is_expanded: bool = false
var _is_equipped: bool = false
var _expand_tween: Tween = null

var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null
var _style_expanded: StyleBoxFlat = null

@onready var _icon: TextureRect = %AbilityIcon
@onready var _name_label: RichTextLabel = %AbilityName
@onready var _cost_label: RichTextLabel = %CostLabel
@onready var _madra_badge: Label = %MadraBadge
@onready var _source_badge: Label = %SourceBadge
@onready var _expanded_details: VBoxContainer = %ExpandedDetails
@onready var _tags_row: HBoxContainer = %TagsRow
@onready var _description_label: RichTextLabel = %DescriptionLabel
@onready var _scaling_label: RichTextLabel = %ScalingLabel
@onready var _equip_button: Button = %EquipButton

func _ready() -> void:
	_equip_button.pressed.connect(_on_equip_button_pressed)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_card_styles()
	_set_children_mouse_pass()
	clip_contents = true

# ----- Public API -----

## Configures the card with ability data and equipped status.
func setup(ability_data: AbilityData, is_equipped: bool) -> void:
	_ability_data = ability_data
	_is_equipped = is_equipped
	_update_display()

## Updates equipped state without full rebuild.
func set_equipped(is_equipped: bool) -> void:
	_is_equipped = is_equipped
	_update_equipped_display()

## Collapses the card (no animation).
func collapse() -> void:
	_is_expanded = false
	_animate_expand(false)
	_apply_card_style()

## Returns the ability data for this card.
func get_ability_data() -> AbilityData:
	return _ability_data

# ----- Drag and Drop -----

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _ability_data:
		return null
	# Solid background so the icon is visible over any surface
	var container: Control = Control.new()
	container.z_index = 100
	container.top_level = true
	var bg: Panel = Panel.new()
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = ThemeConstants.BG_MEDIUM
	bg_style.set_border_width_all(2)
	bg_style.border_color = ThemeConstants.BORDER_PRIMARY
	bg_style.set_corner_radius_all(6)
	bg_style.set_content_margin_all(0)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.position = Vector2(-40, -40)
	bg.size = Vector2(80, 80)
	container.add_child(bg)
	var icon: TextureRect = TextureRect.new()
	icon.texture = _ability_data.icon
	icon.position = Vector2(-32, -32)
	icon.size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(1.5, 1.5, 1.5, 1.0)
	container.add_child(icon)
	set_drag_preview(container)
	return {"ability_id": _ability_data.ability_id}

# ----- Private -----

func _build_card_styles() -> void:
	# Normal style (BG_MEDIUM with subtle border)
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = ThemeConstants.BG_MEDIUM
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = ThemeConstants.BORDER_SUBTLE
	_style_normal.set_corner_radius_all(6)
	_style_normal.set_content_margin_all(12)
	_style_normal.content_margin_top = 10
	_style_normal.content_margin_bottom = 10

	# Hover style (slightly lighter bg, brighter border)
	_style_hover = StyleBoxFlat.new()
	_style_hover.bg_color = Color(0.27, 0.20, 0.15, 1.0)
	_style_hover.set_border_width_all(2)
	_style_hover.border_color = Color(0.55, 0.40, 0.28, 1.0)
	_style_hover.set_corner_radius_all(6)
	_style_hover.set_content_margin_all(12)
	_style_hover.content_margin_top = 10
	_style_hover.content_margin_bottom = 10

	# Expanded style (brighter border, slightly lighter bg)
	_style_expanded = StyleBoxFlat.new()
	_style_expanded.bg_color = Color(0.27, 0.20, 0.15, 1.0)
	_style_expanded.set_border_width_all(2)
	_style_expanded.border_color = ThemeConstants.BORDER_PRIMARY
	_style_expanded.set_corner_radius_all(6)
	_style_expanded.set_content_margin_all(12)
	_style_expanded.content_margin_top = 10
	_style_expanded.content_margin_bottom = 10

	_apply_card_style()

func _apply_card_style() -> void:
	if _is_expanded:
		add_theme_stylebox_override("panel", _style_expanded)
	else:
		add_theme_stylebox_override("panel", _style_normal)

func _update_display() -> void:
	if not _ability_data:
		return

	_icon.texture = _ability_data.icon

	# Ability name with BBCode — larger font set in TSCN (28px override)
	_name_label.text = ""
	_name_label.append_text("[color=#F0E8D8]%s[/color]" % _ability_data.ability_name)

	# Cost summary with colored values
	_update_cost_display()

	# Madra badge
	if _ability_data.madra_type == AbilityData.MadraType.NONE:
		_madra_badge.visible = false
	else:
		_madra_badge.visible = true
		_madra_badge.text = AbilityData.MadraType.keys()[_ability_data.madra_type]

	# Source badge
	_source_badge.text = AbilityData.AbilitySource.keys()[_ability_data.ability_source].capitalize()

	# Tag badges (type + target as pills)
	_update_tags_display()

	# Expanded details
	_description_label.text = ""
	_description_label.append_text("[color=#F0E8D8]%s[/color]" % _ability_data.description)

	_update_scaling_display()
	_update_equipped_display()

func _update_cost_display() -> void:
	_cost_label.text = ""
	var cost_text: String = _ability_data.get_total_cost_display()
	var cd_text: String = "%.1fs CD" % _ability_data.base_cooldown
	var cast_text: String = "Instant" if _ability_data.cast_time <= 0.0 else "%.1fs Cast" % _ability_data.cast_time

	# Color the cost portion
	if cost_text == "Free":
		_cost_label.append_text("[color=#7DCE82]Free[/color]")
	else:
		_cost_label.append_text("[color=#F0E8D8]%s[/color]" % cost_text)
	_cost_label.append_text("[color=#A89070] \u00b7 %s \u00b7 %s[/color]" % [cd_text, cast_text])

func _update_tags_display() -> void:
	# Clear existing tag children
	for child: Node in _tags_row.get_children():
		child.queue_free()

	var type_name: String = AbilityData.AbilityType.keys()[_ability_data.ability_type].capitalize()
	var target_name: String = AbilityData.TargetType.keys()[_ability_data.target_type].capitalize().replace("_", " ")

	_tags_row.add_child(_create_tag_label(type_name))
	_tags_row.add_child(_create_tag_label(target_name))

func _create_tag_label(text: String) -> Label:
	var tag: Label = Label.new()
	tag.text = text
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)

	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = Color(0.42, 0.29, 0.188, 0.25)
	pill.set_border_width_all(1)
	pill.border_color = Color(0.42, 0.29, 0.188, 0.5)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 8.0
	pill.content_margin_right = 8.0
	pill.content_margin_top = 2.0
	pill.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("normal", pill)

	return tag

func _update_scaling_display() -> void:
	_scaling_label.text = ""
	if _ability_data.effects.is_empty():
		_scaling_label.visible = false
		return

	var effect: CombatEffectData = _ability_data.effects[0]

	# Only show damage/scaling for offensive abilities with actual damage values
	var has_damage_info: bool = _has_damage_or_scaling(effect)
	if not has_damage_info:
		_scaling_label.visible = false
		return

	var parts: Array[String] = []

	# Base value
	parts.append("[color=#D4A84A]Base: %.0f[/color]" % effect.base_value)

	# Scaling attributes (only non-zero)
	var scaling_parts: Array[String] = []
	if effect.strength_scaling != 0.0:
		scaling_parts.append("STR (\u00d7%.1f)" % effect.strength_scaling)
	if effect.body_scaling != 0.0:
		scaling_parts.append("BODY (\u00d7%.1f)" % effect.body_scaling)
	if effect.agility_scaling != 0.0:
		scaling_parts.append("AGI (\u00d7%.1f)" % effect.agility_scaling)
	if effect.spirit_scaling != 0.0:
		scaling_parts.append("SPI (\u00d7%.1f)" % effect.spirit_scaling)
	if effect.foundation_scaling != 0.0:
		scaling_parts.append("FND (\u00d7%.1f)" % effect.foundation_scaling)
	if effect.control_scaling != 0.0:
		scaling_parts.append("CTL (\u00d7%.1f)" % effect.control_scaling)
	if effect.resilience_scaling != 0.0:
		scaling_parts.append("RES (\u00d7%.1f)" % effect.resilience_scaling)
	if effect.willpower_scaling != 0.0:
		scaling_parts.append("WIL (\u00d7%.1f)" % effect.willpower_scaling)

	if not scaling_parts.is_empty():
		parts.append("[color=#A89070]Scales: %s[/color]" % ", ".join(scaling_parts))

	_scaling_label.visible = true
	_scaling_label.append_text(" \u00b7 ".join(parts))

func _has_damage_or_scaling(effect: CombatEffectData) -> bool:
	if effect.base_value != 0.0:
		return true
	if effect.strength_scaling != 0.0:
		return true
	if effect.body_scaling != 0.0:
		return true
	if effect.agility_scaling != 0.0:
		return true
	if effect.spirit_scaling != 0.0:
		return true
	if effect.foundation_scaling != 0.0:
		return true
	if effect.control_scaling != 0.0:
		return true
	if effect.resilience_scaling != 0.0:
		return true
	if effect.willpower_scaling != 0.0:
		return true
	return false

func _update_equipped_display() -> void:
	if _is_equipped:
		_equip_button.text = "UNEQUIP"
	else:
		if AbilityManager:
			var filled: int = 0
			for id: String in AbilityManager._live_save_data.equipped_ability_ids:
				if not id.is_empty():
					filled += 1
			if filled >= AbilityManager.get_max_slots():
				_equip_button.text = "SLOTS FULL"
				_equip_button.disabled = true
				return
		_equip_button.text = "EQUIP"
	_equip_button.disabled = false

func _animate_expand(expanding: bool) -> void:
	# Kill any in-flight tween
	if _expand_tween and _expand_tween.is_valid():
		_expand_tween.kill()

	if expanding:
		_expanded_details.visible = true
		_expanded_details.modulate = Color(1, 1, 1, 0)
		_expand_tween = create_tween()
		_expand_tween.set_ease(Tween.EASE_OUT)
		_expand_tween.set_trans(Tween.TRANS_CUBIC)
		_expand_tween.tween_property(_expanded_details, "modulate", Color(1, 1, 1, 1), 0.2)
	else:
		_expand_tween = create_tween()
		_expand_tween.set_ease(Tween.EASE_IN)
		_expand_tween.set_trans(Tween.TRANS_CUBIC)
		_expand_tween.tween_property(_expanded_details, "modulate", Color(1, 1, 1, 0), 0.15)
		_expand_tween.tween_callback(_expanded_details.set.bind("visible", false))

func _on_gui_input(event: InputEvent) -> void:
	# Handle click on RELEASE so the press is available for drag detection
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_is_dragging():
			return
		if _is_expanded:
			_is_expanded = false
			_animate_expand(false)
			_apply_card_style()
		else:
			card_selected.emit(self)
			_is_expanded = true
			_animate_expand(true)
			_apply_card_style()

func _on_equip_button_pressed() -> void:
	if not _ability_data:
		return
	if _is_equipped:
		unequip_requested.emit(_ability_data.ability_id)
	else:
		equip_requested.emit(_ability_data.ability_id)

func _on_mouse_entered() -> void:
	if not _is_expanded:
		add_theme_stylebox_override("panel", _style_hover)

func _on_mouse_exited() -> void:
	if not _is_expanded:
		add_theme_stylebox_override("panel", _style_normal)

## Sets mouse_filter = PASS on all child controls so clicks reach the PanelContainer.
## Skips the EquipButton which needs to remain clickable.
func _set_children_mouse_pass() -> void:
	_set_mouse_pass_recursive(self)

func _set_mouse_pass_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child == _equip_button:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_pass_recursive(child)
