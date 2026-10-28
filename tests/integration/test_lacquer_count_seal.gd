extends GutTest

## Integration tests for LacquerCountSeal, the kit's cinnabar count seal with a
## number on it, which the vitals cabinet's buff sockets, the zone dock's
## buttons and the technique dock's consumable sockets all instance. Its worn
## bites stay in the 6 px at each end, so it is a 9-slice that widens to fit a
## long count from the edge its user keeps: no count is cut off.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SEAL_SCENE_PATH: String = "res://scenes/common/lacquer/lacquer_count_seal.tscn"
const SEAL_TEXTURE_PATH: String = "res://assets/ui/lacquer/lacquer_seal_count_ai.png"
## Each user's seals by unique name, with the edge each keeps (true: the right).
const USERS: Dictionary = {
	"res://scenes/adventure/vitals_plate/vitals_plate.tscn": {"BuffSeal1": true, "BuffSeal2": true, "BuffSeal3": true},
	"res://scenes/ui/dock/system_menu_button/system_menu_button.tscn": {"CountSeal": false},
	"res://scenes/ui/combat/technique_dock/consumable_slot/consumable_slot.tscn": {"CountSeal": true},
}

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A seal at (left, -6) in a parent that places its children by position, as
## its users do.
func _make_seal(left: float, grows_left: bool) -> LacquerCountSeal:
	var holder := Control.new()
	add_child_autofree(holder)
	var seal: LacquerCountSeal = load(SEAL_SCENE_PATH).instantiate()
	seal.grows_left = grows_left
	seal.position = Vector2(left, -6.0)
	holder.add_child(seal)
	return seal

func _label(seal: LacquerCountSeal) -> Label:
	return seal.get_node("%CountLabel") as Label

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_width_for() -> void:
	assert_eq(LacquerCountSeal.width_for(10.0), 24.0, "a short count keeps the seal's 24 px")
	assert_eq(LacquerCountSeal.width_for(30.0), 38.0, "a long one adds its padding")
	assert_eq(LacquerCountSeal.width_for(31.0), 40.0, "rounded up to even")

func test_a_short_count_keeps_the_seals_size() -> void:
	var seal := _make_seal(20.0, true)

	seal.show_count(3)

	assert_eq(_label(seal).text, "3")
	assert_eq(seal.size, Vector2(24.0, 24.0), "the seal's own 24x24")
	assert_eq(seal.position.x, 20.0, "where its user put it")

func test_a_long_count_grows_leftward_from_the_right_edge() -> void:
	var seal := _make_seal(28.0, true)

	seal.show_count(1234)

	assert_gt(seal.size.x, 24.0, "the seal widened")
	assert_eq(fmod(seal.size.x, 2.0), 0.0, "to an even width")
	assert_eq(seal.position.x + seal.size.x, 52.0, "its right edge stays")
	assert_eq(fmod(seal.position.x, 2.0), 0.0, "on the 2 px grid")
	assert_lte(_label(seal).get_minimum_size().x, seal.size.x, "the count fits in it")
	seal.show_count(3)
	assert_eq(seal.size.x, 24.0, "a short count takes it back to 24 px")
	assert_eq(seal.position.x, 28.0)

func test_a_long_count_grows_rightward_from_the_left_edge() -> void:
	var seal := _make_seal(-6.0, false)

	seal.show_count(1234)

	assert_gt(seal.size.x, 24.0, "the seal widened")
	assert_eq(seal.position.x, -6.0, "its left edge stays")

func test_a_count_set_before_it_is_ready_shows_once_it_is() -> void:
	var seal: LacquerCountSeal = load(SEAL_SCENE_PATH).instantiate()
	seal.show_count(120)

	add_child_autofree(seal)

	assert_eq(_label(seal).text, "120")
	assert_gt(seal.size.x, 24.0, "fitted to the count as it enters the tree")

func test_scene_uses_the_kit() -> void:
	var seal := _make_seal(0.0, true)
	var face := seal.get_node("Seal") as NinePatchRect
	var label := _label(seal)

	assert_eq(face.texture.resource_path, SEAL_TEXTURE_PATH)
	assert_eq([face.patch_margin_left, face.patch_margin_top, face.patch_margin_right, face.patch_margin_bottom], [6, 0, 6, 0], "a 9-slice that stretches its plain middle")
	assert_eq(label.theme_type_variation, &"LabelLacquerSeal")
	assert_eq(label.get_theme_font_size(&"font_size"), 15, "the count seals' 15 px")
	assert_false(label.clip_text, "never clips")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "never trims")
	for node: Control in [seal, face, label]:
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to what it sits on" % node.name)

func test_every_count_seal_is_this_one() -> void:
	for path: String in USERS:
		var board: Node = autofree((load(path) as PackedScene).instantiate())
		var seals: Dictionary = USERS[path]
		for seal_name: String in seals:
			var seal := board.get_node_or_null("%" + seal_name) as LacquerCountSeal
			assert_not_null(seal, "%s's %s is a LacquerCountSeal" % [path.get_file(), seal_name])
			if seal != null:
				assert_eq(seal.grows_left, seals[seal_name], "%s's %s keeps its %s edge" % [path.get_file(), seal_name, "right" if seals[seal_name] else "left"])
