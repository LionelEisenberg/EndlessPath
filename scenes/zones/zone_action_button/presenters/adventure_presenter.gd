class_name AdventurePresenter
extends ZoneActionPresenter
## Presenter for ADVENTURE cards, 72 px while their text fits. A run starts on
## whatever the saved Madra pool holds, so the card is always ready: the card's
## steady brass ready frame, the ENTER tag, "<minutes> min run" in brass on the
## left of the detail line and the pool, "<madra> / <max> Madra", in Madra ink
## in its right column (each wraps past its room, and the card grows). It
## follows the pool, and the max Mind and gear set.

@onready var _ready_text: RichTextLabel = %ReadyText

## Moves the ready line onto the card's detail line and shows the pool.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_ready_text.reparent(button.get_detail_slot(), false)
	ResourceManager.madra_changed.connect(_on_madra_changed)
	CharacterManager.stats_changed.connect(_on_stats_changed)
	_update_state()

## Disconnects from the managers.
func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_madra_changed):
		ResourceManager.madra_changed.disconnect(_on_madra_changed)
	if CharacterManager.stats_changed.is_connected(_on_stats_changed):
		CharacterManager.stats_changed.disconnect(_on_stats_changed)

## "60 / 100 Madra": the pool the run starts on, over its max.
static func pool_text() -> String:
	return "%d / %d Madra" % [floori(ResourceManager.get_madra()), floori(ResourceManager.get_max_madra())]

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _update_state() -> void:
	button.set_ready_frame(true)
	button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
	button.set_detail_right(pool_text(), ThemeConstants.LACQUER_MADRA)
	button.set_detail_rich_text(_ready_text, _run_length_text())
	button.relayout()

## "5 min run": the run's time limit.
func _run_length_text() -> String:
	var adventure := action_data as AdventureActionData
	var minutes: float = adventure.time_limit_seconds / 60.0 if adventure else 0.0
	return "%s min run" % LacquerText.rate(minutes).trim_prefix("+")

func _on_madra_changed(_amount: float) -> void:
	_update_state()

## Training, gear and any modifier source move the max Madra stat.
func _on_stats_changed() -> void:
	_update_state()
