class_name NowStrip
extends Control

## The Now tray at the top of the zone chest (lacquer kit §5.5): what the
## zone's idle action, or the cycle, is doing right now. It always shows and
## keeps its space in the chest.
## While an idle action (FORAGE or TRAIN_STATS) runs, a jade bead ring lights
## over each timer cycle (one Aura Well tick, one foraging haul), around the
## action's icon. The Aura Well variant shows its Madra rate,
## "Lv n → n+1 · +1 Spirit", the ticks into the level and a rod; the foraging
## variant shows each loot entry's range and "haul in N s". Clicking the tray
## emits strip_pressed (the chest scrolls to the running card and flashes it).
## While the player cycles, the tray shows the cycle in the Aura Well's layout,
## read from CyclingManager's session snapshot: the ring lights over the
## cycle, "Wilderness Cycling" with the Madra drawn per second, the equipped
## technique with "9 / 15 s" (its length, "15 s cycle", until a cycle runs)
## and the rod filling. The cycling card is not in the list while the player
## cycles, so the cycling tray takes no clicks.
## While none runs, the tray is empty: the ring dark, no icon, and one tan
## line, "<idle action> · paused" while a session action (the shop, an
## adventure, dialogue) stands in for the zone's idle action, or
## "Nothing running" when the zone has none. The empty tray takes no clicks.
## The strip is 392 wide, as the activity cards are (they keep their width beside
## the list's rail), so its edges and theirs line up, and its contents end 16 px
## short of where they ended in the 408 it was. No text in it is cut off: the
## action's name, the level line, the forage name and the empty tray's line wrap
## in what room their neighbours leave them, and the strip grows to hold them,
## 88 tall at least and an even number of px. The foraging yields wrap onto
## further rows of 20 px when a loot table has more than the row holds. The ring
## and the action's icon stay at the top. The tray's face is a NinePatchRect on
## the tray's art (a clean 9-slice). The zone chest listens to resized, and stands
## the Activities header, the list and the lore under the strip's bottom.

## Emitted when the player clicks the tray.
signal strip_pressed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ring strip's last frame: 13 frames, 0 dark and 12 fully lit.
const RING_LAST_FRAME: int = 12
const RING_FRAME_COUNT: int = 13
## The tray flashes once when its running card is clicked.
const FLASH_TIMES: int = 1
const SEPARATOR: String = " · "
## The empty tray's line: the idle action that resumes, or none.
const PAUSED_FORMAT: String = "%s · paused"
const NOTHING_RUNNING: String = "Nothing running"
## The cycle's figure: the seconds into the cycle and its length while a cycle
## runs, the length alone until one does.
const CYCLE_TIME_FORMAT: String = "%d / %d s"
const CYCLE_READY_FORMAT: String = "%d s cycle"
## The cycle's rate is read to CyclingManager.RATE_STEP, as on the cabinet, and
## shows from half that step: below it the rate reads +0.
const RATE_SHOWN_FROM: float = CyclingManager.RATE_STEP / 2.0
## The foraging haul's countdown.
const HAUL_FORMAT: String = "haul in %d s"

## The strip is the kit's 88 tall at least. Under the text of each look the room
## is what makes one line of each exactly that: the Aura Well's content starts 12
## down and is 62 tall (14 under), the forage's starts 18 down and is 50 tall (20
## under), and the empty tray's line starts 36 down and is 18 tall (34 under).
const MIN_HEIGHT: float = 88.0
const TRAINING_BOTTOM_ROOM: float = 14.0
const FORAGE_BOTTOM_ROOM: float = 20.0
const EMPTY_BOTTOM_ROOM: float = 34.0
## The gap between the level line and the ticks in the bottom row.
const ROW_GAP: float = 8.0

const FORAGE_YIELD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/forage_yield.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _ring: LacquerStripRect = %Ring
@onready var _action_icon: TextureRect = %ActionIcon
@onready var _training_content: Control = %TrainingContent
@onready var _training_name: Label = %TrainingName
@onready var _rate_group: Control = %RateGroup
@onready var _rate_text: RichTextLabel = %RateText
@onready var _level_label: Label = %LevelLabel
@onready var _ticks_label: Label = %TicksLabel
@onready var _well_rod: LacquerRod = %WellRod
@onready var _forage_content: Control = %ForageContent
@onready var _forage_name: Label = %ForageName
@onready var _yield_row: HFlowContainer = %YieldRow
@onready var _haul_label: Label = %HaulLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The idle or cycling action shown, or null while the tray is empty.
var _action: ZoneActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	ActionManager.training_tick_processed.connect(_on_training_tick_processed)
	ActionManager.training_level_gained.connect(_on_training_level_gained)
	UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	CyclingManager.equipped_technique_changed.connect(_on_equipped_technique_changed)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_hover_frame.show)
	mouse_exited.connect(_hover_frame.hide)
	_yield_row.sort_children.connect(_on_yield_row_sorted)
	_show_action(ActionManager.get_current_action())

func _process(_delta: float) -> void:
	_update_timer_display()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Flashes the brass frame over the tray once (300 ms on, 300 ms off).
func flash() -> void:
	_flash_frame.flash(FLASH_TIMES)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Shows the action when it is idle or cycling; empties the tray otherwise.
func _show_action(action: ZoneActionData) -> void:
	var idle: bool = _is_idle(action)
	var cycling: bool = _is_cycling(action)
	_action = action if idle or cycling else null
	var running: bool = _action != null
	set_process(running)
	# A press on the tray scrolls the chest to the running card, so only an idle
	# action takes clicks: the cycling card is not in the list while cycling.
	mouse_filter = MOUSE_FILTER_STOP if idle else MOUSE_FILTER_IGNORE
	_empty_label.visible = not running
	if not running:
		_show_empty()
		return
	_action_icon.texture = _action.icon
	var training := _action as TrainingActionData
	var forage := _action as ForageActionData
	_training_content.visible = training != null or cycling
	_forage_content.visible = forage != null
	if training != null:
		_show_training(training)
	elif forage != null:
		_show_forage(forage)
	elif cycling:
		_show_cycling()
	_update_timer_display()
	_fit()

## The empty tray: the ring at its dark frame, no icon, no content, and the
## one line.
func _show_empty() -> void:
	_hover_frame.hide()
	_ring.set_frame(0)
	_action_icon.texture = null
	_training_content.visible = false
	_forage_content.visible = false
	_update_empty_line()

## "<idle action> · paused" for the idle action the current zone resumes
## when the session action ends, or "Nothing running" when it has none.
func _update_empty_line() -> void:
	var zone: ZoneData = ZoneManager.get_current_zone()
	var idle: ZoneActionData = ActionManager.resolve_idle_action(zone.zone_id) if zone != null else null
	_empty_label.text = PAUSED_FORMAT % idle.action_name if idle != null else NOTHING_RUNNING
	_fit()

## "+1.5 Madra / s", "Lv 1 → 2 · +1 Spirit", "214 / 300" and the rod toward
## the next level.
func _show_training(training: TrainingActionData) -> void:
	_training_name.text = training.action_name
	var madra_per_second: float = training.get_madra_per_second()
	_rate_group.visible = madra_per_second > 0.0
	_rate_text.text = LacquerText.decimal_bbcode("%s Madra / s" % LacquerText.rate(madra_per_second))
	_update_training_progress()

func _update_training_progress() -> void:
	var training := _action as TrainingActionData
	if training == null:
		return
	var ticks: int = ZoneManager.get_training_ticks(training.action_id)
	var level: int = training.get_current_level(ticks)
	var ticks_in_level: int = training.get_ticks_in_level(ticks)
	var ticks_for_next: int = training.get_ticks_for_next_level(ticks)
	var level_line: String = "Lv %d → %d" % [level, level + 1]
	var reward: String = _level_reward_text(training)
	if reward != "":
		level_line += SEPARATOR + reward
	_level_label.text = level_line
	_ticks_label.text = "%d / %d" % [ticks_in_level, ticks_for_next]
	_well_rod.set_fraction(float(ticks_in_level) / ticks_for_next if ticks_for_next > 0 else 0.0)
	_fit_training_labels()
	_fit()

## "+1 Spirit": the first attribute award each level grants.
func _level_reward_text(training: TrainingActionData) -> String:
	for effect: EffectData in training.effects_on_level:
		var award := effect as AwardAttributeEffectData
		if award != null:
			return "%s %s" % [LacquerText.rate(award.amount), CharacterManager.get_attribute_display_name(award.attribute_type)]
	return ""

## The cycling action in the Aura Well's layout: its name, and the equipped
## technique where the level line goes. The figure, the rod and the rate follow
## the session snapshot every frame. The tray takes no clicks while cycling, so
## no hover frame stays from the idle action's tray.
func _show_cycling() -> void:
	_hover_frame.hide()
	_training_name.text = _action.action_name
	_update_technique()

## The equipped technique's name, where the Aura Well shows its level line.
func _update_technique() -> void:
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	_level_label.text = technique.technique_name if technique != null else ""

## The ring, the figure, the rod and the rate, read from the session snapshot.
func _update_cycle_display() -> void:
	var progress: float = CyclingManager.get_cycle_progress()
	_light_ring(progress)
	_well_rod.set_fraction(progress)
	_update_cycle_figure()
	_update_cycle_rate()

## "9 / 15 s" while a cycle runs; until one does, the equipped technique's
## length, "15 s cycle".
func _update_cycle_figure() -> void:
	if CyclingManager.is_cycle_running():
		_ticks_label.text = CYCLE_TIME_FORMAT % [floori(CyclingManager.get_cycle_elapsed()), roundi(CyclingManager.get_cycle_duration())]
		return
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	_ticks_label.text = CYCLE_READY_FORMAT % roundi(technique.cycle_duration) if technique != null else ""

## "+13.3 Madra / s" while the cycle draws Madra; hidden otherwise. The rate
## is read to a tenth, so a rate that reads +0 hides instead of showing "+0".
func _update_cycle_rate() -> void:
	var rate: float = CyclingManager.get_madra_rate()
	_rate_group.visible = rate >= RATE_SHOWN_FROM
	if _rate_group.visible:
		_rate_text.text = LacquerText.decimal_bbcode("%s Madra / s" % LacquerText.rate(snappedf(rate, CyclingManager.RATE_STEP)))

## Sizes the strip to what shows in it (an even height, 88 at least): the Aura
## Well's rows, the forage's name and yields, or the empty tray's line.
func _fit() -> void:
	var bottom: float = MIN_HEIGHT
	if _training_content.visible:
		bottom = _training_content.position.y + _training_content.get_combined_minimum_size().y + TRAINING_BOTTOM_ROOM
	elif _forage_content.visible:
		bottom = _forage_content.position.y + _forage_content.get_combined_minimum_size().y + FORAGE_BOTTOM_ROOM
	elif _empty_label.visible:
		bottom = _empty_label.position.y + _empty_label.get_combined_minimum_size().y + EMPTY_BOTTOM_ROOM
	size.y = ceilf(maxf(MIN_HEIGHT, bottom) / 2.0) * 2.0

## The action's name wraps in the row's room less the Madra rate beside it, and the
## level line in its room less the ticks beside it. (A Label that shares its row
## is given its width as a minimum and as the size, so its lines are counted at
## that width at once.)
func _fit_training_labels() -> void:
	var rate_width: float = _rate_group.get_combined_minimum_size().x if _rate_group.visible else 0.0
	_set_wrap_width(_training_name, _training_content.size.x - rate_width)
	_set_wrap_width(_level_label, _training_content.size.x - ROW_GAP - _ticks_label.get_combined_minimum_size().x)

## Gives `label` that width (at least 1 px) as its minimum and as its size, and has
## the boxes above it ask again for its height: a change of width otherwise leaves
## the last height cached.
func _set_wrap_width(label: Label, width: float) -> void:
	var room: float = maxf(width, 1.0)
	label.custom_minimum_size.x = room
	label.size.x = room
	label.update_minimum_size()

## The action's name and one yield per loot entry (its 16 px icon and
## "min–max"). The haul countdown follows the timer every frame.
func _show_forage(forage: ForageActionData) -> void:
	_forage_name.text = forage.action_name
	_fit_haul_column(forage)
	for child: Node in _yield_row.get_children():
		_yield_row.remove_child(child)
		child.queue_free()
	if forage.loot_table == null:
		return
	for entry: LootTableEntry in forage.loot_table.entries:
		if entry == null or entry.item == null:
			continue
		var yield_item: Control = FORAGE_YIELD_SCENE.instantiate() as Control
		_yield_row.add_child(yield_item)
		var icon_rect: TextureRect = yield_item.get_node("%Icon") as TextureRect
		icon_rect.texture = entry.item.get_mini_icon()
		icon_rect.visible = icon_rect.texture != null
		(yield_item.get_node("%RangeText") as RichTextLabel).text = _range_text(entry)

## Gives the haul countdown the width of its widest reading ("haul in N s" for any
## N of a cycle), so the yields wrapping beside it keep the room they have as the
## digits change from one second to the next (a digit is a pixel or two wider than
## another, and a yield that fits by less would jump between rows).
func _fit_haul_column(forage: ForageActionData) -> void:
	var font: Font = _haul_label.get_theme_font(&"font")
	var font_size: int = _haul_label.get_theme_font_size(&"font_size")
	var widest: float = 0.0
	for seconds: int in range(1, ceili(forage.foraging_interval_in_sec) + 1):
		widest = maxf(widest, font.get_string_size(HAUL_FORMAT % seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_haul_label.custom_minimum_size.x = widest

func _range_text(entry: LootTableEntry) -> String:
	if entry.min_quantity == entry.max_quantity:
		return str(entry.min_quantity)
	return "%d–%d" % [entry.min_quantity, entry.max_quantity]

## The ring lights floor(progress × 13) beads, at most 12, where progress is
## how far the action timer is through its cycle; foraging also counts down
## to the haul. While cycling, progress is how far the session snapshot is
## through the cycle, and the figure, the rod and the rate follow it too.
func _update_timer_display() -> void:
	if _action == null:
		return
	if _is_cycling(_action):
		_update_cycle_display()
		return
	var timer: Timer = ActionManager.action_timer
	var progress: float = 0.0
	if not timer.is_stopped() and timer.wait_time > 0.0:
		progress = clampf(1.0 - timer.time_left / timer.wait_time, 0.0, 1.0)
	_light_ring(progress)
	if _forage_content.visible:
		var seconds_left: int = ceili(timer.time_left) if not timer.is_stopped() else ceili(timer.wait_time)
		_haul_label.text = HAUL_FORMAT % seconds_left

## Lights floor(progress × 13) beads of the ring, at most 12.
func _light_ring(progress: float) -> void:
	var ring_frame: int = mini(floori(progress * RING_FRAME_COUNT), RING_LAST_FRAME)
	if ring_frame != _ring.get_frame().x:
		_ring.set_frame(ring_frame)

func _is_idle(action: ZoneActionData) -> bool:
	if action == null:
		return false
	return action.action_type == ZoneActionData.ActionType.FORAGE \
		or action.action_type == ZoneActionData.ActionType.TRAIN_STATS

func _is_cycling(action: ZoneActionData) -> bool:
	return action != null and action.action_type == ZoneActionData.ActionType.CYCLING

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_current_action_changed(action: ZoneActionData) -> void:
	_show_action(action)

## An idle action that unlocks while a session action runs does not start
## (ActionManager waits for the session to end), but it is now the one that
## resumes.
func _on_condition_unlocked(_condition_id: String) -> void:
	if _action == null:
		_update_empty_line()

## The yields wrap in the room the haul countdown leaves them, and how many rows
## they make is known only once the flow has sorted at that width (the strip's
## first fit comes before it), so the strip fits again when the flow has sorted.
func _on_yield_row_sorted() -> void:
	_fit()

func _on_training_tick_processed(training: TrainingActionData, _new_tick_count: int) -> void:
	if training == _action:
		_update_training_progress()

func _on_training_level_gained(training: TrainingActionData, _new_level: int) -> void:
	if training == _action:
		_update_training_progress()

## The detail line and the ready figure follow the equipped technique at once,
## not at the next frame.
func _on_equipped_technique_changed(_technique: CyclingTechniqueData) -> void:
	if _is_cycling(_action):
		_update_technique()
		_update_cycle_figure()

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		strip_pressed.emit()
