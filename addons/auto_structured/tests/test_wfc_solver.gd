extends RefCounted

const WfcGrid := preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver := preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}

	_run_test(results, "Rotation compatibility respects tile orientation", test_rotation_compatibility)
	_run_test(results, "\"None\" sockets interact correctly with empty neighbors", test_none_socket_behavior)
	_run_test(results, "Neighbor variant filtering removes incompatible options", test_neighbor_variant_filtering)

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

func _create_tile(name: String, socket_defs: Array) -> Tile:
	var tile := Tile.new()
	tile.name = name
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
		sockets.append(socket)
	tile.sockets = sockets
	return tile

func _create_solver(grid_size: Vector3i, tiles: Array) -> WfcSolver:
	var grid := WfcGrid.new(grid_size, tiles)
	return WfcSolver.new(grid, null, false)

func _find_variant(grid: WfcGrid, tile: Tile, rotation: int) -> Dictionary:
	for variant in grid.all_tile_variants:
		if variant["tile"] == tile and variant["rotation_degrees"] == rotation:
			return variant
	return {}
