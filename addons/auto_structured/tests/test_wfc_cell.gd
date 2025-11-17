extends RefCounted

const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing WfcCell ===")
	
	test_cell_initialization()
	test_cell_collapse()
	test_cell_entropy_calculation()
	test_cell_entropy_caching()
	test_cell_constraint()
	test_cell_contradiction_detection()
	test_cell_variant_comparison()
	
	print_summary()

func test_cell_initialization() -> void:
	var test_name = "Cell initialization"
	
	# Create test variants
	var tile1 = Tile.new()
	tile1.name = "TestTile1"
	var tile2 = Tile.new()
	tile2.name = "TestTile2"
	
	var variants: Array[Dictionary] = [
		{"tile": tile1, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 90, "weight": 1.0},
		{"tile": tile2, "rotation_degrees": 0, "weight": 1.0}
	]
	
	var position = Vector3i(5, 3, 7)
	var cell = WfcCell.new(position, variants)
	
	# Test position assignment
	assert_true(cell.position == position, "Cell position should match initialization", test_name)
	
	# Test variants assignment
	assert_equal(cell.possible_tile_variants.size(), 3, "Cell should have 3 possible variants", test_name)
	
	# Test not collapsed initially
	assert_false(cell.is_collapsed(), "Cell should not be collapsed initially", test_name)
	
	# Test has no contradiction initially
	assert_false(cell.has_contradiction(), "Cell should not have contradiction initially", test_name)

func test_cell_collapse() -> void:
	var test_name = "Cell collapse"
	
	# Create test variants
	var tile1 = Tile.new()
	tile1.name = "TestTile1"
	
	var variants: Array[Dictionary] = [
		{"tile": tile1, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 90, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 180, "weight": 1.0}
	]
	
	var cell = WfcCell.new(Vector3i.ZERO, variants)
	
	# Collapse the cell
	var result = cell.collapse()
	assert_true(result, "Collapse should succeed", test_name)
	
	# Check it's now collapsed
	assert_true(cell.is_collapsed(), "Cell should be collapsed after collapse()", test_name)
	
	# Check only one variant remains
	assert_equal(cell.possible_tile_variants.size(), 1, "Cell should have exactly 1 variant after collapse", test_name)
	
	# Test collapse on already collapsed cell
	var result2 = cell.collapse()
	assert_true(result2, "Collapsing already collapsed cell should succeed", test_name)
	assert_equal(cell.possible_tile_variants.size(), 1, "Collapsed cell should still have 1 variant", test_name)
	
	# Test collapse on empty cell
	var empty_cell = WfcCell.new(Vector3i.ZERO, [])
	var empty_result = empty_cell.collapse()
	assert_false(empty_result, "Collapse should fail on empty cell", test_name)

func test_cell_entropy_calculation() -> void:
	var test_name = "Cell entropy calculation"
	
	var tile = Tile.new()
	tile.name = "TestTile"
	
	# Test with single variant (collapsed)
	var single_variants: Array[Dictionary] = [
		{"tile": tile, "rotation_degrees": 0, "weight": 1.0}
	]
	var single_cell = WfcCell.new(Vector3i.ZERO, single_variants)
	var single_entropy = single_cell.get_entropy()
	assert_true(single_entropy < 0, "Collapsed cell should have negative entropy", test_name)
	
	# Test with multiple variants
	var multi_variants: Array[Dictionary] = [
		{"tile": tile, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 90, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 180, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 270, "weight": 1.0}
	]
	var multi_cell = WfcCell.new(Vector3i.ZERO, multi_variants)
	var multi_entropy = multi_cell.get_entropy()
	assert_true(multi_entropy > 0, "Multi-variant cell should have positive entropy", test_name)
	
	# Test with empty variants
	var empty_cell = WfcCell.new(Vector3i.ZERO, [])
	var empty_entropy = empty_cell.get_entropy()
	assert_equal(empty_entropy, 0.0, "Empty cell should have zero entropy", test_name)
	
	# Test entropy decreases as options decrease
	var variants: Array[Dictionary] = [
		{"tile": tile, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 90, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 180, "weight": 1.0}
	]
	var cell1 = WfcCell.new(Vector3i.ZERO, variants)
	var entropy1 = cell1.get_entropy()
	
	variants.resize(2)
	var cell2 = WfcCell.new(Vector3i.ZERO, variants)
	var entropy2 = cell2.get_entropy()
	
	assert_true(entropy2 < entropy1, "Entropy should decrease with fewer options", test_name)

func test_cell_entropy_caching() -> void:
	var test_name = "Cell entropy caching"
	
	var tile = Tile.new()
	tile.name = "TestTile"
	
	var variants: Array[Dictionary] = [
		{"tile": tile, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile, "rotation_degrees": 90, "weight": 1.0}
	]
	
	var cell = WfcCell.new(Vector3i.ZERO, variants)
	
	# Calculate entropy first time
	var entropy1 = cell.get_entropy()
	
	# Calculate again - should use cache
	var entropy2 = cell.get_entropy()
	
	# Due to noise, values won't be exactly equal, but should be very close
	assert_true(abs(entropy1 - entropy2) < 0.001, "Cached entropy should be nearly identical", test_name)
	
	# Constrain cell - should invalidate cache
	var new_variants: Array[Dictionary] = [variants[0]]
	cell.constrain(new_variants)
	
	var entropy3 = cell.get_entropy()
	assert_true(abs(entropy3 - entropy1) > 0.1, "Entropy should change after constraint", test_name)

func test_cell_constraint() -> void:
	var test_name = "Cell constraint"
	
	var tile1 = Tile.new()
	tile1.name = "Tile1"
	var tile2 = Tile.new()
	tile2.name = "Tile2"
	
	var all_variants: Array[Dictionary] = [
		{"tile": tile1, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 90, "weight": 1.0},
		{"tile": tile2, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile2, "rotation_degrees": 180, "weight": 1.0}
	]
	
	var cell = WfcCell.new(Vector3i.ZERO, all_variants)
	assert_equal(cell.possible_tile_variants.size(), 4, "Cell should start with 4 variants", test_name)
	
	# Constrain to only tile1
	var valid_variants: Array[Dictionary] = [
		{"tile": tile1, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 90, "weight": 1.0}
	]
	
	var changed = cell.constrain(valid_variants)
	assert_true(changed, "Constraint should return true when cell changed", test_name)
	assert_equal(cell.possible_tile_variants.size(), 2, "Cell should have 2 variants after constraint", test_name)
	
	# Constrain again with same variants
	var changed2 = cell.constrain(valid_variants)
	assert_false(changed2, "Constraint should return false when nothing changes", test_name)
	
	# Test constraining collapsed cell
	cell.collapse()
	var changed3 = cell.constrain(valid_variants)
	assert_false(changed3, "Constraining collapsed cell should return false", test_name)

func test_cell_contradiction_detection() -> void:
	var test_name = "Cell contradiction detection"
	
	var tile = Tile.new()
	tile.name = "TestTile"
	
	var variants: Array[Dictionary] = [
		{"tile": tile, "rotation_degrees": 0, "weight": 1.0}
	]
	
	var cell = WfcCell.new(Vector3i.ZERO, variants)
	assert_false(cell.has_contradiction(), "Cell with variants should not have contradiction", test_name)
	
	# Remove all variants by directly clearing the array
	cell.possible_tile_variants.clear()
	var has_contradiction = cell.has_contradiction()
	var variant_count = cell.possible_tile_variants.size()
	var msg = "Cell with no variants should have contradiction (has_contradiction=" + str(has_contradiction) + ", variant_count=" + str(variant_count) + ")"
	assert_true(has_contradiction, msg, test_name)

func test_cell_variant_comparison() -> void:
	var test_name = "Cell variant comparison"
	
	var tile1 = Tile.new()
	tile1.name = "Tile1"
	var tile2 = Tile.new()
	tile2.name = "Tile2"
	
	var variant1 = {"tile": tile1, "rotation_degrees": 0, "weight": 1.0}
	var variant2 = {"tile": tile1, "rotation_degrees": 0, "weight": 2.0}  # Different weight
	var variant3 = {"tile": tile1, "rotation_degrees": 90, "weight": 1.0}  # Different rotation
	var variant4 = {"tile": tile2, "rotation_degrees": 0, "weight": 1.0}  # Different tile
	
	var list1: Array[Dictionary] = [variant1, variant3]
	var list2: Array[Dictionary] = [variant2]  # Same tile and rotation as variant1
	var list3: Array[Dictionary] = [variant4]
	
	var cell = WfcCell.new(Vector3i.ZERO, list1)
	
	# Test that variant comparison works (should match by tile and rotation)
	assert_true(cell.is_variant_in_list(variant1, list1), "Variant should be found in list", test_name)
	assert_true(cell.is_variant_in_list(variant1, list2), "Variant should match by tile+rotation even with different weight", test_name)
	assert_false(cell.is_variant_in_list(variant1, list3), "Variant should not match different tile", test_name)

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

func print_summary() -> void:
	print("\n--- WfcCell Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
