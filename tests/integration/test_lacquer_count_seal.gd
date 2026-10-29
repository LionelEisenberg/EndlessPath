extends GutTest

## Integration tests for LacquerCountSeal, the kit's cinnabar count seal with a
## number on it, which the vitals cabinet's buff sockets, the zone dock's
## buttons and the technique dock's consumable sockets all instance. It widens
## to fit a long count, so no count is cut off, and it leaves the pointer to
## what it sits on.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SEAL_SCENE_PATH: String = "res://scenes/common/lacquer/lacquer_count_seal.tscn"

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

func test_a_long_count_widens_the_seal_to_fit() -> void:
	var seal := _make_seal(28.0, true)

	seal.show_count(1234)

	assert_gt(seal.size.x, 24.0, "the seal widened")
	assert_lte(_label(seal).get_minimum_size().x, seal.size.x, "the count fits in it")

func test_a_count_set_before_it_is_ready_shows_once_it_is() -> void:
	var seal: LacquerCountSeal = load(SEAL_SCENE_PATH).instantiate()
	seal.show_count(120)

	add_child_autofree(seal)

	assert_eq(_label(seal).text, "120")
	assert_gt(seal.size.x, 24.0, "fitted to the count as it enters the tree")

func test_seal_leaves_the_pointer_to_what_it_sits_on() -> void:
	var seal := _make_seal(0.0, true)
	var face := seal.get_node("Seal") as NinePatchRect
	var label := _label(seal)

	for node: Control in [seal, face, label]:
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to what it sits on" % node.name)
