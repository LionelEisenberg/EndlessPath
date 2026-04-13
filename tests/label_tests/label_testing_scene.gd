extends Control

## Scene that displays every Label theme variation with stats and font comparison columns.

const SAMPLE_TEXT: String = "The quick brown fox jumps over the lazy dog"
const SAMPLE_SHORT: String = "Sacred Artist Lindon"

## m5x7 renders tall/thin; Pixelmix renders denser at the same px size.
## This ratio approximates visual size matching (adjust as needed).
const PIXELMIX_SCALE: float = 0.62
const BMEULJI_SCALE: float = 0.80
const KOREAN_SCALE: float = 0.80
const YATRA_SCALE: float = 0.80
const UBAGE_SCALE: float = 0.80

var _pixelmix_font: Font
var _bmeulji_font: Font
var _korean_font: Font
var _yatra_font: Font
var _ubage_font: Font

# Label variant name → { font_size, color, shadow_color, shadow_offset, notes }
# Values pulled from pixel_theme.tres
const LABEL_VARIANTS: Array[Dictionary] = [
	{
		"name": "Label (Base)",
		"theme_type": "",
		"font_size": 16,
		"color": Color(0.941, 0.910, 0.847, 1),
		"shadow_color": Color(0.102, 0.071, 0.031, 1),
		"shadow_offset": Vector2i(0, 0),
		"notes": "Default label — light beige on dark",
		"used_in": "Base theme default (everywhere)",
	},
	{
		"name": "LabelAbilityBody",
		"theme_type": "LabelAbilityBody",
		"font_size": 28,
		"color": Color(0.941, 0.91, 0.847, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"outline_color": Color(0.1, 0.07, 0.03, 1),
		"outline_size": 2,
		"notes": "Ability body text — beige with outline",
		"used_in": "Ability card (description, stats), stat label",
	},
	{
		"name": "LabelAbilityMuted",
		"theme_type": "LabelAbilityMuted",
		"font_size": 21,
		"color": Color(0.659, 0.565, 0.439, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"outline_color": Color(0.1, 0.07, 0.03, 1),
		"outline_size": 2,
		"notes": "Ability muted text — tan with outline",
		"used_in": "Ability card (cost, type labels)",
	},
	{
		"name": "LabelAbilityTitle",
		"theme_type": "LabelAbilityTitle",
		"font_size": 35,
		"color": Color(0.941, 0.91, 0.847, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"outline_color": Color(0.1, 0.07, 0.03, 1),
		"outline_size": 2,
		"notes": "Ability title — beige with outline",
		"used_in": "Ability card (ability name)",
	},
	{
		"name": "LabelSeparatorDot",
		"theme_type": "LabelSeparatorDot",
		"font_size": 28,
		"color": Color(0.769, 0.533, 0.29, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Separator dot — warm orange/gold",
		"used_in": "Ability stats display (dot separators)",
	},
	{
		"name": "LabelDark",
		"theme_type": "LabelDark",
		"font_size": 16,
		"color": Color(0.165, 0.102, 0.071, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Dark brown text for light backgrounds",
		"used_in": "Unused",
	},
	{
		"name": "LabelDescItemName",
		"theme_type": "LabelDescItemName",
		"font_size": 42,
		"color": Color(0, 0, 0, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Item name in description panel",
		"used_in": "Item description panel (inventory sidebar, end card tooltip)",
	},
	{
		"name": "LabelDescItemType",
		"theme_type": "LabelDescItemType",
		"font_size": 28,
		"color": Color(0.378, 0.378, 0.378, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Item type subtitle in description panel",
		"used_in": "Item description panel (equipment type label)",
	},
	{
		"name": "LabelEndCardDefeatReason",
		"theme_type": "LabelEndCardDefeatReason",
		"font_size": 28,
		"color": Color(0.545, 0, 0, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Defeat reason text — dark red",
		"used_in": "Adventure end card (defeat/victory reason)",
	},
	{
		"name": "LabelEndCardMuted",
		"theme_type": "LabelEndCardMuted",
		"font_size": 18,
		"color": Color(0.5, 0.42, 0.33, 0.8),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Smallest label — muted tan, 80% opacity",
		"used_in": "Adventure end card (empty loot message)",
	},
	{
		"name": "LabelEndCardSection",
		"theme_type": "LabelEndCardSection",
		"font_size": 32,
		"color": Color(0.2, 0.15, 0.1, 1),
		"shadow_color": Color(0, 0, 0, 0.749),
		"shadow_offset": Vector2i(1, 1),
		"notes": "Section header — dark brown with shadow",
		"used_in": "Adventure end card (section headers: LOOT)",
	},
	{
		"name": "LabelEndCardStatName",
		"theme_type": "LabelEndCardStatName",
		"font_size": 22,
		"color": Color(0.65, 0.5, 0.22, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Stat name — muted gold",
		"used_in": "Adventure end card (stat names: COMBAT, GOLD, TIME...)",
	},
	{
		"name": "LabelEndCardStatValue",
		"theme_type": "LabelEndCardStatValue",
		"font_size": 26,
		"color": Color(0.2, 0.15, 0.1, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Stat value — dark brown",
		"used_in": "Adventure end card (stat values)",
	},
	{
		"name": "LabelEndCardTitle",
		"theme_type": "LabelEndCardTitle",
		"font_size": 128,
		"color": Color(0.545, 0.412, 0.078, 1),
		"shadow_color": Color(0, 0, 0, 0.3),
		"shadow_offset": Vector2i(2, 2),
		"notes": "Largest label — gold with shadow",
		"used_in": "Adventure end card (VICTORY / defeat title)",
	},
	{
		"name": "LabelPathBody",
		"theme_type": "LabelPathBody",
		"font_size": 24,
		"color": Color(0.941, 0.91, 0.847, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Path tree body text — light beige",
		"used_in": "Path tree view, benefit card (body text)",
	},
	{
		"name": "LabelPathGreen",
		"theme_type": "LabelPathGreen",
		"font_size": 22,
		"color": Color(0.49, 0.808, 0.51, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Positive/buff indicator — green",
		"used_in": "Path tree (strengths), benefit card (value text)",
	},
	{
		"name": "LabelPathHeading",
		"theme_type": "LabelPathHeading",
		"font_size": 38,
		"color": Color(0.831, 0.659, 0.29, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Path heading — gold",
		"used_in": "Path tree (ACTIVE BENEFITS header), path node tooltip (name)",
	},
	{
		"name": "LabelPathMuted",
		"theme_type": "LabelPathMuted",
		"font_size": 28,
		"color": Color(0.659, 0.565, 0.439, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Path muted text — tan",
		"used_in": "Path tree (points label, description), node tooltip (type, cost, level)",
	},
	{
		"name": "LabelPathRed",
		"theme_type": "LabelPathRed",
		"font_size": 22,
		"color": Color(0.878, 0.376, 0.376, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Negative/debuff indicator — salmon red",
		"used_in": "Path tree (weaknesses in madra info popup)",
	},
	{
		"name": "LabelPathSubheading",
		"theme_type": "LabelPathSubheading",
		"font_size": 26,
		"color": Color(0.659, 0.565, 0.439, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Path subheading — tan",
		"used_in": "Path tree (path description under title)",
	},
	{
		"name": "LabelPathTitle",
		"theme_type": "LabelPathTitle",
		"font_size": 52,
		"color": Color(0.831, 0.659, 0.29, 1),
		"shadow_color": Color(0, 0, 0, 0.6),
		"shadow_offset": Vector2i(2, 2),
		"notes": "Path title — gold with shadow",
		"used_in": "Path tree (main path name heading)",
	},
	{
		"name": "LabelPathValueLarge",
		"theme_type": "LabelPathValueLarge",
		"font_size": 36,
		"color": Color(0.831, 0.659, 0.29, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Large path value — gold",
		"used_in": "Path tree (path points number)",
	},
	{
		"name": "LabelPathValueMedium",
		"theme_type": "LabelPathValueMedium",
		"font_size": 24,
		"color": Color(0.831, 0.659, 0.29, 1),
		"shadow_color": Color.TRANSPARENT,
		"shadow_offset": Vector2i(0, 0),
		"notes": "Medium path value — gold",
		"used_in": "Path tree (path name in popup)",
	},
	{
		"name": "TooltipLabel",
		"theme_type": "TooltipLabel",
		"font_size": 16,
		"color": Color(0.867, 0.867, 0.867, 1),
		"shadow_color": Color(0.133, 0.133, 0.133, 1),
		"shadow_offset": Vector2i(0, 0),
		"notes": "Tooltip text — light gray with dark gray shadow",
		"used_in": "Unused",
	},
]


func _ready() -> void:
	_pixelmix_font = load("res://assets/fonts/pixelmix.ttf")
	if not _pixelmix_font:
		push_error("Failed to load pixelmix.ttf — run Godot --import first")
	_bmeulji_font = load("res://assets/fonts/BMEULJIROTTF.ttf")
	if not _bmeulji_font:
		push_error("Failed to load BMEULJIROTTF.ttf — run Godot --import first")
	_korean_font = load("res://assets/fonts/Korean_Calligraphy.ttf")
	if not _korean_font:
		push_error("Failed to load Korean_Calligraphy.ttf — run Godot --import first")
	_yatra_font = load("res://assets/fonts/YatraOne-Regular.ttf")
	if not _yatra_font:
		push_error("Failed to load YatraOne-Regular.ttf — run Godot --import first")
	_ubage_font = load("res://assets/fonts/Ubage-woA3P.otf")
	if not _ubage_font:
		push_error("Failed to load Ubage-woA3P.otf — run Godot --import first")
	_build_ui()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "Label Testing Scene"
	title.theme_type_variation = &"LabelEndCardTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "All %d label variants  |  m5x7 vs Pixelmix (%.0f%%) vs Korean Calligraphy (%.0f%%)" % [LABEL_VARIANTS.size(), PIXELMIX_SCALE * 100, KOREAN_SCALE * 100]
	subtitle.theme_type_variation = &"LabelPathMuted"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	_add_spacer(main_vbox, 20)

	for variant: Dictionary in LABEL_VARIANTS:
		_add_variant_row(main_vbox, variant)


func _add_variant_row(parent: VBoxContainer, variant: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(panel)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.08, 0.06, 0.04, 1)
	stylebox.border_color = Color(0.2, 0.16, 0.1, 0.4)
	stylebox.set_border_width_all(1)
	stylebox.set_content_margin_all(16)
	stylebox.content_margin_top = 12
	stylebox.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", stylebox)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# --- Column 1: Stats ---
	var stats_vbox := VBoxContainer.new()
	stats_vbox.custom_minimum_size.x = 420
	stats_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(stats_vbox)

	var name_label := Label.new()
	name_label.text = variant["name"]
	name_label.theme_type_variation = &"LabelPathHeading"
	stats_vbox.add_child(name_label)

	var notes_label := Label.new()
	notes_label.text = variant["notes"]
	notes_label.theme_type_variation = &"LabelEndCardMuted"
	stats_vbox.add_child(notes_label)

	_add_spacer(stats_vbox, 4)

	var color: Color = variant["color"]
	var shadow_color: Color = variant["shadow_color"]
	var shadow_offset: Vector2i = variant["shadow_offset"]
	var font_size: int = variant["font_size"]
	var px_matched_size: int = _get_matched_size(font_size, PIXELMIX_SCALE)
	var kr_matched_size: int = _get_matched_size(font_size, KOREAN_SCALE)

	_add_stat_line(stats_vbox, "Font Size", "%dpx" % font_size)
	_add_stat_line(stats_vbox, "Pixelmix", "%dpx matched" % px_matched_size)
	_add_stat_line(stats_vbox, "Korean", "%dpx matched" % kr_matched_size)
	_add_stat_line(stats_vbox, "Color", _color_to_display(color))
	if shadow_color.a > 0:
		_add_stat_line(stats_vbox, "Shadow", "%s  (%d, %d)" % [_color_to_display(shadow_color), shadow_offset.x, shadow_offset.y])
	else:
		_add_stat_line(stats_vbox, "Shadow", "none")
	var outline_size: int = variant.get("outline_size", 0)
	if outline_size > 0:
		var outline_color: Color = variant["outline_color"]
		_add_stat_line(stats_vbox, "Outline", "%s  %dpx" % [_color_to_display(outline_color), outline_size])
	_add_stat_line(stats_vbox, "Used in", variant["used_in"])

	_add_separator(hbox)

	# --- Column 2: m5x7 (theme default) ---
	var m5x7_col := _create_font_column("m5x7 @ %dpx" % font_size, variant, null, font_size)
	hbox.add_child(m5x7_col)

	_add_separator(hbox)

	# --- Column 3: BMEULJIROTTF matched size ---
	var bm_matched_size: int = _get_matched_size(font_size, BMEULJI_SCALE)
	var bm_col := _create_font_column("Bmeuljiro @ %dpx (matched)" % bm_matched_size, variant, _bmeulji_font, bm_matched_size)
	hbox.add_child(bm_col)

	_add_separator(hbox)

	# --- Column 4: Pixelmix matched size ---
	var px_matched_col := _create_font_column("Pixelmix @ %dpx (matched)" % px_matched_size, variant, _pixelmix_font, px_matched_size)
	hbox.add_child(px_matched_col)

	_add_separator(hbox)

	# --- Column 5: Korean Calligraphy matched size ---
	var kr_col := _create_font_column("Korean @ %dpx (matched)" % kr_matched_size, variant, _korean_font, kr_matched_size)
	hbox.add_child(kr_col)

	_add_separator(hbox)

	# --- Column 6: YatraOne matched size ---
	var yt_matched_size: int = _get_matched_size(font_size, YATRA_SCALE)
	var yt_col := _create_font_column("YatraOne @ %dpx (matched)" % yt_matched_size, variant, _yatra_font, yt_matched_size)
	hbox.add_child(yt_col)

	_add_separator(hbox)

	# --- Column 7: Ubage matched size ---
	var ub_matched_size: int = _get_matched_size(font_size, UBAGE_SCALE)
	var ub_col := _create_font_column("Ubage @ %dpx (matched)" % ub_matched_size, variant, _ubage_font, ub_matched_size)
	hbox.add_child(ub_col)


func _create_font_column(header_text: String, variant: Dictionary, font_override: Font, size_override: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.custom_minimum_size.x = 280
	col.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = header_text
	header.theme_type_variation = &"LabelEndCardMuted"
	col.add_child(header)

	# Dark background sample
	var sample_dark := _create_sample_panel(variant, Color(0.06, 0.04, 0.02, 1), font_override, size_override)
	col.add_child(sample_dark)

	# Light background sample
	var sample_light := _create_sample_panel(variant, Color(0.92, 0.88, 0.82, 1), font_override, size_override)
	col.add_child(sample_light)

	return col


func _create_sample_panel(variant: Dictionary, bg_color: Color, font_override: Font, size_override: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_content_margin_all(6)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var sample := Label.new()
	var theme_type: String = variant["theme_type"]
	if theme_type != "":
		sample.theme_type_variation = StringName(theme_type)

	if font_override:
		sample.add_theme_font_override("font", font_override)
	sample.add_theme_font_size_override("font_size", size_override)

	var o_size: int = variant.get("outline_size", 0)
	if o_size > 0:
		sample.add_theme_constant_override("outline_size", o_size)
		sample.add_theme_color_override("font_outline_color", variant["outline_color"])

	if size_override >= 52:
		sample.text = SAMPLE_SHORT
	else:
		sample.text = SAMPLE_TEXT
	sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(sample)

	return panel


func _add_stat_line(parent: VBoxContainer, stat_name: String, stat_value: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.theme_type_variation = &"LabelEndCardStatName"
	name_lbl.custom_minimum_size.x = 100
	hbox.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = stat_value
	value_lbl.theme_type_variation = &"LabelPathBody"
	hbox.add_child(value_lbl)


func _add_separator(parent: HBoxContainer) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	parent.add_child(sep)


func _add_spacer(parent: Control, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)


func _get_matched_size(m5x7_size: int, scale: float) -> int:
	return maxi(int(round(m5x7_size * scale)), 8)


func _color_to_display(color: Color) -> String:
	var hex := color.to_html(color.a < 1.0)
	var r := int(color.r * 255)
	var g := int(color.g * 255)
	var b := int(color.b * 255)
	if color.a < 1.0:
		return "#%s  (%d, %d, %d, %.0f%%)" % [hex, r, g, b, color.a * 100]
	return "#%s  (%d, %d, %d)" % [hex, r, g, b]
