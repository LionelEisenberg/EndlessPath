extends GutTest

## Integration tests for where main_game.tscn places the zone view's furniture:
## the cultivator cabinet, the zone chest, the dock, the log and the Goals board.
## Each sits at its place in its own scene's root. An editor save drops an
## instance's properties that equal its scene's own, and a control in Position
## layout mode snaps to its parent's top-left corner when the mode is set on
## load, so in Position mode the furniture landed at (0, 0) after any save of
## main_game.tscn. The scene is only instanced, never added to the tree: its
## SaveTimer would write the real save.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/main/main_game/main_game.tscn")
## Each panel's place on the 1920x1080 screen, by its path from the scene root.
const PLACES: Dictionary = {
	"MainView/ZoneView/CultivatorPlate": Vector2(24, 24),
	"MainView/ZoneView/ZonePanel": Vector2(1456, 24),
	"MainView/ZoneView/Dock": Vector2(722, 976),
	"MainView/LogWindow": Vector2(24, 852),
	"MainView/GoalsPanel": Vector2(24, 276),
}

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_the_furniture_sits_at_its_places() -> void:
	var main_game: Node = autofree(MAIN_GAME_SCENE.instantiate())
	_assert_places(main_game, "as loaded")

func test_the_furniture_keeps_its_places_through_an_editor_save() -> void:
	var edited: Node = autofree(MAIN_GAME_SCENE.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE))
	var resaved := PackedScene.new()
	assert_eq(resaved.pack(edited), OK, "precondition: the scene packs as the editor saves it")
	var reloaded: Node = autofree(resaved.instantiate())
	_assert_places(reloaded, "after an editor save")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _assert_places(main_game: Node, when: String) -> void:
	for path: String in PLACES:
		var panel: Control = main_game.get_node(path) as Control
		assert_eq(panel.position, PLACES[path] as Vector2, "%s sits at its place %s" % [path.get_file(), when])
