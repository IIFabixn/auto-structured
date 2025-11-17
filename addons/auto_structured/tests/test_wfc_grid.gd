extends RefCounted

const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing WfcGrid ===")
	
	test_grid_initialization()
	test_grid_cell_access()
	test_grid_bounds_checking()
	test_grid_neighbor_access()
	test_grid_flat_array_indexing()
	test_grid_variant_generation()
	test_grid_heap_operations()
	test_grid_reset()
	test_grid_from_library()
	
	print_summary()

func test_grid_initialization() -> void:
	var test_name = "Grid initialization"
	
	var tile = Tile.new()
	tile.name = "TestTile"
	
	var tiles: Array[Tile] = [tile]
	var grid_size = Vector3i(3, 2, 4)
	var grid = WfcGrid.new(grid_size, tiles)
	
	# Test grid size
	assert_equal(grid.size, grid_size, "Grid size should match initialization", test_name)
	
	# Test cell count
	var expected_cells = 3 * 2 * 4
	assert_equal(grid.get_cell_count(), expected_cells, "Grid should have correct number of cells", test_name)
	
	# Test all tiles assigned
	assert_equal(grid.all_tiles.size(), 1, "Grid should have 1 tile", test_name)
	
	# Test variants generated (4 rotations for a normal tile)
	assert_true(grid.all_tile_variants.size() >= 1, "Grid should have at least 1 variant", test_name)

func test_grid_cell_access() -> void:
	var test_name = "Grid cell access"
	
	var tile = Tile.new()
	tile.name = "TestTile"
	
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(5, 5, 5), tiles)
	
	# Test accessing valid cell
	var cell = grid.get_cell(Vector3i(2, 3, 1))
	assert_not_null(cell, "Should get cell at valid position", test_name)
	assert_equal(cell.position, Vector3i(2, 3, 1), "Cell should have correct position", test_name)
	
	# Test accessing corner cells
	var corner1 = grid.get_cell(Vector3i(0, 0, 0))
	assert_not_null(corner1, "Should get cell at (0,0,0)", test_name)
	
	var corner2 = grid.get_cell(Vector3i(4, 4, 4))
	assert_not_null(corner2, "Should get cell at (4,4,4)", test_name)
	
	# Test accessing out of bounds
	var out_of_bounds = grid.get_cell(Vector3i(5, 5, 5))
	assert_null(out_of_bounds, "Should return null for out of bounds position", test_name)
	
	var negative = grid.get_cell(Vector3i(-1, 0, 0))
	assert_null(negative, "Should return null for negative position", test_name)

func test_grid_bounds_checking() -> void:
	var test_name = "Grid bounds checking"
	
	var tile = Tile.new()
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(10, 8, 6), tiles)
	
	# Test valid positions
	assert_true(grid.is_valid_position(Vector3i(0, 0, 0)), "Origin should be valid", test_name)
	assert_true(grid.is_valid_position(Vector3i(9, 7, 5)), "Max corner should be valid", test_name)
	assert_true(grid.is_valid_position(Vector3i(5, 4, 3)), "Middle position should be valid", test_name)
	
	# Test invalid positions
	assert_false(grid.is_valid_position(Vector3i(10, 0, 0)), "X at size should be invalid", test_name)
	assert_false(grid.is_valid_position(Vector3i(0, 8, 0)), "Y at size should be invalid", test_name)
	assert_false(grid.is_valid_position(Vector3i(0, 0, 6)), "Z at size should be invalid", test_name)
	assert_false(grid.is_valid_position(Vector3i(-1, 0, 0)), "Negative X should be invalid", test_name)

func test_grid_neighbor_access() -> void:
	var test_name = "Grid neighbor access"
	
	var tile = Tile.new()
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(5, 5, 5), tiles)
	
	# Test middle cell (should have 6 neighbors)
	var center = Vector3i(2, 2, 2)
	var neighbors = grid.get_neighbors(center)
	assert_equal(neighbors.size(), 6, "Center cell should have 6 neighbors", test_name)
	
	# Test corner cell (should have 3 neighbors)
	var corner = Vector3i(0, 0, 0)
	var corner_neighbors = grid.get_neighbors(corner)
	assert_equal(corner_neighbors.size(), 3, "Corner cell should have 3 neighbors", test_name)
	
	# Test edge cell (should have fewer than 6 neighbors)
	var edge = Vector3i(0, 2, 2)
	var edge_neighbors = grid.get_neighbors(edge)
	assert_equal(edge_neighbors.size(), 5, "Edge cell should have 5 neighbors", test_name)
	
	# Test specific neighbor in direction
	var right_neighbor = grid.get_neighbor_in_direction(center, Vector3i(1, 0, 0))
	assert_not_null(right_neighbor, "Should get right neighbor", test_name)
	assert_equal(right_neighbor.position, Vector3i(3, 2, 2), "Right neighbor should be at correct position", test_name)
	
	# Test neighbor out of bounds
	var invalid_neighbor = grid.get_neighbor_in_direction(Vector3i(4, 2, 2), Vector3i(1, 0, 0))
	assert_null(invalid_neighbor, "Should return null for out of bounds neighbor", test_name)

func test_grid_flat_array_indexing() -> void:
	var test_name = "Grid flat array indexing"
	
	var tile = Tile.new()
	var tiles: Array[Tile] = [tile]
	var grid = WfcGrid.new(Vector3i(4, 3, 5), tiles)
	
	# Test that same position always returns same cell
	var pos = Vector3i(2, 1, 3)
	var cell1 = grid.get_cell(pos)
	var cell2 = grid.get_cell(pos)
	assert_true(cell1 == cell2, "Same position should return same cell reference", test_name)
	
	# Test all cells are unique
	var cell_set: Dictionary = {}
	for x in range(4):
		for y in range(3):
			for z in range(5):
				var cell = grid.get_cell(Vector3i(x, y, z))
				var id = cell.get_instance_id()
				assert_false(cell_set.has(id), "Each cell should be unique instance", test_name)
				cell_set[id] = true
	
	# Verify we have exactly the right number of unique cells
	assert_equal(cell_set.size(), 4 * 3 * 5, "Should have correct number of unique cells", test_name)

func test_grid_variant_generation() -> void:
	var test_name = "Grid variant generation"
	
	var tile1 = Tile.new()
	tile1.name = "Tile1"
	var tile2 = Tile.new()
	tile2.name = "Tile2"
	
	var tiles: Array[Tile] = [tile1, tile2]
	var grid = WfcGrid.new(Vector3i(2, 2, 2), tiles)
	
	# Each tile should generate rotations (typically 4 for symmetrical tiles)
	assert_true(grid.all_tile_variants.size() >= 2, "Should have at least 2 variants (one per tile minimum)", test_name)
	
	# Check variant structure
	for variant in grid.all_tile_variants:
		assert_true(variant.has("tile"), "Variant should have tile key", test_name)
		assert_true(variant.has("rotation_degrees"), "Variant should have rotation_degrees key", test_name)
		assert_true(variant["tile"] is Tile, "Variant tile should be Tile instance", test_name)
		assert_true(variant["rotation_degrees"] is int, "Variant rotation should be int", test_name)

func test_grid_heap_operations() -> void:
	var test_name = "Grid heap operations"
	
	# Create multiple tiles so cells have more than 1 variant
	var tile1 = Tile.new()
	tile1.name = "TestTile1"
	var tile2 = Tile.new()
	tile2.name = "TestTile2"
	
	var tiles: Array[Tile] = [tile1, tile2]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	
	# Initialize heap
	grid.initialize_heap()
	
	# Debug: check heap has items
	var heap_size = grid._entropy_heap.size()
	assert_true(heap_size > 0, "Heap should have items after initialization (has " + str(heap_size) + ")", test_name)
	
	# Test getting lowest entropy cell
	var lowest = grid.get_lowest_entropy_cell()
	assert_not_null(lowest, "Should get lowest entropy cell from heap", test_name)
	if lowest != null:
		assert_false(lowest.is_collapsed(), "Lowest entropy cell should not be collapsed", test_name)
	
	# Collapse a cell and mark its neighbors
	if lowest != null:
		lowest.collapse()
		var neighbors = grid.get_neighbors(lowest.position)
		for neighbor in neighbors:
			grid.mark_cell_entropy_changed(neighbor)
		
		# Test that heap still works after updates
		var next_lowest = grid.get_lowest_entropy_cell()
		assert_not_null(next_lowest, "Should still get cells from heap after updates", test_name)

func test_grid_reset() -> void:
	var test_name = "Grid reset"
	
	# Create multiple tiles so cells have more than 1 variant
	var tile1 = Tile.new()
	tile1.name = "TestTile1"
	var tile2 = Tile.new()
	tile2.name = "TestTile2"
	
	var tiles: Array[Tile] = [tile1, tile2]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	
	# Initialize and collapse some cells
	grid.initialize_heap()
	var cell1 = grid.get_cell(Vector3i(0, 0, 0))
	var cell2 = grid.get_cell(Vector3i(1, 1, 1))
	cell1.collapse()
	cell2.collapse()
	
	assert_true(cell1.is_collapsed(), "Cell should be collapsed before reset", test_name)
	
	# Reset grid
	grid.reset()
	
	# Check all cells are uncollapsed
	var all_cells = grid.get_all_cells()
	var all_uncollapsed = true
	for cell in all_cells:
		if cell.is_collapsed():
			all_uncollapsed = false
			break
	assert_true(all_uncollapsed, "All cells should be uncollapsed after reset", test_name)
	
	# Check cell1 specifically
	var cell1_after = grid.get_cell(Vector3i(0, 0, 0))
	assert_false(cell1_after.is_collapsed(), "Previously collapsed cell should be reset", test_name)

func test_grid_from_library() -> void:
	var test_name = "Grid from library"
	
	var library = ModuleLibrary.new()
	library.library_name = "TestLibrary"
	
	var tile = Tile.new()
	tile.name = "LibraryTile"
	var tiles_array: Array[Tile] = [tile]
	library.tiles = tiles_array
	
	var grid = WfcGrid.from_library(Vector3i(4, 4, 4), library)
	
	assert_not_null(grid, "Should create grid from library", test_name)
	assert_equal(grid.size, Vector3i(4, 4, 4), "Grid should have correct size", test_name)
	assert_equal(grid.all_tiles.size(), 1, "Grid should have tile from library", test_name)
	assert_equal(grid.all_tiles[0].name, "LibraryTile", "Grid should have correct tile from library", test_name)

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

func assert_null(value, message: String, test_name: String) -> void:
	assert_true(value == null, message, test_name)

func print_summary() -> void:
	print("\n--- WfcGrid Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
