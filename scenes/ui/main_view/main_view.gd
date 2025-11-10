extends VBoxContainer

# The paths are now one level deeper, inside MainViewContainer
@onready var view_container = $MainViewContainer 
@onready var nav_bar = $GameSystemNavBar

# This dictionary maps the GameSystem enum to its corresponding View node
var system_views: Dictionary = {}

func _ready():
	system_views = {
		UnlockManager.GameSystem.ZONE: $MainViewContainer/ZoneView,
		UnlockManager.GameSystem.CYCLING: $MainViewContainer/CyclingView,
		UnlockManager.GameSystem.SCRIPTING: $MainViewContainer/ScriptingView,
		UnlockManager.GameSystem.ELIXIR_MAKING: $MainViewContainer/ElixirMakingView,
		UnlockManager.GameSystem.SOULSMITHING: $MainViewContainer/SoulSmithingView,
		UnlockManager.GameSystem.ADVENTURING: $MainViewContainer/AdventuringView
	}

	nav_bar.system_selected.connect(_on_system_selected)
	_on_system_selected(UnlockManager.GameSystem.ZONE)


## This is the function that does the view switching.
func _on_system_selected(system: UnlockManager.GameSystem):
	show_system(system)

func initalize_system_with_action(system: UnlockManager.GameSystem, zone_action_data: ZoneActionData):
	match system:
		UnlockManager.GameSystem.CYCLING:
			if system_views.has(system):
				if system_views[system].has_method("initialize_cycling"):
					system_views[system].initialize_cycling(zone_action_data)

func show_system(system: UnlockManager.GameSystem):
	# Ensure the system_enum is valid
	if not system_views.has(system):
		printerr("MainGame: No view found for system: %s" % system)
		return

	for view in system_views.values():
		view.visible = false
		
	system_views[system].visible = true
