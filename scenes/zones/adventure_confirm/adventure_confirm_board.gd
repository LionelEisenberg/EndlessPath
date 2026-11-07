class_name AdventureConfirmBoard
extends Control
## The "Head out?" board: the question the adventure card asks when Health or
## Madra is below half its max (AdventurePresenter). A small board in the map
## gap, with no backdrop, so the cabinet and the chest stay up beside it: the
## Tribulation intro's frame and buttons. It shows each low pool as the card does
## (the dock's mini and its figure, in its ink), then what refills it, and Head
## out and Not yet. Head out emits confirmed; Not yet and a click outside the
## board emit dismissed. AdventureConfirmState shows it, answers both, and closes
## it on Esc.

signal confirmed
signal dismissed

const HEALTH_ADVICE: String = "Below half. Riverbank Training heals it."
const MADRA_ADVICE: String = "Below half. Cycling refills it."
const BOTH_ADVICE: String = "Below half. Riverbank Training heals Health; cycling refills Madra."
const NO_HEALTH_ADVICE: String = "The first hit that lands ends the run. Riverbank Training heals it."
## The Health lines before Riverbank Training opens: a won first fight can send
## the player home hurt before First Steps Out's end opens it.
const HEALTH_ADVICE_BEFORE_RIVER: String = "Below half. Return to the [INTERVENER] to heal it."
const BOTH_ADVICE_BEFORE_RIVER: String = "Below half. Return to the [INTERVENER] to heal Health; cycling refills Madra."
const NO_HEALTH_ADVICE_BEFORE_RIVER: String = "The first hit that lands ends the run."
## The action that heals at home, which the Health lines name once it is open.
const RIVERBANK_ACTION_ID: String = "riverbank_training_action"
## How far a button's word drops while it is held down, with its pressed face.
const PRESSED_TEXT_DROP: float = 2.0

@onready var _click_away: Control = %ClickAway
@onready var _health_pool: HBoxContainer = %HealthPool
@onready var _madra_pool: HBoxContainer = %MadraPool
@onready var _advice: Label = %Advice
@onready var _go_button: TextureButton = %GoButton
@onready var _go_label: Label = %GoLabel
@onready var _go_hover: LacquerFrameOverlay = %GoHover
@onready var _stay_button: TextureButton = %StayButton
@onready var _stay_label: Label = %StayLabel
@onready var _stay_hover: LacquerFrameOverlay = %StayHover

func _ready() -> void:
	hide()
	(_health_pool.get_node("%Icon") as TextureRect).texture = AdventurePresenter.HEALTH_ICON
	(_madra_pool.get_node("%Icon") as TextureRect).texture = AdventurePresenter.MADRA_ICON
	_go_button.pressed.connect(confirmed.emit)
	_stay_button.pressed.connect(dismissed.emit)
	_click_away.gui_input.connect(_on_click_away_gui_input)
	for pair: Array in [[_go_button, _go_hover, _go_label], [_stay_button, _stay_hover, _stay_label]]:
		var button: TextureButton = pair[0]
		var hover: LacquerFrameOverlay = pair[1]
		button.mouse_entered.connect(hover.show)
		button.mouse_exited.connect(hover.hide)
		button.button_down.connect(_drop_word.bind(pair[2], true))
		button.button_up.connect(_drop_word.bind(pair[2], false))

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Writes the low pools and their advice as they stand, and shows the board.
func ask() -> void:
	var health_low: bool = ResourceManager.is_health_low()
	var madra_low: bool = ResourceManager.is_madra_low()
	_write_pool(_health_pool, AdventurePresenter.health_text(), ThemeConstants.LACQUER_HEALTH, health_low)
	_write_pool(_madra_pool, AdventurePresenter.madra_text(), ThemeConstants.LACQUER_MADRA, madra_low)
	_advice.text = advice_text()
	for hover: LacquerFrameOverlay in [_go_hover, _stay_hover]:
		hover.hide()
	show()

## Hides the board.
func close() -> void:
	hide()

## What refills the low pools: one line for Health, Madra or both, and a
## warning at 0 Health, whatever Madra holds. The Health lines name Riverbank
## Training only once it is open.
static func advice_text() -> String:
	var river_open: bool = _is_riverbank_open()
	if ResourceManager.get_health() <= 0.0:
		return NO_HEALTH_ADVICE if river_open else NO_HEALTH_ADVICE_BEFORE_RIVER
	var health_low: bool = ResourceManager.is_health_low()
	var madra_low: bool = ResourceManager.is_madra_low()
	if health_low and madra_low:
		return BOTH_ADVICE if river_open else BOTH_ADVICE_BEFORE_RIVER
	if health_low:
		return HEALTH_ADVICE if river_open else HEALTH_ADVICE_BEFORE_RIVER
	return MADRA_ADVICE

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## True when Riverbank Training's unlock conditions have latched.
static func _is_riverbank_open() -> bool:
	var action: ZoneActionData = ZoneManager.get_action_by_id(RIVERBANK_ACTION_ID)
	return action != null and UnlockManager.are_unlock_conditions_met(action.unlock_conditions)

## Shows a low pool's figure in its ink, and hides a pool at half or more.
func _write_pool(pool: HBoxContainer, figure: String, ink: Color, low: bool) -> void:
	pool.visible = low
	var text: RichTextLabel = pool.get_node("%YieldText") as RichTextLabel
	text.text = LacquerText.decimal_bbcode(figure)
	text.add_theme_color_override(&"default_color", ink)

## Stands `label` PRESSED_TEXT_DROP px lower when `dropped`, or home.
func _drop_word(label: Label, dropped: bool) -> void:
	label.position.y = PRESSED_TEXT_DROP if dropped else 0.0

## A press outside the board: Not yet.
func _on_click_away_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed:
		accept_event()
		dismissed.emit()
