extends GutTest

## EncounterCoin, the coin that marks an encounter on the adventure map (spec:
## The map, Coins): which tiles get one, its face in each state, and the glyph
## each face carries (the question mark none, whatever it is handed). The statics
## are called as the map layer calls them, and a real coin scene is set up as the
## map layer sets one up.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const EncounterCoinScene := preload("res://scenes/adventure/adventure_map_markers/encounter_coin/encounter_coin.tscn")
const Type := AdventureEncounter.EncounterType

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## An encounter of the given type, with no choices.
func _encounter(type: AdventureEncounter.EncounterType) -> AdventureEncounter:
	var encounter := AdventureEncounter.new()
	encounter.encounter_type = type
	return encounter

## A coin in the tree, set up for the type's glyph the way the map layer sets
## one up: its strip, frame size, frames and pace from the statics.
func _make_coin(face: EncounterCoin.Face, type: AdventureEncounter.EncounterType) -> EncounterCoin:
	var coin := EncounterCoinScene.instantiate() as EncounterCoin
	add_child_autofree(coin)
	_set_up(coin, face, type)
	return coin

## Sets the coin up for the face and the type's glyph (the spent one when the
## face is CLEARED).
func _set_up(coin: EncounterCoin, face: EncounterCoin.Face, type: AdventureEncounter.EncounterType) -> void:
	var cleared: bool = face == EncounterCoin.Face.CLEARED
	coin.setup(
		face,
		EncounterCoin.glyph_for(type, cleared),
		EncounterCoin.glyph_frame_size_for(type),
		EncounterCoin.glyph_frames_for(type, cleared),
		EncounterCoin.frame_seconds_for(type))

func _glyph(coin: EncounterCoin) -> LacquerStripRect:
	return coin.get_node("%Glyph") as LacquerStripRect

#-----------------------------------------------------------------------------
# WHICH TILES GET A COIN
#-----------------------------------------------------------------------------

func test_needs_coin() -> void:
	var fight: AdventureEncounter = _encounter(Type.COMBAT_REGULAR)
	var empty := NoOpEncounter.new()

	# A tile with something on it always has a coin: a "?" while it is only
	# revealed, its glyph once visited or dev revealed.
	assert_true(EncounterCoin.needs_coin(fight, false, false), "a revealed fight")
	assert_true(EncounterCoin.needs_coin(fight, true, false), "a visited fight")
	assert_true(EncounterCoin.needs_coin(fight, false, true), "a dev revealed fight")

	# A revealed empty tile keeps its "?", so a coin never gives away that a tile
	# is empty. Once it is visited, or shown by the dev override, there is
	# nothing left to mark.
	assert_true(EncounterCoin.needs_coin(empty, false, false), "a revealed empty tile keeps its question mark")
	assert_false(EncounterCoin.needs_coin(empty, true, false), "a visited empty tile has no coin")
	assert_false(EncounterCoin.needs_coin(empty, false, true), "a dev revealed empty tile has no coin")
	assert_false(EncounterCoin.needs_coin(null, true, false), "a visited tile the map holds nothing on")
	assert_false(EncounterCoin.needs_coin(null, false, true), "a dev revealed tile the map holds nothing on")

#-----------------------------------------------------------------------------
# THE FACE
#-----------------------------------------------------------------------------

func test_face_for_each_state() -> void:
	var fight: AdventureEncounter = _encounter(Type.COMBAT_REGULAR)
	var boss: AdventureEncounter = _encounter(Type.COMBAT_BOSS)
	var empty := NoOpEncounter.new()
	var glyph: EncounterCoin.Face = EncounterCoin.Face.GLYPH
	var unknown: EncounterCoin.Face = EncounterCoin.Face.UNKNOWN
	var cleared: EncounterCoin.Face = EncounterCoin.Face.CLEARED
	var boss_face: EncounterCoin.Face = EncounterCoin.Face.BOSS

	# face_for(encounter, visited, completed, dev_revealed)
	assert_eq(EncounterCoin.face_for(fight, true, true, false), cleared, "visited and resolved: carved")
	assert_eq(EncounterCoin.face_for(fight, true, false, false), glyph, "visited, not resolved: its glyph")
	assert_eq(EncounterCoin.face_for(fight, false, false, false), unknown, "only revealed: the question mark")
	assert_eq(EncounterCoin.face_for(fight, false, false, true), glyph, "dev revealed: its glyph")

	assert_eq(EncounterCoin.face_for(boss, false, false, false), boss_face, "a revealed boss shows through the veil")
	assert_eq(EncounterCoin.face_for(boss, false, false, true), boss_face, "and keeps its own coin under the dev override")
	assert_eq(EncounterCoin.face_for(boss, true, false, false), glyph, "a visited boss shows its glyph")
	assert_eq(EncounterCoin.face_for(boss, true, true, false), cleared, "a beaten boss is carved")

	assert_eq(EncounterCoin.face_for(empty, false, false, false), unknown, "a revealed empty tile: the question mark")

func test_face_selects_the_glyph() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.COMBAT_REGULAR)
	var glyph: LacquerStripRect = _glyph(coin)
	assert_eq(coin.get_face(), EncounterCoin.Face.GLYPH)
	assert_true(glyph.visible, "with its glyph")
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false))

	# The question mark carries no glyph at all: nothing under the veil is shown.
	coin.setup(EncounterCoin.Face.UNKNOWN, null, Vector2i.ZERO, 1, 0.0)
	assert_eq(coin.get_face(), EncounterCoin.Face.UNKNOWN)
	assert_false(glyph.visible, "no glyph")
	assert_null(coin.get_glyph_texture())

	# Whatever is passed with it, the question mark never shows a glyph.
	_set_up(coin, EncounterCoin.Face.UNKNOWN, Type.COMBAT_REGULAR)
	assert_false(glyph.visible, "a glyph handed to a question mark stays hidden")
	assert_null(coin.get_glyph_texture(), "and is not kept")

	_set_up(coin, EncounterCoin.Face.CLEARED, Type.COMBAT_REGULAR)
	assert_true(glyph.visible)
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, true), "with the spent glyph")

	_set_up(coin, EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	assert_true(glyph.visible)
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_BOSS, false))
