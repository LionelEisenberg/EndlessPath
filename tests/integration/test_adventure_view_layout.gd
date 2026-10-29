extends GutTest

## Regression test: adventure_view.tscn's frame (the vitals cabinet, the chest and
## the technique dock) keeps its places through an editor save. An editor save
## drops an instance's properties that equal its scene's own, and a control in
## Position layout mode snaps to its parent's top-left corner when the mode is set
## on load, so in Position mode the boards landed at (0, 0) after a save of
## adventure_view.tscn (the zone furniture's fix, test_main_game_layout.gd). The
## scene is only instanced, never added to the tree.

const ADVENTURE_VIEW_SCENE: PackedScene = preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
## Each board's place on the 1920x1080 screen, by its path from the scene root.
const PLACES: Dictionary = {
	"VitalsPlate": Vector2(24, 24),
	"AdventureChest": Vector2(1456, 24),
	"TechniqueDock": Vector2(722, 856),
}

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_the_boards_keep_their_places_through_an_editor_save() -> void:
	var edited: Node = autofree(ADVENTURE_VIEW_SCENE.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE))
	var resaved := PackedScene.new()
	assert_eq(resaved.pack(edited), OK, "precondition: the scene packs as the editor saves it")
	var reloaded: Node = autofree(resaved.instantiate())
	_assert_places(reloaded, "after an editor save")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _assert_places(view: Node, when: String) -> void:
	for path: String in PLACES:
		var board: Control = view.get_node(path) as Control
		assert_eq(board.position, PLACES[path] as Vector2, "%s sits at its place %s" % [path, when])
