extends RefCounted

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Socket ===")
	
	test_socket_initialization()
	test_socket_direction_validation()
	test_socket_compatibility()
	test_socket_id_accessors()
	test_socket_compatible_list_accessors()
	test_socket_add_remove_compatible()
	
	print_summary()

func test_socket_initialization() -> void:
	var test_name = "Socket initialization"
	
	var socket = Socket.new()
	assert_not_null(socket, "Socket should be created", test_name)
	assert_equal(socket.direction, Vector3i.UP, "Socket should have default UP direction", test_name)
	assert_null(socket.socket_type, "Socket should have null socket_type initially", test_name)

func test_socket_direction_validation() -> void:
	var test_name = "Socket direction validation"
	
	var socket = Socket.new()
	
	# Test valid cardinal directions
	socket.direction = Vector3i.RIGHT
	assert_equal(socket.direction, Vector3i.RIGHT, "Should accept RIGHT direction", test_name)
	
	socket.direction = Vector3i.LEFT
	assert_equal(socket.direction, Vector3i.LEFT, "Should accept LEFT direction", test_name)
	
	socket.direction = Vector3i.UP
	assert_equal(socket.direction, Vector3i.UP, "Should accept UP direction", test_name)
	
	socket.direction = Vector3i.DOWN
	assert_equal(socket.direction, Vector3i.DOWN, "Should accept DOWN direction", test_name)
	
	socket.direction = Vector3i.FORWARD
	assert_equal(socket.direction, Vector3i.FORWARD, "Should accept FORWARD direction", test_name)
	
	socket.direction = Vector3i.BACK
	assert_equal(socket.direction, Vector3i.BACK, "Should accept BACK direction", test_name)
	
	# Test invalid direction (reverts to UP default)
	socket.direction = Vector3i.RIGHT
	socket.direction = Vector3i(2, 0, 0)
	assert_equal(socket.direction, Vector3i.UP, "Should reject invalid direction and revert to UP", test_name)
	
	# Test is_valid_direction static method
	assert_true(Socket.is_valid_direction(Vector3i.RIGHT), "RIGHT should be valid", test_name)
	assert_true(Socket.is_valid_direction(Vector3i.LEFT), "LEFT should be valid", test_name)
	assert_true(Socket.is_valid_direction(Vector3i.UP), "UP should be valid", test_name)
	assert_true(Socket.is_valid_direction(Vector3i.DOWN), "DOWN should be valid", test_name)
	assert_true(Socket.is_valid_direction(Vector3i.FORWARD), "FORWARD should be valid", test_name)
	assert_true(Socket.is_valid_direction(Vector3i.BACK), "BACK should be valid", test_name)
	assert_false(Socket.is_valid_direction(Vector3i(1, 1, 0)), "Diagonal should be invalid", test_name)

func test_socket_compatibility() -> void:
	var test_name = "Socket compatibility"
	
	# Create compatible socket types
	var type_a = SocketType.new()
	type_a.type_id = "type_a"
	type_a.set_compatible_types(["type_b"])
	
	var type_b = SocketType.new()
	type_b.type_id = "type_b"
	type_b.set_compatible_types(["type_a"])
	
	var type_c = SocketType.new()
	type_c.type_id = "type_c"
	type_c.set_compatible_types([])
	
	# Create sockets
	var socket_a = Socket.new()
	socket_a.socket_type = type_a
	
	var socket_b = Socket.new()
	socket_b.socket_type = type_b
	
	var socket_c = Socket.new()
	socket_c.socket_type = type_c
	
	# Test compatibility
	assert_true(socket_a.is_compatible_with(socket_b), "Socket A should be compatible with Socket B", test_name)
	assert_true(socket_b.is_compatible_with(socket_a), "Socket B should be compatible with Socket A", test_name)
	assert_false(socket_a.is_compatible_with(socket_c), "Socket A should not be compatible with Socket C", test_name)
	assert_false(socket_c.is_compatible_with(socket_a), "Socket C should not be compatible with Socket A", test_name)
	
	# Test with null socket_type
	var socket_null = Socket.new()
	assert_false(socket_null.is_compatible_with(socket_a), "Null socket_type should not be compatible", test_name)
	assert_false(socket_a.is_compatible_with(socket_null), "Socket should not be compatible with null", test_name)

func test_socket_id_accessors() -> void:
	var test_name = "Socket ID accessors"
	
	var socket = Socket.new()
	
	# Test getting empty socket_id
	assert_equal(socket.socket_id, "", "Empty socket should have empty socket_id", test_name)
	
	# Test setting socket_id creates SocketType
	socket.socket_id = "wall"
	assert_not_null(socket.socket_type, "Setting socket_id should create SocketType", test_name)
	assert_equal(socket.socket_type.type_id, "wall", "SocketType should have correct type_id", test_name)
	assert_equal(socket.socket_id, "wall", "socket_id getter should return correct value", test_name)
	
	# Test setting empty socket_id clears SocketType
	socket.socket_id = ""
	assert_null(socket.socket_type, "Setting empty socket_id should clear SocketType", test_name)
	
	# Test setting socket_id with whitespace
	socket.socket_id = "  trimmed  "
	assert_equal(socket.socket_type.type_id, "trimmed", "socket_id should be trimmed", test_name)

func test_socket_compatible_list_accessors() -> void:
	var test_name = "Socket compatible list accessors"
	
	var socket = Socket.new()
	socket.socket_id = "test"
	
	# Test getting empty list
	var compat_list = socket.compatible_sockets
	assert_equal(compat_list.size(), 0, "New socket should have no compatible sockets", test_name)
	
	# Test adding compatible types and reading them back
	socket.add_compatible_socket("type_a")
	socket.add_compatible_socket("type_b")
	socket.add_compatible_socket("type_c")
	var compat_list2 = socket.compatible_sockets
	assert_equal(compat_list2.size(), 3, "Should have 3 compatible types after adding", test_name)
	assert_true("type_a" in compat_list2, "Should contain type_a", test_name)
	assert_true("type_b" in compat_list2, "Should contain type_b", test_name)
	assert_true("type_c" in compat_list2, "Should contain type_c", test_name)

func test_socket_add_remove_compatible() -> void:
	var test_name = "Socket add/remove compatible"
	
	var socket = Socket.new()
	socket.socket_id = "test"
	
	# Test adding compatible types
	socket.add_compatible_socket("type_a")
	var compat1 = socket.compatible_sockets
	assert_equal(compat1.size(), 1, "Should have 1 compatible type after add", test_name)
	assert_true("type_a" in compat1, "Should contain type_a", test_name)
	
	socket.add_compatible_socket("type_b")
	var compat2 = socket.compatible_sockets
	assert_equal(compat2.size(), 2, "Should have 2 compatible types", test_name)
	
	# Test adding duplicate (should not increase count)
	socket.add_compatible_socket("type_a")
	var compat3 = socket.compatible_sockets
	assert_equal(compat3.size(), 2, "Should still have 2 compatible types (no duplicates)", test_name)
	
	# Test removing compatible type
	socket.remove_compatible_socket("type_a")
	var compat4 = socket.compatible_sockets
	assert_equal(compat4.size(), 1, "Should have 1 compatible type after remove", test_name)
	assert_false("type_a" in compat4, "Should not contain type_a after removal", test_name)
	assert_true("type_b" in compat4, "Should still contain type_b", test_name)
	
	# Test removing non-existent type (should not crash)
	socket.remove_compatible_socket("type_xyz")
	var compat5 = socket.compatible_sockets
	assert_equal(compat5.size(), 1, "Should still have 1 compatible type", test_name)

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
	print("\n--- Socket Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
