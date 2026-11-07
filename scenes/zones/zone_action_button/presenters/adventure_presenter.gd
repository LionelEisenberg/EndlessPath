class_name AdventurePresenter
extends ZoneActionPresenter
## Presenter for ADVENTURE cards, 72 px while their text fits. The detail line
## is the two pools a run plays on, each as the dock's 16 px mini and its figure
## in its ink, read as the cabinet reads them ([heart] 38 / 100  [drop] 100 /
## 100), and the run's length, "<minutes> min run", in brass in the right
## column. The card is always ready: the steady brass ready frame and ENTER.
##
## A pool below half its max (ResourceManager.is_health_low(), is_madra_low())
## blinks: its figure steps between its ink and dim tan, BLINK_SECONDS each,
## while it is low, both on one beat. A click then asks before the run starts:
## can_activate() is false, and on_activation_rejected() hands the question to
## ActionManager.ask_to_start_adventure(), which the "Head out?" board answers.
## The card follows both pools, and the stats that move their maxima (Body,
## Mind, gear).

const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const MADRA_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_madra_ai.png")
## How long a low figure stays lit, and then dim.
const BLINK_SECONDS: float = 0.5

@onready var _pools: HFlowContainer = %Pools
@onready var _health_pool: HBoxContainer = %HealthPool
@onready var _madra_pool: HBoxContainer = %MadraPool
@onready var _blink_timer: Timer = %BlinkTimer

## Whether a low figure shows its ink (lit) or dim tan: the blink's step.
var _lit: bool = true

## Moves the pools line onto the card's detail line and shows the pools.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_pools.reparent(button.get_detail_slot(), false)
	(_health_pool.get_node("%Icon") as TextureRect).texture = HEALTH_ICON
	(_madra_pool.get_node("%Icon") as TextureRect).texture = MADRA_ICON
	_blink_timer.wait_time = BLINK_SECONDS
	_blink_timer.timeout.connect(_on_blink_timer_timeout)
	ResourceManager.madra_changed.connect(_on_pool_changed)
	ResourceManager.health_changed.connect(_on_pool_changed)
	CharacterManager.stats_changed.connect(_on_stats_changed)
	_update_state()

## Disconnects from the managers and stops the blink.
func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_pool_changed):
		ResourceManager.madra_changed.disconnect(_on_pool_changed)
	if ResourceManager.health_changed.is_connected(_on_pool_changed):
		ResourceManager.health_changed.disconnect(_on_pool_changed)
	if CharacterManager.stats_changed.is_connected(_on_stats_changed):
		CharacterManager.stats_changed.disconnect(_on_stats_changed)
	_blink_timer.stop()

## True while Health or Madra is below half its max: the card blinks, and a
## click asks before the run starts.
static func is_a_pool_low() -> bool:
	return ResourceManager.is_health_low() or ResourceManager.is_madra_low()

## "38 / 100": the Health pool over its max, as the cabinet reads it.
static func health_text() -> String:
	return VitalsText.health_pair(ResourceManager.get_health(), ResourceManager.get_max_health())

## "60 / 100": the Madra pool over its max, as the cabinet reads it.
static func madra_text() -> String:
	return "%d / %d" % [floori(ResourceManager.get_madra()), floori(ResourceManager.get_max_madra())]

## A run starts at once only while both pools are at half or more.
func can_activate() -> bool:
	return not is_a_pool_low()

## Below half: asks the player first. The "Head out?" board starts the run.
func on_activation_rejected() -> void:
	ActionManager.ask_to_start_adventure(action_data as AdventureActionData)

## Whether a low figure is lit at this step of the blink. Always true while no
## pool is low.
func is_lit() -> bool:
	return _lit

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _update_state() -> void:
	button.set_ready_frame(true)
	button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
	button.set_detail_right(_run_length_text(), ThemeConstants.LACQUER_BRASS)
	if not is_a_pool_low():
		_blink_timer.stop()
		_lit = true
	elif _blink_timer.is_stopped():
		_lit = true
		_blink_timer.start()
	_write_pools()

## Each pool's figure, in its ink, or dim tan while it is low and the blink is
## at its dim step. The line takes the room the right column leaves, and a pool
## that would pass it moves to the next line whole: the card grows.
func _write_pools() -> void:
	_write_pool(_health_pool, health_text(), ThemeConstants.LACQUER_HEALTH, ResourceManager.is_health_low())
	_write_pool(_madra_pool, madra_text(), ThemeConstants.LACQUER_MADRA, ResourceManager.is_madra_low())
	_pools.custom_minimum_size.x = button.get_detail_room()
	button.relayout()

func _write_pool(pool: HBoxContainer, figure: String, ink: Color, low: bool) -> void:
	var text: RichTextLabel = pool.get_node("%YieldText") as RichTextLabel
	text.text = LacquerText.decimal_bbcode(figure)
	text.add_theme_color_override(&"default_color", ThemeConstants.LACQUER_DIM if low and not _lit else ink)

## "5 min run": the run's time limit.
func _run_length_text() -> String:
	var adventure := action_data as AdventureActionData
	var minutes: float = adventure.time_limit_seconds / 60.0 if adventure else 0.0
	return "%s min run" % LacquerText.rate(minutes).trim_prefix("+")

func _on_pool_changed(_amount: float) -> void:
	_update_state()

## Training, gear and any modifier source move the pools' maxima.
func _on_stats_changed() -> void:
	_update_state()

## The blink's step: a low figure turns dim, or lit again.
func _on_blink_timer_timeout() -> void:
	_lit = not _lit
	_write_pools()
