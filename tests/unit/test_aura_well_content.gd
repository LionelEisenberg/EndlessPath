extends GutTest

## Content checks on the Aura Well's files: each writes out the values it
## would otherwise leave to its script's defaults, since Godot's text saver
## drops a value equal to the default and a changed default would then
## silently change the Well. The Well refills Madra only: it trains no stat.

const ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres"
const TRICKLE_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres"

## Each file and the fields it writes out.
const WRITTEN_OUT_FIELDS: Dictionary = {
	ACTION_PATH: ["tick_interval_seconds", "ticks_per_level", "tail_growth_multiplier"],
	TRICKLE_PATH: ["resource_type", "amount", "quiet"],
}

func test_every_file_writes_out_its_values() -> void:
	for path: String in WRITTEN_OUT_FIELDS:
		var text: String = FileAccess.get_file_as_string(path)
		for field: String in WRITTEN_OUT_FIELDS[path]:
			assert_true(text.contains("\n%s = " % field), "%s writes out %s" % [path, field])

func test_the_trickle_is_madra() -> void:
	var trickle: AwardResourceEffectData = load(TRICKLE_PATH)
	assert_eq(trickle.resource_type, ResourceManager.ResourceType.MADRA)
	assert_eq(trickle.amount, 1.5)

## Training at the Well is idle from the start, so it raises no stat, per tick
## or per training level (the anti-goals).
func test_the_well_awards_no_stat() -> void:
	var well: TrainingActionData = load(ACTION_PATH)
	for effect: EffectData in well.effects_per_tick + well.effects_on_level:
		assert_false(effect is AwardAttributeEffectData, "the Well awards no stat: %s" % effect)
	assert_eq(well.effects_on_level.size(), 0, "its training levels pay nothing")
