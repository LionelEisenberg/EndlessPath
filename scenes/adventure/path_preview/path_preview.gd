class_name PathPreview
extends Line2D

## PathPreview
## Renders a tiled-texture line from the player's current tile through
## intermediate tiles to a target tile (either a hovered tile or a
## committed destination). The Line2D's texture_mode is set to
## LINE_TEXTURE_TILE in the .tscn, so the texture U axis maps along the
## line's length and tiles as the line stretches. The texture's height
## should match the Line2D's width; left/right edges must match for
## seamless tiling.
##
## The texture is loaded at runtime from TEXTURE_PATH with a
## missing-file guard — if no art has been authored yet, the Line2D
## falls back to its default_color for a solid stroke.
##
## During a committed trip (adventure tilemap's locked destination),
## the Line2D's points stay completely static — the adventure tilemap
## only calls set_fade_behind() each frame to slide a two-stop alpha
## gradient so the section behind the character goes transparent while
## the section ahead stays opaque. Because the points never move, the
## LINE_TEXTURE_TILE UVs remain stable across frames (no tile centers
## resize, no texture sliding, no joint retriangulation artifacts).

## Where the tileable stroke texture lives on disk. Drop a 64×16 (or
## similarly sized) RGBA PNG here and the next scene load picks it up.
## Shared with the zone map's GlowingPath if that ever adopts the same
## visual treatment — hence living under sprites/tilemap/ rather than
## under the path_preview folder.
const TEXTURE_PATH := "res://assets/sprites/tilemap/path_line_texture.png"

## Width of the fade region (in screen pixels of the line) between the
## fully-invisible trailing part of the path and the fully-visible
## leading part. Bigger = softer dissolve edge behind the player.
## Smaller = crisp "snipped right behind the boot" look.
const FADE_PIXELS := 18.0

var _gradient: Gradient

func _ready() -> void:
	if ResourceLoader.exists(TEXTURE_PATH):
		texture = load(TEXTURE_PATH)
	# Build the per-instance gradient with both stops fully opaque so
	# hover previews render at full brightness. set_fade_behind() swaps
	# the colors to (transparent, opaque) when a committed trip begins;
	# _reset_fade() restores both to white.
	_gradient = Gradient.new()
	_gradient.set_color(0, Color.WHITE)
	_gradient.set_color(1, Color.WHITE)
	_gradient.set_offset(0, 0.0)
	_gradient.set_offset(1, 1.0)
	gradient = _gradient

## Shows a path from the player's current tile through the given world-
## space points. Resets the fade so the whole line is visible — any
## prior committed-trip fade is wiped. Hides the preview if the path
## is too short to draw (single tile).
func show_path(world_points: Array[Vector2]) -> void:
	clear_points()
	for p in world_points:
		add_point(p)
	visible = world_points.size() >= 2
	_reset_fade()

## Clears all points and hides the preview. Called on tile unhover,
## adventure teardown, and when a committed destination releases.
func clear_path() -> void:
	clear_points()
	visible = false
	_reset_fade()

## Slides the gradient so everything up to the closest point on the
## polyline to `target` fades out, and everything past it stays opaque.
## Uses per-segment closest-point projection so the result is stable
## even if the target drifts slightly off the exact polyline (e.g. the
## character sprite center isn't precisely on the line).
func set_fade_behind(target: Vector2) -> void:
	if _gradient == null or get_point_count() < 2:
		return
	var total_length: float = _compute_total_length()
	if total_length < 0.0001:
		return
	var absolute_progress: float = _compute_absolute_progress(target)
	var normalized_progress: float = absolute_progress / total_length
	var fade_offset: float = FADE_PIXELS / total_length
	var upper: float = clamp(normalized_progress, 0.0001, 1.0)
	var lower: float = max(0.0, upper - fade_offset)
	# Switch both stops to (transparent, opaque) and position the cutoff.
	_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	_gradient.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	_gradient.set_offset(0, lower)
	_gradient.set_offset(1, upper)

## Restores both gradient stops to fully opaque white so hover previews
## render at full brightness with no alpha fade anywhere along the line.
func _reset_fade() -> void:
	if _gradient == null:
		return
	_gradient.set_color(0, Color.WHITE)
	_gradient.set_color(1, Color.WHITE)
	_gradient.set_offset(0, 0.0)
	_gradient.set_offset(1, 1.0)

func _compute_total_length() -> float:
	var total: float = 0.0
	for i in range(get_point_count() - 1):
		total += (get_point_position(i + 1) - get_point_position(i)).length()
	return total

## Projects `target` onto each segment of the polyline and returns the
## cumulative length from the first point to the closest projection.
## This is the absolute distance along the line (not normalized) — the
## caller divides by total length to get a 0..1 parameter.
func _compute_absolute_progress(target: Vector2) -> float:
	var best_progress: float = 0.0
	var best_dist: float = INF
	var cumulative: float = 0.0
	for i in range(get_point_count() - 1):
		var p0: Vector2 = get_point_position(i)
		var p1: Vector2 = get_point_position(i + 1)
		var seg: Vector2 = p1 - p0
		var seg_len: float = seg.length()
		if seg_len < 0.0001:
			continue
		var proj: float = clamp((target - p0).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
		var closest: Vector2 = p0 + seg * proj
		var dist: float = (closest - target).length()
		if dist < best_dist:
			best_dist = dist
			best_progress = cumulative + proj * seg_len
		cumulative += seg_len
	return best_progress
