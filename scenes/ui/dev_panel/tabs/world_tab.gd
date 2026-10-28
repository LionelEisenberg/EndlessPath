extends ScrollContainer

## The dev panel's World tab: travel to any zone, the ones the map hides included,
## and the zone map's two dev toggles, the demo zones and the hidden zones. Travel
## goes through DevCommands, which logs it, and shows why it was refused. Each
## toggle sets ZoneManager's own switch and writes a [DEV] line to the player's log.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _travel_option: OptionButton = %TravelOption
@onready var _travel_button: Button = %TravelButton
@onready var _travel_status: Label = %TravelStatus
@onready var _demo_zones_check: CheckButton = %DemoZonesCheck
@onready var _hidden_zones_check: CheckButton = %HiddenZonesCheck

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Lists every zone in the travel picker, each item's metadata its id, and sets the
## checks from ZoneManager without toggling them, so building the tab logs nothing.
func _ready() -> void:
	for zone: ZoneData in ZoneManager.get_all_zones():
		_travel_option.add_item(zone.zone_name)
		_travel_option.set_item_metadata(_travel_option.item_count - 1, zone.zone_id)
	_demo_zones_check.set_pressed_no_signal(ZoneManager.are_demo_zones_visible())
	_hidden_zones_check.set_pressed_no_signal(ZoneManager.are_hidden_zones_visible())
	_travel_button.pressed.connect(_on_travel_pressed)
	_demo_zones_check.toggled.connect(_on_demo_zones_toggled)
	_hidden_zones_check.toggled.connect(_on_hidden_zones_toggled)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Travels to the picked zone. A refusal shows under the picker until a travel works.
func _on_travel_pressed() -> void:
	if _travel_option.selected < 0:
		return
	var zone_id: String = _travel_option.get_item_metadata(_travel_option.selected)
	var refusal: String = DevCommands.travel_to_zone(zone_id)
	_travel_status.text = refusal
	_travel_status.visible = refusal != ""

## Shows or hides the two demo zones (a locked Advancement Zone and an
## Uncharted hex) on the zone map. They live outside zone_data_list.tres and
## never enter the save.
func _on_demo_zones_toggled(pressed: bool) -> void:
	ZoneManager.set_demo_zones_visible(pressed)
	DevCommands.log_dev_line("Demo zones: %s" % ("ON" if pressed else "OFF"))

## Shows or hides the zones the map hides (Test Zone).
func _on_hidden_zones_toggled(pressed: bool) -> void:
	ZoneManager.set_hidden_zones_visible(pressed)
	DevCommands.log_dev_line("Show hidden zones: %s" % ("ON" if pressed else "OFF"))
