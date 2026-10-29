extends GutTest

## Unit tests for EncounterIcon.configure_for_type() and set_completed()

const EncounterIconScene := preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")

var icon: EncounterIcon

func before_each() -> void:
	icon = EncounterIconScene.instantiate()
	add_child_autofree(icon)
	# Force _ready by simulating a frame
	await get_tree().process_frame

## Every encounter type but NONE configures an icon and remembers its type.
func test_configure_returns_true_for_every_encounter() -> void:
	var cases: Array[AdventureEncounter.EncounterType] = [
		AdventureEncounter.EncounterType.COMBAT_REGULAR,
		AdventureEncounter.EncounterType.COMBAT_AMBUSH,
		AdventureEncounter.EncounterType.COMBAT_ELITE,
		AdventureEncounter.EncounterType.COMBAT_BOSS,
		AdventureEncounter.EncounterType.REST_SITE,
		AdventureEncounter.EncounterType.TREASURE,
		AdventureEncounter.EncounterType.TRAP,
	]
	var type_names: Array = AdventureEncounter.EncounterType.keys()
	for type: AdventureEncounter.EncounterType in cases:
		assert_true(icon.configure_for_type(type), "%s configures" % type_names[type])
		assert_eq(icon.get_configured_type(), type, "%s is the configured type" % type_names[type])

func test_configure_ambush_uses_combat_visuals() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	var combat_texture := icon._glyph.texture
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	assert_eq(icon._glyph.texture, combat_texture, "ambush should look identical to regular combat")

func test_configure_none_returns_false() -> void:
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.NONE)
	assert_false(result)

## set_completed() shows the checkmark badge on a cleared tile, and hides it
## again when the tile is set back.
func test_set_completed_toggles_the_checkmark() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	var cases: Array[Array] = [
		[true, true],
		[false, false],
	]
	for case: Array in cases:
		icon.set_completed(case[0])
		assert_eq(icon._checkmark.visible, case[1], "completed %s: checkmark shows %s" % [case[0], case[1]])
