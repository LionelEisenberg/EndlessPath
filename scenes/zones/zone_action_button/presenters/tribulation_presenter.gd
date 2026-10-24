class_name TribulationPresenter
extends ZoneActionPresenter
## Presenter for TRIBULATION cards:
##   below the cap: the Core row, the core rod (level / cap) and "Core <level> /
##     <cap>" in tan; tag TRIAL.
##   at the cap: "About <n> s · a failure costs <levels> levels" in brass on the
##     detail line, the card's steady brass ready frame and the ENTER tag.
## The card is ready while TribulationActionData.can_attempt(): the stage before
## the trial's target with a full core. It follows the core's level and the
## stage, and gates activation on the same question. A rejected click shakes the
## Core row softly in even-px steps (MapGlyph's soft shake) and logs why.
## The card is the normal 72 px drawer in both states. The ready line is one
## Label fitted by ZoneActionButton.fit_detail_label(), so a line wider than the
## detail slot wraps in the tall drawer instead of being cut; the card is short
## again once it is not ready.

@onready var _need_group: Control = %NeedGroup
@onready var _core_rod: LacquerRod = %CoreRod
@onready var _core_figure: Label = %CoreFigure
@onready var _ready_label: Label = %ReadyLabel

var _shake_tween: Tween = null

## Moves the Core row into the card's footer and the ready line onto its detail
## line, and shows the state for the current Core Density.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_need_group.reparent(button.get_footer_slot(), false)
	_ready_label.reparent(button.get_detail_slot(), false)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	_update_state()

## Disconnects from the manager and stops a running shake.
func teardown() -> void:
	if CultivationManager.core_density_level_updated.is_connected(_on_core_density_level_updated):
		CultivationManager.core_density_level_updated.disconnect(_on_core_density_level_updated)
	if CultivationManager.advancement_stage_changed.is_connected(_on_advancement_stage_changed):
		CultivationManager.advancement_stage_changed.disconnect(_on_advancement_stage_changed)
	_stop_shake()

## True while the player may face the trial now: the core is full, in the stage
## before the trial's target.
func can_activate() -> bool:
	return _can_attempt()

## Shakes the Core row and logs how far the core is from full.
func on_activation_rejected() -> void:
	_shake_reject()
	var level: int = floori(CultivationManager.get_core_density_level())
	var cap: int = CultivationManager.get_core_density_cap()
	LogManager.log_message("[color=red]Your core must be full to face the Tribulation (%d / %d).[/color]" % [level, cap])

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _can_attempt() -> bool:
	var tribulation := action_data as TribulationActionData
	return tribulation != null and tribulation.can_attempt()

func _update_state() -> void:
	var is_ready: bool = _can_attempt()
	_need_group.visible = not is_ready
	_ready_label.visible = is_ready
	button.set_ready_frame(is_ready)
	if is_ready:
		button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
		_ready_label.text = _ready_line()
		button.fit_detail_label(_ready_label)
	else:
		button.set_mode_tag(ZoneActionGroups.mode_tag(action_data), ZoneActionButton.TagStyle.CARVED)
		# A ready line that wrapped made the card tall; the Core row sits on the short one.
		button.set_tall(false)
		_update_need()

func _update_need() -> void:
	var level: int = floori(CultivationManager.get_core_density_level())
	var cap: int = CultivationManager.get_core_density_cap()
	_core_figure.text = "Core %d / %d" % [level, cap]
	_core_rod.set_fraction(float(level) / cap if cap > 0 else 0.0)

## How long the trial takes and what a failure costs. Only read while the card
## is ready, which needs a trial.
func _ready_line() -> String:
	var trial: TribulationData = (action_data as TribulationActionData).tribulation
	var seconds: int = roundi(TribulationRun.new(trial).get_duration())
	return "About %d s · a failure costs %d levels" % [seconds, trial.failure_level_loss]

## Shakes the Core row left and right in whole even-px steps (no easing, no
## scale): the soft shake a refused technique shakes its slot by, the map lock's
## rhythm at half its travel, 0, -4, 4, -2, 2, 0 over 0.44 s.
func _shake_reject() -> void:
	_stop_shake()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_shake, 0.0, MapGlyph.SHAKE_SECONDS, MapGlyph.SHAKE_SECONDS)

func _apply_shake(elapsed: float) -> void:
	_need_group.position.x = MapGlyph.shake_offset_at(elapsed, MapGlyph.SOFT_SHAKE_KEYFRAMES)

func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if is_instance_valid(_need_group):
		_need_group.position.x = 0.0

func _on_core_density_level_updated(_xp: float, _level: float) -> void:
	_update_state()

func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_state()
