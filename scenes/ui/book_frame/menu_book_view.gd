class_name MenuBookView
extends Control

## MenuBookView
## Base for the bottom-row menus drawn as books (Inventory, Abilities,
## Character, Path). Opens and closes the view's BookFrame, shows the page
## content only while the book lies open, and passes the close tab on.
## GreyBackground drives it through animate_open() and animate_close(), and
## waits for close_finished before it hides the view.
##
## The view's scene must hold a BookFrame with the unique name %BookFrame.
## Subclasses that define _ready() must call super._ready().

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The book's close tab was clicked.
signal close_requested
## The book finished closing.
signal close_finished

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Content shown only while the book lies open: hidden as soon as it starts
## to close, shown again once it has opened.
@export var page_content: Array[Control] = []

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var book_frame: BookFrame = %BookFrame

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	book_frame.opened.connect(_on_book_opened)
	book_frame.closed.connect(_on_book_closed)
	book_frame.close_requested.connect(close_requested.emit)
	_set_pages_visible(false)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the book. The pages appear once it lies open.
func animate_open() -> void:
	_before_open()
	_set_pages_visible(false)
	book_frame.animate_open()

## Closes the book. Emits close_finished once it has closed.
func animate_close() -> void:
	_set_pages_visible(false)
	book_frame.animate_close()

#-----------------------------------------------------------------------------
# HOOKS
#-----------------------------------------------------------------------------

## Called before the book opens. Refresh the pages here.
func _before_open() -> void:
	pass

## Called once the book lies open and its pages are shown.
func _after_open() -> void:
	pass

## Called once the book has closed, before close_finished.
func _after_close() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_book_opened() -> void:
	_set_pages_visible(true)
	_after_open()

func _on_book_closed() -> void:
	_after_close()
	close_finished.emit()

func _set_pages_visible(is_shown: bool) -> void:
	for content: Control in page_content:
		content.visible = is_shown
