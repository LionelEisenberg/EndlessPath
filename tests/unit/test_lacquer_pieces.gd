extends GutTest

## Unit tests for the lacquer kit's shared pieces: the frame strip rect, the
## stepped rod, the brass frame overlay's flash, the floater and the text
## helpers.

const THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
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

## The decimal point in Yatra One, its ascent and descent trimmed by 3 px so
## the dot never makes its line taller (the mock's `.pt { line-height: 0 }`).
const YATRA_POINT: String = "[font name=res://assets/fonts/YatraOne-Regular.ttf top_spacing=-3 bottom_spacing=-3].[/font]"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _theme() -> Theme:
	return load(THEME_PATH) as Theme

## A RichTextLacquer label sized to its content, in the tree.
func _make_rich_text(bbcode: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.theme = _theme()
	rich.theme_type_variation = &"RichTextLacquer"
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

#-----------------------------------------------------------------------------
# ROD
#-----------------------------------------------------------------------------

func test_rod_steps() -> void:
	var rod := _make_well_rod()

	rod.set_fraction(0.0)
	assert_eq(rod.get_step(), 0)

	rod.set_fraction(1.0 / 152.0)
	assert_eq(rod.get_step(), 1)

	rod.set_fraction(0.5)
	assert_eq(rod.get_step(), 76)

func test_rod_clamps() -> void:
	var rod := _make_well_rod()
	rod.set_fraction(-0.5)
	assert_eq(rod.get_step(), 0)
	rod.set_fraction(2.0)
	assert_eq(rod.get_step(), 152)

#-----------------------------------------------------------------------------
# FRAME OVERLAY
#-----------------------------------------------------------------------------

func test_frame_overlay_starts_hidden_and_ignores_the_mouse() -> void:
	var overlay: LacquerFrameOverlay = FRAME_OVERLAY_SCENE.instantiate() as LacquerFrameOverlay
	add_child_autofree(overlay)
	assert_false(overlay.visible)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)

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

func test_flash_shows_and_ends_hidden() -> void:
	var overlay: LacquerFrameOverlay = FRAME_OVERLAY_SCENE.instantiate() as LacquerFrameOverlay
	add_child_autofree(overlay)
	overlay.flash(2)
	assert_true(overlay.visible, "shown at once")
	assert_true(overlay.is_flashing())
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

func test_floater_pops_a_haul_as_counts_and_icons() -> void:
	var floater: LacquerFloater = FLOATER_SCENE.instantiate() as LacquerFloater
	add_child_autofree(floater)
	var dew := MaterialDefinitionData.new()
	dew.item_name = "Dewdrop Tear"
	dew.mini_icon = PlaceholderTexture2D.new()
	var nameless := MaterialDefinitionData.new()
	nameless.item_name = "Iconless Stone"
	floater.pop_items({dew: 3, nameless: 1}, ThemeConstants.LACQUER_CREAM)
	var text: RichTextLabel = floater.get_node("%Text") as RichTextLabel
	assert_true(floater.visible, "pop_items shows the floater")
	assert_eq(floater.get_text(), "+3  +1", "the counts, two spaces between items")
	assert_eq(floater.get_icons(), [dew.mini_icon] as Array[Texture2D], "an item's mini icon stands for its name")
	assert_false(text.get_parsed_text().contains("Dewdrop"), "no name beside an icon")
	assert_string_contains(text.get_parsed_text(), "Iconless Stone", "an item with no icon keeps its name")
	floater.pop("+1.5 Madra", ThemeConstants.LACQUER_MADRA)
	assert_true(floater.get_icons().is_empty(), "plain text clears the icons")

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
