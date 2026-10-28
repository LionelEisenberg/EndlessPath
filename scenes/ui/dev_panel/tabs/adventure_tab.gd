class_name DevAdventureTab
extends ScrollContainer

## The dev panel's Adventure tab: the controls that act on a run. While none runs it
## says so and shows nothing else. During a run it shows exits as a victory and as a
## defeat, a toggle that lifts the fog off the whole map, a refill of the player's
## Health and Stamina, and, in a fight only, a button that wins the fight. Each calls
## DevCommands, which logs it and says why it refused, and a refusal shows above the
## controls until a command works. The whole-map toggle lives on the view, not in
## DevCommands, so the tab writes its [DEV] line itself.
##
## The tab follows the run through ActionManager's start_adventure and stop_adventure,
## as the view does, and asks the view whether a fight is on while the tab is in view.
## DevPanel hands it the view in _ready() (set_adventure_view()).

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _no_run_label: Label = %NoRunLabel
@onready var _run_controls: Control = %RunControls
@onready var _status: Label = %AdventureStatus
@onready var _fight_box: Control = %FightBox
@onready var _force_win: Button = %ForceWin
@onready var _exit_victory: Button = %ExitVictory
@onready var _exit_defeat: Button = %ExitDefeat
@onready var _show_whole_map: CheckButton = %ShowWholeMap
@onready var _refill_vitals: Button = %RefillVitals

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The adventure view the commands act on. Null until set_adventure_view().
var _view: AdventureView = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_force_win.pressed.connect(_on_force_win_pressed)
	_exit_victory.pressed.connect(_on_exit_pressed.bind(true))
	_exit_defeat.pressed.connect(_on_exit_pressed.bind(false))
	_show_whole_map.toggled.connect(_on_show_whole_map_toggled)
	_refill_vitals.pressed.connect(_on_refill_vitals_pressed)
	ActionManager.start_adventure.connect(_on_adventure_started)
	ActionManager.stop_adventure.connect(_on_adventure_stopped)
	_show_run(false)

## Shows the fight button while the view has a fight on. Only while the tab is in view:
## a closed panel, or another tab on top, asks the view nothing.
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_fight_box.visible = is_instance_valid(_view) and _view.is_in_combat

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Sets the adventure view the commands act on, and shows whether it has a run on
## already. DevPanel calls it from its _ready().
func set_adventure_view(view: AdventureView) -> void:
	_view = view
	_show_run(is_instance_valid(view) and view.is_adventure_running())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_adventure_started(_action: AdventureActionData, _madra_budget: float) -> void:
	_show_run(true)

func _on_adventure_stopped() -> void:
	_show_run(false)

func _on_force_win_pressed() -> void:
	_show_result(DevCommands.force_win_fight(_view))

func _on_exit_pressed(victory: bool) -> void:
	_show_result(DevCommands.exit_adventure(_view, victory))

func _on_refill_vitals_pressed() -> void:
	_show_result(DevCommands.refill_vitals())

## Lifts the fog off the whole map, or puts it back. A toggle on the view, so the tab
## logs its [DEV] line itself.
func _on_show_whole_map_toggled(pressed: bool) -> void:
	if not is_instance_valid(_view):
		return
	_view.set_show_whole_map(pressed)
	DevCommands.log_dev_line("Show Whole Map: %s" % ("ON" if pressed else "OFF"))

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Shows the run's controls while a run is on and "No adventure running" while none is,
## and forgets the last refusal. The whole-map toggle starts from the state of the
## view's map, which outlasts a run, without toggling it.
func _show_run(running: bool) -> void:
	_no_run_label.visible = not running
	_run_controls.visible = running
	if running and is_instance_valid(_view):
		_show_whole_map.set_pressed_no_signal(_view.adventure_tilemap.is_dev_reveal_all())
	_show_result("")

## Shows why a command refused, above the controls, and hides the line once a command
## works (it returns "").
func _show_result(refusal: String) -> void:
	_status.text = refusal
	_status.visible = refusal != ""
