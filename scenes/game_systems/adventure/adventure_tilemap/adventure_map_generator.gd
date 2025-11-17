class_name AdventureMapGenerator
extends Node

# Generation constants
const MAX_TILE_PLACEMENT_ATTEMPTS = 100

var adventure_map_data : AdventureMapData
var tile_map : HexagonTileMapLayer

var all_map_tiles : Dictionary[Vector3i, AdventureTileEvent] = {} 

func set_adventure_map_data(map_data : AdventureMapData) -> void:
	adventure_map_data = map_data

func set_tile_map(tm: HexagonTileMapLayer):
	tile_map = tm

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Generates the full set of tile coordinates for an adventure map.
## Returns an array of Vector3i (cube coordinates) for all generated tiles.
func generate_adventure_map() -> Dictionary[Vector3i, AdventureTileEvent]:
	if not adventure_map_data:
		Log.error("AdventureMapGenerator: Adventure map data is not set")
		return {}

	if not tile_map:
		Log.error("AdventureMapGenerator: Tile map is not set")
		return {}
	
	all_map_tiles[Vector3i.ZERO] = AdventureTileEvent.new() # Ensure origin is in the map

	_place_special_tiles()
	
	_generate_mst_paths()
	
	return all_map_tiles


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Places special tiles based on parameters
func _place_special_tiles() -> void:
	var special_tiles: Array[Vector3i] = []

	for i in adventure_map_data.num_special_tiles:
		var attempts = 0
		var tile_placed = false
		
		while not tile_placed and attempts < MAX_TILE_PLACEMENT_ATTEMPTS:
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
				all_map_tiles[random_coord] = AdventureTileEvent.new()
				tile_placed = true
				Log.info("AdventureMapGenerator: Placed special tile at %s after %s attempts" % [random_coord, attempts])

		if attempts >= MAX_TILE_PLACEMENT_ATTEMPTS:
			Log.warn("AdventureMapGenerator: Could not place a special tile. Check map parameters.")
			break

## Generates a path network connecting all special tiles using Prim's MST algorithm.
func _generate_mst_paths():
	# A set of all nodes that are not yet part of the MST.
	var nodes_to_add: Array[Vector3i] = all_map_tiles.keys().duplicate()
	
	# A set of all nodes that are already included in the MST.
	# We start the tree from the origin.
	var nodes_in_tree: Array[Vector3i] = [Vector3i.ZERO]

	# Loop until all special tiles have been added to the tree.
	while not nodes_to_add.is_empty():
		var min_dist = INF
		var best_start_node: Vector3i
		var best_target_node: Vector3i

		# Find the cheapest edge connecting the "tree" to a "non-tree" node.
		for start_node in nodes_in_tree:
			for target_node in nodes_to_add:
				var dist = tile_map.cube_distance(start_node, target_node)
				
				if dist < min_dist:
					min_dist = dist
					best_start_node = start_node
					best_target_node = target_node

		# If no path is found (e.g., isolated nodes, though this shouldn't happen),
		# safety break.
		if min_dist == INF:
			break

		# We found the best path. Add it to the map.
		var path = tile_map.cube_linedraw(best_start_node, best_target_node)
		for coord in path:
			all_map_tiles[coord] = AdventureTileEvent.new()

		# Move the newly connected node from 'nodes_to_add' to 'nodes_in_tree'.
		nodes_in_tree.append(best_target_node)
		nodes_to_add.erase(best_target_node)
