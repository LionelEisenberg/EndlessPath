extends GutTest

## Unit tests for ConsumableDefinitionData.
## Verifies item_type, use() effect dispatch, and tooltip formatting.

## Counter EffectData subclass used to observe process() invocations.
class CountingEffect extends EffectData:
	var call_count: int = 0

	func process() -> void:
		call_count += 1

	func _to_string() -> String:
		return "CountingEffect"

func test_init_sets_item_type_to_consumable() -> void:
	var def := ConsumableDefinitionData.new()
	assert_eq(def.item_type, ItemDefinitionData.ItemType.CONSUMABLE,
		"_init should set item_type to CONSUMABLE")

func test_inherits_default_stack_size() -> void:
	var def := ConsumableDefinitionData.new()
	assert_eq(def.stack_size, 99, "should inherit default stack_size from ItemDefinitionData")

func test_use_calls_process_on_each_effect_in_order() -> void:
	var def := ConsumableDefinitionData.new()
	var first := CountingEffect.new()
	var second := CountingEffect.new()
	def.effects = [first, second]

	def.use()

	assert_eq(first.call_count, 1, "first effect should be processed once")
	assert_eq(second.call_count, 1, "second effect should be processed once")

func test_use_with_empty_effects_is_noop() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = []
	# Should not raise.
	def.use()
	pass_test("use() with empty effects did not raise")

func test_get_item_effects_returns_one_line_per_effect() -> void:
	var def := ConsumableDefinitionData.new()
	var first := CountingEffect.new()
	var second := CountingEffect.new()
	def.effects = [first, second]
	def.cooldown_seconds = 0.0

	var lines := def._get_item_effects()

	assert_eq(lines.size(), 2, "should return one line per effect when cooldown is 0")
	assert_true(lines[0].contains("CountingEffect"), "line should include effect _to_string")

func test_get_item_effects_includes_cooldown_line_when_positive() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = [CountingEffect.new()]
	def.cooldown_seconds = 10.0

	var lines := def._get_item_effects()

	assert_eq(lines.size(), 2, "should return effect line + cooldown line")
	assert_true(lines[1].contains("Cooldown"), "second line should mention Cooldown")
	assert_true(lines[1].contains("10"), "second line should include the cooldown value")

func test_get_item_effects_omits_cooldown_line_when_zero() -> void:
	var def := ConsumableDefinitionData.new()
	def.effects = [CountingEffect.new()]
	def.cooldown_seconds = 0.0

	var lines := def._get_item_effects()

	for line in lines:
		assert_false(line.contains("Cooldown"), "no cooldown line when cooldown_seconds == 0")
