class_name StatModifierStack
extends RefCounted

## StatModifierStack
## The player's stat bonuses, by source (gear today; path perks and elixirs
## later). A source is a Callable that returns Array[StatModifierData]. It is
## asked each time a stat is read, so the stack holds no copy that could go
## stale: a source owner only has to say when its bonuses changed.
##
## A stat is (base + sum of flat) x (1 + sum of percent), over every source.

## Source name -> provider.
var _sources: Dictionary[StringName, Callable] = {}

## Adds the source, or replaces the one already under that name.
func set_source(source: StringName, provider: Callable) -> void:
	_sources[source] = provider

## Removes the source, if there is one under that name.
func remove_source(source: StringName) -> void:
	_sources.erase(source)

## Returns base with every source's modifiers for the stat: the flat ones
## added, then the percentages summed and applied once. A source whose
## owner has been freed is skipped.
func apply(stat: StatModifierData.Stat, base: float) -> float:
	var flat: float = 0.0
	var percent: float = 0.0
	for provider: Callable in _sources.values():
		if not provider.is_valid():
			continue
		for modifier: StatModifierData in provider.call():
			if modifier.stat != stat:
				continue
			if modifier.kind == StatModifierData.Kind.PERCENT:
				percent += modifier.value
			else:
				flat += modifier.value
	return (base + flat) * (1.0 + percent)
