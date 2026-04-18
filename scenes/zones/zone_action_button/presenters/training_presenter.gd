class_name TrainingPresenter
extends ZoneActionPresenter
## Presenter for TRAIN_STATS actions. Fills all three slots:
##   OverlaySlot — per-tick sweep (same shader as foraging, tied to ActionManager.action_timer)
##   InlineSlot  — attribute badge "current / max" (e.g. "0 / 4")
##   FooterSlot  — TickProgressBar showing ticks-within-current-level
##
## Spawns a Madra FlyingParticle on each tick, aimed at the Madra orb.
## Plays a 0.3s flash/fade on the progress bar when a new level is gained.

const TICK_PARTICLE_COLOR: Color = Color(0.5, 0.78, 1.0, 0.85)
const TICK_PARTICLE_SIZE: float = 4.0
const TICK_PARTICLE_DURATION: float = 0.5
const FILL_TINT_OPACITY: float = 0.45
const LEVEL_UP_FLASH_DURATION: float = 0.3

@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _attribute_badge: RichTextLabel = %AttributeBadge
@onready var _tick_progress_bar: TickProgressBar = %TickProgressBar

var _is_tracking_timer: bool = false

func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, inline_slot: Control, footer_slot: Control) -> void:
	action_data = data
	button = owner_button

	_progress_fill.reparent(overlay_slot)
	_progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_fill_color(button.get_category_color())
	_set_fill_amount(0.0)

	_attribute_badge.reparent(inline_slot)

	_tick_progress_bar.reparent(footer_slot)
	_tick_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tick_progress_bar.set_fill_color(button.get_category_color())

	ActionManager.training_tick_processed.connect(_on_tick)
	ActionManager.training_level_gained.connect(_on_level)

	_refresh_from_state()

func teardown() -> void:
	if ActionManager.training_tick_processed.is_connected(_on_tick):
		ActionManager.training_tick_processed.disconnect(_on_tick)
	if ActionManager.training_level_gained.is_connected(_on_level):
		ActionManager.training_level_gained.disconnect(_on_level)

func set_is_current(is_current: bool) -> void:
	if is_current:
		_start_sweep()
	else:
		_stop_sweep()

#-----------------------------------------------------------------------------
# PROCESS — sweep follows ActionManager.action_timer
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _is_tracking_timer:
		var timer: Timer = ActionManager.action_timer
		if timer.wait_time > 0.0 and not timer.is_stopped():
			var progress: float = 1.0 - (timer.time_left / timer.wait_time)
			_set_fill_amount(progress)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_tick(tick_action: TrainingActionData, new_tick_count: int) -> void:
	if tick_action != action_data:
		return
	_update_progress_bar(new_tick_count)
	_update_attribute_badge(new_tick_count)
	_spawn_madra_particle(tick_action)
	# Reset the sweep shader; _process will ramp it back up from 0 as action_timer counts down again.
	_set_fill_amount(0.0)

func _on_level(level_action: TrainingActionData, _new_level: int) -> void:
	if level_action != action_data:
		return
	var flash_color: Color = button.get_category_color()
	_tick_progress_bar.flash_and_reset(flash_color, LEVEL_UP_FLASH_DURATION)

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

func _refresh_from_state() -> void:
	var ticks: int = ZoneManager.get_training_ticks(action_data.action_id)
	_update_progress_bar(ticks)
	_update_attribute_badge(ticks)

func _update_progress_bar(accumulated_ticks: int) -> void:
	var training: TrainingActionData = action_data as TrainingActionData
	if training == null:
		return
	var level: int = training.get_current_level(accumulated_ticks)
	var cumulative_through_current_level: int = 0
	for i in range(1, level + 1):
		cumulative_through_current_level += training.get_ticks_required_for_level(i)
	var ticks_in_level: int = accumulated_ticks - cumulative_through_current_level
	var ticks_required_for_next: int = training.get_ticks_required_for_level(level + 1)
	_tick_progress_bar.set_progress(ticks_in_level, ticks_required_for_next)

func _update_attribute_badge(accumulated_ticks: int) -> void:
	var training: TrainingActionData = action_data as TrainingActionData
	if training == null:
		return
	var attribute_effect: AwardAttributeEffectData = _find_attribute_effect(training)
	if attribute_effect == null:
		_attribute_badge.text = ""
		return
	var levels_available: int = training.ticks_per_level.size()
	var amount_per_level: float = attribute_effect.amount
	var current_level: int = training.get_current_level(accumulated_ticks)
	var current_total: int = int(round(current_level * amount_per_level))
	var max_total: int = int(round(levels_available * amount_per_level))
	var attr_name: String = CharacterAttributesData.AttributeType.keys()[attribute_effect.attribute_type].capitalize()
	_attribute_badge.text = "[right][color=#D4A84A]%d[/color][color=#7a6a52] / %d %s[/color][/right]" % [current_total, max_total, attr_name]

func _find_attribute_effect(training: TrainingActionData) -> AwardAttributeEffectData:
	for effect in training.effects_on_level:
		if effect is AwardAttributeEffectData:
			return effect as AwardAttributeEffectData
	return null

#-----------------------------------------------------------------------------
# SWEEP CONTROL
#-----------------------------------------------------------------------------

func _set_fill_amount(amount: float) -> void:
	if is_instance_valid(_progress_fill) and _progress_fill.material:
		_progress_fill.material.set_shader_parameter("fill_amount", amount)

func _set_fill_color(cat_color: Color) -> void:
	if is_instance_valid(_progress_fill):
		_progress_fill.color = Color(cat_color, FILL_TINT_OPACITY)

func _start_sweep() -> void:
	_set_fill_amount(0.0)
	_is_tracking_timer = true

func _stop_sweep() -> void:
	_is_tracking_timer = false
	_set_fill_amount(0.0)
	if is_instance_valid(_progress_fill):
		_progress_fill.self_modulate.a = 1.0

#-----------------------------------------------------------------------------
# PARTICLES
#-----------------------------------------------------------------------------

func _spawn_madra_particle(_tick_action: TrainingActionData) -> void:
	var target: Vector2 = button.get_madra_target_global_position()
	if target == Vector2.ZERO:
		return
	var card: PanelContainer = button.get_action_card()
	var spawn_pos: Vector2 = card.global_position + card.size * 0.5
	var particle: FlyingParticle = FlyingParticle.new()
	get_tree().current_scene.add_child(particle)
	particle.launch(spawn_pos, target, TICK_PARTICLE_COLOR, TICK_PARTICLE_DURATION, TICK_PARTICLE_SIZE)
