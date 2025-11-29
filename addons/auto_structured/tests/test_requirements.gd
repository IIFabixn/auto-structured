extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
const MaxCountRequirement = preload("res://addons/auto_structured/core/requirements/max_count_requirement.gd")
const AdjacentRequirement = preload("res://addons/auto_structured/core/requirements/adjacent_requirement.gd")
const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
const BoundaryRequirement = preload("res://addons/auto_structured/core/requirements/boundary_requirement.gd")
const RegionBoundaryRequirement = preload("res://addons/auto_structured/core/requirements/region_boundary_requirement.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Tile Weight & Requirements ===")
	
	# Weight tests
	test_tile_weight_default()
	test_tile_weight_custom()
	test_tile_weight_validation()
	
	# Requirement base class tests
	test_requirement_enabled()
	test_requirement_display_name()
	
	# HeightRequirement tests
	test_height_requirement_exact()
	test_height_requirement_min()
	test_height_requirement_max()
	test_height_requirement_range()
	
	# MaxCountRequirement tests
	test_max_count_requirement()
	test_max_count_requirement_context()
	
	# AdjacentRequirement tests
	test_adjacent_requirement_must_have()
	test_adjacent_requirement_must_not_have()
	
	# TagRequirement tests
	test_tag_requirement_has_all()
	test_tag_requirement_has_any()
	test_tag_requirement_has_none()
	
	# BoundaryRequirement tests
	test_boundary_requirement_must_touch()
	test_boundary_requirement_interior_only()
	
	print_summary()

## ============================================================================
## WEIGHT TESTS
## ============================================================================

func test_tile_weight_default() -> void:
	var test_name = "Tile weight default value"
	var tile = Tile.new()
	assert_equal(tile.weight, 1.0, "Default weight should be 1.0", test_name)

func test_tile_weight_custom() -> void:
	var test_name = "Tile weight custom value"
	var tile = Tile.new()
	tile.weight = 5.5
	assert_equal(tile.weight, 5.5, "Weight should be settable", test_name)

func test_tile_weight_validation() -> void:
	var test_name = "Tile weight validation"
	var tile = Tile.new()
	
	# Test minimum value enforcement
	tile.weight = 0.0
	assert_true(tile.weight >= 0.01, "Weight should be clamped to minimum 0.01", test_name)
	
	tile.weight = -5.0
	assert_true(tile.weight >= 0.01, "Negative weight should be clamped to minimum 0.01", test_name)
	
	# Test that valid values work
	tile.weight = 100.0
	assert_equal(tile.weight, 100.0, "Large weight should be allowed", test_name)

## ============================================================================
## REQUIREMENT BASE CLASS TESTS
## ============================================================================

func test_requirement_enabled() -> void:
	var test_name = "Requirement enabled flag"
	var req = HeightRequirement.new()
	
	assert_true(req.enabled, "Requirement should be enabled by default", test_name)
	
	req.enabled = false
	assert_false(req.enabled, "Requirement should be disableable", test_name)

func test_requirement_display_name() -> void:
	var test_name = "Requirement display name generation"
	var req = HeightRequirement.new()
	
	assert_false(req.display_name.is_empty(), "Display name should be auto-generated", test_name)
	# Note: display_name is generated from class name which may be internal format
	assert_true(req.display_name.length() > 0, "Display name should have content", test_name)

## ============================================================================
## HEIGHT REQUIREMENT TESTS
## ============================================================================

func test_height_requirement_exact() -> void:
	var test_name = "HeightRequirement EXACT mode"
	var tile = _create_test_tile("TestTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.EXACT
	req.height_value = 5
	
	assert_true(req.evaluate(tile, Vector3i(0, 5, 0), grid, context), "Should allow at exact height", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 4, 0), grid, context), "Should deny below exact height", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 6, 0), grid, context), "Should deny above exact height", test_name)

func test_height_requirement_min() -> void:
	var test_name = "HeightRequirement MIN mode"
	var tile = _create_test_tile("TestTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.MIN
	req.height_value = 3
	
	assert_true(req.evaluate(tile, Vector3i(0, 3, 0), grid, context), "Should allow at min height", test_name)
	assert_true(req.evaluate(tile, Vector3i(0, 10, 0), grid, context), "Should allow above min height", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 2, 0), grid, context), "Should deny below min height", test_name)

func test_height_requirement_max() -> void:
	var test_name = "HeightRequirement MAX mode"
	var tile = _create_test_tile("TestTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.MAX
	req.height_value = 7
	
	assert_true(req.evaluate(tile, Vector3i(0, 7, 0), grid, context), "Should allow at max height", test_name)
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should allow below max height", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 8, 0), grid, context), "Should deny above max height", test_name)

func test_height_requirement_range() -> void:
	var test_name = "HeightRequirement RANGE mode"
	var tile = _create_test_tile("TestTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.RANGE
	req.min_height = 2
	req.max_height = 5
	
	assert_true(req.evaluate(tile, Vector3i(0, 2, 0), grid, context), "Should allow at min range", test_name)
	assert_true(req.evaluate(tile, Vector3i(0, 5, 0), grid, context), "Should allow at max range", test_name)
	assert_true(req.evaluate(tile, Vector3i(0, 3, 0), grid, context), "Should allow within range", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 1, 0), grid, context), "Should deny below range", test_name)
	assert_false(req.evaluate(tile, Vector3i(0, 6, 0), grid, context), "Should deny above range", test_name)

## ============================================================================
## MAX COUNT REQUIREMENT TESTS
## ============================================================================

func test_max_count_requirement() -> void:
	var test_name = "MaxCountRequirement basic"
	var tile = _create_test_tile("RareTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = MaxCountRequirement.new()
	req.max_count = 2
	
	# First placement should succeed
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "First placement should succeed", test_name)

func test_max_count_requirement_context() -> void:
	var test_name = "MaxCountRequirement with context tracking"
	var tile = _create_test_tile("UniqueTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = MaxCountRequirement.new()
	req.max_count = 1
	
	var count_key = "tile_count_" + str(tile.get_instance_id())
	
	# No tiles placed yet
	context[count_key] = 0
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should allow when count is 0", test_name)
	
	# One tile placed
	context[count_key] = 1
	assert_false(req.evaluate(tile, Vector3i(1, 0, 0), grid, context), "Should deny when max count reached", test_name)

## ============================================================================
## ADJACENT REQUIREMENT TESTS
## ============================================================================

func test_adjacent_requirement_must_have() -> void:
	var test_name = "AdjacentRequirement MUST_HAVE mode"
	var tile = _create_test_tile("DoorTile")
	var empty_tags: Array[String] = []
	empty_tags.assign([])
	tile.tags = empty_tags
	
	var wall_tile = _create_test_tile("WallTile")
	var wall_tags: Array[String] = []
	wall_tags.assign(["wall"])
	wall_tile.tags = wall_tags
	

func test_region_boundary_requirement_neighbors() -> void:
	var test_name = "RegionBoundaryRequirement neighbor enforcement"
	var tile = Tile.new()
	tile.name = "EdgeTile"
	tile.boundary_role = Tile.BoundaryRole.EDGE
	var boundary_neighbor = Tile.new()
	boundary_neighbor.name = "BoundaryNeighbor"
	boundary_neighbor.boundary_role = Tile.BoundaryRole.EDGE
	var grid = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_place_tile_at(grid, boundary_neighbor, Vector3i(0, 0, 1))
	_place_tile_at(grid, boundary_neighbor, Vector3i(2, 0, 1))
	var req = RegionBoundaryRequirement.new()
	assert_true(req.evaluate(tile, Vector3i(1, 0, 1), grid, {}), "Should allow when two boundary neighbors exist", test_name)
	var fail_grid = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_place_tile_at(fail_grid, boundary_neighbor, Vector3i(0, 0, 1))
	assert_false(req.evaluate(tile, Vector3i(1, 0, 1), fail_grid, {}), "Should fail with insufficient neighbors", test_name)

func test_region_boundary_requirement_counts_potential() -> void:
	var test_name = "RegionBoundaryRequirement counts potential"
	var tile = Tile.new()
	tile.name = "EdgeTile"
	tile.boundary_role = Tile.BoundaryRole.EDGE
	var boundary_neighbor = Tile.new()
	boundary_neighbor.name = "BoundaryNeighbor"
	boundary_neighbor.boundary_role = Tile.BoundaryRole.EDGE
	var filler = Tile.new()
	filler.name = "Filler"
	var grid = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_place_tile_at(grid, boundary_neighbor, Vector3i(0, 0, 1))
	_set_cell_variants(grid, Vector3i(2, 0, 1), [boundary_neighbor, filler])
	var req = RegionBoundaryRequirement.new()
	assert_true(req.evaluate(tile, Vector3i(1, 0, 1), grid, {}), "Should allow when potential neighbor can satisfy", test_name)

func test_region_boundary_requirement_relax_on_boundary() -> void:
	var test_name = "RegionBoundaryRequirement relaxes on world boundary"
	var tile = Tile.new()
	tile.name = "EdgeTile"
	tile.boundary_role = Tile.BoundaryRole.EDGE
	var boundary_neighbor = Tile.new()
	boundary_neighbor.name = "BoundaryNeighbor"
	boundary_neighbor.boundary_role = Tile.BoundaryRole.EDGE
	var grid = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_place_tile_at(grid, boundary_neighbor, Vector3i(1, 0, 1))
	var req = RegionBoundaryRequirement.new()
	var boundary_position = Vector3i(0, 0, 1)
	req.relax_on_world_boundary = true
	assert_true(req.evaluate(tile, boundary_position, grid, {}), "Should allow at world boundary with single neighbor", test_name)
	req.relax_on_world_boundary = false
	assert_false(req.evaluate(tile, boundary_position, grid, {}), "Should fail without relaxation", test_name)

func test_adjacent_requirement_must_have_with_potential_neighbor() -> void:
	var test_name = "AdjacentRequirement MUST_HAVE potential neighbor"
	var tile = _create_test_tile("ConstraintTile")
	var wall_tile = _create_test_tile("WallTile")
	var floor_tile = _create_test_tile("FloorTile")
	var wall_tags: Array[String] = []
	wall_tags.assign(["wall"])
	wall_tile.tags = wall_tags
	var grid = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_set_cell_variants(grid, Vector3i(1, 0, 0), [wall_tile, floor_tile])
	var req = AdjacentRequirement.new()
	req.mode = AdjacentRequirement.AdjacentMode.MUST_HAVE
	req.required_tags.assign(["wall"])
	var context = {}
	assert_true(req.evaluate(tile, Vector3i(1, 0, 1), grid, context), "Should allow when neighbor can still satisfy", test_name)

func test_adjacent_requirement_must_not_have() -> void:
	var test_name = "AdjacentRequirement MUST_NOT_HAVE mode"
	var tile = _create_test_tile("FloorTile")
	var grid = _create_mock_grid()
	var context = {}
	
	var req = AdjacentRequirement.new()
	req.mode = AdjacentRequirement.AdjacentMode.MUST_NOT_HAVE
	req.required_tags.assign(["water"])
	
	# This test is simplified - in practice would need actual adjacent tiles
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should work with basic setup", test_name)

func test_adjacent_requirement_exact_count_feasibility() -> void:
	var test_name = "AdjacentRequirement EXACT_COUNT feasibility"
	var tile = _create_test_tile("DoorTile")
	var wall_tile = _create_test_tile("WallTile")
	var alt_tile = _create_test_tile("AltTile")
	var wall_tags: Array[String] = []
	wall_tags.assign(["wall"])
	wall_tile.tags = wall_tags
	var req = AdjacentRequirement.new()
	req.mode = AdjacentRequirement.AdjacentMode.EXACT_COUNT
	req.required_tags.assign(["wall"])
	req.required_count = 2
	var context = {}
	# Enough potential matches
	var grid_possible = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_set_cell_variants(grid_possible, Vector3i(1, 0, 0), [wall_tile, alt_tile])
	_set_cell_variants(grid_possible, Vector3i(1, 0, 2), [wall_tile])
	assert_true(req.evaluate(tile, Vector3i(1, 0, 1), grid_possible, context), "Should allow when exact count achievable", test_name)
	# Not enough potential matches
	var grid_impossible = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_set_cell_variants(grid_impossible, Vector3i(1, 0, 0), [alt_tile])
	_set_cell_variants(grid_impossible, Vector3i(1, 0, 2), [alt_tile])
	assert_false(req.evaluate(tile, Vector3i(1, 0, 1), grid_impossible, context), "Should deny when exact count impossible", test_name)
	# Too many confirmed matches
	var grid_excess = _create_test_grid_with_tiles(Vector3i(3, 1, 3))
	_place_tile_at(grid_excess, wall_tile, Vector3i(1, 0, 0))
	_place_tile_at(grid_excess, wall_tile, Vector3i(1, 0, 2))
	_place_tile_at(grid_excess, wall_tile, Vector3i(0, 0, 1))
	assert_false(req.evaluate(tile, Vector3i(1, 0, 1), grid_excess, context), "Should deny when exact count already exceeded", test_name)

## ============================================================================
## TAG REQUIREMENT TESTS
## ============================================================================

func test_tag_requirement_has_all() -> void:
	var test_name = "TagRequirement HAS_ALL mode"
	var tile = _create_test_tile("TestTile")
	var test_tags: Array[String] = []
	test_tags.assign(["indoor", "floor", "wood"])
	tile.tags = test_tags
	var grid = _create_mock_grid()
	var context = {}
	
	var req = TagRequirement.new()
	req.mode = TagRequirement.TagMode.HAS_ALL
	req.required_tags.assign(["indoor", "floor"])
	
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should pass when has all tags", test_name)
	
	req.required_tags.assign(["indoor", "stone"])
	assert_false(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should fail when missing a tag", test_name)

func test_tag_requirement_has_any() -> void:
	var test_name = "TagRequirement HAS_ANY mode"
	var tile = _create_test_tile("TestTile")
	var test_tags: Array[String] = []
	test_tags.assign(["indoor", "floor"])
	tile.tags = test_tags
	var grid = _create_mock_grid()
	var context = {}
	
	var req = TagRequirement.new()
	req.mode = TagRequirement.TagMode.HAS_ANY
	req.required_tags.assign(["outdoor", "floor"])
	
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should pass when has at least one tag", test_name)
	
	req.required_tags.assign(["outdoor", "ceiling"])
	assert_false(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should fail when has none of the tags", test_name)

func test_tag_requirement_has_none() -> void:
	var test_name = "TagRequirement HAS_NONE mode"
	var tile = _create_test_tile("TestTile")
	var test_tags: Array[String] = []
	test_tags.assign(["indoor", "floor"])
	tile.tags = test_tags
	var grid = _create_mock_grid()
	var context = {}
	
	var req = TagRequirement.new()
	req.mode = TagRequirement.TagMode.HAS_NONE
	req.required_tags.assign(["outdoor", "ceiling"])
	
	assert_true(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should pass when has none of the tags", test_name)
	
	req.required_tags.assign(["indoor", "ceiling"])
	assert_false(req.evaluate(tile, Vector3i(0, 0, 0), grid, context), "Should fail when has any of the tags", test_name)

## ============================================================================
## BOUNDARY REQUIREMENT TESTS
## ============================================================================

func test_boundary_requirement_must_touch() -> void:
	var test_name = "BoundaryRequirement MUST_TOUCH mode"
	var tile = _create_test_tile("EdgeTile")
	var grid = _create_test_grid_with_tiles(Vector3i(5, 1, 5))
	var context = {}
	
	var req = BoundaryRequirement.new()
	req.mode = BoundaryRequirement.BoundaryMode.MUST_TOUCH
	req.check_x_boundaries = true
	req.check_z_boundaries = true
	req.check_y_boundaries = false
	
	# On edge
	assert_true(req.evaluate(tile, Vector3i(0, 0, 2), grid, context), "Should allow on X boundary", test_name)
	assert_true(req.evaluate(tile, Vector3i(2, 0, 0), grid, context), "Should allow on Z boundary", test_name)
	
	# Interior
	assert_false(req.evaluate(tile, Vector3i(2, 0, 2), grid, context), "Should deny in interior", test_name)

func test_boundary_requirement_interior_only() -> void:
	var test_name = "BoundaryRequirement INTERIOR_ONLY mode"
	var tile = _create_test_tile("InteriorTile")
	var grid = _create_test_grid_with_tiles(Vector3i(5, 1, 5))
	var context = {}
	
	var req = BoundaryRequirement.new()
	req.mode = BoundaryRequirement.BoundaryMode.INTERIOR_ONLY
	req.check_x_boundaries = true
	req.check_z_boundaries = true
	
	# Interior
	assert_true(req.evaluate(tile, Vector3i(2, 0, 2), grid, context), "Should allow in interior", test_name)
	
	# On boundary
	assert_false(req.evaluate(tile, Vector3i(0, 0, 2), grid, context), "Should deny on boundary", test_name)

## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _create_test_tile(tile_name: String, boundary_role: int = Tile.BoundaryRole.NONE) -> Tile:
	var tile = Tile.new()
	tile.name = tile_name
	tile.size = Vector3i.ONE
	if boundary_role != Tile.BoundaryRole.NONE:
		var boundary_req = RegionBoundaryRequirement.new()
		boundary_req.boundary_role = boundary_role
		tile.requirements.append(boundary_req)
	
	# Add a basic "any" socket so tiles can connect
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP, Vector3i.DOWN]:
		var socket = Socket.new()
		socket.direction = dir
		socket.socket_id = "any"
		tile.sockets.append(socket)
	
	return tile

func _create_mock_grid():
	"""Create a minimal mock grid object for testing."""
	var tiles: Array[Tile] = []
	var mock_grid = WfcGrid.new(Vector3i(10, 10, 10), tiles)
	return mock_grid

func _create_test_grid_with_tiles(grid_size: Vector3i) -> WfcGrid:
	var tiles: Array[Tile] = []
	var grid = WfcGrid.new(grid_size, tiles)
	return grid

func _set_cell_variants(grid: WfcGrid, pos: Vector3i, tiles: Array[Tile]) -> void:
	var cell = grid.get_cell(pos)
	if cell == null:
		return
	cell.possible_tile_variants.clear()
	for variant_tile in tiles:
		if variant_tile == null:
			continue
		cell.possible_tile_variants.append({
			"tile": variant_tile,
			"rotation_degrees": 0,
			"weight": 1.0
		})

func _place_tile_at(grid: WfcGrid, tile: Tile, pos: Vector3i) -> void:
	"""Helper to place a tile at a specific position (for adjacency tests)."""
	var cell = grid.get_cell(pos)
	if cell:
		cell.possible_tile_variants.clear()
		cell.possible_tile_variants.append({"tile": tile, "rotation_degrees": 0, "weight": 1.0})
		cell.collapse()

## ============================================================================
## ASSERTION HELPERS
## ============================================================================

func assert_true(condition: bool, message: String, test_name: String) -> void:
	if condition:
		tests_passed += 1
		test_results.append({"name": test_name, "passed": true, "message": message})
	else:
		tests_failed += 1
		test_results.append({"name": test_name, "passed": false, "message": message})
		print("  ✘ ", test_name, ": ", message)

func assert_false(condition: bool, message: String, test_name: String) -> void:
	assert_true(not condition, message, test_name)

func assert_equal(actual, expected, message: String, test_name: String) -> void:
	if actual == expected:
		tests_passed += 1
		test_results.append({"name": test_name, "passed": true, "message": message})
	else:
		tests_failed += 1
		var fail_msg = message + " (expected: %s, got: %s)" % [expected, actual]
		test_results.append({"name": test_name, "passed": false, "message": fail_msg})
		print("  ✘ ", test_name, ": ", fail_msg)

func assert_not_null(value, message: String, test_name: String) -> void:
	assert_true(value != null, message, test_name)

func print_summary() -> void:
	print("\n=== Test Summary ===")
	print("Passed: ", tests_passed)
	print("Failed: ", tests_failed)
	print("Total:  ", tests_passed + tests_failed)
	
	if tests_failed > 0:
		print("\nFailed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - ", result["name"], ": ", result["message"])
