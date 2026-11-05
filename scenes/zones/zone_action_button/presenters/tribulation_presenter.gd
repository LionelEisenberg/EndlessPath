class_name TribulationPresenter
extends ZoneActionPresenter
## Presenter for TRIBULATION cards:
##   not ready: the Core row, the core rod (level / cap) and "Core <level> /
##     <cap>" in tan, and on a line under it the main stats still short
##     ("Strength Lv 3 / 10, Spirit Lv 9 / 10") in tan; tag TRIAL.
##   ready: "About <n> s" in brass on the left of the detail line and "failure
##     costs <levels> levels" in brass in its right column, the card's steady
##     brass ready frame and the ENTER tag.
## The card is ready while TribulationActionData.can_attempt(): the stage before
## the trial's target, a full core, and Strength and Spirit at the cap. It
## follows the core's level, the stage and the stat levels, and gates activation
## on the same question. A rejected click shakes the Core row softly in even-px
## steps (MapGlyph's soft shake) and logs a line per missing requirement.
## The card is the normal 72 px drawer unless a part of the ready line wraps or
## the stat line shows. The ready line's left part is one Label fitted by
## ZoneActionButton.fit_detail_label() and its right column wraps past half the
## line (set_detail_right), so neither is cut: a part too wide for its room wraps
## in the tall drawer.

@onready var _need_group: Control = %NeedGroup
@onready var _core_rod: LacquerRod = %CoreRod
@onready var _core_figure: Label = %CoreFigure
@onready var _stat_need_label: Label = %StatNeedLabel
@onready var _ready_label: Label = %ReadyLabel

var _shake_tween: Tween = null

## Moves the Core row into the card's footer and the ready line onto its detail
## line, and shows the state for the current Core Density and stat levels.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_need_group.reparent(button.get_footer_slot(), false)
	_ready_label.reparent(button.get_detail_slot(), false)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	CharacterManager.stat_level_changed.connect(_on_stat_level_changed)
	_update_state()

## Disconnects from the managers and stops a running shake.
func teardown() -> void:
	if CultivationManager.core_density_level_updated.is_connected(_on_core_density_level_updated):
		CultivationManager.core_density_level_updated.disconnect(_on_core_density_level_updated)
	if CultivationManager.advancement_stage_changed.is_connected(_on_advancement_stage_changed):
		CultivationManager.advancement_stage_changed.disconnect(_on_advancement_stage_changed)
	if CharacterManager.stat_level_changed.is_connected(_on_stat_level_changed):
		CharacterManager.stat_level_changed.disconnect(_on_stat_level_changed)
	_stop_shake()

## True while the player may face the trial now: a full core and Strength and
## Spirit at the cap, in the stage before the trial's target.
func can_activate() -> bool:
	return _can_attempt()

## Shakes the Core row and logs a line per missing requirement. The whole list on
## one line would run past the Log board.
func on_activation_rejected() -> void:
	_shake_reject()
	for requirement: String in TribulationActionData.get_missing_requirements():
		LogManager.log_message("[color=red]The Tribulation needs %s.[/color]" % requirement)

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
		var trial: TribulationData = (action_data as TribulationActionData).tribulation
		button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
		button.set_detail_right("failure costs %d levels" % trial.failure_level_loss, ThemeConstants.LACQUER_BRASS)
		_ready_label.text = "About %d s" % roundi(TribulationRun.new(trial).get_duration())
		button.fit_detail_label(_ready_label)
	else:
		button.set_mode_tag(ZoneActionGroups.mode_tag(action_data), ZoneActionButton.TagStyle.CARVED)
		button.set_detail_right("")
		_update_need()
		# A ready line that wrapped made the card tall; the Core row alone sits on
		# the short drawer, the stat line under it on the tall one.
		button.set_tall(_stat_need_label.visible)

## The Core row, and under it the main stats still short, shown only while one is.
func _update_need() -> void:
	var level: int = floori(CultivationManager.get_core_density_level())
	var cap: int = CultivationManager.get_core_density_cap()
	_core_figure.text = "Core %d / %d" % [level, cap]
	_core_rod.set_fraction(float(level) / cap if cap > 0 else 0.0)
	_stat_need_label.text = ", ".join(TribulationActionData.get_missing_requirements(false))
	_stat_need_label.visible = not _stat_need_label.text.is_empty()

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

## A stat's new level moves the stat line, and can ready the card or take it back.
func _on_stat_level_changed(_stat: CharacterAttributesData.AttributeType, _level: int) -> void:
	_update_state()
