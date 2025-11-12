extends HBoxContainer

signal system_selected(system_enum: UnlockManager.GameSystem)

signal open_inventory()

var nav_buttons: Dictionary = {}

# Node references from your GameSystemNavBar.tscn scene tree
@onready var zone_button = %ZoneTextureButton
@onready var cycling_button = %CyclingTextureButton
@onready var scripting_button =  %ScriptingTextureButton
@onready var elixir_button = %ElixirMakingTextureButton
@onready var soulsmithing_button = %SoulsmithingTextureButton
@onready var adventuring_button = %AdventuringTextureButton

@onready var inventory_button = %InventoryButton

# We track the currently active system to manage button visuals
var _current_active_system: UnlockManager.GameSystem = UnlockManager.GameSystem.ZONE

func _ready():
	nav_buttons = {
		UnlockManager.GameSystem.ZONE: zone_button,
		UnlockManager.GameSystem.CYCLING: cycling_button,
		UnlockManager.GameSystem.SCRIPTING: scripting_button,
		UnlockManager.GameSystem.ELIXIR_MAKING: elixir_button,
		UnlockManager.GameSystem.SOULSMITHING: soulsmithing_button,
		UnlockManager.GameSystem.ADVENTURING: adventuring_button
	}

	for system_enum in nav_buttons:
		nav_buttons[system_enum].pressed.connect(_on_button_pressed.bind(system_enum))
	
	UnlockManager.game_systems_updated.connect(_on_systems_updated)
	
	_on_systems_updated(UnlockManager.get_unlocked_game_systems())
	_update_button_visuals(_current_active_system)
	
	## TODO: Delete
	inventory_button.pressed.connect(open_inventory.emit)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Called when any main system button is pressed.
func _on_button_pressed(system_enum: UnlockManager.GameSystem):
	# Don't do anything if we clicked the button that's already active
	if system_enum == _current_active_system:
		return
	
	_current_active_system = system_enum
	
	# Emit the signal for MainGame to catch
	system_selected.emit(system_enum)
	
	# Update the button visuals to show the new selection
	_update_button_visuals(system_enum)


## Called by the UnlockManager signal (and once in _ready).
func _on_systems_updated(unlocked_systems: Array[UnlockManager.GameSystem]):
	# This fulfills your first requirement: show only unlocked buttons
	for system_enum in nav_buttons:
		nav_buttons[system_enum].visible = system_enum in unlocked_systems

#-----------------------------------------------------------------------------
# HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Updates the "disabled" state of all buttons
func _update_button_visuals(active_system_enum: UnlockManager.GameSystem):
	for system_enum in nav_buttons:
		var button_node = nav_buttons[system_enum]
		
		# Disable the button that is active, enable all others
		button_node.disabled = (system_enum == active_system_enum)
		
		if button_node.disabled:
			button_node.modulate = Color(0.5, 0.5, 0.5) # Tint disabled
		else:
			button_node.modulate = Color(1.0, 1.0, 1.0) # Normal tint
