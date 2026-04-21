extends GutTest

## Tests for CombatBuffManager stacking behavior on OUTGOING_DAMAGE_MODIFIER.
## Mirrors the existing DoT stacking pattern: re-applying the same buff id
## increments stack_count and the modifier compounds as multiplier^stack_count.

var _manager: CombatBuffManager

func before_each() -> void:
	_manager = CombatBuffManager.new()
	add_child_autofree(_manager)

func _make_outgoing_buff(buff_id: String, multiplier: float, duration: float = 10.0) -> BuffEffectData:
	var b := BuffEffectData.new()
	b.buff_id = buff_id
	b.effect_name = buff_id
	b.duration = duration
	b.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	b.damage_multiplier = multiplier
	return b

func test_outgoing_modifier_single_application_returns_base_multiplier() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	assert_almost_eq(_manager.get_outgoing_damage_modifier(), 1.5, 0.0001,
		"Single stack of 1.5x should return 1.5")

func test_outgoing_modifier_stacks_multiplicatively_on_reapply() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	assert_almost_eq(_manager.get_outgoing_damage_modifier(), 1.5 * 1.5 * 1.5, 0.0001,
		"Three stacks of 1.5x should compound to 3.375x")

func test_outgoing_modifier_reapply_keeps_single_active_buff_entry() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	assert_eq(_manager.active_buffs.size(), 1,
		"Re-applying same buff id should not create a second ActiveBuff")
	assert_eq(_manager.active_buffs[0].stack_count, 2,
		"Re-applying same buff id should increment stack_count")

func test_outgoing_modifier_stacking_emits_buff_stacked_signal() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	watch_signals(_manager)
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	assert_signal_emit_count(_manager, "buff_stacked", 2,
		"buff_stacked should fire once per stacking re-apply")
	assert_eq(_manager.active_buffs[0].stack_count, 3,
		"Stack count should reflect number of applications")

func test_outgoing_modifier_reapply_refreshes_duration() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5, 10.0))
	_manager.active_buffs[0].time_remaining = 2.0
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5, 10.0))
	assert_almost_eq(_manager.active_buffs[0].time_remaining, 10.0, 0.0001,
		"Re-applying should refresh remaining time to full duration")

func test_consume_outgoing_modifier_uses_stacked_multiplier() -> void:
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	_manager.apply_buff(_make_outgoing_buff("hunger", 1.5))
	assert_almost_eq(_manager.consume_outgoing_modifier(), 1.5 * 1.5, 0.0001,
		"consume_outgoing_modifier should honor stack_count")

func test_dot_stacking_still_works_unchanged() -> void:
	var dot := BuffEffectData.new()
	dot.buff_id = "bleed"
	dot.effect_name = "Bleed"
	dot.duration = 10.0
	dot.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	dot.dot_damage_per_tick = 5.0
	_manager.apply_buff(dot)
	_manager.apply_buff(dot)
	assert_eq(_manager.active_buffs[0].stack_count, 2,
		"DoT stacking should still increment stack_count as before")
