extends RefCounted

const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing SocketType ===")
	
	test_socket_type_initialization()
	test_socket_type_display_name()
	test_socket_type_compatibility_check()
	test_socket_type_add_compatible()
	test_socket_type_remove_compatible()
	test_socket_type_set_compatible_types()
	test_socket_type_edge_cases()
	
	print_summary()

func test_socket_type_initialization() -> void:
	var test_name = "SocketType initialization"
	
	var socket_type = SocketType.new()
	assert_not_null(socket_type, "SocketType should be created", test_name)
	assert_equal(socket_type.type_id, "", "type_id should be empty by default", test_name)
	assert_equal(socket_type.display_name, "", "display_name should be empty by default", test_name)
	assert_equal(socket_type.compatible_types.size(), 0, "compatible_types should be empty array", test_name)
	
	# Test initialization with values
	var socket_type2 = SocketType.new()
	socket_type2.type_id = "wall"
	socket_type2.display_name = "Wall Socket"
	assert_equal(socket_type2.type_id, "wall", "type_id should be set", test_name)
	assert_equal(socket_type2.display_name, "Wall Socket", "display_name should be set", test_name)

func test_socket_type_display_name() -> void:
	var test_name = "SocketType display name"
	
	var socket_type = SocketType.new()
	socket_type.type_id = "wall_socket"
	
	# Test get_display_name falls back to type_id when display_name is empty
	var display = socket_type.get_display_name()
	assert_equal(display, "wall_socket", "get_display_name should return type_id when display_name is empty", test_name)
	
	# Test get_display_name returns display_name when set
	socket_type.display_name = "Wall Socket"
	var display2 = socket_type.get_display_name()
	assert_equal(display2, "Wall Socket", "get_display_name should return display_name when set", test_name)
	
	# Test get_display_name trims whitespace
	socket_type.display_name = "  Trimmed  "
	var display3 = socket_type.get_display_name()
	assert_equal(display3, "Trimmed", "get_display_name should trim whitespace", test_name)
	
	# Test get_display_name falls back when display_name is only whitespace
	socket_type.display_name = "   "
	var display4 = socket_type.get_display_name()
	assert_equal(display4, "wall_socket", "get_display_name should fall back to type_id for whitespace-only display_name", test_name)

func test_socket_type_compatibility_check() -> void:
	var test_name = "SocketType compatibility check"
	
	var type_a = SocketType.new()
	type_a.type_id = "type_a"
	type_a.set_compatible_types(["type_b", "type_c"])
	
	var type_b = SocketType.new()
	type_b.type_id = "type_b"
	
	var type_c = SocketType.new()
	type_c.type_id = "type_c"
	
	var type_d = SocketType.new()
	type_d.type_id = "type_d"
	
	# Test compatibility
	assert_true(type_a.is_compatible_with(type_b), "type_a should be compatible with type_b", test_name)
	assert_true(type_a.is_compatible_with(type_c), "type_a should be compatible with type_c", test_name)
	assert_false(type_a.is_compatible_with(type_d), "type_a should not be compatible with type_d", test_name)
	
	# Test with null
	assert_false(type_a.is_compatible_with(null), "Should not be compatible with null", test_name)

func test_socket_type_add_compatible() -> void:
	var test_name = "SocketType add compatible"
	
	var socket_type = SocketType.new()
	socket_type.type_id = "test"
	
	# Test adding single compatible type
	socket_type.add_compatible_type("type_a")
	assert_equal(socket_type.compatible_types.size(), 1, "Should have 1 compatible type", test_name)
	assert_true("type_a" in socket_type.compatible_types, "Should contain type_a", test_name)
	
	# Test adding another compatible type
	socket_type.add_compatible_type("type_b")
	assert_equal(socket_type.compatible_types.size(), 2, "Should have 2 compatible types", test_name)
	assert_true("type_b" in socket_type.compatible_types, "Should contain type_b", test_name)
	
	# Test adding duplicate (should not add)
	socket_type.add_compatible_type("type_a")
	assert_equal(socket_type.compatible_types.size(), 2, "Should still have 2 compatible types (no duplicates)", test_name)
	
	# Test adding empty string (should not add)
	socket_type.add_compatible_type("")
	assert_equal(socket_type.compatible_types.size(), 2, "Should still have 2 compatible types (empty rejected)", test_name)
	
	# Test adding whitespace (should trim and add)
	socket_type.add_compatible_type("  type_c  ")
	assert_equal(socket_type.compatible_types.size(), 3, "Should have 3 compatible types", test_name)
	assert_true("type_c" in socket_type.compatible_types, "Should contain trimmed type_c", test_name)
	
	# Test array is sorted
	var types = socket_type.compatible_types
	for i in range(types.size() - 1):
		assert_true(types[i] <= types[i + 1], "Compatible types should be sorted", test_name)

func test_socket_type_remove_compatible() -> void:
	var test_name = "SocketType remove compatible"
	
	var socket_type = SocketType.new()
	socket_type.type_id = "test"
	socket_type.set_compatible_types(["type_a", "type_b", "type_c"])
	
	# Test removing existing type
	socket_type.remove_compatible_type("type_b")
	assert_equal(socket_type.compatible_types.size(), 2, "Should have 2 compatible types after removal", test_name)
	assert_false("type_b" in socket_type.compatible_types, "Should not contain type_b", test_name)
	assert_true("type_a" in socket_type.compatible_types, "Should still contain type_a", test_name)
	assert_true("type_c" in socket_type.compatible_types, "Should still contain type_c", test_name)
	
	# Test removing non-existent type (should not crash or change array)
	socket_type.remove_compatible_type("type_xyz")
	assert_equal(socket_type.compatible_types.size(), 2, "Should still have 2 compatible types", test_name)
	
	# Test removing with whitespace
	socket_type.remove_compatible_type("  type_a  ")
	assert_equal(socket_type.compatible_types.size(), 1, "Should have 1 compatible type after trimmed removal", test_name)
	assert_false("type_a" in socket_type.compatible_types, "Should not contain type_a", test_name)

func test_socket_type_set_compatible_types() -> void:
	var test_name = "SocketType set compatible types"
	
	var socket_type = SocketType.new()
	socket_type.type_id = "test"
	
	# Test setting array of types
	socket_type.set_compatible_types(["type_a", "type_b", "type_c"])
	assert_equal(socket_type.compatible_types.size(), 3, "Should have 3 compatible types", test_name)
	assert_true("type_a" in socket_type.compatible_types, "Should contain type_a", test_name)
	assert_true("type_b" in socket_type.compatible_types, "Should contain type_b", test_name)
	assert_true("type_c" in socket_type.compatible_types, "Should contain type_c", test_name)
	
	# Test setting replaces existing
	socket_type.set_compatible_types(["type_x", "type_y"])
	assert_equal(socket_type.compatible_types.size(), 2, "Should have 2 compatible types after set", test_name)
	assert_false("type_a" in socket_type.compatible_types, "Should not contain old type_a", test_name)
	assert_true("type_x" in socket_type.compatible_types, "Should contain new type_x", test_name)
	
	# Test setting with duplicates
	socket_type.set_compatible_types(["dup", "dup", "unique"])
	assert_equal(socket_type.compatible_types.size(), 2, "Should have 2 unique types", test_name)
	
	# Test setting with empty strings
	socket_type.set_compatible_types(["valid", "", "  ", "another"])
	assert_equal(socket_type.compatible_types.size(), 2, "Should have 2 non-empty types", test_name)
	assert_true("valid" in socket_type.compatible_types, "Should contain valid", test_name)
	assert_true("another" in socket_type.compatible_types, "Should contain another", test_name)
	
	# Test setting with whitespace (should trim)
	socket_type.set_compatible_types(["  trim_me  ", "normal"])
	assert_true("trim_me" in socket_type.compatible_types, "Should contain trimmed value", test_name)
	assert_false("  trim_me  " in socket_type.compatible_types, "Should not contain untrimmed value", test_name)
	
	# Test array is sorted
	socket_type.set_compatible_types(["zebra", "apple", "banana"])
	var types = socket_type.compatible_types
	assert_equal(types[0], "apple", "First should be apple (sorted)", test_name)
	assert_equal(types[1], "banana", "Second should be banana (sorted)", test_name)
	assert_equal(types[2], "zebra", "Third should be zebra (sorted)", test_name)

func test_socket_type_edge_cases() -> void:
	var test_name = "SocketType edge cases"
	
	# Test self-compatibility
	var self_type = SocketType.new()
	self_type.type_id = "self"
	self_type.set_compatible_types(["self"])
	
	assert_true(self_type.is_compatible_with(self_type), "Should be compatible with itself if in compatible_types", test_name)
	
	# Test that types must match exactly
	var type1 = SocketType.new()
	type1.type_id = "exact"
	type1.set_compatible_types(["match"])
	
	var type2 = SocketType.new()
	type2.type_id = "different"
	
	assert_false(type1.is_compatible_with(type2), "Non-matching types should not be compatible", test_name)

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
	print("\n--- SocketType Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
