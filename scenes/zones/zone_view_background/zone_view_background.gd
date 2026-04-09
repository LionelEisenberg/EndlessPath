class_name ZoneViewBackground
extends Node2D
## Parallax background built from layered pixel art.
## Each layer is wrapped in a Parallax2D node with increasing scroll_scale
## so deeper layers move slower than the camera, creating depth.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How much the frontmost layer scrolls relative to the camera (0 = fixed, 1 = moves with camera).
## Kept low to preserve the layered composition — high values separate layers and show sky gaps.
const MAX_SCROLL_SCALE: float = 0.2

## Scale applied to layer sprites (640×320 pixel art → fills 1920×1080 viewport).
@export var LAYER_SCALE: float = 6.0
## Sky layer (solid color) needs extra scale to cover full camera pan range.
const SKY_LAYER_SCALE: float = 15.0

## Spirit Valley layer files, ordered back-to-front.
const SPIRIT_VALLEY_PATH: String = "res://assets/sprites/zones/backgrounds/background 1 - Spirit Valley/"
const SPIRIT_VALLEY_LAYERS: PackedStringArray = [
	"0.png",
	"1.png",
	"2.png",
	"3.png",
	"4.png",
	"5.png",
	"6.png",
	"7.png",
	"8.png",
	"9-(floor).png",
	"10.png",
	"11.png",
]

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_build_layers(SPIRIT_VALLEY_PATH, SPIRIT_VALLEY_LAYERS)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _build_layers(folder_path: String, layer_files: PackedStringArray) -> void:
	var total: int = layer_files.size()
	if total == 0:
		return

	for i in range(total):
		var texture: Texture2D = load(folder_path + layer_files[i])
		if texture == null:
			LogManager.log_message("[color=red]ZoneViewBackground: Failed to load layer %s[/color]" % layer_files[i])
			continue

		var scroll_factor: float = 0.0
		if total > 1:
			scroll_factor = float(i) / float(total - 1) * MAX_SCROLL_SCALE

		var parallax: Parallax2D = Parallax2D.new()
		parallax.name = "Layer%02d" % i
		parallax.scroll_scale = Vector2(scroll_factor, scroll_factor)

		var layer_scale: float = SKY_LAYER_SCALE if i == 0 else LAYER_SCALE
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(layer_scale, layer_scale)

		parallax.add_child(sprite)
		add_child(parallax)
