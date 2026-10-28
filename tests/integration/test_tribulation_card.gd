extends GutTest

## Integration tests for the Tribulation's activity card (the TribulationPresenter
## on a ZoneActionButton). Below the cap the card shows "Core 95 / 100" on a jade
## rod, tagged TRIAL, and refuses a click with a shake and a log line. At the cap
## it is ready: the brass ready frame, the ENTER tag and the trial's length and
## penalty on its detail line. It follows the core's level and the stage. Cards
## are built with setup_action on a fresh save with the card's unlock condition
## forced, as the zone panel builds them; the trial itself is test_tribulation_flow.gd's.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")

const TRIBULATION_ID: String = "spirit_valley_tribulation"
const AURA_WELL_ID: String = "aura_well_training"

## The unlock condition that reveals the Tribulation's card.
const FULL_CORE_CONDITION: String = "core_density_full"
const AURA_WELL_EVENT: String = "aura_well_discovered"

const SHORT_HEIGHT: float = 72.0
const TALL_HEIGHT: float = 96.0
## The core rod has the adventure's Madra rod's 74 steps.
const ROD_STEPS: int = 74

## Foundation's Core Density cap, and the level a failed trial (five levels lost)
## leaves a full core at.
const FULL_CORE: float = 100.0
const SHORT_CORE: float = 95.0

## A trial this slow with a penalty this heavy makes a ready line wider than the
## detail line's 316 px (the shipped line is 243 px wide).
const SLOW_TEMPO: float = 0.0000001
const HEAVY_PENALTY: int = 123456789

## Player-log lines since the test started.
var _logged: Array[String] = []

## The save the test found, put back after it.
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	UnlockManager.force_unlock_condition(FULL_CORE_CONDITION)
	_logged.clear()
	LogManager.message_logged.connect(_on_message_logged)

func after_each() -> void:
	LogManager.message_logged.disconnect(_on_message_logged)
	_stop_everything()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the managers back to the original save resumes the idle action it
	# left off with: stop that one too, so no timer runs on into the next file.
	_stop_everything()

func _on_message_logged(bbcode_message: String) -> void:
	_logged.append(bbcode_message)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Never leave an action running for the next test. Stopping a session action
## can resume the idle one, so stop until nothing is left.
func _stop_everything() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## Puts the core at this level. A card reads the level as it is built.
func _set_core_level(level: float) -> void:
	PersistenceManager.save_game_data.core_density_level = level

func _card_for(action: ZoneActionData) -> ZoneActionButton:
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(action)
	add_child_autofree(card)
	return card

## The shipped Spirit Valley card.
func _card() -> ZoneActionButton:
	return _card_for(ZoneManager.get_action_by_id(TRIBULATION_ID))

## The shipped Tribulation action with a copy of its trial at this tempo and
## penalty. The shipped resources are shared, so a test never changes them.
func _action_with_trial(tempo: float, level_loss: int) -> TribulationActionData:
	var action := ZoneManager.get_action_by_id(TRIBULATION_ID).duplicate() as TribulationActionData
	action.tribulation = action.tribulation.duplicate() as TribulationData
	action.tribulation.tempo = tempo
	action.tribulation.failure_level_loss = level_loss
	return action

## Every visible Label and RichTextLabel text in the card.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if child is Label:
			texts.append((child as Label).text)
		elif child is RichTextLabel:
			texts.append((child as RichTextLabel).get_parsed_text())
		texts.append_array(_texts(child))
	return texts

func _has_text_containing(card: Control, fragment: String) -> bool:
	for text: String in _texts(card):
		if text.contains(fragment):
			return true
	return false

func _tag_text(card: ZoneActionButton) -> String:
	return (card.get_node("%TagLabel") as Label).text

func _ready_frame(card: ZoneActionButton) -> LacquerFrameOverlay:
	return card.get_node("%ReadyFrame") as LacquerFrameOverlay

## The Core figure and its rod, in the card's footer.
func _need_row(card: ZoneActionButton) -> Control:
	return card.get_footer_slot().find_child("NeedGroup", true, false) as Control

func _core_rod(card: ZoneActionButton) -> LacquerRod:
	return card.get_footer_slot().find_child("CoreRod", true, false) as LacquerRod

## The ready line, on the card's detail line.
func _ready_label(card: ZoneActionButton) -> Label:
	return card.get_detail_slot().find_child("ReadyLabel", true, false) as Label

func _click(card: ZoneActionButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	card.gui_input.emit(press)

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## Unlocks the Aura Well, which starts it (the first idle unlock auto-starts).
func _run_aura_well() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")

#-----------------------------------------------------------------------------
# THE PRESENTER
#-----------------------------------------------------------------------------

func test_presenter_is_registered() -> void:
	assert_true(ZoneActionButton.PRESENTER_SCENES.has(ZoneActionData.ActionType.TRIBULATION), "the Tribulation has a presenter of its own")

#-----------------------------------------------------------------------------
# BELOW THE CAP
#-----------------------------------------------------------------------------

func test_below_the_cap_shows_the_core_figure() -> void:
	_set_core_level(SHORT_CORE)
	var card: ZoneActionButton = _card()
	assert_true(_has_text_containing(card, "Core 95 / 100"), "the level and the cap beside the rod")
	assert_false(_has_text_containing(card, "About"), "the ready line is hidden")
	assert_eq(_tag_text(card), "TRIAL")
	var rod: LacquerRod = _core_rod(card)
	assert_not_null(rod, "the core rod sits in the footer")
	if rod:
		assert_eq(rod.get_step(), roundi(0.95 * ROD_STEPS), "95 / 100 of 74 steps")
	assert_false(_ready_frame(card).visible, "no ready frame below the cap")

#-----------------------------------------------------------------------------
# AT THE CAP
#-----------------------------------------------------------------------------

func test_at_the_cap_the_card_is_ready() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card()
	assert_eq(_ready_label(card).text if _ready_label(card) else "", "About 38 s", "the trial's length on the left")
	assert_eq(card.get_detail_right_text(), "failure costs 5 levels", "and its penalty in the right column")
	assert_eq((card.get_node("%DetailRight") as RichTextLabel).get_theme_color(&"default_color"), ThemeConstants.LACQUER_BRASS, "in brass too")
	assert_false(_has_text_containing(card, "·"), "two columns, not a sentence joined with a dot")
	assert_eq(_tag_text(card), "ENTER")
	var frame: LacquerFrameOverlay = _ready_frame(card)
	assert_true(frame.visible, "the steady brass ready frame")
	assert_false(frame.is_flashing(), "shown steadily, not flashed")
	var row: Control = _need_row(card)
	assert_not_null(row, "the Core figure and its rod sit in the footer")
	if row:
		assert_false(row.visible, "and hide once the card is ready")
	var line: Label = _ready_label(card)
	assert_not_null(line, "the ready line sits on the detail line")
	if line:
		assert_eq(line.get_theme_color(&"font_color"), ThemeConstants.LACQUER_BRASS, "in brass")

## The line reads the trial's own tempo and penalty, not the shipped numbers: a
## trial at tempo 2 takes half as long, and its failure costs what its data says.
func test_ready_line_follows_the_trial_data() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card_for(_action_with_trial(2.0, 7))
	assert_true(_has_text_containing(card, "About 19 s"))
	assert_eq(card.get_detail_right_text(), "failure costs 7 levels")

## The last level of a core, earned with XP, readies the card the player is
## looking at.
func test_filling_the_core_readies_the_card() -> void:
	_set_core_level(FULL_CORE - 1.0)
	var card: ZoneActionButton = _card()
	assert_true(_has_text_containing(card, "Core 99 / 100"), "precondition: one level short")
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
	assert_eq(_tag_text(card), "ENTER")
	assert_true(_ready_frame(card).visible)
	assert_true(_has_text_containing(card, "About 38 s"))

func test_card_uses_the_short_drawer_in_both_states() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card()
	assert_eq(card.size.y, SHORT_HEIGHT, "at the cap")
	CultivationManager.lose_core_density_levels(5)
	assert_eq(card.size.y, SHORT_HEIGHT, "below the cap")
	assert_eq(card.custom_minimum_size.y, SHORT_HEIGHT)

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

func test_rejected_click_below_the_cap_logs_why() -> void:
	_run_aura_well()
	_set_core_level(SHORT_CORE)
	var card: ZoneActionButton = _card()
	_logged.clear()
	_click(card)
	assert_eq(_current_id(), AURA_WELL_ID, "the idle action runs on")
	assert_eq(_logged.size(), 1, "the reject writes one log line")
	if _logged.size() == 1:
		assert_string_contains(_logged[0], "Your core must be full to face the Tribulation (95 / 100).")

func test_click_at_the_cap_starts_the_trial() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card()
	_logged.clear()
	watch_signals(ActionManager)
	_click(card)
	assert_eq(_current_id(), TRIBULATION_ID, "the trial is the current action")
	assert_signal_emitted(ActionManager, "start_tribulation")
	for line: String in _logged:
		assert_false(line.contains("must be full"), "a ready click writes no refusal")

## A refused click shakes the need row softly, as a refused click on the Adventure
## card shakes its rod row: MapGlyph's soft keyframes, 0, -4, 4, -2, 2, 0 px, each
## held 0.088 s.
func test_rejected_click_shakes_the_need_row() -> void:
	_set_core_level(SHORT_CORE)
	var card: ZoneActionButton = _card()
	var row: Control = _need_row(card)
	assert_not_null(row, "the need row sits in the footer")
	if row == null:
		return
	assert_not_null(row.find_child("CoreRod", true, false), "the rod shakes with its row")
	# A tween's first step carries the whole frame it starts in, and the frame
	# that built the card can be long enough to skip a keyframe: click in a
	# fresh one.
	await wait_process_frames(2)
	_click(card)
	# Read the offsets frame by frame (the tween runs on frame time).
	var offsets: Array[float] = [row.position.x]
	var settled: bool = await wait_until(func() -> bool:
		if row.position.x != offsets[-1]:
			offsets.append(row.position.x)
		return offsets.size() > 1 and row.position.x == 0.0, 2.0)
	assert_true(settled, "the row settles back at 0")
	assert_eq(offsets, [0.0, -4.0, 4.0, -2.0, 2.0, 0.0] as Array[float], "the soft keyframes in order, each a whole even px")

#-----------------------------------------------------------------------------
# FOLLOWING THE CORE
#-----------------------------------------------------------------------------

func test_card_follows_a_lost_level() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card()
	assert_eq(_tag_text(card), "ENTER", "precondition: a full core is ready")
	CultivationManager.lose_core_density_levels(5)
	assert_true(_has_text_containing(card, "Core 95 / 100"))
	assert_eq(_tag_text(card), "TRIAL")
	assert_false(_ready_frame(card).visible, "the ready frame goes")
	assert_false(_has_text_containing(card, "About"), "and the ready line")
	var rod: LacquerRod = _core_rod(card)
	assert_not_null(rod)
	if rod:
		assert_eq(rod.get_step(), roundi(0.95 * ROD_STEPS), "the rod follows the level")

## The stage alone, with the level where it was, takes the card out of its ready
## state: the trial leads out of the stage before its target.
func test_card_follows_a_stage_change() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card()
	assert_eq(_tag_text(card), "ENTER", "precondition: ready")
	PersistenceManager.save_game_data.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	CultivationManager.advancement_stage_changed.emit(CultivationManager.AdvancementStage.COPPER)
	assert_eq(_tag_text(card), "TRIAL")
	assert_false(_ready_frame(card).visible)

#-----------------------------------------------------------------------------
# LONG TEXT
#-----------------------------------------------------------------------------

## A ready line too wide for the detail line wraps in the tall drawer instead of
## being cut, and the card is short again once it is not ready. Here the penalty
## runs past half the line, so the right column wraps; Label.text holds the whole
## left part whatever fit_detail_label() does to it (an ellipsis, two lines at
## most), so the label's own lines are counted once it has been laid out: every
## one shows.
func test_a_long_ready_line_grows_the_card_and_it_shrinks_back() -> void:
	_set_core_level(FULL_CORE)
	var card: ZoneActionButton = _card_for(_action_with_trial(SLOW_TEMPO, HEAVY_PENALTY))
	await wait_process_frames(2)
	var line: Label = _ready_label(card)
	var right: RichTextLabel = card.get_node("%DetailRight") as RichTextLabel
	assert_not_null(line, "the ready line sits on the detail line")
	if line:
		assert_eq(line.get_visible_line_count(), line.get_line_count(), "no line of the left part is cut")
	assert_eq(card.get_detail_right_text(), "failure costs %d levels" % HEAVY_PENALTY, "the right column keeps its whole text")
	assert_gt(right.get_line_count(), 1, "and wraps")
	assert_lte(right.size.x, 158.0, "at half the line")
	assert_eq(card.size.y, TALL_HEIGHT, "the line wraps in the tall drawer")
	CultivationManager.lose_core_density_levels(5)
	assert_eq(card.size.y, SHORT_HEIGHT, "below the cap the card is short again")
	assert_eq(card.custom_minimum_size.y, SHORT_HEIGHT)
	assert_eq(card.get_detail_right_text(), "", "and its right column goes")

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func test_leaving_the_tree_disconnects_from_the_cultivation_manager() -> void:
	var levels: int = CultivationManager.core_density_level_updated.get_connections().size()
	var stages: int = CultivationManager.advancement_stage_changed.get_connections().size()
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(ZoneManager.get_action_by_id(TRIBULATION_ID))
	add_child(card)
	assert_eq(CultivationManager.core_density_level_updated.get_connections().size(), levels + 1, "precondition: the card follows the level")
	assert_eq(CultivationManager.advancement_stage_changed.get_connections().size(), stages + 1, "precondition: and the stage")
	remove_child(card)
	assert_eq(CultivationManager.core_density_level_updated.get_connections().size(), levels, "the level is let go")
	assert_eq(CultivationManager.advancement_stage_changed.get_connections().size(), stages, "and the stage")
	card.free()
