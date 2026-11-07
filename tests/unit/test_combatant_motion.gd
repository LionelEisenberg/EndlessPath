extends GutTest

## A fighter's way into a fight and its fall out of it (#138's canvas), in the
## look's whole steps: CombatantVisual slides in 420 px over 0.4 s at a steady
## speed, in even px, shown outright, and a beaten fighter is knocked 48 px back
## over 0.16 s, then blinks out (off, on, off, on, gone, 0.08 s each).

const VisualScene := preload("res://scenes/combat/combatant/combatant_visual/combatant_visual.tscn")
const ENEMY_TEXTURE := preload("res://assets/sprites/combat/enemies/test_enemy_sprite.png")

#-----------------------------------------------------------------------------
# THE STEPS
#-----------------------------------------------------------------------------

func test_the_entrance_steps_in_even_px() -> void:
	var cases: Array[Array] = [[0.0, 420], [0.05, 368], [0.2, 210], [0.35, 52], [0.4, 0], [0.6, 0]]
	for case: Array in cases:
		var offset: int = CombatantVisual.enter_offset_at(case[0])
		assert_eq(offset, case[1], "%.1f s in" % case[0])
		assert_eq(offset % 2, 0, "%.1f s in: an even px" % case[0])

func test_the_knockback_steps_in_even_px() -> void:
	var cases: Array[Array] = [[0.0, 0], [0.04, 12], [0.08, 24], [0.16, 48], [0.3, 48]]
	for case: Array in cases:
		var offset: int = CombatantVisual.knockback_offset_at(case[0])
		assert_eq(offset, case[1], "%.2f s in" % case[0])
		assert_eq(offset % 2, 0, "%.2f s in: an even px" % case[0])

func test_the_fall_blinks_then_stays_gone() -> void:
	var cases: Array[Array] = [
		[0.1, true], [0.16, false], [0.17, false], [0.24, true], [0.25, true], [0.33, false], [0.41, true],
		[CombatantVisual.DEFEAT_SECONDS, false], [0.49, false], [2.0, false],
	]
	for case: Array in cases:
		assert_eq(CombatantVisual.shown_while_falling_at(case[0]), case[1], "%.2f s into the fall" % case[0])

#-----------------------------------------------------------------------------
# AN ENEMY ON THE STAGE
#-----------------------------------------------------------------------------

## An enemy, set up as CombatantNode sets one up: it faces left, from the right.
func _enemy_visual() -> CombatantVisual:
	var visual: CombatantVisual = VisualScene.instantiate()
	add_child_autofree(visual)
	visual.setup(ENEMY_TEXTURE, 1.0, Vector2.ZERO, true, false)
	return visual

func test_an_enemy_waits_off_its_spot_and_arrives() -> void:
	var visual: CombatantVisual = _enemy_visual()

	visual.place_for_entrance()

	assert_eq(visual.position.x, 420.0, "it waits 420 px out on its own side")
	visual.play_enter()
	await wait_seconds(CombatantVisual.ENTER_SECONDS * 0.5)
	assert_gt(visual.position.x, 0.0, "partway in")
	assert_eq(fmod(visual.position.x, 2.0), 0.0, "on an even px")
	for item: CanvasItem in [visual, visual.get_node("%Body"), visual.get_node("%Sprite"), visual.get_node("%Shadow")]:
		assert_eq(item.modulate.a, 1.0, "%s shows outright, with no fade" % item.name)
	await wait_seconds(CombatantVisual.ENTER_SECONDS)
	assert_eq(visual.position.x, 0.0, "and stands on its spot")

func test_a_fallen_fighter_is_gone() -> void:
	var visual: CombatantVisual = _enemy_visual()
	assert_false(visual.is_fallen(), "precondition: it stands")

	visual.play_defeat()
	await wait_seconds(CombatantVisual.DEFEAT_SECONDS + 0.1)

	assert_true(visual.is_fallen(), "it is gone")
	assert_eq(visual.position.x, 48.0, "knocked 48 px back, away from the player")
	assert_false(visual.get_node("%Body").visible, "its body hidden")
	assert_false(visual.get_node("%Shadow").visible, "and its shadow")
