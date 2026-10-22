class_name Dock
extends Control

## The lacquer dock (lacquer kit §5.4): the recessed shelf centred at the
## bottom of the zone view with the four SystemMenuButtons (Inventory,
## Abilities, Character, Path). Replaces the Toolbar; gold moved to the
## cultivator cabinet.
## It decides which buttons are notified: Path shows the brass ring and the
## count seal while path points are unspent, Abilities shows the ring with no
## count while an unlocked ability sits unequipped.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _abilities_button: SystemMenuButton = %AbilitiesButton
@onready var _path_button: SystemMenuButton = %PathButton

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	PathManager.points_changed.connect(_on_path_points_changed)
	AbilityManager.ability_unlocked.connect(_on_ability_unlocked)
	AbilityManager.equipped_abilities_changed.connect(_update_abilities_notification)
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	_update_path_notification(PathManager.get_point_balance())
	_update_abilities_notification()

#-----------------------------------------------------------------------------
# NOTIFICATIONS
#-----------------------------------------------------------------------------

## The Path button counts the unspent path points.
func _update_path_notification(balance: int) -> void:
	_path_button.set_notification(balance > 0, balance)

## The Abilities button rings, with no count, while an unlock is unequipped.
func _update_abilities_notification() -> void:
	_abilities_button.set_notification(AbilityManager.has_unequipped_unlocks())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_path_points_changed(new_balance: int) -> void:
	_update_path_notification(new_balance)

func _on_ability_unlocked(_ability: AbilityData) -> void:
	_update_abilities_notification()

## AbilityManager announces nothing on a save reset; PathManager emits
## points_changed, but reading both again keeps the dock right either way.
func _on_save_data_reset() -> void:
	_update_path_notification(PathManager.get_point_balance())
	_update_abilities_notification()
