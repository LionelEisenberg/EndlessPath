extends GutTest

## Unit tests for EncounterIcon.configure_for_type()

const EncounterIconScene := preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")

var icon: EncounterIcon

func before_each() -> void:
	icon = EncounterIconScene.instantiate()
	add_child_autofree(icon)
	# Force _ready by simulating a frame
	await get_tree().process_frame

func test_configure_combat_returns_true() -> void:
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	assert_true(result)
	assert_eq(icon.get_configured_type(), AdventureEncounter.EncounterType.COMBAT_REGULAR)

func test_configure_ambush_uses_combat_visuals() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	var combat_color := icon._glyph.modulate
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	assert_eq(icon._glyph.modulate, combat_color, "ambush should look identical to regular combat")

func test_configure_elite_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_ELITE))

func test_configure_boss_enables_ornamental_ring() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_true(icon._ornamental_ring.visible)
	assert_almost_eq(icon._frame.scale.x, 1.65, 0.01)

func test_configure_rest_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.REST_SITE))

func test_configure_treasure_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.TREASURE))

func test_configure_trap_unvisited_returns_false() -> void:
	icon.set_visited(false)
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.TRAP)
	assert_false(result, "trap should be hidden until visited")

func test_configure_trap_visited_returns_true() -> void:
	icon.set_visited(true)
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.TRAP)
	assert_true(result, "trap should be visible once visited")

func test_configure_none_returns_false() -> void:
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.NONE)
	assert_false(result)

func test_configure_resets_ornamental_ring_for_non_boss() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_true(icon._ornamental_ring.visible)
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	assert_false(icon._ornamental_ring.visible)

func test_set_completed_dims_dimmable_wrapper() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	icon.set_completed(true)
	assert_almost_eq(icon._dimmable.modulate.a, 0.45, 0.01, "completed state should dim the Dimmable wrapper")
	assert_true(icon._checkmark.visible, "completed state should show the checkmark badge")

func test_set_completed_false_restores_full_opacity() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	icon.set_completed(true)
	icon.set_completed(false)
	assert_almost_eq(icon._dimmable.modulate.a, 1.0, 0.01, "uncompleted state should be fully opaque")
	assert_false(icon._checkmark.visible, "uncompleted state should hide the checkmark badge")
