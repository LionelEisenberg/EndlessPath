extends GutTest

## Integration-ish tests for the new AdventureMapGenerator. Uses a bare
## HexagonTileMapLayer instance for hex math — no actual tiles are painted.

const GENERATOR_SCRIPT := preload("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
const TILEMAP_SCENE := preload("res://scenes/tilemaps/hexagon_tile_map_layer.tscn")

func _make_tilemap() -> HexagonTileMapLayer:
	var tm: HexagonTileMapLayer = TILEMAP_SCENE.instantiate()
	add_child_autofree(tm)
	return tm

func _make_encounter(id: String, placement: AdventureEncounter.Placement, min_dist: int = 0, min_fillers: int = 0) -> AdventureEncounter:
	var enc := AdventureEncounter.new()
	enc.encounter_id = id
	enc.placement = placement
	enc.min_distance_from_origin = min_dist
	enc.min_fillers_on_path = min_fillers
	return enc

func _make_quota(enc: AdventureEncounter, count: int) -> EncounterQuota:
	var q := EncounterQuota.new()
	q.encounter = enc
	q.count = count
	return q

func _make_data() -> AdventureData:
	var data := AdventureData.new()
	data.max_distance_from_start = 6
	data.sparse_factor = 2
	data.num_extra_edges = 2
	data.boss_encounter = _make_encounter("boss", AdventureEncounter.Placement.ANCHOR, 5)
	data.encounter_quotas = [
		_make_quota(_make_encounter("rest", AdventureEncounter.Placement.ANCHOR, 3, 1), 1),
		_make_quota(_make_encounter("combat", AdventureEncounter.Placement.FILLER), 4),
	]
	return data

func _run_generation(data: AdventureData) -> Dictionary:
	var gen = GENERATOR_SCRIPT.new()
	add_child_autofree(gen)
	gen.set_adventure_data(data)
	gen.set_tile_map(_make_tilemap())
	return gen.generate_adventure_map()

func test_invalid_config_returns_empty_map() -> void:
	var data := _make_data()
	data.boss_encounter = null
	var tiles := _run_generation(data)
	assert_eq(tiles.size(), 0, "invalid config should yield an empty map")

func test_anchors_respect_min_distance_from_origin() -> void:
	var data := _make_data()
	for trial in 50:
		var tiles := _run_generation(data)
		var rest_coord: Vector3i = Vector3i.ZERO
		var rest_found := false
		for coord in tiles.keys():
			if tiles[coord].encounter_id == "rest":
				rest_coord = coord
				rest_found = true
				break
		assert_true(rest_found, "trial %d: rest anchor missing" % trial)
		var tilemap := _make_tilemap()
		var distance: int = tilemap.cube_distance(Vector3i.ZERO, rest_coord)
		assert_gte(distance, 3, "trial %d: rest placed at distance %d, expected >= 3" % [trial, distance])

func test_anchors_respect_sparse_factor() -> void:
	var data := _make_data()
	for trial in 50:
		var tiles := _run_generation(data)
		var tilemap := _make_tilemap()
		var anchor_coords: Array[Vector3i] = []
		for coord in tiles.keys():
			var enc: AdventureEncounter = tiles[coord]
			if enc == null: continue
			if enc.placement == AdventureEncounter.Placement.ANCHOR:
				anchor_coords.append(coord)
		for i in range(anchor_coords.size()):
			assert_gte(tilemap.cube_distance(Vector3i.ZERO, anchor_coords[i]), data.sparse_factor,
				"trial %d: anchor too close to origin" % trial)
			for j in range(i + 1, anchor_coords.size()):
				var d: int = tilemap.cube_distance(anchor_coords[i], anchor_coords[j])
				assert_gte(d, data.sparse_factor,
					"trial %d: anchors %s and %s within sparse_factor" % [trial, anchor_coords[i], anchor_coords[j]])

func test_boss_is_at_farthest_anchor() -> void:
	var data := _make_data()
	for trial in 20:
		var tiles := _run_generation(data)
		var tilemap := _make_tilemap()
		var boss_coord: Vector3i = Vector3i.ZERO
		var boss_distance: int = -1
		var max_anchor_distance: int = -1
		for coord in tiles.keys():
			var enc: AdventureEncounter = tiles[coord]
			if enc == null: continue
			if enc.encounter_id == "boss":
				boss_coord = coord
				boss_distance = tilemap.cube_distance(Vector3i.ZERO, coord)
			elif enc.placement == AdventureEncounter.Placement.ANCHOR:
				max_anchor_distance = max(max_anchor_distance, tilemap.cube_distance(Vector3i.ZERO, coord))
		assert_gte(boss_distance, max_anchor_distance,
			"trial %d: boss at distance %d but another anchor is at %d" % [trial, boss_distance, max_anchor_distance])

func test_extra_edges_add_branching() -> void:
	# With num_extra_edges = 2, the total edge count should exceed the MST
	# size (anchor_count - 1) by 2 when anchors are spread enough.
	var data := _make_data()
	data.num_extra_edges = 2
	var found_branching := false
	for trial in 20:
		var tiles := _run_generation(data)
		var anchor_count: int = 0
		for enc in tiles.values():
			if enc != null and enc.placement == AdventureEncounter.Placement.ANCHOR:
				anchor_count += 1
		var degree: Dictionary = {}
		for coord in tiles.keys():
			for off in _neighbor_offsets():
				if (coord + off) in tiles:
					degree[coord] = degree.get(coord, 0) + 1
		var degree_3_or_more: int = 0
		for v in degree.values():
			if v >= 3:
				degree_3_or_more += 1
		if degree_3_or_more > 0:
			found_branching = true
			break
	assert_true(found_branching, "expected at least one trial to produce a tile with degree >= 3 via extra edges")

func _neighbor_offsets() -> Array[Vector3i]:
	return [
		Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
		Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
		Vector3i(0, +1, -1), Vector3i(0, -1, +1),
	]

func test_quota_counts_are_respected() -> void:
	# Use min_fillers_on_path = 0 for the rest anchor so Phase 4's critical-path
	# promotion never fires, keeping the combat count deterministically at 4.
	var data := AdventureData.new()
	data.max_distance_from_start = 6
	data.sparse_factor = 2
	data.num_extra_edges = 2
	data.boss_encounter = _make_encounter("boss", AdventureEncounter.Placement.ANCHOR, 5)
	data.encounter_quotas = [
		_make_quota(_make_encounter("rest", AdventureEncounter.Placement.ANCHOR, 3, 0), 1),
		_make_quota(_make_encounter("combat", AdventureEncounter.Placement.FILLER), 4),
	]
	var tiles := _run_generation(data)
	var counts: Dictionary = {"rest": 0, "combat": 0, "boss": 0}
	for enc in tiles.values():
		if enc.encounter_id in counts:
			counts[enc.encounter_id] += 1
	assert_eq(counts["rest"], 1)
	assert_eq(counts["combat"], 4)
	assert_eq(counts["boss"], 1)

func test_ineligible_encounter_is_skipped() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	var data := _make_data()
	var cond := UnlockConditionData.new()
	cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	cond.target_value = "never_fires_generator_test"
	data.encounter_quotas[1].encounter.unlock_conditions = {cond: true}
	var tiles := _run_generation(data)
	for enc in tiles.values():
		assert_ne(enc.encounter_id, "combat", "ineligible combat should not be placed")

func test_no_infinite_loop_on_oversized_filler_quota() -> void:
	var data := _make_data()
	data.max_distance_from_start = 2
	data.boss_encounter.min_distance_from_origin = 2
	data.encounter_quotas[0].encounter.min_distance_from_origin = 1 # keep <= max_distance_from_start
	data.encounter_quotas[1].count = 500 # deliberately unreachable
	# This call must terminate; if it hangs, the test runner will time out.
	var tiles := _run_generation(data)
	assert_gt(tiles.size(), 0, "generator should still produce some map")

func test_min_fillers_on_path_guaranteed() -> void:
	var data := _make_data()
	for trial in 50:
		var tiles := _run_generation(data)
		var rest_coord: Vector3i = Vector3i.ZERO
		for coord in tiles.keys():
			if tiles[coord].encounter_id == "rest":
				rest_coord = coord
				break
		# BFS from origin across the generated graph.
		var path: Array = _bfs_path(tiles, Vector3i.ZERO, rest_coord)
		assert_false(path.is_empty(), "trial %d: no path from origin to rest" % trial)
		var fillers_on_path: int = 0
		for coord in path:
			if coord == Vector3i.ZERO or coord == rest_coord:
				continue
			if tiles[coord].placement == AdventureEncounter.Placement.FILLER:
				fillers_on_path += 1
		assert_gte(fillers_on_path, 1, "trial %d: path from origin to rest had no filler" % trial)

func _bfs_path(tiles: Dictionary, start: Vector3i, goal: Vector3i) -> Array:
	var neighbors_offsets: Array[Vector3i] = [
		Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
		Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
		Vector3i(0, +1, -1), Vector3i(0, -1, +1),
	]
	var came_from: Dictionary = {start: null}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var current: Vector3i = frontier.pop_front()
		if current == goal:
			var path: Array = []
			var node = goal
			while node != null:
				path.push_front(node)
				node = came_from[node]
			return path
		for off in neighbors_offsets:
			var next: Vector3i = current + off
			if next in tiles and not (next in came_from):
				came_from[next] = current
				frontier.append(next)
	return []
