extends GutTest

## Unit tests for PathDetailsCard's effect lines, and the copy of Torrential
## Flow's path node.

const TORRENTIAL_NODE_PATH: String = "res://resources/path_progression/pure_madra/nodes/torrential_flow.tres"

## A path node effect that unlocks the cycling technique with this id.
func _unlock(technique_id: String) -> PathNodeEffectData:
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE
	effect.string_value = technique_id
	return effect

func test_a_technique_unlock_names_the_technique() -> void:
	assert_eq(PathDetailsCard.format_effect(_unlock("torrential_flow")), "▲ Unlocks: Torrential Flow", "the technique's name")
	assert_eq(PathDetailsCard.format_effect(_unlock("no_such_technique")), "▲ Unlocks: no_such_technique", "an unknown technique keeps its id")

## The node promises what Torrential Flow does now: it trains Mind, and costs no
## Core Density XP (cycling pays none). Its benefit names it.
func test_torrential_flow_s_node_copy() -> void:
	var node: PathNodeData = load(TORRENTIAL_NODE_PATH) as PathNodeData
	assert_false(node.description.contains("Core Density"), "no Core Density in the description")
	assert_true(node.description.contains("Mind"), "it says what the technique trains")
	assert_true(node.benefit_summary.begins_with(node.display_name), "the benefit names the technique")
