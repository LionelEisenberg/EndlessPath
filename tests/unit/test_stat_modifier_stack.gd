extends GutTest

## Unit tests for StatModifierData's mapping between attributes and stats, and
## for StatModifierStack: sources asked at read time, flat bonuses added to the
## base, then the percentages summed and applied once.

const Stat = StatModifierData.Stat
const Kind = StatModifierData.Kind
const AttributeType = CharacterAttributesData.AttributeType

## A node whose method serves as a source, so a test can free its owner.
class SourceOwner extends Node:
	func modifiers() -> Array[StatModifierData]:
		var result: Array[StatModifierData] = [StatModifierData.new(Stat.BODY, Kind.FLAT, 5.0)]
		return result

var _stack: StatModifierStack
var _live_bonus: float = 0.0

func before_each() -> void:
	_stack = StatModifierStack.new()
	_live_bonus = 0.0

func _flat(stat: Stat, value: float) -> StatModifierData:
	return StatModifierData.new(stat, Kind.FLAT, value)

func _percent(stat: Stat, value: float) -> StatModifierData:
	return StatModifierData.new(stat, Kind.PERCENT, value)

## A source that always returns the given modifiers.
func _source(modifiers: Array[StatModifierData]) -> Callable:
	return func() -> Array[StatModifierData]: return modifiers

#-----------------------------------------------------------------------------
# STAT <-> ATTRIBUTE
#-----------------------------------------------------------------------------

func test_every_attribute_has_a_stat_of_the_same_name() -> void:
	for attribute: int in AttributeType.values():
		var stat: int = StatModifierData.for_attribute(attribute)
		assert_eq(Stat.keys()[stat], AttributeType.keys()[attribute])
		assert_eq(StatModifierData.attribute_of(stat), attribute)

func test_derived_vitals_are_not_attributes() -> void:
	for stat: int in [Stat.MAX_HEALTH, Stat.MAX_STAMINA, Stat.MAX_MADRA]:
		assert_eq(StatModifierData.attribute_of(stat), -1, "%s is not an attribute" % Stat.keys()[stat])

#-----------------------------------------------------------------------------
# STACKING
#-----------------------------------------------------------------------------

func test_no_sources_returns_the_base() -> void:
	assert_eq(_stack.apply(Stat.BODY, 10.0), 10.0)

func test_flat_modifiers_add() -> void:
	_stack.set_source(&"a", _source([_flat(Stat.BODY, 3.0), _flat(Stat.BODY, 2.0)]))
	assert_eq(_stack.apply(Stat.BODY, 10.0), 15.0)

func test_percent_modifiers_add_before_applying() -> void:
	_stack.set_source(&"a", _source([_percent(Stat.BODY, 0.1), _percent(Stat.BODY, 0.1)]))
	assert_almost_eq(_stack.apply(Stat.BODY, 10.0), 12.0, 0.0001, "two +10% make +20%, not +21%")

func test_flat_applies_before_percent() -> void:
	_stack.set_source(&"a", _source([_percent(Stat.BODY, 0.2), _flat(Stat.BODY, 5.0)]))
	assert_almost_eq(_stack.apply(Stat.BODY, 10.0), 18.0, 0.0001, "(10 + 5) x 1.2")

func test_modifiers_for_other_stats_are_ignored() -> void:
	_stack.set_source(&"a", _source([_flat(Stat.SPIRIT, 5.0), _percent(Stat.MAX_HEALTH, 0.5)]))
	assert_eq(_stack.apply(Stat.BODY, 10.0), 10.0)

func test_sources_stack() -> void:
	_stack.set_source(&"a", _source([_flat(Stat.BODY, 2.0)]))
	_stack.set_source(&"b", _source([_flat(Stat.BODY, 3.0)]))
	assert_eq(_stack.apply(Stat.BODY, 10.0), 15.0)

func test_setting_a_source_again_replaces_it() -> void:
	_stack.set_source(&"a", _source([_flat(Stat.BODY, 2.0)]))
	_stack.set_source(&"a", _source([_flat(Stat.BODY, 7.0)]))
	assert_eq(_stack.apply(Stat.BODY, 10.0), 17.0)

func test_remove_source() -> void:
	_stack.set_source(&"a", _source([_flat(Stat.BODY, 2.0)]))
	_stack.remove_source(&"a")
	assert_eq(_stack.apply(Stat.BODY, 10.0), 10.0)

func test_providers_are_asked_at_read_time() -> void:
	_stack.set_source(&"live", func() -> Array[StatModifierData]:
		var result: Array[StatModifierData] = [_flat(Stat.BODY, _live_bonus)]
		return result)
	_live_bonus = 4.0
	assert_eq(_stack.apply(Stat.BODY, 10.0), 14.0)
	_live_bonus = 1.0
	assert_eq(_stack.apply(Stat.BODY, 10.0), 11.0, "the source's current bonus, not a cached one")

func test_a_freed_providers_source_is_skipped() -> void:
	var source_owner := SourceOwner.new()
	_stack.set_source(&"owned", source_owner.modifiers)
	assert_eq(_stack.apply(Stat.BODY, 10.0), 15.0, "precondition: the source counts while its owner lives")
	source_owner.free()
	assert_eq(_stack.apply(Stat.BODY, 10.0), 10.0)
