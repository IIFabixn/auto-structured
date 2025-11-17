extends RefCounted

const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing WfcHelper ===")
	
	test_rotation_y_to_basis()
	test_cardinal_directions()
	test_direction_index()
	test_direction_names()
	test_opposite_direction()
	test_rotate_direction()
	test_world_grid_conversion()
	test_cardinal_rotations()
	test_socket_alignment()
	test_rotated_bounds()
	test_can_sockets_connect()
	
	print_summary()

func test_rotation_y_to_basis() -> void:
	var test_name = "Rotation Y to Basis"
	
	# Test identity rotation (0 degrees)
	var basis_0 = WfcHelper.rotation_y_to_basis(0)
	assert_true(basis_0.is_equal_approx(Basis.IDENTITY), "0 degree rotation should be identity", test_name)
	
	# Test 90 degree rotation
	var basis_90 = WfcHelper.rotation_y_to_basis(90)
	var forward = Vector3.FORWARD
	var rotated_90 = basis_90 * forward
	assert_true(rotated_90.is_equal_approx(Vector3.LEFT), "90 degree rotation should rotate forward to left", test_name)
	
	# Test 180 degree rotation
	var basis_180 = WfcHelper.rotation_y_to_basis(180)
	var rotated_180 = basis_180 * forward
	assert_true(rotated_180.is_equal_approx(Vector3.BACK), "180 degree rotation should rotate forward to back", test_name)
	
	# Test 270 degree rotation
	var basis_270 = WfcHelper.rotation_y_to_basis(270)
	var rotated_270 = basis_270 * forward
	assert_true(rotated_270.is_equal_approx(Vector3.RIGHT), "270 degree rotation should rotate forward to right", test_name)

func test_cardinal_directions() -> void:
	var test_name = "Cardinal directions"
	
	var directions = WfcHelper.get_cardinal_directions()
	
	# Test count
	assert_equal(directions.size(), 6, "Should have 6 cardinal directions", test_name)
	
	# Test each direction exists
	assert_true(Vector3i.RIGHT in directions, "Should include RIGHT direction", test_name)
	assert_true(Vector3i.LEFT in directions, "Should include LEFT direction", test_name)
	assert_true(Vector3i.UP in directions, "Should include UP direction", test_name)
	assert_true(Vector3i.DOWN in directions, "Should include DOWN direction", test_name)
	assert_true(Vector3i.FORWARD in directions, "Should include FORWARD direction", test_name)
	assert_true(Vector3i.BACK in directions, "Should include BACK direction", test_name)

func test_direction_index() -> void:
	var test_name = "Direction index"
	
	# Test each direction has unique index
	assert_equal(WfcHelper.get_direction_index(Vector3i.RIGHT), 0, "RIGHT should be index 0", test_name)
	assert_equal(WfcHelper.get_direction_index(Vector3i.LEFT), 1, "LEFT should be index 1", test_name)
	assert_equal(WfcHelper.get_direction_index(Vector3i.UP), 2, "UP should be index 2", test_name)
	assert_equal(WfcHelper.get_direction_index(Vector3i.DOWN), 3, "DOWN should be index 3", test_name)
	assert_equal(WfcHelper.get_direction_index(Vector3i.BACK), 4, "BACK should be index 4", test_name)
	assert_equal(WfcHelper.get_direction_index(Vector3i.FORWARD), 5, "FORWARD should be index 5", test_name)
	
	# Test invalid direction
	var invalid_index = WfcHelper.get_direction_index(Vector3i(2, 0, 0))
	assert_equal(invalid_index, -1, "Invalid direction should return -1", test_name)

func test_direction_names() -> void:
	var test_name = "Direction names"
	
	# Test each direction has a name
	assert_true(WfcHelper.get_direction_name(Vector3i.RIGHT).length() > 0, "RIGHT should have name", test_name)
	assert_true(WfcHelper.get_direction_name(Vector3i.LEFT).length() > 0, "LEFT should have name", test_name)
	assert_true(WfcHelper.get_direction_name(Vector3i.UP).length() > 0, "UP should have name", test_name)
	assert_true(WfcHelper.get_direction_name(Vector3i.DOWN).length() > 0, "DOWN should have name", test_name)
	assert_true(WfcHelper.get_direction_name(Vector3i.FORWARD).length() > 0, "FORWARD should have name", test_name)
	assert_true(WfcHelper.get_direction_name(Vector3i.BACK).length() > 0, "BACK should have name", test_name)

func test_opposite_direction() -> void:
	var test_name = "Opposite direction"
	
	# Test each direction has correct opposite
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.RIGHT), Vector3i.LEFT, "Opposite of RIGHT is LEFT", test_name)
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.LEFT), Vector3i.RIGHT, "Opposite of LEFT is RIGHT", test_name)
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.UP), Vector3i.DOWN, "Opposite of UP is DOWN", test_name)
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.DOWN), Vector3i.UP, "Opposite of DOWN is UP", test_name)
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.FORWARD), Vector3i.BACK, "Opposite of FORWARD is BACK", test_name)
	assert_equal(WfcHelper.get_opposite_direction(Vector3i.BACK), Vector3i.FORWARD, "Opposite of BACK is FORWARD", test_name)

func test_rotate_direction() -> void:
	var test_name = "Rotate direction"
	
	# Test rotation of RIGHT direction by 90 degrees
	var rotation_90 = WfcHelper.rotation_y_to_basis(90)
	var rotated = WfcHelper.rotate_direction(Vector3i.RIGHT, rotation_90)
	assert_equal(rotated, Vector3i.FORWARD, "RIGHT rotated 90° should become FORWARD", test_name)
	
	# Test rotation of FORWARD direction by 90 degrees
	var rotated_forward = WfcHelper.rotate_direction(Vector3i.FORWARD, rotation_90)
	assert_equal(rotated_forward, Vector3i.LEFT, "FORWARD rotated 90° should become LEFT", test_name)
	
	# Test that UP/DOWN don't change with Y rotation
	var rotated_up = WfcHelper.rotate_direction(Vector3i.UP, rotation_90)
	assert_equal(rotated_up, Vector3i.UP, "UP should not change with Y rotation", test_name)

func test_world_grid_conversion() -> void:
	var test_name = "World grid conversion"
	
	# Test grid to world
	var grid_pos = Vector3i(2, 3, 1)
	var world_pos = WfcHelper.grid_to_world(grid_pos, Vector3.ONE)
	assert_equal(world_pos, Vector3(2, 3, 1), "Grid to world with unit cell size", test_name)
	
	# Test with different cell size
	var world_pos_scaled = WfcHelper.grid_to_world(grid_pos, Vector3(2, 3, 2))
	assert_equal(world_pos_scaled, Vector3(4, 9, 2), "Grid to world with scaled cell size", test_name)
	
	# Test world to grid
	var back_to_grid = WfcHelper.world_to_grid(world_pos, Vector3.ONE)
	assert_equal(back_to_grid, grid_pos, "World to grid should reverse conversion", test_name)
	
	# Test origin
	var origin_world = WfcHelper.grid_to_world(Vector3i.ZERO, Vector3.ONE)
	assert_equal(origin_world, Vector3.ZERO, "Grid origin should be world origin", test_name)

func test_cardinal_rotations() -> void:
	var test_name = "Cardinal rotations"
	
	var rotations = WfcHelper.get_cardinal_rotations()
	
	# Test count
	assert_equal(rotations.size(), 4, "Should have 4 cardinal rotations", test_name)
	
	# Test first is identity
	assert_true(rotations[0].is_equal_approx(Basis.IDENTITY), "First rotation should be identity", test_name)
	
	# Test rotations are different
	var all_different = true
	for i in range(rotations.size()):
		for j in range(i + 1, rotations.size()):
			if rotations[i].is_equal_approx(rotations[j]):
				all_different = false
				break
	assert_true(all_different, "All rotations should be different", test_name)

func test_socket_alignment() -> void:
	var test_name = "Socket alignment"
	
	# Create a socket facing right
	var socket = Socket.new()
	socket.direction = Vector3i.RIGHT
	
	# Test alignment with same direction
	var can_align_right = WfcHelper.can_socket_align_with_rotation(socket, Vector3.RIGHT)
	assert_true(can_align_right, "Horizontal socket should align with horizontal direction", test_name)
	
	# Test alignment with opposite direction (can be rotated 180°)
	var can_align_left = WfcHelper.can_socket_align_with_rotation(socket, Vector3.LEFT)
	assert_true(can_align_left, "Horizontal socket should be rotatable to opposite direction", test_name)
	
	# Test alignment with perpendicular direction (can be rotated 90°)
	var can_align_forward = WfcHelper.can_socket_align_with_rotation(socket, Vector3.FORWARD)
	assert_true(can_align_forward, "Horizontal socket should be rotatable to perpendicular direction", test_name)
	
	# Test vertical socket can't align to horizontal
	var vertical_socket = Socket.new()
	vertical_socket.direction = Vector3i.UP
	var can_align_vertical = WfcHelper.can_socket_align_with_rotation(vertical_socket, Vector3.RIGHT)
	assert_false(can_align_vertical, "Vertical socket should not align with horizontal direction", test_name)

func test_rotated_bounds() -> void:
	var test_name = "Rotated bounds"
	
	# Test 1x1x1 tile (should stay same size with all rotations)
	var size_1x1x1 = Vector3i(1, 1, 1)
	var bounds_0 = WfcHelper.get_rotated_bounds_in_cells(size_1x1x1, 0)
	assert_not_null(bounds_0, "Should get bounds for 1x1x1 tile", test_name)
	assert_true(bounds_0.has("min") and bounds_0.has("max"), "Bounds should have min and max", test_name)
	
	# Test asymmetric tile (3x2x1)
	var size_3x2x1 = Vector3i(3, 2, 1)
	var rotated_size_0 = WfcHelper.get_rotated_size_in_cells(size_3x2x1, 0)
	assert_equal(rotated_size_0, Vector3(3, 2, 1), "Unrotated asymmetric tile should keep size", test_name)
	
	# Test 90 degree rotation swaps X and Z
	var rotated_size_90 = WfcHelper.get_rotated_size_in_cells(size_3x2x1, 90)
	assert_true(rotated_size_90.x > 0 and rotated_size_90.z > 0, "Rotated tile should have positive dimensions", test_name)

func test_can_sockets_connect() -> void:
	var test_name = "Can sockets connect"
	
	# Create compatible socket types
	var type_a = SocketType.new()
	type_a.type_id = "a"
	type_a.set_compatible_types(["b"])
	
	var type_b = SocketType.new()
	type_b.type_id = "b"
	type_b.set_compatible_types(["a"])
	
	# Create sockets
	var socket_a = Socket.new()
	socket_a.socket_type = type_a
	socket_a.direction = Vector3i.RIGHT
	
	var socket_b = Socket.new()
	socket_b.socket_type = type_b
	socket_b.direction = Vector3i.LEFT
	
	var tile1 = Tile.new()
	var tile2 = Tile.new()
	
	# Test compatible sockets
	var can_connect = WfcHelper.can_sockets_connect(socket_a, socket_b, tile1, tile2)
	assert_true(can_connect, "Compatible sockets should be able to connect", test_name)
	
	# Create incompatible socket
	var type_c = SocketType.new()
	type_c.type_id = "c"
	type_c.set_compatible_types([])
	
	var socket_c = Socket.new()
	socket_c.socket_type = type_c
	socket_c.direction = Vector3i.RIGHT
	
	# Test incompatible sockets
	var cannot_connect = WfcHelper.can_sockets_connect(socket_a, socket_c, tile1, tile2)
	assert_false(cannot_connect, "Incompatible sockets should not be able to connect", test_name)

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
	print("\n--- WfcHelper Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
