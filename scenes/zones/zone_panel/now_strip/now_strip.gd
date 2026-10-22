class_name NowStrip
extends Control

## The Now tray at the top of the zone chest (lacquer kit §5.5): what the
## zone's idle action is doing right now. It shows only while an idle action
## (FORAGE or TRAIN_STATS) runs, and hides outright otherwise.
## A jade bead ring lights over each timer cycle (one Aura Well tick, one
## foraging haul), around the action's icon. The Aura Well variant shows its
## Madra rate, "Lv n → n+1 · +1 Spirit", the ticks into the level and a rod;
## the foraging variant shows each loot entry's range and "haul in N s".
## Clicking the tray emits strip_pressed (the chest scrolls to the running
## card and flashes it).

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
@onready var _yield_row: HBoxContainer = %YieldRow
@onready var _haul_label: Label = %HaulLabel
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The idle action shown, or null while the strip is hidden.
var _action: ZoneActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	ActionManager.training_tick_processed.connect(_on_training_tick_processed)
	ActionManager.training_level_gained.connect(_on_training_level_gained)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_hover_frame.show)
	mouse_exited.connect(_hover_frame.hide)
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

## Shows the action when it is idle; hides the strip otherwise.
func _show_action(action: ZoneActionData) -> void:
	_action = action if _is_idle(action) else null
	visible = _action != null
	set_process(visible)
	if _action == null:
		_hover_frame.hide()
		return
	_action_icon.texture = _action.icon
	var training := _action as TrainingActionData
	var forage := _action as ForageActionData
	_training_content.visible = training != null
	_forage_content.visible = forage != null
	if training != null:
		_show_training(training)
	elif forage != null:
		_show_forage(forage)
	_update_timer_display()

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

## "+1 Spirit": the first attribute award each level grants.
func _level_reward_text(training: TrainingActionData) -> String:
	for effect: EffectData in training.effects_on_level:
		var award := effect as AwardAttributeEffectData
		if award != null:
			return "%s %s" % [LacquerText.rate(award.amount), CharacterManager.get_attribute_display_name(award.attribute_type)]
	return ""

## The action's name and one yield per loot entry (its 16 px icon and
## "min–max"). The haul countdown follows the timer every frame.
func _show_forage(forage: ForageActionData) -> void:
	_forage_name.text = forage.action_name
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
		icon_rect.texture = ForagingPresenter.MINI_ICONS.get(entry.item.item_id, entry.item.icon) as Texture2D
		icon_rect.visible = icon_rect.texture != null
		(yield_item.get_node("%RangeText") as RichTextLabel).text = _range_text(entry)

func _range_text(entry: LootTableEntry) -> String:
	if entry.min_quantity == entry.max_quantity:
		return str(entry.min_quantity)
	return "%d–%d" % [entry.min_quantity, entry.max_quantity]

## The ring lights floor(progress × 13) beads, at most 12, where progress is
## how far the action timer is through its cycle; foraging also counts down
## to the haul.
func _update_timer_display() -> void:
	if _action == null:
		return
	var timer: Timer = ActionManager.action_timer
	var progress: float = 0.0
	if not timer.is_stopped() and timer.wait_time > 0.0:
		progress = clampf(1.0 - timer.time_left / timer.wait_time, 0.0, 1.0)
	var ring_frame: int = mini(floori(progress * RING_FRAME_COUNT), RING_LAST_FRAME)
	if ring_frame != _ring.get_frame().x:
		_ring.set_frame(ring_frame)
	if _forage_content.visible:
		var seconds_left: int = ceili(timer.time_left) if not timer.is_stopped() else ceili(timer.wait_time)
		_haul_label.text = "haul in %d s" % seconds_left

func _is_idle(action: ZoneActionData) -> bool:
	if action == null:
		return false
	return action.action_type == ZoneActionData.ActionType.FORAGE \
		or action.action_type == ZoneActionData.ActionType.TRAIN_STATS

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_current_action_changed(action: ZoneActionData) -> void:
	_show_action(action)

func _on_training_tick_processed(training: TrainingActionData, _new_tick_count: int) -> void:
	if training == _action:
		_update_training_progress()

func _on_training_level_gained(training: TrainingActionData, _new_level: int) -> void:
	if training == _action:
		_update_training_progress()

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		strip_pressed.emit()
