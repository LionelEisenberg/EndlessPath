@tool
class_name LacquerStripRect
extends TextureRect

## Shows one frame of a lacquer frame strip (the orbs, XP beads and timer
## rings, lacquer kit §4.3) at its file size. Each rect draws through its own
## AtlasTexture, so two rects on the same strip show different frames.
## Frames are counted in columns and rows of frame_size; set_frame clamps to
## the strip, so a ratio above 1 shows the last frame.
## It runs in the editor (@tool) so placed rects show their frame. The
## AtlasTexture it draws through is rebuilt from strip and frame_size, so it
## is never saved into the scene.

## The strip texture: frames of frame_size laid out in columns and rows.
@export var strip: Texture2D = null:
	set(value):
		strip = value
		_refresh()

## The size of one frame in the strip, in px.
@export var frame_size: Vector2i = Vector2i.ZERO:
	set(value):
		frame_size = value
		_refresh()

var _frame: Vector2i = Vector2i.ZERO
var _atlas: AtlasTexture = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _validate_property(property: Dictionary) -> void:
	# texture is derived from strip and frame_size: read-only, never saved.
	if property.name == "texture":
		property.usage = (property.usage & ~PROPERTY_USAGE_STORAGE) | PROPERTY_USAGE_READ_ONLY

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the frame at column, row (both from 0), clamped to the strip.
func set_frame(column: int, row: int = 0) -> void:
	_frame = Vector2i(column, row)
	_refresh()

## Returns the column and row of the frame shown.
func get_frame() -> Vector2i:
	return _frame

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _refresh() -> void:
	if strip == null or frame_size.x <= 0 or frame_size.y <= 0:
		texture = null
		return
	@warning_ignore("integer_division")
	var columns: int = maxi(1, strip.get_width() / frame_size.x)
	@warning_ignore("integer_division")
	var rows: int = maxi(1, strip.get_height() / frame_size.y)
	_frame = Vector2i(clampi(_frame.x, 0, columns - 1), clampi(_frame.y, 0, rows - 1))
	if _atlas == null:
		_atlas = AtlasTexture.new()
	_atlas.atlas = strip
	_atlas.region = Rect2(Vector2(_frame * frame_size), Vector2(frame_size))
	texture = _atlas
