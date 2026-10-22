class_name BookStyleData
extends Resource

## BookStyleData
## The colours that make one menu book its own: the cover edge, the page border
## line and the bookmark. BookFrame swaps them into the shared book art, which
## every book draws from one master spritesheet.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

@export_group("Cover edge")
## Lightest of the three cover-edge shades.
@export var cover_light: Color = Color(162 / 255.0, 112 / 255.0, 100 / 255.0)
## Middle cover-edge shade.
@export var cover_mid: Color = Color(128 / 255.0, 72 / 255.0, 69 / 255.0)
## Darkest cover-edge shade.
@export var cover_dark: Color = Color(101 / 255.0, 51 / 255.0, 60 / 255.0)

@export_group("Page")
## The thin border line drawn around both pages, with its corner ornaments.
@export var page_border: Color = Color(230 / 255.0, 201 / 255.0, 169 / 255.0)

@export_group("Bookmark")
## Bookmark edges and the shadow where it leaves the pages.
@export var bookmark_dark: Color = Color(112 / 255.0, 34 / 255.0, 38 / 255.0)
## Bookmark body.
@export var bookmark_mid: Color = Color(160 / 255.0, 50 / 255.0, 50 / 255.0)
## Bookmark satin highlight.
@export var bookmark_light: Color = Color(206 / 255.0, 92 / 255.0, 84 / 255.0)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Colours for the book art, in BookFrame.BOOK_SOURCE_COLORS order:
## cover light, cover mid, cover dark, page border.
func get_book_colors() -> PackedColorArray:
	return PackedColorArray([cover_light, cover_mid, cover_dark, page_border])

## Colours for the bookmark, in BookFrame.BOOKMARK_SOURCE_COLORS order:
## dark, mid, light.
func get_bookmark_colors() -> PackedColorArray:
	return PackedColorArray([bookmark_dark, bookmark_mid, bookmark_light])
