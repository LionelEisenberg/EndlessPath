extends RefCounted

## Modifier sources for tests, to hand CharacterManager.set_modifier_source().
## A test that sets one removes it again in after_each().
## Preload it: const StatSources := preload("res://tests/helpers/stat_sources.gd").

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## A modifier source that raises `stat` by a FLAT `amount`.
static func flat(stat: StatModifierData.Stat, amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(stat, StatModifierData.Kind.FLAT, amount)]
		return modifiers
