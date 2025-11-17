extends RefCounted

const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing WfcSolver ===")
	
	test_solver_initialization()
	test_solver_compatibility_basic()
	test_solver_compatibility_with_sockets()
	test_solver_propagation()
	test_solver_simple_solve()
	test_solver_weights()
	test_solver_backtracking()
	test_solver_progress_callback()
	test_solver_cache_stats()
	
	print_summary()

func test_solver_initialization() -> void:
	var test_name = "Solver initialization"
	
	var tile = create_simple_tile("TestTile")
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	var solver = WfcSolver.new(grid, false)
	
	# Test solver has grid
	assert_not_null(solver.grid, "Solver should have grid reference", test_name)
	assert_equal(solver.grid, grid, "Solver grid should match passed grid", test_name)
	
	# Test default settings
	assert_true(solver.max_iterations > 0, "Solver should have positive max iterations", test_name)
	assert_true(solver.logging_enabled, "Logging should be enabled by default", test_name)
	
	# Test backtracking settings
	assert_true(solver.enable_backtracking, "Backtracking should be enabled by default", test_name)
	assert_true(solver.max_backtrack_depth > 0, "Should have positive backtrack depth", test_name)

func test_solver_compatibility_basic() -> void:
	var test_name = "Solver compatibility basic"
	
	# Create two tiles with compatible sockets
	var socket_type1 = SocketType.new()
	socket_type1.type_id = "wall"
	socket_type1.set_compatible_types(["wall"])
	
	var tile1 = Tile.new()
	tile1.name = "WallTile"
	tile1.size = Vector3i.ONE
	
	# Add sockets on all sides
	for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
		var socket = Socket.new()
		socket.socket_type = socket_type1
		socket.direction = direction
		tile1.sockets.append(socket)
	
	var tiles: Array[Tile] = [tile1]
	var grid = WfcGrid.new(Vector3i(2, 2, 2), tiles)
	var solver = WfcSolver.new(grid, false)
	
	# Test that tile is compatible with itself
	var compatible = solver.are_variants_compatible(tile1, 0, tile1, 0, Vector3i.RIGHT)
	assert_true(compatible, "Wall tile should be compatible with itself", test_name)

func test_solver_compatibility_with_sockets() -> void:
	var test_name = "Solver compatibility with sockets"
	
	# Create socket types
	var socket_type_a = SocketType.new()
	socket_type_a.type_id = "type_a"
	socket_type_a.set_compatible_types(["type_b"])
	
	var socket_type_b = SocketType.new()
	socket_type_b.type_id = "type_b"
	socket_type_b.set_compatible_types(["type_a"])
	
	# Create tile with type_a on right
	var tile_a = Tile.new()
	tile_a.name = "TileA"
	tile_a.size = Vector3i.ONE
	var socket_a = Socket.new()
	socket_a.socket_type = socket_type_a
	socket_a.direction = Vector3i.RIGHT
	tile_a.sockets.append(socket_a)
	
	# Create tile with type_b on left
	var tile_b = Tile.new()
	tile_b.name = "TileB"
	tile_b.size = Vector3i.ONE
	var socket_b = Socket.new()
	socket_b.socket_type = socket_type_b
	socket_b.direction = Vector3i.LEFT
	tile_b.sockets.append(socket_b)
	
	var tiles: Array[Tile] = [tile_a, tile_b]
	var grid = WfcGrid.new(Vector3i(2, 1, 1), tiles)
	var solver = WfcSolver.new(grid, false)
	
	# Test compatibility in correct direction
	var compatible = solver.are_variants_compatible(tile_a, 0, tile_b, 0, Vector3i.RIGHT)
	assert_true(compatible, "TileA should be compatible with TileB to the right", test_name)
	
	# Test incompatibility in wrong direction
	var incompatible = solver.are_variants_compatible(tile_a, 0, tile_b, 0, Vector3i.LEFT)
	assert_false(incompatible, "TileA should not be compatible with TileB to the left", test_name)

func test_solver_propagation() -> void:
	var test_name = "Solver propagation"
	
	var tile = create_simple_tile("TestTile")
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(3, 1, 1), tiles)
	var solver = WfcSolver.new(grid, false)
	solver.set_logging_enabled(false)
	
	# Initialize heap
	grid.initialize_heap()
	
	# Collapse center cell
	var center_cell = grid.get_cell(Vector3i(1, 0, 0))
	center_cell.collapse()
	
	# Propagate constraints
	var result = solver.propagate(center_cell)
	assert_true(result, "Propagation should succeed", test_name)
	
	# Check that neighbors were affected (though in this simple case they may still have same variants)
	var left_neighbor = grid.get_cell(Vector3i(0, 0, 0))
	var right_neighbor = grid.get_cell(Vector3i(2, 0, 0))
	assert_not_null(left_neighbor, "Left neighbor should exist", test_name)
	assert_not_null(right_neighbor, "Right neighbor should exist", test_name)

func test_solver_simple_solve() -> void:
	var test_name = "Solver simple solve"
	
	# Create a simple universal tile that connects to itself
	var tile = create_universal_tile("UniversalTile")
	var tiles: Array[Tile] = [tile]
	
	# Small grid for quick testing
	var grid = WfcGrid.new(Vector3i(2, 2, 2), tiles)
	var solver = WfcSolver.new(grid, false)
	solver.set_logging_enabled(false)
	
	# Solve the grid
	var result = solver.solve()
	assert_true(result, "Solver should successfully solve small grid", test_name)
	
	# Check all cells are collapsed
	var all_collapsed = true
	for cell in grid.get_all_cells():
		if not cell.is_collapsed():
			all_collapsed = false
			break
	assert_true(all_collapsed, "All cells should be collapsed after solve", test_name)
	
	# Check no contradictions
	assert_false(grid.has_contradiction(), "Grid should have no contradictions after solve", test_name)

func test_solver_weights() -> void:
	var test_name = "Solver weights"
	
	var tile1 = create_universal_tile("Tile1")
	var tile2 = create_universal_tile("Tile2")
	var tiles: Array[Tile] = [tile1, tile2]
	
	var grid = WfcGrid.new(Vector3i(2, 2, 2), tiles)
	var solver = WfcSolver.new(grid, false)
	solver.set_logging_enabled(false)
	
	# Set heavy weight on tile1
	solver.set_tile_weight_all_rotations(tile1, 10.0)
	solver.set_tile_weight_all_rotations(tile2, 1.0)
	
	# Check that weights were set
	var found_weighted = false
	for variant in grid.all_tile_variants:
		if variant["tile"] == tile1:
			if variant.get("weight", 1.0) == 10.0:
				found_weighted = true
				break
	assert_true(found_weighted, "Tile1 should have weight of 10.0", test_name)
	
	# Solve and verify tile1 appears more often (probabilistic test)
	var result = solver.solve()
	assert_true(result, "Weighted solve should succeed", test_name)

func test_solver_backtracking() -> void:
	var test_name = "Solver backtracking"
	
	var tile = create_universal_tile("TestTile")
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	var solver = WfcSolver.new(grid, false)
	solver.set_logging_enabled(false)
	
	# Enable backtracking
	solver.enable_backtracking = true
	solver.max_backtrack_depth = 5
	solver.backtrack_checkpoint_frequency = 2
	
	# Solve
	var result = solver.solve()
	assert_true(result, "Solver with backtracking should solve", test_name)
	
	# Test disable backtracking
	grid.reset()
	solver.enable_backtracking = false
	var result2 = solver.solve()
	assert_true(result2, "Solver without backtracking should still solve simple grid", test_name)

func test_solver_progress_callback() -> void:
	var test_name = "Solver progress callback"
	
	var tile = create_universal_tile("TestTile")
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	var solver = WfcSolver.new(grid, false)
	solver.set_logging_enabled(false)
	
	# Set up progress tracking
	var progress_calls: Array = []
	solver.progress_callback = func(data: Dictionary):
		progress_calls.append(data)
	
	solver.progress_report_frequency = 5
	
	# Solve
	var result = solver.solve()
	assert_true(result, "Solver should solve", test_name)
	
	# Check that progress was reported
	assert_true(progress_calls.size() > 0, "Progress callback should be called", test_name)
	
	# Check progress data structure
	if progress_calls.size() > 0:
		var first_progress = progress_calls[0]
		assert_true(first_progress.has("progress"), "Progress data should have progress field", test_name)
		assert_true(first_progress.has("cells_collapsed"), "Progress data should have cells_collapsed field", test_name)
		assert_true(first_progress.has("total_cells"), "Progress data should have total_cells field", test_name)

func test_solver_cache_stats() -> void:
	var test_name = "Solver cache stats"
	
	var tile = create_universal_tile("TestTile")
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(2, 2, 2), tiles)
	var solver = WfcSolver.new(grid, false)
	
	# Get cache stats
	var stats = solver.get_cache_stats()
	
	assert_true(stats.has("cache_size"), "Stats should have cache_size", test_name)
	assert_true(stats.has("variants"), "Stats should have variants", test_name)
	assert_true(stats.has("estimated_memory_kb"), "Stats should have estimated_memory_kb", test_name)
	
	assert_true(stats["cache_size"] > 0, "Cache size should be positive", test_name)
	assert_true(stats["variants"] > 0, "Variants count should be positive", test_name)

# Helper functions to create test tiles
func create_simple_tile(tile_name: String) -> Tile:
	var tile = Tile.new()
	tile.name = tile_name
	tile.size = Vector3i.ONE
	return tile

func create_universal_tile(tile_name: String) -> Tile:
	"""Create a tile that connects to itself in all directions."""
	var socket_type = SocketType.new()
	socket_type.type_id = "universal"
	socket_type.set_compatible_types(["universal"])
	
	var tile = Tile.new()
	tile.name = tile_name
	tile.size = Vector3i.ONE
	
	# Add sockets on all six sides
	for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
		var socket = Socket.new()
		socket.socket_type = socket_type
		socket.direction = direction
		tile.sockets.append(socket)
	
	return tile

# Helper assertion methods
func assert_true(condition: bool, message: String, test_name: String) -> void:
	if condition:
		test_results.append({"test": test_name, "status": "PASS", "message": message})
		tests_passed += 1
	else:
		test_results.append({"test": test_name, "status": "FAIL", "message": message})
		tests_failed += 1
		print("  [FAIL] ", test_name, ": ", message)

func assert_false(condition: bool, message: String, test_name: String) -> void:
	assert_true(!condition, message, test_name)

func assert_equal(actual, expected, message: String, test_name: String) -> void:
	if actual == expected:
		test_results.append({"test": test_name, "status": "PASS", "message": message})
		tests_passed += 1
	else:
		var msg = "%s (expected: %s, actual: %s)" % [message, expected, actual]
		test_results.append({"test": test_name, "status": "FAIL", "message": msg})
		tests_failed += 1
		print("  [FAIL] ", test_name, ": ", msg)

func assert_not_null(value, message: String, test_name: String) -> void:
	assert_true(value != null, message, test_name)

func print_summary() -> void:
	print("\n--- WfcSolver Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
