class_name TitleMenu
extends CanvasLayer

## TitleMenu
## The title screen a launch on the player's own save opens on: Continue, New Game
## and Quit on a lacquer board, over the game, which is paused until the player
## picks. It opens once per run (should_open()), so the main scene that New Game or
## a dev switch loads again comes up without it, and a preset, a --save file or a
## GUT run never opens it.
##
## - Continue closes it. It shows only for a save that was there at launch and
##   that this build can play and write (can_continue()).
## - New Game on the save this launch wrote new, because there was none, just
##   closes it: the save is new already. On any other save it asks for a second
##   click, then starts a new game on the player's save (DevManager.new_game()),
##   which backs the save up, writes a fresh one over it and loads the main scene
##   again.
## - Quit closes the game as the window's close button does, which saves first. A
##   web build hides it: a browser tab cannot close itself.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## What New Game reads, and what it reads while it waits for its second click.
const _NEW_GAME_WORDS: String = "New Game"
const _NEW_GAME_ARMED_WORDS: String = "Start over? Click again"

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Whether the menu has opened in this run. Static, so it outlasts the main scene
## being freed and loaded again.
static var _opened_this_run: bool = false

## Starts a new game on the player's save. For tests only, to stand in for
## DevManager.new_game(), which a GUT run refuses (it has no main save).
var start_new_game: Callable = DevManager.new_game

## Whether New Game is waiting for its second click.
var _new_game_armed: bool = false

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _continue_button: TitleMenuButton = %ContinueButton
@onready var _new_game_button: TitleMenuButton = %NewGameButton
@onready var _quit_button: TitleMenuButton = %QuitButton
@onready var _confirm_timer: Timer = %ConfirmTimer

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	hide()
	_continue_button.pressed.connect(close)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_confirm_timer.timeout.connect(_disarm_new_game)
	_quit_button.visible = not OS.has_feature("web")
	if should_open(DevManager.get_session_kind(), LaunchOptions.is_test_run(), _opened_this_run):
		open()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Whether the main scene opens on the title menu: only on the player's own save,
## never in a GUT run, and only the first time in a run.
static func should_open(session_kind: DevManager.SessionKind, test_run: bool, opened_before: bool) -> bool:
	return session_kind == DevManager.SessionKind.YOUR_SAVE and not test_run and not opened_before

## Whether the menu offers Continue: the save was there at launch (this launch did
## not write it new) and saving it is not blocked. A save that would not load
## plays as a new game in memory, which nothing would ever write, so New Game is
## the way on from it.
static func can_continue(opened_new_save: bool, save_blocked: bool) -> bool:
	return not opened_new_save and not save_blocked

## Shows the menu over the paused game, with Continue only when can_continue(),
## and gives the first button the keyboard focus.
func open() -> void:
	_opened_this_run = true
	_disarm_new_game()
	_continue_button.visible = can_continue(PersistenceManager.opened_new_save(), PersistenceManager.is_save_blocked())
	show()
	get_tree().paused = true
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()

## Hides the menu and lets the game run.
func close() -> void:
	_disarm_new_game()
	hide()
	get_tree().paused = false

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	# The save this launch wrote new is the new game already.
	if PersistenceManager.opened_new_save():
		close()
		return
	if not _new_game_armed:
		_new_game_armed = true
		_new_game_button.words = _NEW_GAME_ARMED_WORDS
		_confirm_timer.start()
		return
	# Unpaused first: the switch runs on the next frame and loads the main scene
	# again, which must come up running.
	close()
	start_new_game.call()

func _disarm_new_game() -> void:
	_new_game_armed = false
	_new_game_button.words = _NEW_GAME_WORDS
	_confirm_timer.stop()

## Closes the game the way the window's close button does: the close request
## saves first (PersistenceManager), then the game quits.
func _on_quit_pressed() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()
