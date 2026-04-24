class_name AdventureMapGenerator
extends Node

const MAX_PLACEMENT_ATTEMPTS: int = 100
const MAX_REGENERATION_ATTEMPTS: int = 5

const NEIGHBOR_OFFSETS: Array[Vector3i] = [
	Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
	Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
	Vector3i(0, +1, -1), Vector3i(0, -1, +1),
]

var adventure_data: AdventureData
var tile_map: HexagonTileMapLayer

var all_map_tiles: Dictionary[Vector3i, AdventureEncounter] = {}

## Sets the adventure_data used for generation.
func set_adventure_data(p_adventure_data: AdventureData) -> void:
	adventure_data = p_adventure_data

## Sets the tile map layer to be used.
func set_tile_map(tm: HexagonTileMapLayer) -> void:
	tile_map = tm

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Generates a full adventure map. Returns the coord->encounter dictionary,
## or an empty dictionary if validation fails.
func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
	if adventure_data == null:
		Log.error("AdventureMapGenerator: adventure_data is not set")
		return {}
	if tile_map == null:
		Log.error("AdventureMapGenerator: tile_map is not set")
		return {}

	var errors: Array[String] = adventure_data.validate()
	if errors.size() > 0:
		for err in errors:
			Log.error("AdventureMapGenerator: %s" % err)
		return {}

	for attempt in MAX_REGENERATION_ATTEMPTS:
		all_map_tiles = {}
		all_map_tiles[Vector3i.ZERO] = NoOpEncounter.new()

		_place_anchors()
		_generate_paths()
		_place_fillers()

		if _validate_critical_paths():
			return all_map_tiles

		Log.warn("AdventureMapGenerator: critical-path check failed, regenerating (attempt %d)" % (attempt + 1))

	Log.error("AdventureMapGenerator: exhausted regeneration attempts, returning best-effort map")
	return all_map_tiles

#-----------------------------------------------------------------------------
# PHASE 1 — SCATTER ANCHORS
#-----------------------------------------------------------------------------

func _place_anchors() -> void:
	for quota in adventure_data.encounter_quotas:
		if quota == null or quota.encounter == null:
			continue
		if quota.encounter.placement != AdventureEncounter.Placement.ANCHOR:
			continue
		if not quota.encounter.is_eligible():
			Log.info("AdventureMapGenerator: skipping %s — unlock_conditions not met" % quota.encounter.encounter_id)
			continue
		for i in quota.count:
			_place_single_anchor(quota.encounter)

	# Boss always placed last at the farthest anchor-valid coord found.
	if adventure_data.boss_encounter != null:
		_place_boss()

func _place_single_anchor(encounter: AdventureEncounter) -> void:
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var coord := _random_cube_coord(adventure_data.max_distance_from_start)
		if tile_map.cube_distance(Vector3i.ZERO, coord) > adventure_data.max_distance_from_start:
			continue
		if tile_map.cube_distance(Vector3i.ZERO, coord) < encounter.min_distance_from_origin:
			continue
		if _violates_sparse_factor(coord):
			continue
		all_map_tiles[coord] = encounter
		return
	Log.warn("AdventureMapGenerator: could not place anchor %s after %d attempts" % [encounter.encounter_id, MAX_PLACEMENT_ATTEMPTS])

func _place_boss() -> void:
	var boss := adventure_data.boss_encounter
	var best_coord: Vector3i = Vector3i.ZERO
	var best_distance: int = -1
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var coord := _random_cube_coord(adventure_data.max_distance_from_start)
		if tile_map.cube_distance(Vector3i.ZERO, coord) > adventure_data.max_distance_from_start:
			continue
		if tile_map.cube_distance(Vector3i.ZERO, coord) < boss.min_distance_from_origin:
			continue
		if _violates_sparse_factor(coord):
			continue
		var d: int = tile_map.cube_distance(Vector3i.ZERO, coord)
		if d > best_distance:
			best_distance = d
			best_coord = coord
	if best_distance >= 0:
		all_map_tiles[best_coord] = boss
	else:
		Log.warn("AdventureMapGenerator: could not place boss %s" % boss.encounter_id)

func _random_cube_coord(radius: int) -> Vector3i:
	var q := randi_range(-radius, radius)
	var r := randi_range(-radius, radius)
	return Vector3i(q, r, -q - r)

func _violates_sparse_factor(coord: Vector3i) -> bool:
	if tile_map.cube_distance(Vector3i.ZERO, coord) < adventure_data.sparse_factor:
		return true
	for existing in all_map_tiles.keys():
		if existing == Vector3i.ZERO:
			continue
		if tile_map.cube_distance(existing, coord) < adventure_data.sparse_factor:
			return true
	return false

#-----------------------------------------------------------------------------
# PHASE 2 — MST + EXTRA EDGES
#-----------------------------------------------------------------------------

func _generate_paths() -> void:
	var anchors: Array[Vector3i] = all_map_tiles.keys().duplicate()

	var mst_edges: Array = []
	var in_tree: Array[Vector3i] = [Vector3i.ZERO]
	var remaining: Array[Vector3i] = anchors.filter(func(c): return c != Vector3i.ZERO)

	while not remaining.is_empty():
		var best_from: Vector3i
		var best_to: Vector3i
		var best_dist: int = 1 << 30
		for a in in_tree:
			for b in remaining:
				var d: int = tile_map.cube_distance(a, b)
				if d < best_dist:
					best_dist = d
					best_from = a
					best_to = b
		if best_dist == 1 << 30:
			break
		mst_edges.append([best_from, best_to])
		in_tree.append(best_to)
		remaining.erase(best_to)

	for edge in mst_edges:
		_stamp_line(edge[0], edge[1])

	# Extra edges — shortest non-tree edges between any two anchors.
	var candidate_edges: Array = []
	for i in range(anchors.size()):
		for j in range(i + 1, anchors.size()):
			var a: Vector3i = anchors[i]
			var b: Vector3i = anchors[j]
			if _edge_in_mst(mst_edges, a, b):
				continue
			candidate_edges.append({"a": a, "b": b, "dist": tile_map.cube_distance(a, b)})
	candidate_edges.sort_custom(func(x, y): return x.dist < y.dist)

	var added: int = 0
	for c in candidate_edges:
		if added >= adventure_data.num_extra_edges:
			break
		_stamp_line(c.a, c.b)
		added += 1

func _edge_in_mst(mst_edges: Array, a: Vector3i, b: Vector3i) -> bool:
	for e in mst_edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false

func _stamp_line(from: Vector3i, to: Vector3i) -> void:
	for coord in tile_map.cube_linedraw(from, to):
		if not coord in all_map_tiles:
			all_map_tiles[coord] = NoOpEncounter.new()

#-----------------------------------------------------------------------------
# PHASE 3 — PLACE FILLERS
#-----------------------------------------------------------------------------

func _place_fillers() -> void:
	for quota in adventure_data.encounter_quotas:
		if quota == null or quota.encounter == null:
			continue
		if quota.encounter.placement != AdventureEncounter.Placement.FILLER:
			continue
		if not quota.encounter.is_eligible():
			Log.info("AdventureMapGenerator: skipping filler %s — unlock_conditions not met" % quota.encounter.encounter_id)
			continue
		var placed: int = 0
		while placed < quota.count:
			var noop_coords: Array[Vector3i] = _collect_noop_coords()
			if noop_coords.is_empty():
				Log.warn("AdventureMapGenerator: filler quota %s exceeds available NoOp tiles (placed %d of %d)" % [quota.encounter.encounter_id, placed, quota.count])
				break
			var pick: Vector3i = noop_coords[randi_range(0, noop_coords.size() - 1)]
			all_map_tiles[pick] = quota.encounter
			placed += 1

func _collect_noop_coords() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coord in all_map_tiles.keys():
		if coord == Vector3i.ZERO:
			continue
		if all_map_tiles[coord] is NoOpEncounter:
			result.append(coord)
	return result

#-----------------------------------------------------------------------------
# PHASE 4 — CRITICAL-PATH CHECK
#-----------------------------------------------------------------------------

## Returns true if every encounter with min_fillers_on_path > 0 has enough
## fillers on its shortest path from origin. Mutates all_map_tiles to promote
## NoOp tiles to combat fillers where possible. Returns false if unable to
## satisfy (caller should regenerate).
func _validate_critical_paths() -> bool:
	for coord in all_map_tiles.keys():
		var enc: AdventureEncounter = all_map_tiles[coord]
		if enc == null or enc.min_fillers_on_path <= 0:
			continue
		var path: Array[Vector3i] = _bfs_path(Vector3i.ZERO, coord)
		if path.is_empty():
			return false
		var filler_count: int = 0
		var noops_on_path: Array[Vector3i] = []
		for p in path:
			if p == Vector3i.ZERO or p == coord:
				continue
			var enc_on_path: AdventureEncounter = all_map_tiles[p]
			if enc_on_path is NoOpEncounter:
				noops_on_path.append(p)
			elif enc_on_path.placement == AdventureEncounter.Placement.FILLER:
				filler_count += 1
		var deficit: int = enc.min_fillers_on_path - filler_count
		if deficit <= 0:
			continue
		if deficit > noops_on_path.size():
			return false
		var promote_pool: AdventureEncounter = _find_eligible_filler_encounter()
		if promote_pool == null:
			return false
		for i in deficit:
			all_map_tiles[noops_on_path[i]] = promote_pool
	return true

func _find_eligible_filler_encounter() -> AdventureEncounter:
	# Prefer COMBAT_REGULAR; fall back to any eligible FILLER.
	var fallback: AdventureEncounter = null
	for quota in adventure_data.encounter_quotas:
		if quota == null or quota.encounter == null:
			continue
		if quota.encounter.placement != AdventureEncounter.Placement.FILLER:
			continue
		if not quota.encounter.is_eligible():
			continue
		if quota.encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_REGULAR:
			return quota.encounter
		if fallback == null:
			fallback = quota.encounter
	return fallback

func _bfs_path(start: Vector3i, goal: Vector3i) -> Array[Vector3i]:
	var came_from: Dictionary = {start: null}
	var frontier: Array[Vector3i] = [start]
	while not frontier.is_empty():
		var current: Vector3i = frontier.pop_front()
		if current == goal:
			var path: Array[Vector3i] = []
			var node = goal
			while node != null:
				path.push_front(node)
				node = came_from[node]
			return path
		for off in NEIGHBOR_OFFSETS:
			var next: Vector3i = current + off
			if next in all_map_tiles and not (next in came_from):
				came_from[next] = current
				frontier.append(next)
	return []
