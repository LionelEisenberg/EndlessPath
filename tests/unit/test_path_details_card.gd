extends GutTest

## Unit tests for PathDetailsCard's effect lines, and the copy of the Seal Flow
## Technique's path node.

const TORRENTIAL_NODE_PATH: String = "res://resources/path_progression/pure_madra/nodes/torrential_flow.tres"
const TORRENTIAL_TECHNIQUE_PATH: String = "res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres"

## A path node effect that unlocks the cycling technique with this id.
func _unlock(technique_id: String) -> PathNodeEffectData:
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE
	effect.string_value = technique_id
	return effect

func test_a_technique_unlock_names_the_technique() -> void:
	assert_eq(PathDetailsCard.format_effect(_unlock("torrential_flow")), "▲ Unlocks: Seal Flow Technique", "the technique's name")
	assert_eq(PathDetailsCard.format_effect(_unlock("no_such_technique")), "▲ Unlocks: no_such_technique", "an unknown technique keeps its id")

## The node promises what the Seal Flow Technique does now: its seals train
## Mind, and it costs no Core Density XP (cycling pays none). It carries the
## technique's name, and its benefit names it.
func test_seal_flow_s_node_copy() -> void:
	var node: PathNodeData = load(TORRENTIAL_NODE_PATH) as PathNodeData
	var technique: CyclingTechniqueData = load(TORRENTIAL_TECHNIQUE_PATH) as CyclingTechniqueData
	assert_eq(node.display_name, technique.technique_name, "the node and the technique share one name")
	assert_true(node.description.contains("seal"), "it says how the technique plays")
	assert_false(node.description.contains("Core Density"), "no Core Density in the description")
	assert_true(node.description.contains("Mind"), "it says what the technique trains")
	assert_true(node.benefit_summary.begins_with(node.display_name), "the benefit names the technique")
