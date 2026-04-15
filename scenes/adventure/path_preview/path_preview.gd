class_name PathPreview
extends Line2D

## PathPreview
## Renders a tiled-texture line from the player's current tile through
## intermediate tiles to a hover-target tile. The Line2D's texture_mode
## is set to LINE_TEXTURE_TILE in the .tscn, so the texture U axis maps
## along the line's length and tiles as the line stretches. The
## texture's height should match the Line2D's width; left/right edges
## must match for seamless tiling.
##
## The texture is loaded at runtime from TEXTURE_PATH with a
## missing-file guard — if no art has been authored yet, the Line2D
## falls back to its gradient + default_color for a solid stroke.

## Where the tileable stroke texture lives on disk. Drop a 64×16 (or
## similarly sized) RGBA PNG here and the next scene load picks it up.
## Shared with the zone map's GlowingPath if that ever adopts the same
## visual treatment — hence living under sprites/tilemap/ rather than
## under the path_preview folder.
const TEXTURE_PATH := "res://assets/sprites/tilemap/path_line_texture.png"

func _ready() -> void:
	if ResourceLoader.exists(TEXTURE_PATH):
		texture = load(TEXTURE_PATH)

## Shows a path from the player's current tile to the hover target by
## feeding the world-space tile centers into the Line2D's point list.
## Hides the preview if the path is too short to draw (single tile).
func show_path(world_points: Array[Vector2]) -> void:
	clear_points()
	for p in world_points:
		add_point(p)
	visible = world_points.size() >= 2

## Clears all points and hides the preview. Called from
## _on_tile_unhovered and stop_adventure in adventure_tilemap.gd.
func clear_path() -> void:
	clear_points()
	visible = false
