class_name AdventurePresenter
extends ZoneActionPresenter
## Presenter for ADVENTURE cards, always on the tall drawer (lacquer kit §5.5):
##   below the threshold: "Needs <threshold> Madra · you have <madra>", the
##     Madra rod (Madra / threshold) and a hint, "ready in ~<n> s" in cream
##     while a Madra action runs, else "train or cycle to fill" in tan; tag
##     ACTIVE.
##   at the threshold: the brass-edged ready drawer, "Ready · carries up to
##     <capacity> Madra · <minutes> min run" in brass (an ellipsis past
##     316 px), and the ENTER tag.
## Capacity is the total max Madra and the threshold half of it, so gear that
## adds Foundation changes both: the card follows equipment changes too.
## Gates activation on ResourceManager.can_start_adventure(); a rejected click
## shakes the Madra line in even-px steps and logs why.

## The reject shake: x offsets of the Madra line, one key every SHAKE_STEP s.
const SHAKE_KEYS: Array[float] = [-8.0, 8.0, -6.0, 4.0, 0.0]
const SHAKE_STEP_SECONDS: float = 0.088

@onready var _need_group: Control = %NeedGroup
@onready var _need_label: Label = %NeedLabel
@onready var _madra_rod: LacquerRod = %MadraRod
@onready var _hint_label: Label = %HintLabel
@onready var _ready_text: RichTextLabel = %ReadyText

var _is_affordable: bool = false
var _shake_tween: Tween = null

## Moves the Madra line, rod, hint and ready line into the card (always
## tall) and shows the state for the current Madra.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	var footer: Control = button.get_footer_slot()
	_need_group.reparent(footer, false)
	_ready_text.reparent(footer, false)
	button.set_tall(true)
	ResourceManager.madra_changed.connect(_on_madra_changed)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	CharacterManager.base_attribute_changed.connect(_on_base_attribute_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	_update_state()

## Disconnects from the managers and stops a running shake.
func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_madra_changed):
		ResourceManager.madra_changed.disconnect(_on_madra_changed)
	if ActionManager.current_action_changed.is_connected(_on_current_action_changed):
		ActionManager.current_action_changed.disconnect(_on_current_action_changed)
	if CharacterManager.base_attribute_changed.is_connected(_on_base_attribute_changed):
		CharacterManager.base_attribute_changed.disconnect(_on_base_attribute_changed)
	if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
	_stop_shake()

## True once Madra reaches the adventure threshold.
func can_activate() -> bool:
	return _is_affordable

## Shakes the Madra line and logs the shortfall.
func on_activation_rejected() -> void:
	_shake_reject()
	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var current: float = ResourceManager.get_madra()
	LogManager.log_message("[color=red]Not enough Madra! Need %.0f, have %.0f[/color]" % [threshold, current])

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _update_state() -> void:
	_is_affordable = ResourceManager.can_start_adventure()
	_need_group.visible = not _is_affordable
	_ready_text.visible = _is_affordable
	button.set_ready_edge(_is_affordable)
	if _is_affordable:
		button.set_mode_tag("ENTER", ZoneActionButton.TagStyle.ENTER)
		button.fit_detail_rich_text(_ready_text, _ready_line())
	else:
		button.set_mode_tag(ZoneActionGroups.mode_tag(action_data), ZoneActionButton.TagStyle.CARVED)
		_update_need()

func _update_need() -> void:
	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var madra: float = ResourceManager.get_madra()
	_need_label.text = "Needs %d Madra · you have %d" % [ceili(threshold), floori(madra)]
	_madra_rod.set_fraction(madra / threshold if threshold > 0.0 else 0.0)
	var rate: float = ActionManager.get_current_madra_per_second()
	if rate > 0.0:
		_hint_label.text = "ready in ~%d s" % ceili(maxf(threshold - madra, 0.0) / rate)
		_hint_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM)
	else:
		_hint_label.text = "train or cycle to fill"
		_hint_label.remove_theme_color_override(&"font_color")

func _ready_line() -> String:
	var capacity: int = floori(ResourceManager.get_adventure_madra_capacity())
	var adventure := action_data as AdventureActionData
	var minutes: float = adventure.time_limit_seconds / 60.0 if adventure else 0.0
	return "Ready · carries up to %d Madra · %s min run" % [capacity, LacquerText.rate(minutes).trim_prefix("+")]

## Shakes the Madra line left and right in whole even-px steps (no easing, no
## scale), the map lock's 0, -8, 8, -6, 4, 0 over 0.44 s.
func _shake_reject() -> void:
	_stop_shake()
	_need_group.position.x = 0.0
	_shake_tween = create_tween()
	for key: float in SHAKE_KEYS:
		_shake_tween.tween_callback(_set_need_offset.bind(key)).set_delay(SHAKE_STEP_SECONDS)

func _set_need_offset(x: float) -> void:
	_need_group.position.x = x

func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if is_instance_valid(_need_group):
		_need_group.position.x = 0.0

func _on_madra_changed(_amount: float) -> void:
	_update_state()

func _on_current_action_changed(_action: ZoneActionData) -> void:
	_update_state()

func _on_base_attribute_changed(_attribute_type: CharacterAttributesData.AttributeType, _new_value: float) -> void:
	_update_state()

## Equipping or removing gear changes the total attributes, so the capacity
## and threshold. CharacterManager has no signal of its own for that.
func _on_inventory_changed(_inventory: InventoryData) -> void:
	_update_state()
