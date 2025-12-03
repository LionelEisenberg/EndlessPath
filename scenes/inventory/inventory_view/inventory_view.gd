extends Control

# Signal for opening the inventory
signal open_inventory

# Signal for closing the inventory
signal close_inventory

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

@onready var tab_switcher: Control = %TabSwitcher
@onready var tabs: Array[Control] = [%EquipmentTab, %MaterialsTab]

func _ready() -> void:
	tab_switcher.tab_changed.connect(_on_tab_changed)
	
	# Initialize visibility
	_on_tab_changed(0)

func _on_tab_changed(index: int) -> void:
	# Set all tabs to invisible, play animation, set tab to visible
	for i in range(tabs.size()):
		tabs[i].visible = false
	if ($BookBackground/AnimationPlayer as AnimationPlayer).animation_finished.has_connections():
		$BookBackground/AnimationPlayer.animation_finished.disconnect(_on_animation_finished)
	$BookBackground/AnimationPlayer.animation_finished.connect(_on_animation_finished.bind(index))
	$BookBackground/AnimationPlayer.play("PageTurningAnimation")

func _on_animation_finished(_args, index : int) -> void:
	tabs[index].visible = true

# Handle input for closing inventory
func _input(event):
	if visible and event.is_action_pressed("close_inventory"):
		close_inventory.emit()
		return
	
	if event.is_action_pressed("open_inventory"):
		open_inventory.emit()
		return
