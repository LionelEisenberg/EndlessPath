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
@onready var book_animation_player: AnimationPlayer = %BookAnimationPlayer
@onready var page_turning_animation_player: AnimationPlayer = %PageTurningAnimationPlayer


func _ready() -> void:
	tab_switcher.tab_changed.connect(_on_tab_changed)
	
	# Initialize visibility
	for i in range(tabs.size()):
		tabs[i].visible = false
	tabs[0].visible = true

	book_content.visible = false

## Animate opening the book.
func animate_open() -> void:
	if book_animation_player.is_playing():
		return

	if not book_animation_player.animation_finished.is_connected(_on_inventory_open_animation_finished):
		book_animation_player.animation_finished.connect(_on_inventory_open_animation_finished.unbind(1))

	book_animation_player.play_backwards("BookClosingAnimation")

## Animate closing the book.
func animate_close() -> void:
	if book_animation_player.is_playing():
		return

	if not book_animation_player.animation_finished.is_connected(_on_inventory_close_animation_finished):
		book_animation_player.animation_finished.connect(_on_inventory_close_animation_finished.unbind(1))

	if book_content:
		book_content.visible = false
	book_animation_player.play("BookClosingAnimation")

## Handle tab changes by playing page turn animation.
func _on_tab_changed(index: int) -> void:
	# Set all tabs to invisible, play animation, set tab to visible
	for i in range(tabs.size()):
		tabs[i].visible = false
	if page_turning_animation_player.animation_finished.has_connections():
		page_turning_animation_player.animation_finished.disconnect(_on_animation_finished)
	page_turning_animation_player.animation_finished.connect(_on_animation_finished.bind(index))
	page_turning_animation_player.play("PageTurningAnimation")

## Show the new tab content when page turn animation finishes.
func _on_animation_finished(_args, index: int) -> void:
	tabs[index].visible = true

## Handle completion of book opening animation.
func _on_inventory_open_animation_finished() -> void:
	if book_content:
		book_content.visible = true
	book_animation_player.animation_finished.disconnect(_on_inventory_open_animation_finished)
	inventory_opened.emit()

## Handle completion of book closing animation.
func _on_inventory_close_animation_finished() -> void:
	book_animation_player.animation_finished.disconnect(_on_inventory_close_animation_finished)
	inventory_closed.emit()
