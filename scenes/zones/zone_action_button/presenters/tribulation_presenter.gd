class_name TribulationPresenter
extends ZoneActionPresenter
## Presenter for TRIBULATION cards:
##   not ready: the Core row, the core's stars (LacquerStarRow, small), and on a
##     line under it the main stats still short ("Strength Lv 3 / 10, Spirit Lv
##     9 / 10") in tan; tag TRIAL.
##   ready: "About <n> s" in brass on the left of the detail line and "failure
##     costs half a star" (the trial's level loss in the core's stars) in brass
##     in its right column, the full stars under them, the card's steady brass
##     ready frame and the ENTER tag.
## The card is ready while TribulationActionData.can_attempt(): the stage before
## the trial's target, a full core, and Strength and Spirit at the cap. It
## follows the core's level, the stage, the stat levels and a save reset (which
## swaps them all at once), and gates activation
## on the same question. A rejected click shakes the Core row softly in even-px
## steps (MapGlyph's soft shake, through its offset transform, which the detail
## slot's layout leaves alone) and logs a line per missing requirement
## (TribulationActionData.get_refusal_lines(): the stage first, when the player
## stands in another).
## Nothing on the card is cut off. The Core row is the detail line's first row,
## and the stat line under it wraps at the detail line's width: the card grows
## by its lines and the Core row stays put. The ready line's left part is one
## Label wrapped by ZoneActionButton.fit_detail_label() and its right column
## wraps past half the line (set_detail_right); the ready stars are a row of
## their own under it.

## The Core row: one detail line, as wide as the detail line, with the stat line
## under it.
const ROW_WIDTH: float = ZoneActionButton.DETAIL_WIDTH
const ROW_HEIGHT: float = 18.0

@onready var _need_group: Control = %NeedGroup
@onready var _core_stars: LacquerStarRow = %CoreStars
@onready var _stat_need_label: Label = %StatNeedLabel
@onready var _ready_label: Label = %ReadyLabel
@onready var _ready_stars_row: Control = %ReadyStarsRow
@onready var _ready_stars: LacquerStarRow = %ReadyStars

var _shake_tween: Tween = null

## Moves the Core row, the ready line and the ready stars onto the card's detail
## line, and shows
## the state for the current Core Density and stat levels.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_need_group.reparent(button.get_detail_slot(), false)
	_ready_label.reparent(button.get_detail_slot(), false)
	_ready_stars_row.reparent(button.get_detail_slot(), false)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	CharacterManager.stat_level_changed.connect(_on_stat_level_changed)
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	_update_state()

## Disconnects from the managers and stops a running shake.
func teardown() -> void:
	if CultivationManager.core_density_level_updated.is_connected(_on_core_density_level_updated):
		CultivationManager.core_density_level_updated.disconnect(_on_core_density_level_updated)
	if CultivationManager.advancement_stage_changed.is_connected(_on_advancement_stage_changed):
		CultivationManager.advancement_stage_changed.disconnect(_on_advancement_stage_changed)
	if CharacterManager.stat_level_changed.is_connected(_on_stat_level_changed):
		CharacterManager.stat_level_changed.disconnect(_on_stat_level_changed)
	if PersistenceManager.save_data_reset.is_connected(_on_save_data_reset):
		PersistenceManager.save_data_reset.disconnect(_on_save_data_reset)
	_stop_shake()

## True while the player may face the trial now: a full core and Strength and
## Spirit at the cap, in the stage before the trial's target.
func can_activate() -> bool:
	return _can_attempt()

## Shakes the Core row and logs a line per missing requirement. The whole list on
## one line would run past the Log board.
func on_activation_rejected() -> void:
	_shake_reject()
	for requirement: String in (action_data as TribulationActionData).get_refusal_lines():
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
	_ready_stars_row.visible = is_ready
	button.set_ready_frame(is_ready)
	if is_ready:
		var trial: TribulationData = (action_data as TribulationActionData).tribulation
		button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
		button.set_detail_right("failure costs %s" % CultivationManager.describe_levels_in_stars(trial.failure_level_loss), ThemeConstants.LACQUER_BRASS)
		_ready_stars.set_fills(_core_fills())
		_ready_label.text = "About %d s" % roundi(TribulationRun.new(trial).get_duration())
		button.fit_detail_label(_ready_label)
	else:
		button.set_mode_tag(ZoneActionGroups.mode_tag(action_data), ZoneActionButton.TagStyle.CARVED)
		button.set_detail_right("")
		_update_need()
	button.relayout()

## The Core row's stars, and under them the main stats still short, shown only
## while one is; the row is as tall as the two.
func _update_need() -> void:
	_core_stars.set_fills(_core_fills())
	_stat_need_label.text = ", ".join(TribulationActionData.get_missing_requirements(false))
	_stat_need_label.visible = not _stat_need_label.text.is_empty()
	var row_height: float = ROW_HEIGHT
	if _stat_need_label.visible:
		# The width first: a wrapping label's height depends on it.
		_stat_need_label.size = Vector2(ROW_WIDTH, _stat_need_label.size.y)
		_stat_need_label.size = Vector2(ROW_WIDTH, _stat_need_label.get_minimum_size().y)
		row_height += _stat_need_label.size.y
	_need_group.custom_minimum_size = Vector2(ROW_WIDTH, row_height)

## The core's stars as it stands.
static func _core_fills() -> Array[float]:
	return CultivationManager.get_star_fills_at(floori(CultivationManager.get_core_density_level()))

## Shakes the Core row left and right in whole even-px steps (no easing, no
## scale): the soft shake a refused technique shakes its slot by, the map lock's
## rhythm at half its travel, 0, -4, 4, -2, 2, 0 over 0.44 s.
func _shake_reject() -> void:
	_stop_shake()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_shake, 0.0, MapGlyph.SHAKE_SECONDS, MapGlyph.SHAKE_SECONDS)

func _apply_shake(elapsed: float) -> void:
	_need_group.offset_transform_position = Vector2(MapGlyph.shake_offset_at(elapsed, MapGlyph.SOFT_SHAKE_KEYFRAMES), 0.0)

func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if is_instance_valid(_need_group):
		_need_group.offset_transform_position = Vector2.ZERO

func _on_core_density_level_updated(_xp: float, _level: float) -> void:
	_update_state()

func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_state()

## A stat's new level moves the stat line, and can ready the card or take it back.
func _on_stat_level_changed(_stat: CharacterAttributesData.AttributeType, _level: int) -> void:
	_update_state()

## A save reset swaps the core, the stage and the stat levels at once, with no
## stat level signal: the card re-reads them all.
func _on_save_data_reset() -> void:
	_update_state()
