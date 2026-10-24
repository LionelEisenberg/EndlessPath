extends GutTest

## Unit tests for the lacquer theme and its shared pieces: the frame strip
## rect, the stepped rod, the brass frame overlay's flash, the floater, the
## text helpers, the theme variants (kit §3), the 9-slice styleboxes (kit §4),
## the wrapped Label's 1 px pad and the Madra orb shader's colour uniforms.

const THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const MADRA_ORB_SHADER_PATH: String = "res://assets/shaders/lacquer_madra_orb.gdshader"
const WRAP_PAD_PATH: String = "res://assets/styleboxes/lacquer/wrap_pad.tres"
const ROD_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_rod.tscn")
const FRAME_OVERLAY_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_frame_overlay.tscn")
const FLOATER_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_floater/lacquer_floater.tscn")
## One 60 FPS frame, for stepping the flash's tween by hand.
const FRAME: float = 1.0 / 60.0

const CORE_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_orb_core_strip_ai.png")
const MADRA_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_orb_madra_strip_ai.png")
const ROD_WELL_EMPTY: Texture2D = preload("res://assets/ui/lacquer/lacquer_rod_well_empty_ai.png")
const ROD_WELL_FULL: Texture2D = preload("res://assets/ui/lacquer/lacquer_rod_well_full_ai.png")
const ROD_WELL_END: Texture2D = preload("res://assets/ui/lacquer/lacquer_rod_well_end_ai.png")

const YATRA_PATH: String = "res://assets/fonts/YatraOne-Regular.ttf"
const EULJIRO_PATH: String = "res://assets/fonts/BMEULJIROTTF.ttf"
## The decimal point in Yatra One, its ascent and descent trimmed by 3 px so
## the dot never makes its line taller (the mock's `.pt { line-height: 0 }`).
const YATRA_POINT: String = "[font name=res://assets/fonts/YatraOne-Regular.ttf top_spacing=-3 bottom_spacing=-3].[/font]"

## [variant, font path, font size, colour, kit line height] for every Label
## variant (kit §3). The line height is the kit's: wrapped lines step by it.
var _label_variants: Array[Array] = [
	[&"LabelLacquerZoneName", YATRA_PATH, 30, ThemeConstants.LACQUER_BRASS, 44],
	[&"LabelLacquerPanelTitle", YATRA_PATH, 22, ThemeConstants.LACQUER_BRASS, 28],
	[&"LabelLacquerSection", YATRA_PATH, 20, ThemeConstants.LACQUER_BRASS, 24],
	[&"LabelLacquerStage", YATRA_PATH, 21, ThemeConstants.LACQUER_CREAM, 28],
	[&"LabelLacquerBig", EULJIRO_PATH, 30, ThemeConstants.LACQUER_CREAM, 36],
	[&"LabelLacquerGold", EULJIRO_PATH, 22, ThemeConstants.LACQUER_CREAM, 28],
	[&"LabelLacquerName", EULJIRO_PATH, 17, ThemeConstants.LACQUER_CREAM, 20],
	[&"LabelLacquerRate", EULJIRO_PATH, 17, ThemeConstants.LACQUER_TAN, 20],
	[&"LabelLacquerNowName", EULJIRO_PATH, 18, ThemeConstants.LACQUER_CREAM, 22],
	[&"LabelLacquerNowRate", EULJIRO_PATH, 16, ThemeConstants.LACQUER_CREAM, 22],
	[&"LabelLacquerDetail", EULJIRO_PATH, 15, ThemeConstants.LACQUER_TAN, 18],
	[&"LabelLacquerTag", EULJIRO_PATH, 13, ThemeConstants.LACQUER_TAN, 22],
	[&"LabelLacquerSeal", EULJIRO_PATH, 13, ThemeConstants.LACQUER_CREAM, 22],
	[&"LabelLacquerLegend", EULJIRO_PATH, 14, ThemeConstants.LACQUER_INK, 22],
	[&"LabelLacquerDock", EULJIRO_PATH, 14, ThemeConstants.LACQUER_CREAM, 18],
	[&"LabelLacquerHotkey", EULJIRO_PATH, 14, ThemeConstants.LACQUER_TAN, 18],
	[&"LabelLacquerLore", EULJIRO_PATH, 16, ThemeConstants.LACQUER_CREAM, 22],
	[&"LabelLacquerPlateName", EULJIRO_PATH, 16, ThemeConstants.LACQUER_CREAM, 18],
	[&"LabelLacquerPlateLine", EULJIRO_PATH, 14, ThemeConstants.LACQUER_CREAM, 18],
	[&"LabelLacquerPopoverTitle", EULJIRO_PATH, 18, ThemeConstants.LACQUER_CREAM, 22],
	[&"LabelLacquerPopoverBody", EULJIRO_PATH, 15, ThemeConstants.LACQUER_CREAM, 20],
	[&"LabelLacquerFloater", EULJIRO_PATH, 16, ThemeConstants.LACQUER_CREAM, 20],
]

## The painted titles: the only variants with the kit's 2 px ink text shadow.
const SHADOWED_VARIANTS: Array[StringName] = [
	&"LabelLacquerZoneName",
	&"LabelLacquerPanelTitle",
	&"LabelLacquerSection",
	&"LabelLacquerStage",
]

## Mode tags and seals are set with 1 px letter spacing (kit §3, the mock's CSS).
const SPACED_VARIANTS: Array[StringName] = [&"LabelLacquerTag", &"LabelLacquerSeal"]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _theme() -> Theme:
	return load(THEME_PATH) as Theme

func _font_path(font: Font) -> String:
	if font is FontVariation:
		return (font as FontVariation).base_font.resource_path
	return font.resource_path

## A label in the lacquer theme, in the tree and laid out.
func _make_label(variant: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme = _theme()
	label.theme_type_variation = variant
	label.text = text
	add_child_autofree(label)
	return label

## A RichTextLacquer label sized to its content, in the tree. A font_size
## above 0 overrides the variant's 15 px.
func _make_rich_text(bbcode: String, font_size: int = 0) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.theme = _theme()
	rich.theme_type_variation = &"RichTextLacquer"
	if font_size > 0:
		rich.add_theme_font_size_override(&"normal_font_size", font_size)
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich.text = bbcode
	add_child_autofree(rich)
	return rich

func _make_well_rod() -> LacquerRod:
	var rod: LacquerRod = ROD_SCENE.instantiate() as LacquerRod
	rod.empty_texture = ROD_WELL_EMPTY
	rod.full_texture = ROD_WELL_FULL
	rod.end_texture = ROD_WELL_END
	rod.steps = 152
	add_child_autofree(rod)
	return rod

## The default a shader declares for a colour uniform, read from its code
## (`uniform vec4 name : source_color = vec4(r, g, b, a);`), or null when the
## code declares none. Headless Godot returns no parameter defaults from the
## RenderingServer, so the declaration is the only place to read one.
func _declared_colour(code: String, uniform_name: String) -> Variant:
	var declaration := RegEx.new()
	declaration.compile("uniform\\s+vec4\\s+" + uniform_name + "\\s*:\\s*source_color\\s*=\\s*vec4\\(([^)]*)\\)\\s*;")
	var found: RegExMatch = declaration.search(code)
	if found == null:
		return null
	var channels: PackedStringArray = found.get_string(1).split(",")
	if channels.size() != 4:
		return null
	return Color(channels[0].to_float(), channels[1].to_float(), channels[2].to_float(), channels[3].to_float())

## Every .tscn under a folder, subfolders included.
func _scene_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	for subfolder: String in DirAccess.get_directories_at(folder):
		found.append_array(_scene_files(folder.path_join(subfolder)))
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tscn"):
			found.append(folder.path_join(file))
	return found

#-----------------------------------------------------------------------------
# STRIP RECT
#-----------------------------------------------------------------------------

func test_strip_rect_selects_frame() -> void:
	var rect := LacquerStripRect.new()
	rect.strip = CORE_STRIP
	rect.frame_size = Vector2i(80, 80)
	add_child_autofree(rect)
	rect.set_frame(3, 1)
	var atlas: AtlasTexture = rect.texture as AtlasTexture
	assert_not_null(atlas, "the rect draws through an AtlasTexture")
	assert_eq(atlas.atlas, CORE_STRIP, "the atlas is the strip")
	assert_eq(atlas.region, Rect2(240, 80, 80, 80), "frame (3, 1) of 80x80 frames")
	assert_eq(rect.get_frame(), Vector2i(3, 1))

func test_strip_rect_defaults_to_frame_zero() -> void:
	var rect := LacquerStripRect.new()
	rect.strip = MADRA_STRIP
	rect.frame_size = Vector2i(80, 80)
	add_child_autofree(rect)
	assert_eq((rect.texture as AtlasTexture).region, Rect2(0, 0, 80, 80))
	assert_eq(rect.get_minimum_size(), Vector2(80, 80), "the rect shows one frame at its file size")

func test_strip_rect_clamps_to_the_strip() -> void:
	var rect := LacquerStripRect.new()
	rect.strip = MADRA_STRIP
	rect.frame_size = Vector2i(80, 80)
	add_child_autofree(rect)
	rect.set_frame(99, 3)
	assert_eq(rect.get_frame(), Vector2i(32, 0), "the Madra strip has 33 frames in one row")
	rect.set_frame(-4)
	assert_eq(rect.get_frame(), Vector2i(0, 0))

func test_strip_rects_do_not_share_their_atlas() -> void:
	var first := LacquerStripRect.new()
	var second := LacquerStripRect.new()
	for rect: LacquerStripRect in [first, second]:
		rect.strip = MADRA_STRIP
		rect.frame_size = Vector2i(80, 80)
		add_child_autofree(rect)
	first.set_frame(5)
	assert_eq((second.texture as AtlasTexture).region, Rect2(0, 0, 80, 80), "each rect owns its AtlasTexture")

func test_strip_rect_saves_its_strip_not_its_atlas() -> void:
	# The rect runs in the editor (@tool), so its derived AtlasTexture must
	# not be written into the scenes that place it: strip and frame_size are
	# the saved state.
	var owner_node := Control.new()
	add_child_autofree(owner_node)
	var rect := LacquerStripRect.new()
	rect.strip = MADRA_STRIP
	rect.frame_size = Vector2i(80, 80)
	owner_node.add_child(rect)
	rect.owner = owner_node
	var packed := PackedScene.new()
	assert_eq(packed.pack(owner_node), OK)
	var state: SceneState = packed.get_state()
	var saved: Array[StringName] = []
	for i: int in state.get_node_property_count(1):
		saved.append(state.get_node_property_name(1, i))
	assert_does_not_have(saved, &"texture", "the AtlasTexture is rebuilt from strip and frame_size")
	assert_has(saved, &"strip")
	assert_has(saved, &"frame_size")

func test_pieces_show_in_the_editor() -> void:
	# Builders place strip rects and rods in .tscn files: they must draw there.
	assert_true((load("res://scenes/common/lacquer/lacquer_strip_rect.gd") as Script).is_tool(), "LacquerStripRect is @tool")
	assert_true((load("res://scenes/common/lacquer/lacquer_rod.gd") as Script).is_tool(), "LacquerRod is @tool")

#-----------------------------------------------------------------------------
# ROD
#-----------------------------------------------------------------------------

func test_rod_steps() -> void:
	var rod := _make_well_rod()
	var full_clip: Control = rod.get_node("%FullClip") as Control
	var end_cap: TextureRect = rod.get_node("%End") as TextureRect

	rod.set_fraction(0.0)
	assert_eq(rod.get_step(), 0)
	assert_eq(full_clip.size.x, 2.0, "an empty rod still shows the full rod's 2 px lip")
	assert_false(end_cap.visible, "no end cap below step 2")

	rod.set_fraction(1.0 / 152.0)
	assert_eq(rod.get_step(), 1)
	assert_false(end_cap.visible, "no end cap at step 1")

	rod.set_fraction(0.5)
	assert_eq(rod.get_step(), 76)
	assert_eq(full_clip.size.x, 154.0, "width 2 + 2k")
	assert_eq(end_cap.position.x, 152.0, "end cap at x = 2k")
	assert_true(end_cap.visible)

func test_rod_clamps() -> void:
	var rod := _make_well_rod()
	rod.set_fraction(-0.5)
	assert_eq(rod.get_step(), 0)
	rod.set_fraction(2.0)
	assert_eq(rod.get_step(), 152)
	assert_eq((rod.get_node("%FullClip") as Control).size.x, 306.0)

func test_rod_is_the_size_of_its_groove() -> void:
	var rod := _make_well_rod()
	assert_eq(rod.get_combined_minimum_size(), Vector2(308, 10))
	assert_eq(rod.custom_minimum_size, Vector2.ZERO, "the size comes from the groove, not a saved custom_minimum_size")
	assert_true((rod.get_node("%FullClip") as Control).clip_contents, "the full rod is clipped, not scaled")

#-----------------------------------------------------------------------------
# FRAME OVERLAY
#-----------------------------------------------------------------------------

func test_frame_overlay_starts_hidden_and_ignores_the_mouse() -> void:
	var overlay: LacquerFrameOverlay = FRAME_OVERLAY_SCENE.instantiate() as LacquerFrameOverlay
	add_child_autofree(overlay)
	assert_false(overlay.visible)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var style: StyleBoxTexture = overlay.get_theme_stylebox(&"panel") as StyleBoxTexture
	assert_not_null(style, "the overlay draws a 9-slice texture")
	assert_false(style.draw_center, "the frame has no fill")

## Moves every running tween in the tree on by `seconds`, a 60 FPS frame at a
## time, as frames would.
func _run_tweens(seconds: float) -> void:
	for _frame: int in roundi(seconds / FRAME):
		for tween: Tween in get_tree().get_processed_tweens():
			if tween.is_valid() and tween.is_running():
				tween.custom_step(FRAME)

## Runs 60 FPS frames of tweens until `done` returns true or `limit` seconds
## pass.
func _run_tweens_until(done: Callable, limit: float) -> void:
	for _frame: int in roundi(limit / FRAME):
		if done.call():
			return
		_run_tweens(FRAME)

func test_flash_toggles_and_ends_hidden() -> void:
	var overlay: LacquerFrameOverlay = FRAME_OVERLAY_SCENE.instantiate() as LacquerFrameOverlay
	add_child_autofree(overlay)
	overlay.flash(2)
	assert_true(overlay.visible, "shown at once")
	assert_true(overlay.is_flashing())
	_run_tweens(0.45)
	assert_false(overlay.visible, "hidden in the first off phase (0.3 to 0.6 s)")
	_run_tweens(0.3)
	assert_true(overlay.visible, "shown again for the second flash (0.6 to 0.9 s)")
	_run_tweens_until(func() -> bool: return not overlay.is_flashing(), 2.0)
	assert_false(overlay.is_flashing())
	assert_false(overlay.visible, "the flash ends hidden")

func test_flash_restarts_cleanly() -> void:
	# Restart in the middle of a longer flash: the first one would show the
	# frame again at 1.2 s, after the new one has ended, if its tween lived on.
	var overlay: LacquerFrameOverlay = FRAME_OVERLAY_SCENE.instantiate() as LacquerFrameOverlay
	add_child_autofree(overlay)
	overlay.flash(3)
	_run_tweens(0.45)
	overlay.flash(1)
	assert_true(overlay.visible, "a new flash shows the frame at once")
	_run_tweens_until(func() -> bool: return not overlay.is_flashing(), 2.0)
	assert_false(overlay.visible)
	_run_tweens(0.3)
	assert_false(overlay.visible, "the first flash's tween is gone")

#-----------------------------------------------------------------------------
# FLOATER
#-----------------------------------------------------------------------------

func test_floater_pops_on_an_even_token() -> void:
	# The floater stands on its own, without MapMarkers: a cycling-style hit
	# line ("PERFECT +25 XP") pops onto a token on the kit's 2 px grid.
	var floater: LacquerFloater = FLOATER_SCENE.instantiate() as LacquerFloater
	add_child_autofree(floater)
	floater.pop("PERFECT +25 XP", ThemeConstants.LACQUER_BRASS)
	assert_true(floater.visible, "pop shows the floater")
	assert_gt(floater.get_token_width(), LacquerFloater.TOKEN_TEXT_PADDING, "the text was measured: the token is wider than its padding")
	assert_eq(floater.get_token_width() % 2, 0, "the token is an even width, on the 2 px grid")
	assert_eq(floater.get_color(), ThemeConstants.LACQUER_BRASS)
	assert_eq(LacquerFloater.rise_at(0.05), 2, "the first 2 px step comes at 50 ms")

#-----------------------------------------------------------------------------
# TEXT
#-----------------------------------------------------------------------------

func test_rate_format() -> void:
	assert_eq(LacquerText.rate(1.5), "+1.5")
	assert_eq(LacquerText.rate(2.0), "+2")
	assert_eq(LacquerText.rate(0.5), "+0.5")
	assert_eq(LacquerText.rate(0.25), "+0.25")

func test_decimal_bbcode_wraps_only_between_digits() -> void:
	assert_eq(LacquerText.decimal_bbcode("+1.5 Madra / s"), "+1" + YATRA_POINT + "5 Madra / s")
	assert_eq(LacquerText.decimal_bbcode("Lv 1 → 2."), "Lv 1 → 2.")
	assert_eq(LacquerText.decimal_bbcode("1.5 and 2.25"), "1" + YATRA_POINT + "5 and 2" + YATRA_POINT + "25")
	assert_eq(LacquerText.decimal_bbcode("[x] 1.5"), "[lb]x] 1" + YATRA_POINT + "5", "a [ in the text is escaped")

func test_decimal_bbcode_shows_brackets_as_text() -> void:
	# The input is plain text: a name like "[b]old" must not turn into a tag
	# and swallow the rest of the line.
	var rich := _make_rich_text(LacquerText.decimal_bbcode("[b]old [url]Madra 1.5"))
	assert_eq(rich.get_parsed_text(), "[b]old [url]Madra 1.5")

func test_decimal_line_keeps_the_kit_line_height() -> void:
	# Kit §3: RichTextLacquer lines are 15/18. Plain Yatra One would grow a
	# line with a decimal to 24 px and drop its baseline 3 px.
	var one := _make_rich_text(LacquerText.decimal_bbcode("+1.5 Madra / s"))
	var two := _make_rich_text(LacquerText.decimal_bbcode("+1.5 Madra / s") + "\nTrain or cycle to fill")
	await wait_process_frames(2)
	assert_eq(one.get_parsed_text(), "+1.5 Madra / s", "the dot is still there")
	assert_eq(one.get_content_height(), 18, "one decimal line is 18 px")
	assert_eq(two.get_line_offset(1), 18.0, "the second line starts 18 px down")
	assert_eq(two.get_content_height(), 36, "two lines step by 18 px")

func test_decimal_point_never_grows_a_line() -> void:
	# Card details (15), plate lines (14), the Now rate (16), the cabinet rate
	# (17): the decimal line is as tall as the same line without the dot.
	for font_size: int in [13, 14, 15, 16, 17, 18]:
		var with_point := _make_rich_text(LacquerText.decimal_bbcode("+1.5 Madra / s"), font_size)
		var plain := _make_rich_text("+15 Madra / s", font_size)
		await wait_process_frames(2)
		assert_eq(with_point.get_content_height(), plain.get_content_height(), "decimal line height at %d px" % font_size)

#-----------------------------------------------------------------------------
# THEME
#-----------------------------------------------------------------------------

func test_theme_has_variants() -> void:
	var theme := _theme()
	assert_not_null(theme, "the lacquer theme loads")
	for row: Array in _label_variants:
		var variant: StringName = row[0]
		assert_eq(theme.get_type_variation_base(variant), &"Label", "%s is a Label variant" % variant)
		assert_true(theme.has_font_size(&"font_size", variant), "%s sets its own size" % variant)
		assert_eq(theme.get_font_size(&"font_size", variant), row[2], "%s size" % variant)
		assert_true(theme.has_font(&"font", variant), "%s sets its own font" % variant)
		assert_eq(_font_path(theme.get_font(&"font", variant)), row[1], "%s font" % variant)
		assert_eq(theme.get_color(&"font_color", variant), row[3], "%s colour" % variant)

func test_zone_name_uses_yatra_one() -> void:
	var font: Font = _theme().get_font(&"font", &"LabelLacquerZoneName")
	assert_eq(font.resource_path, YATRA_PATH)

func test_theme_sets_no_defaults() -> void:
	# A default font or size would answer for every type before pixel_theme's
	# own variants are reached, so reused pieces inside a lacquer panel would
	# lose their sizes (UI_STYLING.md, LabelMerchantTitle).
	var theme := _theme()
	assert_false(theme.has_default_font())
	assert_false(theme.has_default_font_size())

func test_wrapped_lines_step_by_the_kit_line_height() -> void:
	# Measured on real Labels: a second line adds exactly the kit's line height.
	var pairs: Array[Array] = []
	for row: Array in _label_variants:
		pairs.append([row, _make_label(row[0], "Ag"), _make_label(row[0], "Ag\nAg")])
	await wait_process_frames(2)
	for pair: Array in pairs:
		var row: Array = pair[0]
		var one: Label = pair[1]
		var two: Label = pair[2]
		var pitch: float = two.get_minimum_size().y - one.get_minimum_size().y
		assert_eq(pitch, float(row[4]), "%s line pitch" % row[0])

func test_rich_text_lines_step_by_18() -> void:
	var rich := _make_rich_text("Ready in ~4 s\nTrain or cycle to fill")
	await wait_process_frames(2)
	assert_eq(rich.get_line_offset(1), 18.0)
	assert_eq(rich.get_content_height(), 36)

func test_only_painted_titles_cast_a_shadow() -> void:
	var theme := _theme()
	for row: Array in _label_variants:
		var variant: StringName = row[0]
		var shadow: Color = theme.get_color(&"font_shadow_color", variant)
		if variant in SHADOWED_VARIANTS:
			assert_eq(shadow, ThemeConstants.LACQUER_INK, "%s shadow colour" % variant)
			assert_eq(theme.get_constant(&"shadow_offset_x", variant), 2, "%s shadow x" % variant)
			assert_eq(theme.get_constant(&"shadow_offset_y", variant), 2, "%s shadow y" % variant)
			assert_true(theme.has_constant(&"shadow_outline_size", variant), "%s sets its shadow outline" % variant)
			assert_eq(theme.get_constant(&"shadow_outline_size", variant), 0, "%s shadow is a hard copy, not grown" % variant)
		else:
			assert_true(theme.has_color(&"font_shadow_color", variant), "%s overrides pixel_theme's shadow" % variant)
			assert_eq(shadow.a, 0.0, "%s has no shadow" % variant)

func test_tags_and_seals_are_letter_spaced() -> void:
	var theme := _theme()
	for variant: StringName in SPACED_VARIANTS:
		var font: FontVariation = theme.get_font(&"font", variant) as FontVariation
		assert_not_null(font, "%s uses a FontVariation" % variant)
		assert_eq(font.spacing_glyph, 1, "%s letter spacing" % variant)

func test_tags_and_seals_are_indented_1_px() -> void:
	# The 1 px letter spacing also trails the last letter, which would pull
	# centred text 0.5 px left. The mock adds text-indent: 1px; the theme gives
	# tags and seals a 1 px left content margin to match.
	var theme := _theme()
	for variant: StringName in SPACED_VARIANTS:
		var style: StyleBox = theme.get_stylebox(&"normal", variant)
		assert_true(theme.has_stylebox(&"normal", variant), "%s sets its own normal style" % variant)
		assert_true(style is StyleBoxEmpty, "%s draws nothing behind the text" % variant)
		assert_eq(style.get_margin(SIDE_LEFT), 1.0, "%s text-indent" % variant)
		assert_eq(style.get_margin(SIDE_RIGHT), 0.0, "%s right margin" % variant)
		assert_eq(style.get_margin(SIDE_TOP), 0.0, "%s top margin" % variant)
		assert_eq(style.get_margin(SIDE_BOTTOM), 0.0, "%s bottom margin" % variant)
	var tag := _make_label(&"LabelLacquerTag", "IDLE")
	await wait_process_frames(2)
	var text_width: float = tag.get_theme_font(&"font").get_string_size("IDLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	assert_eq(tag.get_minimum_size().x, text_width + 1.0, "a tag is its text plus the 1 px indent")

func test_floater_has_no_outline() -> void:
	# Kit §0 (revision 2): map floaters ride a lacquer token, "with no outline".
	# Set explicitly, so no outline from an ancestor theme can reach it.
	var theme := _theme()
	assert_true(theme.has_constant(&"outline_size", &"LabelLacquerFloater"), "the floater sets its outline size")
	assert_eq(theme.get_constant(&"outline_size", &"LabelLacquerFloater"), 0)

func test_cooldown_variant() -> void:
	# A technique's cooldown seconds sit on its icon: Euljiro 22 in cream with the
	# painted titles' hard 2 px ink shadow, so the number reads over any icon.
	var theme := _theme()
	var variant: StringName = &"LabelLacquerCooldown"
	assert_eq(theme.get_type_variation_base(variant), &"Label", "a Label variant")
	assert_true(theme.has_font_size(&"font_size", variant), "sets its own size")
	assert_eq(theme.get_font_size(&"font_size", variant), 22, "size")
	assert_true(theme.has_font(&"font", variant), "sets its own font")
	assert_eq(_font_path(theme.get_font(&"font", variant)), EULJIRO_PATH, "font")
	assert_eq(theme.get_color(&"font_color", variant), ThemeConstants.LACQUER_CREAM, "colour")
	assert_eq(theme.get_color(&"font_shadow_color", variant), ThemeConstants.LACQUER_INK, "shadow colour")
	assert_eq(theme.get_constant(&"shadow_offset_x", variant), 2, "shadow x")
	assert_eq(theme.get_constant(&"shadow_offset_y", variant), 2, "shadow y")
	assert_true(theme.has_constant(&"shadow_outline_size", variant), "sets its shadow outline")
	assert_eq(theme.get_constant(&"shadow_outline_size", variant), 0, "the shadow is a hard copy, not grown")

func test_rich_text_variant() -> void:
	var theme := _theme()
	assert_eq(theme.get_type_variation_base(&"RichTextLacquer"), &"RichTextLabel")
	assert_eq(_font_path(theme.get_font(&"normal_font", &"RichTextLacquer")), EULJIRO_PATH)
	assert_eq(theme.get_font_size(&"normal_font_size", &"RichTextLacquer"), 15)
	assert_eq(theme.get_color(&"default_color", &"RichTextLacquer"), ThemeConstants.LACQUER_TAN)

#-----------------------------------------------------------------------------
# STYLEBOXES
#-----------------------------------------------------------------------------

func test_frame_styleboxes_are_unfilled_nine_slices() -> void:
	var brass: StyleBoxTexture = load("res://assets/styleboxes/lacquer/frame_brass.tres") as StyleBoxTexture
	var hover: StyleBoxTexture = load("res://assets/styleboxes/lacquer/frame_hover.tres") as StyleBoxTexture
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(brass.get_texture_margin(side), 8.0, "frame_brass margin")
		assert_eq(hover.get_texture_margin(side), 4.0, "frame_hover margin")
	assert_false(brass.draw_center)
	assert_false(hover.draw_center)

func test_rail_thumb_is_a_vertical_three_slice() -> void:
	var thumb: StyleBoxTexture = load("res://assets/styleboxes/lacquer/rail_thumb.tres") as StyleBoxTexture
	assert_eq(thumb.texture_margin_top, 4.0)
	assert_eq(thumb.texture_margin_bottom, 4.0)
	assert_eq(thumb.texture_margin_left, 0.0)
	assert_eq(thumb.texture_margin_right, 0.0)
	assert_true(thumb.draw_center)

func test_token_margins_skip_its_baked_shadow() -> void:
	var token: StyleBoxTexture = load("res://assets/styleboxes/lacquer/token.tres") as StyleBoxTexture
	assert_eq(token.texture_margin_left, 6.0)
	assert_eq(token.texture_margin_top, 6.0)
	assert_eq(token.texture_margin_right, 8.0)
	assert_eq(token.texture_margin_bottom, 8.0)
	assert_true(token.draw_center)

func test_token_hugs_a_floater_line() -> void:
	# Kit §0: the token is 28 px tall plus its 2 px baked shadow, the text line
	# (16/20) starts 4 px down, and the token is the text width + 28 wide.
	var panel := PanelContainer.new()
	panel.theme = _theme()
	panel.add_theme_stylebox_override(&"panel", load("res://assets/styleboxes/lacquer/token.tres") as StyleBoxTexture)
	add_child_autofree(panel)
	var line := RichTextLabel.new()
	line.theme_type_variation = &"RichTextLacquer"
	line.add_theme_font_size_override(&"normal_font_size", 16)
	line.bbcode_enabled = true
	line.fit_content = true
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.text = LacquerText.decimal_bbcode("+1.5 Madra")
	panel.add_child(line)
	await wait_process_frames(2)
	assert_eq(line.size.y, 20.0, "a 16 px RichTextLacquer line is 20 px")
	assert_eq(line.position, Vector2(14, 4), "the text sits 14 px in and 4 px down")
	assert_eq(panel.size.y, 30.0, "28 px token + 2 px shadow")
	assert_eq(panel.size.x, line.size.x + 30.0, "text + 28, + 2 px shadow")

func test_board9_margins() -> void:
	# The plain board under the tooltips: a 24x24 board with its 4 px shadow baked
	# into the right and bottom of a 28x28 file, so the slices are 8 px on the
	# left and top and 12 px on the right and bottom. The content margins keep the
	# text 16 px in and 14 px down, with the shadow's 4 px added on the far sides.
	var board: StyleBoxTexture = load("res://assets/styleboxes/lacquer/board9.tres") as StyleBoxTexture
	assert_not_null(board, "board9.tres loads as a StyleBoxTexture")
	if board == null:
		return
	assert_eq(board.texture.resource_path, "res://assets/ui/lacquer/lacquer_board9_ai.png")
	assert_eq(board.texture.get_size(), Vector2(28, 28), "a 24x24 board plus its 4 px shadow")
	assert_eq(board.texture_margin_left, 8.0, "texture margin left")
	assert_eq(board.texture_margin_top, 8.0, "texture margin top")
	assert_eq(board.texture_margin_right, 12.0, "texture margin right skips the shadow")
	assert_eq(board.texture_margin_bottom, 12.0, "texture margin bottom skips the shadow")
	assert_eq(board.content_margin_left, 16.0, "content margin left")
	assert_eq(board.content_margin_top, 14.0, "content margin top")
	assert_eq(board.content_margin_right, 20.0, "content margin right")
	assert_eq(board.content_margin_bottom, 18.0, "content margin bottom")
	assert_true(board.draw_center)

func test_wrap_pad_is_a_one_pixel_bottom_pad() -> void:
	# The `normal` style of a wrapped 15/18 or 18/22 Label: n lines come to 18 n or
	# 22 n instead of 18 n - 1 or 22 n - 1, so every row stays on an even y. It draws
	# nothing, adds one pixel under the text and nothing on the other three sides.
	var pad: StyleBox = load(WRAP_PAD_PATH) as StyleBox
	assert_not_null(pad, "wrap_pad.tres loads as a StyleBox")
	if pad == null:
		return
	assert_true(pad is StyleBoxEmpty, "it draws nothing")
	assert_eq(pad.get_margin(SIDE_BOTTOM), 1.0, "one pixel under the text")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT]:
		assert_eq(pad.get_margin(side), 0.0, "nothing on side %d" % side)
	assert_eq(pad.get_minimum_size(), Vector2(0, 1), "so a Label grows by a pixel and no width")

## A scene that uses wrap_pad.tres names it by the uid the file declares, in the
## text Godot writes (an id written with another alphabet decodes to the same
## number but is not what the editor saves, and the next save rewrites it).
func test_every_scene_names_wrap_pad_by_its_own_uid() -> void:
	var id: int = ResourceLoader.get_resource_uid(WRAP_PAD_PATH)
	assert_ne(id, ResourceUID.INVALID_ID, "precondition: wrap_pad.tres declares a uid")
	var uid_text: String = ResourceUID.id_to_text(id)
	var named: int = 0
	for path: String in _scene_files("res://scenes"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("[ext_resource") and line.contains("path=\"%s\"" % WRAP_PAD_PATH):
				named += 1
				assert_true(line.contains("uid=\"%s\"" % uid_text), "%s names wrap_pad.tres as %s" % [path.get_file(), uid_text])
	assert_gte(named, 4, "precondition: the walk met the scenes that use it (the drawer, the page, the Goals board, the Now strip)")

#-----------------------------------------------------------------------------
# THEME CONSTANTS
#-----------------------------------------------------------------------------

func test_lacquer_palette_matches_the_kit() -> void:
	assert_eq(ThemeConstants.LACQUER_INK, Color("#150909"))
	assert_eq(ThemeConstants.LACQUER_RIM, Color("#692F2F"))
	assert_eq(ThemeConstants.LACQUER_BRASS, Color("#D4A84A"))
	assert_eq(ThemeConstants.LACQUER_CREAM, Color("#F0E8D8"))
	assert_eq(ThemeConstants.LACQUER_TAN, Color("#A89070"))
	assert_eq(ThemeConstants.LACQUER_DIM, Color("#94806A"))
	assert_eq(ThemeConstants.LACQUER_MADRA_HI, Color("#E8F6FD"))
	assert_eq(ThemeConstants.LACQUER_MADRA, Color("#BBD5E7"))
	assert_eq(ThemeConstants.LACQUER_MADRA_MID, Color("#849BE4"))
	assert_eq(ThemeConstants.LACQUER_VERMILION, Color("#A83C30"))

func test_vitals_colours() -> void:
	# The text colours of the Health crimson and Stamina bamboo ramps.
	assert_eq(ThemeConstants.LACQUER_HEALTH, Color("#E8737A"))
	assert_eq(ThemeConstants.LACQUER_STAMINA, Color("#C9DB86"))

#-----------------------------------------------------------------------------
# MADRA ORB SHADER
#-----------------------------------------------------------------------------

func test_orb_colours_default_to_madra() -> void:
	# The liquid's ramp is three colour uniforms so the Health orb can set its own
	# crimson on its material. Their defaults are the Madra ramp, which keeps the
	# cultivator cabinet's orb as it was without setting anything but `progress`.
	var shader: Shader = load(MADRA_ORB_SHADER_PATH) as Shader
	assert_not_null(shader, "the Madra orb shader loads")
	if shader == null:
		return
	var uniform_types: Dictionary = {}
	for uniform: Dictionary in shader.get_shader_uniform_list():
		uniform_types[uniform["name"]] = uniform["type"]
	var madra_ramp: Dictionary = {
		"light": Color("#E8F6FD"),
		"pale": Color("#BBD5E7"),
		"blue": Color("#849BE4"),
	}
	for uniform_name: String in madra_ramp:
		assert_true(uniform_types.has(uniform_name), "%s is a shader uniform" % uniform_name)
		assert_eq(uniform_types.get(uniform_name), TYPE_COLOR, "%s is a colour" % uniform_name)
		var declared: Variant = _declared_colour(shader.code, uniform_name)
		assert_not_null(declared, "%s declares its default in the shader code" % uniform_name)
		if declared != null:
			var expected: Color = madra_ramp[uniform_name]
			assert_true((declared as Color).is_equal_approx(expected), "%s defaults to %s, the shader declares %s" % [uniform_name, expected, declared])
