extends RefCounted

## Stat levels for tests that need the Tribulation's stat requirement met.
## Preload it: const StatCaps := preload("res://tests/helpers/stat_caps.gd").

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Trains Strength and Spirit to the current stage's cap, as the Tribulation
## needs them, through CharacterManager.set_stat_level() on the live save.
static func cap_main_stats() -> void:
	var cap: int = CharacterManager.get_stat_level_cap()
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.STRENGTH, cap)
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, cap)
