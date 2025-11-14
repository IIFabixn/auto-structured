extends RefCounted

const WfcGrid := preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver := preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")
const Requirement := preload("res://addons/auto_structured/core/requirements/requirement.gd")
const TagRequirement := preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}

	_run_test(results, "Rotation compatibility respects tile orientation", test_rotation_compatibility)
	_run_test(results, "Tile symmetry reduces redundant variants", test_tile_symmetry_variant_generation)
	_run_test(results, "\"None\" sockets interact correctly with empty neighbors", test_none_socket_behavior)
	_run_test(results, "Neighbor variant filtering removes incompatible options", test_neighbor_variant_filtering)
	_run_test(results, "Socket requirements constrain neighbors", test_socket_requirements)

	return results

func _run_test(results: Dictionary, name: String, callable: Callable) -> void:
	results["total"] += 1
	var outcome = callable.call()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func test_rotation_compatibility() -> Variant:
	var tile_a := _create_tile("TileA", [
		{
			"direction": Vector3i.RIGHT,
			"id": "socket_a",
			"compatible": ["socket_b"]
		}
	])
	var tile_b := _create_tile("TileB", [
		{
			"direction": Vector3i.LEFT,
			"id": "socket_b",
			"compatible": ["socket_a"]
		},
		{
			"direction": Vector3i.BACK,
			"id": "socket_b",
			"compatible": ["socket_a"]
		}
	])

	var solver := _create_solver(Vector3i.ONE, [tile_a, tile_b])

	if not solver.are_variants_compatible(tile_a, 0, tile_b, 0, Vector3i.RIGHT):
		return "Base orientation should allow direct adjacency"

	if not solver.are_variants_compatible(tile_a, 90, tile_b, 0, Vector3i.FORWARD):
		return "Rotated source tile should connect on its rotated right face"

	if solver.are_variants_compatible(tile_a, 90, tile_b, 0, Vector3i.RIGHT):
		return "Rotated tile must not incorrectly report compatibility on its original right face"

	return null

func test_tile_symmetry_variant_generation() -> Variant:
	var tile_none := _create_tile("Asym", [], Tile.Symmetry.NONE)
	var tile_half_turn := _create_tile("HalfTurn", [], Tile.Symmetry.ROTATION_180)
	var tile_quarter_turn := _create_tile("QuarterTurn", [], Tile.Symmetry.ROTATION_90)

	var solver := _create_solver(Vector3i.ONE, [tile_none, tile_half_turn, tile_quarter_turn])
	var variants := solver.grid.all_tile_variants

	var asym_rotations := _get_rotations_for_tile(variants, tile_none)
	if asym_rotations != [0, 90, 180, 270]:
		return "Expected four unique rotations for asymmetrical tile but got %s" % [asym_rotations]

	var half_turn_rotations := _get_rotations_for_tile(variants, tile_half_turn)
	if half_turn_rotations != [0, 90]:
		return "Expected two unique rotations for 180° symmetric tile but got %s" % [half_turn_rotations]

	var quarter_turn_rotations := _get_rotations_for_tile(variants, tile_quarter_turn)
	if quarter_turn_rotations != [0]:
		return "Expected single rotation for 90° symmetric tile but got %s" % [quarter_turn_rotations]

	if variants.size() != 7:
		return "Expected 7 total variants but got %d" % variants.size()

	return null

func test_none_socket_behavior() -> Variant:
	var tile_none := _create_tile("TileNone", [
		{
			"direction": Vector3i.RIGHT,
			"id": "none",
			"compatible": ["none"]
		}
	])
	var tile_empty := _create_tile("TileEmpty", [])
	var tile_solid := _create_tile("TileSolid", [
		{
			"direction": Vector3i.RIGHT,
			"id": "solid",
			"compatible": []
		}
	])

	var solver := _create_solver(Vector3i.ONE, [tile_none, tile_empty, tile_solid])

	if not solver.are_variants_compatible(tile_none, 0, tile_empty, 0, Vector3i.RIGHT):
		return "Socket with id 'none' should accept an empty neighbor"

	if solver.are_variants_compatible(tile_solid, 0, tile_empty, 0, Vector3i.RIGHT):
		return "Non-'none' sockets must not connect to empty space"

	return null

func test_neighbor_variant_filtering() -> Variant:
	var tile_source := _create_tile("Source", [
		{
			"direction": Vector3i.RIGHT,
			"id": "male",
			"compatible": ["female"]
		}
	])
	var tile_good := _create_tile("Good", [
		{
			"direction": Vector3i.LEFT,
			"id": "female",
			"compatible": ["male"]
		}
	])
	var tile_bad := _create_tile("Bad", [
		{
			"direction": Vector3i.LEFT,
			"id": "blocked",
			"compatible": []
		}
	])

	var solver := _create_solver(Vector3i(2, 1, 1), [tile_source, tile_good, tile_bad])
	var grid := solver.grid

	var source_cell := grid.get_cell(Vector3i.ZERO)
	var neighbor_cell := grid.get_cell(Vector3i(1, 0, 0))

	var source_variant := _find_variant(grid, tile_source, 0)
	var good_variant := _find_variant(grid, tile_good, 0)
	var bad_variant := _find_variant(grid, tile_bad, 0)

	if source_variant.is_empty() or good_variant.is_empty() or bad_variant.is_empty():
		return "Failed to locate expected tile variants in grid"

	var source_variants: Array[Dictionary] = []
	source_variants.append(source_variant)
	source_cell.possible_tile_variants = source_variants
	if not source_cell.collapse():
		return "Unable to collapse source cell during setup"

	var neighbor_variants: Array[Dictionary] = []
	neighbor_variants.append(good_variant)
	neighbor_variants.append(bad_variant)
	neighbor_cell.possible_tile_variants = neighbor_variants

	var valid := solver.get_valid_variants_for_neighbor(source_cell, neighbor_cell, Vector3i.RIGHT)
	if valid.size() != 1:
		return "Expected exactly one valid neighbor variant but received %d" % valid.size()

	if valid[0]["tile"] != tile_good:
		return "Filtering kept an unexpected tile variant"

	return null

func test_socket_requirements() -> Variant:
	var tag_requirement := TagRequirement.new()
	tag_requirement.required_tag = "friendly"

	var source_tile := _create_tile("SourceReq", [
		{
			"direction": Vector3i.RIGHT,
			"id": "male",
			"compatible": ["female"],
			"requirements": [tag_requirement]
		}
	])

	var friendly_tile := _create_tile("Friendly", [
		{
			"direction": Vector3i.LEFT,
			"id": "female",
			"compatible": ["male"]
		}
	])
	friendly_tile.tags = ["friendly"]

	var enemy_tile := _create_tile("Enemy", [
		{
			"direction": Vector3i.LEFT,
			"id": "female",
			"compatible": ["male"]
		}
	])

	var solver := _create_solver(Vector3i.ONE, [source_tile, friendly_tile, enemy_tile])

	if not solver.are_variants_compatible(source_tile, 0, friendly_tile, 0, Vector3i.RIGHT):
		return "Requirement should allow tile with matching tag"

	if solver.are_variants_compatible(source_tile, 0, enemy_tile, 0, Vector3i.RIGHT):
		return "Requirement should block tile missing required tag"

	return null

func _get_rotations_for_tile(variants: Array[Dictionary], tile: Tile) -> Array[int]:
	var rotations: Array[int] = []
	for variant in variants:
		if variant["tile"] == tile:
			rotations.append(int(variant["rotation_degrees"]))
	rotations.sort()
	return rotations


func _create_tile(name: String, socket_defs: Array, symmetry: int = Tile.Symmetry.NONE) -> Tile:
	var tile := Tile.new()
	tile.name = name
	tile.symmetry = symmetry
	var sockets: Array[Socket] = []
	for def in socket_defs:
		var socket := Socket.new()
		socket.direction = def.get("direction", Vector3i.RIGHT)
		socket.socket_id = def.get("id", "none")
		var compat: Array[String] = []
		var raw_compat = def.get("compatible", [])
		for id in raw_compat:
			compat.append(str(id))
		socket.compatible_sockets = compat
		var reqs_raw = def.get("requirements", [])
		if not reqs_raw.is_empty():
			var reqs: Array[Requirement] = []
			for req in reqs_raw:
				reqs.append(req)
			socket.requirements = reqs
		sockets.append(socket)
	tile.sockets = sockets
	return tile

func _create_solver(grid_size: Vector3i, tiles: Array) -> WfcSolver:
	var typed_tiles: Array[Tile] = []
	for tile in tiles:
		typed_tiles.append(tile)
	var grid := WfcGrid.new(grid_size, typed_tiles)
	return WfcSolver.new(grid, null, false)

func _find_variant(grid: WfcGrid, tile: Tile, rotation: int) -> Dictionary:
	for variant in grid.all_tile_variants:
		if variant["tile"] == tile and variant["rotation_degrees"] == rotation:
			return variant
	return {}
