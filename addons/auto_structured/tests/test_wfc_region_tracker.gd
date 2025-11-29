extends RefCounted

const WfcRegionTracker = preload("res://addons/auto_structured/core/wfc/wfc_region_tracker.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing WfcRegionTracker ===")
	
	test_single_tile_creates_region()
	test_adjacent_tiles_same_region()
	test_separate_tiles_different_regions()
	test_max_regions_check()
	test_snapshot_and_restore()
	test_world_boundary_detection()
	test_non_boundary_tiles_ignored()
	test_vertical_connectivity()


func create_boundary_tile(role: Tile.BoundaryRole = Tile.BoundaryRole.EDGE) -> Tile:
	var tile = Tile.new()
	tile.name = "TestBoundary"
	tile.boundary_role = role
	return tile


func create_non_boundary_tile() -> Tile:
	var tile = Tile.new()
	tile.name = "TestNonBoundary"
	tile.boundary_role = Tile.BoundaryRole.NONE
	return tile


func create_infill_tile() -> Tile:
	var tile = Tile.new()
	tile.name = "TestInfill"
	tile.boundary_role = Tile.BoundaryRole.INFILL
	return tile


func test_single_tile_creates_region() -> void:
	var test_name = "Single tile creates one region"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 3, 5))
	var tile = create_boundary_tile()
	
	assert_equal(tracker.get_region_count(), 0, "Should start with 0 regions", test_name)
	
	tracker.register_boundary_tile(Vector3i(2, 0, 2), tile)
	
	assert_equal(tracker.get_region_count(), 1, "Should have 1 region after adding tile", test_name)
	assert_true(tracker.is_boundary_position(Vector3i(2, 0, 2)), "Position should be tracked", test_name)


func test_adjacent_tiles_same_region() -> void:
	var test_name = "Adjacent tiles form single region"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 3, 5))
	var tile = create_boundary_tile()
	
	# Add tiles in a line
	tracker.register_boundary_tile(Vector3i(1, 0, 2), tile)
	tracker.register_boundary_tile(Vector3i(2, 0, 2), tile)
	tracker.register_boundary_tile(Vector3i(3, 0, 2), tile)
	
	assert_equal(tracker.get_region_count(), 1, "Adjacent tiles should form 1 region", test_name)
	assert_true(tracker.are_in_same_region(Vector3i(1, 0, 2), Vector3i(3, 0, 2)), 
		"First and last tile should be in same region", test_name)


func test_separate_tiles_different_regions() -> void:
	var test_name = "Separate tiles form different regions"
	
	var tracker = WfcRegionTracker.new(Vector3i(10, 3, 10))
	var tile = create_boundary_tile()
	
	# Add tiles with gap between them
	tracker.register_boundary_tile(Vector3i(1, 0, 1), tile)
	tracker.register_boundary_tile(Vector3i(8, 0, 8), tile)
	
	assert_equal(tracker.get_region_count(), 2, "Separate tiles should form 2 regions", test_name)
	assert_false(tracker.are_in_same_region(Vector3i(1, 0, 1), Vector3i(8, 0, 8)), 
		"Distant tiles should be in different regions", test_name)


func test_max_regions_check() -> void:
	var test_name = "Max regions check works"
	
	var tracker = WfcRegionTracker.new(Vector3i(10, 3, 10))
	var tile = create_boundary_tile()
	
	# Add one isolated tile
	tracker.register_boundary_tile(Vector3i(1, 0, 1), tile)
	assert_equal(tracker.get_region_count(), 1, "Should have 1 region", test_name)
	
	# Check if adding another isolated tile would exceed max
	var would_exceed = tracker.would_exceed_max_regions(Vector3i(8, 0, 8), tile, 1)
	assert_true(would_exceed, "Should exceed max_regions=1 when adding second isolated tile", test_name)
	
	# Adding adjacent tile should not exceed
	var would_not_exceed = tracker.would_exceed_max_regions(Vector3i(2, 0, 1), tile, 1)
	assert_false(would_not_exceed, "Adding adjacent tile should not exceed max", test_name)
	
	# Unlimited should always allow
	var unlimited = tracker.would_exceed_max_regions(Vector3i(8, 0, 8), tile, 0)
	assert_false(unlimited, "max_regions=0 (unlimited) should always allow", test_name)


func test_snapshot_and_restore() -> void:
	var test_name = "Snapshot and restore works"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 3, 5))
	var tile = create_boundary_tile()
	
	# Add initial tiles
	tracker.register_boundary_tile(Vector3i(1, 0, 1), tile)
	tracker.register_boundary_tile(Vector3i(2, 0, 1), tile)
	
	assert_equal(tracker.get_region_count(), 1, "Should have 1 region before snapshot", test_name)
	
	# Create snapshot
	var snapshot = tracker.create_snapshot()
	
	# Add more tiles to create second region
	tracker.register_boundary_tile(Vector3i(4, 0, 4), tile)
	assert_equal(tracker.get_region_count(), 2, "Should have 2 regions after adding isolated tile", test_name)
	
	# Restore snapshot
	tracker.restore_snapshot(snapshot)
	assert_equal(tracker.get_region_count(), 1, "Should have 1 region after restore", test_name)
	assert_true(tracker.is_boundary_position(Vector3i(1, 0, 1)), "Original tile should still exist", test_name)
	assert_false(tracker.is_boundary_position(Vector3i(4, 0, 4)), "New tile should not exist after restore", test_name)


func test_world_boundary_detection() -> void:
	var test_name = "World boundary detection"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 3, 5))
	var tile = create_boundary_tile()
	
	# Add tile at edge of grid
	tracker.register_boundary_tile(Vector3i(0, 0, 2), tile)
	assert_true(tracker.region_touches_world_boundary(Vector3i(0, 0, 2)), 
		"Tile at x=0 should touch world boundary", test_name)
	
	# Add tile in center
	var tracker2 = WfcRegionTracker.new(Vector3i(5, 3, 5))
	tracker2.register_boundary_tile(Vector3i(2, 0, 2), tile)
	assert_false(tracker2.region_touches_world_boundary(Vector3i(2, 0, 2)), 
		"Tile in center should not touch world boundary", test_name)


func test_non_boundary_tiles_ignored() -> void:
	var test_name = "Non-boundary tiles are ignored"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 3, 5))
	var non_boundary_tile = create_non_boundary_tile()
	var infill_tile = create_infill_tile()
	var boundary_tile = create_boundary_tile()
	
	# Register non-boundary tile (should be ignored)
	tracker.register_boundary_tile(Vector3i(1, 0, 1), non_boundary_tile)
	assert_equal(tracker.get_region_count(), 0, "Non-boundary tile should not create region", test_name)
	
	# Register INFILL tile (should also be ignored - it's interior, not perimeter)
	tracker.register_boundary_tile(Vector3i(2, 0, 1), infill_tile)
	assert_equal(tracker.get_region_count(), 0, "INFILL tile should not create region", test_name)
	
	# Register EDGE boundary tile
	tracker.register_boundary_tile(Vector3i(3, 0, 2), boundary_tile)
	assert_equal(tracker.get_region_count(), 1, "EDGE tile should create region", test_name)


func test_vertical_connectivity() -> void:
	var test_name = "Vertical connectivity (multi-story)"
	
	var tracker = WfcRegionTracker.new(Vector3i(5, 5, 5))
	tracker.include_vertical_neighbors = true
	var tile = create_boundary_tile()
	
	# Stack tiles vertically
	tracker.register_boundary_tile(Vector3i(2, 0, 2), tile)
	tracker.register_boundary_tile(Vector3i(2, 1, 2), tile)
	tracker.register_boundary_tile(Vector3i(2, 2, 2), tile)
	
	assert_equal(tracker.get_region_count(), 1, "Vertically stacked tiles should form 1 region", test_name)
	assert_true(tracker.are_in_same_region(Vector3i(2, 0, 2), Vector3i(2, 2, 2)), 
		"Bottom and top tile should be in same region", test_name)


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
	print("\n--- WfcRegionTracker Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
