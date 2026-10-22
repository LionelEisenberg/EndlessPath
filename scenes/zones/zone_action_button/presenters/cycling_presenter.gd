class_name CyclingPresenter
extends ZoneActionPresenter
## Presenter for CYCLING cards: "<equipped technique> · Madra and Core Density
## XP", following the equipped technique. A line wider than the detail slot
## wraps in the tall drawer (the fresh save's "Foundational Technique" does).

const REWARD_TEXT: String = "Madra and Core Density XP"

@onready var _detail_label: Label = %DetailLabel

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_label.reparent(button.get_detail_slot(), false)
	CyclingManager.equipped_technique_changed.connect(_on_equipped_technique_changed)
	_refresh()

## Disconnects from the managers before the card goes.
func teardown() -> void:
	if CyclingManager.equipped_technique_changed.is_connected(_on_equipped_technique_changed):
		CyclingManager.equipped_technique_changed.disconnect(_on_equipped_technique_changed)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _refresh() -> void:
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	if technique != null and technique.technique_name != "":
		_detail_label.text = "%s · %s" % [technique.technique_name, REWARD_TEXT]
	else:
		_detail_label.text = REWARD_TEXT
	button.fit_detail_label(_detail_label)

func _on_equipped_technique_changed(_technique: CyclingTechniqueData) -> void:
	_refresh()
