extends GutTest

## Tests for CombatBuffManager.strip_all_buffs() — mid-combat buff wipe.

var _manager: CombatBuffManager

func before_each() -> void:
	_manager = CombatBuffManager.new()
	add_child_autofree(_manager)

func _make_buff(buff_id: String) -> BuffEffectData:
	var b := BuffEffectData.new()
	b.buff_id = buff_id
	b.effect_name = buff_id
	b.duration = 10.0
	b.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	return b

func test_strip_all_buffs_removes_every_buff() -> void:
	_manager.apply_buff(_make_buff("buff_a"))
	_manager.apply_buff(_make_buff("buff_b"))
	_manager.apply_buff(_make_buff("buff_c"))
	assert_eq(_manager.active_buffs.size(), 3)

	_manager.strip_all_buffs()
	assert_eq(_manager.active_buffs.size(), 0,
		"All active buffs should be removed")

func test_strip_all_buffs_emits_removed_per_buff() -> void:
	_manager.apply_buff(_make_buff("buff_a"))
	_manager.apply_buff(_make_buff("buff_b"))
	watch_signals(_manager)

	_manager.strip_all_buffs()

	assert_signal_emit_count(_manager, "buff_removed", 2,
		"buff_removed should emit once per stripped buff")

func test_strip_all_buffs_with_no_buffs_is_noop() -> void:
	watch_signals(_manager)
	_manager.strip_all_buffs()
	assert_signal_emit_count(_manager, "buff_removed", 0)
	assert_eq(_manager.active_buffs.size(), 0)

func test_strip_all_buffs_stops_dot_timer() -> void:
	var dot := BuffEffectData.new()
	dot.buff_id = "test_dot"
	dot.effect_name = "Test DoT"
	dot.duration = 10.0
	dot.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	dot.dot_damage_per_tick = 5.0
	_manager.apply_buff(dot)
	assert_false(_manager._dot_timer.is_stopped(),
		"DoT timer should run while a DoT buff is active")

	_manager.strip_all_buffs()
	assert_true(_manager._dot_timer.is_stopped(),
		"DoT timer should stop once all DoT buffs are stripped")
