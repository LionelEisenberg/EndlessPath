extends GutTest

## EncounterCoin, the coin that marks an encounter on the adventure map (spec:
## The map, Coins): which tiles get one, its face in each state, the glyph for
## each encounter type with its frame size, frames and pace, how an animated
## glyph steps through its frames, and the shake. The statics are called as the
## map layer calls them, and a real coin scene is driven with simulated frames.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const EncounterCoinScene := preload("res://scenes/adventure/adventure_map_markers/encounter_coin/encounter_coin.tscn")
const Type := AdventureEncounter.EncounterType

const TOKENS_PATH := "res://assets/ui/lacquer/lacquer_marker_tokens_ai.png"
const GLYPH_DIR := "res://assets/sprites/adventure/encounter_glyphs/"
const COMBAT_ICON_PATH := "res://assets/sprites/ui/stat_icons/combat_icon.png"

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

func _token(coin: EncounterCoin) -> LacquerStripRect:
	return coin.get_node("%Token") as LacquerStripRect

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

func test_faces_are_the_token_frames() -> void:
	assert_eq(EncounterCoin.Face.GLYPH, 0, "frame 0: the brass-rimmed glyph coin")
	assert_eq(EncounterCoin.Face.UNKNOWN, 1, "frame 1: the carved coin with the tan question mark")
	assert_eq(EncounterCoin.Face.CLEARED, 2, "frame 2: the carved cleared coin")
	assert_eq(EncounterCoin.Face.BOSS, 3, "frame 3: the boss coin with its vermilion ring")

#-----------------------------------------------------------------------------
# THE GLYPH
#-----------------------------------------------------------------------------

func test_glyph_for_each_type() -> void:
	var cases: Array[Dictionary] = [
		{"type": Type.COMBAT_REGULAR, "live": COMBAT_ICON_PATH, "spent": GLYPH_DIR + "adv_glyph_combat_spent_light_ai.png"},
		{"type": Type.COMBAT_AMBUSH, "live": COMBAT_ICON_PATH, "spent": GLYPH_DIR + "adv_glyph_combat_spent_light_ai.png"},
		{"type": Type.COMBAT_ELITE, "live": GLYPH_DIR + "elite.png", "spent": GLYPH_DIR + "adv_glyph_elite_spent_light_ai.png"},
		{"type": Type.REST_SITE, "live": GLYPH_DIR + "rest-sheet.png", "spent": GLYPH_DIR + "adv_glyph_rest_spent_light_ai.png"},
		{"type": Type.COMBAT_BOSS, "live": GLYPH_DIR + "boss_spritesheet.png", "spent": GLYPH_DIR + "adv_glyph_boss_spent_light_ai.png"},
		{"type": Type.TREASURE, "live": GLYPH_DIR + "treasure.png", "spent": GLYPH_DIR + "adv_glyph_treasure_spent_light_ai.png"},
		{"type": Type.TRAP, "live": GLYPH_DIR + "trap.png", "spent": GLYPH_DIR + "adv_glyph_trap_spent_light_ai.png"},
	]
	for case: Dictionary in cases:
		var type: AdventureEncounter.EncounterType = case["type"]
		var type_name: String = Type.find_key(type)
		var live: Texture2D = EncounterCoin.glyph_for(type, false)
		var spent: Texture2D = EncounterCoin.glyph_for(type, true)
		assert_not_null(live, "%s has a glyph" % type_name)
		assert_not_null(spent, "%s has a spent glyph" % type_name)
		if live == null or spent == null:
			continue
		assert_eq(live.resource_path, case["live"], "%s: the user's glyph" % type_name)
		assert_eq(spent.resource_path, case["spent"], "%s: the kit's spent glyph once cleared" % type_name)

		# The frame size and frame count describe the art they come with.
		var frame_size: Vector2i = EncounterCoin.glyph_frame_size_for(type)
		var frames: int = EncounterCoin.glyph_frames_for(type, false)
		assert_eq(Vector2i(live.get_size()), Vector2i(frame_size.x * frames, frame_size.y), "%s: %d frames of %s" % [type_name, frames, frame_size])
		assert_eq(Vector2i(spent.get_size()), frame_size, "%s: the spent glyph is one frame of the same size" % type_name)

func test_glyph_frame_sizes() -> void:
	assert_eq(EncounterCoin.glyph_frame_size_for(Type.TRAP), Vector2i(32, 32), "the trap's art is 32 px native")
	for type: AdventureEncounter.EncounterType in [Type.COMBAT_REGULAR, Type.COMBAT_AMBUSH, Type.COMBAT_ELITE, Type.COMBAT_BOSS, Type.REST_SITE, Type.TREASURE]:
		assert_eq(EncounterCoin.glyph_frame_size_for(type), Vector2i(64, 64), "%s: 64 px art" % Type.find_key(type))

func test_a_type_with_no_glyph_has_none() -> void:
	assert_null(EncounterCoin.glyph_for(Type.NONE, false), "nothing to draw for a tile with no encounter")
	assert_null(EncounterCoin.glyph_for(Type.NONE, true))

func test_animated_glyphs() -> void:
	assert_eq(EncounterCoin.glyph_frames_for(Type.COMBAT_BOSS, false), 7, "the boss strip has 7 frames")
	assert_eq(EncounterCoin.frame_seconds_for(Type.COMBAT_BOSS), 0.2, "0.2 s each, 1.4 s a cycle")
	assert_eq(EncounterCoin.glyph_frames_for(Type.REST_SITE, false), 5, "the rest strip has 5 frames")
	assert_eq(EncounterCoin.frame_seconds_for(Type.REST_SITE), 0.4, "0.4 s each, 2 s a cycle")
	for type: AdventureEncounter.EncounterType in [Type.COMBAT_REGULAR, Type.COMBAT_AMBUSH, Type.COMBAT_ELITE, Type.TREASURE, Type.TRAP]:
		assert_eq(EncounterCoin.glyph_frames_for(type, false), 1, "%s is one still frame" % Type.find_key(type))
		assert_eq(EncounterCoin.frame_seconds_for(type), 0.0, "%s has no pace" % Type.find_key(type))
	for type: AdventureEncounter.EncounterType in [Type.COMBAT_BOSS, Type.REST_SITE]:
		assert_eq(EncounterCoin.glyph_frames_for(type, true), 1, "the spent %s glyph is one still frame" % Type.find_key(type))

	# A boss coin steps through its 7 frames in _process, 0.2 s each, and wraps.
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	var glyph: LacquerStripRect = _glyph(coin)
	assert_eq(glyph.get_frame(), Vector2i(0, 0), "starts on the first frame")
	simulate(coin, 1, 0.19)
	assert_eq(glyph.get_frame(), Vector2i(0, 0), "0.19 s: still the first")
	simulate(coin, 1, 0.02)
	assert_eq(glyph.get_frame(), Vector2i(1, 0), "0.21 s: the second")
	simulate(coin, 1, 0.4)
	assert_eq(glyph.get_frame(), Vector2i(3, 0), "0.61 s: the fourth")
	simulate(coin, 1, 0.8)
	assert_eq(glyph.get_frame(), Vector2i(0, 0), "1.41 s: wrapped to the first")

	# A time exactly on a frame boundary shows the frame that starts there, though
	# 0.6 / 0.2 divides to 2.9999999999999996 and 1.4 / 0.2 to 6.999999999999999.
	var at_third_boundary: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	simulate(at_third_boundary, 1, 0.6)
	assert_eq(_glyph(at_third_boundary).get_frame(), Vector2i(3, 0), "0.6 s: the fourth frame starts")
	var at_cycle_end: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	simulate(at_cycle_end, 1, 1.4)
	assert_eq(_glyph(at_cycle_end).get_frame(), Vector2i(0, 0), "1.4 s: the cycle starts over")

	# A rest coin has 5 frames of 0.4 s.
	var rest: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.REST_SITE)
	var rest_glyph: LacquerStripRect = _glyph(rest)
	simulate(rest, 1, 0.41)
	assert_eq(rest_glyph.get_frame(), Vector2i(1, 0), "0.41 s: the second")
	simulate(rest, 1, 1.6)
	assert_eq(rest_glyph.get_frame(), Vector2i(0, 0), "2.01 s: wrapped to the first")

func test_still_glyph_stays_on_its_frame() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.COMBAT_REGULAR)

	simulate(coin, 10, 0.5)

	assert_eq(_glyph(coin).get_frame(), Vector2i(0, 0), "a one-frame glyph never moves")

func test_a_coin_only_processes_while_it_has_something_to_do() -> void:
	var still: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.COMBAT_REGULAR)
	assert_false(still.is_processing(), "a still glyph needs no frames")
	var spent_boss: EncounterCoin = _make_coin(EncounterCoin.Face.CLEARED, Type.COMBAT_BOSS)
	assert_false(spent_boss.is_processing(), "nor does a cleared boss glyph, though it is handed the boss's pace")
	var unknown: EncounterCoin = _make_coin(EncounterCoin.Face.UNKNOWN, Type.COMBAT_BOSS)
	assert_false(unknown.is_processing(), "nor a question mark, whatever it is handed")
	var boss: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	assert_true(boss.is_processing(), "an animated glyph does")

	still.shake()
	assert_true(still.is_processing(), "a shake needs frames too")
	simulate(still, 1, 0.5)
	assert_false(still.is_shaking(), "precondition: the shake is over")
	assert_false(still.is_processing(), "and the coin goes quiet when it ends")

func test_setting_up_again_keeps_the_animation_going() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	simulate(coin, 1, 0.65)
	assert_eq(_glyph(coin).get_frame(), Vector2i(3, 0), "precondition: a few frames in")

	# The map layer sets every coin up on each redraw; nothing changed.
	_set_up(coin, EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	assert_eq(_glyph(coin).get_frame(), Vector2i(3, 0), "the same glyph carries on")
	simulate(coin, 1, 0.2)
	assert_eq(_glyph(coin).get_frame(), Vector2i(4, 0), "and goes on from where it was")

	# A different glyph starts from its first frame.
	_set_up(coin, EncounterCoin.Face.GLYPH, Type.REST_SITE)
	assert_eq(_glyph(coin).get_frame(), Vector2i(0, 0), "a new glyph starts at its first frame")

#-----------------------------------------------------------------------------
# THE COIN
#-----------------------------------------------------------------------------

func test_coin_is_54_square_and_lets_the_mouse_through() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.COMBAT_REGULAR)
	var token: LacquerStripRect = _token(coin)
	var glyph: LacquerStripRect = _glyph(coin)

	assert_eq(coin.size, Vector2(54, 54), "a 52 px coin and its 2 px shadow")
	assert_eq(coin.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the hexes under it stay hoverable")
	assert_eq(token.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(glyph.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_eq(token.strip.resource_path, TOKENS_PATH, "the kit's token strip")
	assert_eq(token.frame_size, Vector2i(54, 54))
	assert_eq(token.position, Vector2.ZERO)
	assert_eq(token.size, Vector2(54, 54))

	assert_eq(glyph.position, Vector2(10, 10), "the 32 px glyph centred on the 52 px coin")
	assert_eq(glyph.size, Vector2(32, 32), "the user's 64 px art halved (style guide 9)")
	assert_eq(glyph.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "the rect, not the art, sets the size")

func test_face_selects_the_token_frame_and_the_glyph() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.COMBAT_REGULAR)
	var token: LacquerStripRect = _token(coin)
	var glyph: LacquerStripRect = _glyph(coin)
	assert_eq(coin.get_face(), EncounterCoin.Face.GLYPH)
	assert_eq(token.get_frame(), Vector2i(0, 0), "GLYPH: the brass-rimmed coin")
	assert_true(glyph.visible, "with its glyph")
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false))
	assert_eq(glyph.strip, EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false))
	assert_eq(glyph.frame_size, Vector2i(64, 64))

	# The question mark carries no glyph at all: nothing under the veil is shown.
	coin.setup(EncounterCoin.Face.UNKNOWN, null, Vector2i.ZERO, 1, 0.0)
	assert_eq(coin.get_face(), EncounterCoin.Face.UNKNOWN)
	assert_eq(token.get_frame(), Vector2i(1, 0), "UNKNOWN: the carved coin with its tan question mark")
	assert_false(glyph.visible, "no glyph")
	assert_null(coin.get_glyph_texture())

	# Whatever is passed with it, the question mark never shows a glyph.
	_set_up(coin, EncounterCoin.Face.UNKNOWN, Type.COMBAT_REGULAR)
	assert_false(glyph.visible, "a glyph handed to a question mark stays hidden")
	assert_null(coin.get_glyph_texture(), "and is not kept")

	_set_up(coin, EncounterCoin.Face.CLEARED, Type.COMBAT_REGULAR)
	assert_eq(token.get_frame(), Vector2i(2, 0), "CLEARED: the carved coin")
	assert_true(glyph.visible)
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, true), "with the spent glyph")

	_set_up(coin, EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	assert_eq(token.get_frame(), Vector2i(3, 0), "BOSS: the vermilion inner ring")
	assert_true(glyph.visible)
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_BOSS, false))

func test_trap_glyph_shows_at_its_file_size() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.GLYPH, Type.TRAP)
	var glyph: LacquerStripRect = _glyph(coin)

	assert_eq(glyph.frame_size, Vector2i(32, 32), "the trap's 32 px frame")
	assert_eq(glyph.size, Vector2(32, 32), "in the same 32 px rect: 1:1")
	assert_eq(glyph.texture.get_size(), Vector2(32, 32))

#-----------------------------------------------------------------------------
# THE SHAKE
#-----------------------------------------------------------------------------

func test_shake_steps() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	var token: LacquerStripRect = _token(coin)
	var glyph: LacquerStripRect = _glyph(coin)
	var glyph_home_x: float = glyph.position.x
	assert_false(coin.is_shaking(), "still before the shake")

	coin.shake()
	assert_true(coin.is_shaking())
	assert_eq(token.position.x, 0.0, "a shake starts at home")

	# The coin moves as MapGlyph's keyframes say: the token and its glyph together.
	simulate(coin, 1, 0.1)
	assert_eq(token.position.x, float(MapGlyph.shake_offset_at(0.1)), "0.1 s in")
	assert_eq(glyph.position.x, glyph_home_x + MapGlyph.shake_offset_at(0.1), "the glyph goes with its coin")
	assert_true(coin.is_shaking())

	simulate(coin, 1, 0.1)
	assert_eq(token.position.x, float(MapGlyph.shake_offset_at(0.2)), "0.2 s in")
	assert_eq(glyph.position.x, glyph_home_x + MapGlyph.shake_offset_at(0.2))

	simulate(coin, 1, 0.24)
	assert_eq(token.position.x, 0.0, "back home after 0.44 s")
	assert_eq(glyph.position.x, glyph_home_x)
	simulate(coin, 1, 0.01)
	assert_false(coin.is_shaking(), "and done")
	assert_eq(token.position.x, 0.0, "home for good")
	assert_eq(coin.position, Vector2.ZERO, "the coin itself never moves: the map layer places it")

func test_shake_moves_in_whole_steps() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	var token: LacquerStripRect = _token(coin)
	coin.shake()

	# Every frame of the shake sits on one of the keyframes: whole even px.
	var seen: Array[float] = []
	for _frame: int in 60:
		simulate(coin, 1, 0.01)
		if not seen.has(token.position.x):
			seen.append(token.position.x)
	seen.sort()

	assert_eq(seen, [-8.0, -6.0, 0.0, 4.0, 8.0] as Array[float], "only the keyframe offsets are ever shown")

func test_shake_again_restarts_it() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	var token: LacquerStripRect = _token(coin)
	coin.shake()
	simulate(coin, 1, 0.3)
	assert_eq(token.position.x, float(MapGlyph.shake_offset_at(0.3)), "precondition: mid-shake")

	coin.shake()

	assert_eq(token.position.x, 0.0, "a new shake starts from home")
	simulate(coin, 1, 0.1)
	assert_eq(token.position.x, float(MapGlyph.shake_offset_at(0.1)), "and runs from its first keyframe")

func test_shake_does_not_stop_the_glyph_animation() -> void:
	var coin: EncounterCoin = _make_coin(EncounterCoin.Face.BOSS, Type.COMBAT_BOSS)
	coin.shake()

	simulate(coin, 1, 0.21)

	assert_eq(_glyph(coin).get_frame(), Vector2i(1, 0), "the boss glyph keeps stepping while its coin shakes")
