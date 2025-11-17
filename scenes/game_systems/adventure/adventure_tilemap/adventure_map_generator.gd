class_name AdventureMapGenerator
extends Node

var adventure_map_data : AdventureMapData
var tile_map : HexagonTileMapLayer

var all_map_tiles : Dictionary[Vector3i, bool] = {} 

func set_adventure_map_data(map_data : AdventureMapData) -> void:
	adventure_map_data = map_data

func set_tile_map(tm: HexagonTileMapLayer):
	tile_map = tm

# --- Public API ---

## Generates the full set of tile coordinates for an adventure map.
## Returns an array of Vector3i (cube coordinates) for all generated tiles.
func generate_adventure_map() -> Dictionary[Vector3i, bool]:
	if not adventure_map_data:
		Log.error("AdventureMapGenerator: Adventure map data is not set")
		return {}

	if not tile_map:
		Log.error("AdventureMapGenerator: Tile map is not set")
		return {}

	# 1. Add the starting tile at the origin
	all_map_tiles[Vector3i.ZERO] = true

	# 2. Place all special tiles
	var special_tile_coords: Array[Vector3i] = _place_special_tiles()
	for coord in special_tile_coords:
		all_map_tiles[coord] = true

	if special_tile_coords.is_empty():
		# No special tiles to pathfind to, just return the origin
		return all_map_tiles
	
	# 3. Create Origin Paths
	# Find the 'n' nearest special tiles to the origin
	var nearest_to_origin = _find_n_nearest(
		Vector3i.ZERO,
		special_tile_coords,
		adventure_map_data.num_original_paths
	)
	
#
	for target_coord in nearest_to_origin:
		var path = tile_map.cube_linedraw(Vector3i.ZERO, target_coord)
		for coord in path:
			all_map_tiles[coord] = true

	# 4. Create Inter-Special Paths (Nearest Neighbor Chaining)
	for start_coord in special_tile_coords:
		# Create a list of all *other* special tiles
		var other_tiles = special_tile_coords.duplicate()
		other_tiles.erase(start_coord)

		if other_tiles.is_empty():
			# This was the only special tile, nothing to connect to
			continue

		# Find the single closest neighbor
		var target_coord = _find_nearest_neighbor(start_coord, other_tiles)
		if target_coord != null:
			var path = tile_map.cube_linedraw(start_coord, target_coord)
			for coord in path:
				all_map_tiles[coord] = true

	# 5. Return the final list of unique coordinates
	return all_map_tiles


# --- Private Helper Functions ---

## Places special tiles based on parameters
func _place_special_tiles() -> Array[Vector3i]:
	var special_tiles: Array[Vector3i] = []
	var max_attempts_per_tile = 100 # Safety break

	for i in adventure_map_data.num_special_tiles:
		var attempts = 0
		var tile_placed = false
		
		while not tile_placed and attempts < max_attempts_per_tile:
			attempts += 1
			
			# 1. Pick a random coordinate
			# We pick 'q' and 'r' and 's' is derived (-q-r)
			var q = randi_range(-adventure_map_data.max_distance_from_start, adventure_map_data.max_distance_from_start)
			var r = randi_range(-adventure_map_data.max_distance_from_start, adventure_map_data.max_distance_from_start)
			var s = -q - r
			var random_coord = Vector3i(q, r, s)

			# 2. Check max distance
			if tile_map.cube_distance(Vector3i.ZERO, random_coord) > adventure_map_data.max_distance_from_start:
				continue # Tile is too far from origin, try again

			# 3. Check sparse factor (distance from *other* special tiles AND from origin)
			var is_valid_sparse = true
			if tile_map.cube_distance(Vector3i.ZERO, random_coord) < adventure_map_data.sparse_factor:
				is_valid_sparse = false
			for existing_tile in special_tiles:
				if tile_map.cube_distance(existing_tile, random_coord) < adventure_map_data.sparse_factor:
					is_valid_sparse = false
					break # Tile is too close to another special tile
			
			if is_valid_sparse:
				special_tiles.append(random_coord)
				tile_placed = true
				Log.info("AdventureMapGenerator: Placed special tile at %s after %s attempts" % [random_coord, attempts])

		if attempts >= max_attempts_per_tile:
			Log.warn("AdventureMapGenerator: Could not place a special tile. Check map parameters.")
			break

	return special_tiles


# Finds the N nearest coordinates to an origin point
func _find_n_nearest(origin: Vector3i, points: Array[Vector3i], n: int) -> Array[Vector3i]:
	var sorted_points = points.duplicate()
	
	# Create a custom sort function that captures the 'origin'
	var sorter = func(a: Vector3i, b: Vector3i):
		var dist_a = tile_map.cube_distance(origin, a)
		var dist_b = tile_map.cube_distance(origin, b)
		return dist_a < dist_b
		
	sorted_points.sort_custom(sorter)
	
	# Return the first 'n' elements
	return sorted_points.slice(0, n)


## Finds the single nearest neighbor to an origin point from a list
func _find_nearest_neighbor(origin: Vector3i, other_points: Array[Vector3i]) -> Vector3i:
	if other_points.is_empty():
		return origin

	var nearest_point = other_points[0]
	var min_dist = tile_map.cube_distance(origin, nearest_point)

	for i in range(1, other_points.size()):
		var dist = tile_map.cube_distance(origin, other_points[i])
		if dist < min_dist:
			min_dist = dist
			nearest_point = other_points[i]
			
	return nearest_point
