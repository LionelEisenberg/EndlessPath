## Manages the inventory view, including book animations and tab switching.
extends Control

# Signal for opening the inventory
signal inventory_opened

# Signal for closing the inventory
signal inventory_closed

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

@onready var tab_switcher: Control = %TabSwitcher
@onready var tabs: Array[Control] = [%EquipmentTab, %MaterialsTab]
@onready var book_content: Control = %BookContent
@onready var animation_player: AnimationPlayer = %BookAnimationPlayer


func _ready() -> void:
	tab_switcher.tab_changed.connect(_on_tab_changed)
	
	# Initialize visibility
	_on_tab_changed(0)
	book_content.visible = false

## Animate opening the book.
func animate_open() -> void:
	if animation_player.is_playing():
		return

	if not animation_player.animation_finished.is_connected(_on_inventory_open_animation_finished):
		animation_player.animation_finished.connect(_on_inventory_open_animation_finished.unbind(1))

	animation_player.play_backwards("BookClosingAnimation")

## Animate closing the book.
func animate_close() -> void:
	if animation_player.is_playing():
		return

	if not animation_player.animation_finished.is_connected(_on_inventory_close_animation_finished):
		animation_player.animation_finished.connect(_on_inventory_close_animation_finished.unbind(1))

	if book_content:
		book_content.visible = false
	animation_player.play("BookClosingAnimation")

func _on_tab_changed(index: int) -> void:
	# Set all tabs to invisible, play animation, set tab to visible
	for i in range(tabs.size()):
		tabs[i].visible = false
	if animation_player.animation_finished.has_connections():
		animation_player.animation_finished.disconnect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_finished.bind(index))
	animation_player.play("PageTurningAnimation")

func _on_animation_finished(_args, index: int) -> void:
	tabs[index].visible = true

func _on_inventory_open_animation_finished() -> void:
	if book_content:
		book_content.visible = true
	animation_player.animation_finished.disconnect(_on_inventory_open_animation_finished)
	inventory_opened.emit()

func _on_inventory_close_animation_finished() -> void:
	animation_player.animation_finished.disconnect(_on_inventory_close_animation_finished)
	inventory_closed.emit()
