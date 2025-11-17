extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Tile Rotation System ===")
	
	# Symmetry mode tests
	test_rotation_symmetry_full()
	test_rotation_symmetry_half()
	test_rotation_symmetry_quarter()
	test_rotation_symmetry_custom()
	test_rotation_symmetry_custom_invalid()
	
	# Auto-detection tests
	test_auto_detect_full_asymmetry()
	test_auto_detect_quarter_symmetry()
	test_auto_detect_half_symmetry()
	test_auto_detect_no_sockets()
	
	print_summary()

## ============================================================================
## SYMMETRY MODE TESTS
## ============================================================================

func test_rotation_symmetry_full() -> void:
	var test_name = "RotationSymmetry FULL mode"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.FULL
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 4, "FULL mode should return 4 rotations", test_name)
	assert_true(0 in rotations, "Should include 0°", test_name)
	assert_true(90 in rotations, "Should include 90°", test_name)
	assert_true(180 in rotations, "Should include 180°", test_name)
	assert_true(270 in rotations, "Should include 270°", test_name)

func test_rotation_symmetry_half() -> void:
	var test_name = "RotationSymmetry HALF mode"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.HALF
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 2, "HALF mode should return 2 rotations", test_name)
	assert_true(0 in rotations, "Should include 0°", test_name)
	assert_true(90 in rotations, "Should include 90°", test_name)

func test_rotation_symmetry_quarter() -> void:
	var test_name = "RotationSymmetry QUARTER mode"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.QUARTER
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 1, "QUARTER mode should return 1 rotation", test_name)
	assert_equal(rotations[0], 0, "Should only include 0°", test_name)

func test_rotation_symmetry_custom() -> void:
	var test_name = "RotationSymmetry CUSTOM mode"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.CUSTOM
	tile.custom_rotations.assign([0, 90, 180])
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 3, "CUSTOM mode should return custom rotations", test_name)
	assert_true(0 in rotations, "Should include 0°", test_name)
	assert_true(90 in rotations, "Should include 90°", test_name)
	assert_true(180 in rotations, "Should include 180°", test_name)
	assert_false(270 in rotations, "Should not include 270°", test_name)

func test_rotation_symmetry_custom_invalid() -> void:
	var test_name = "RotationSymmetry CUSTOM with empty array"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.CUSTOM
	tile.custom_rotations.clear()
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 1, "Empty custom rotations should fallback to [0]", test_name)
	assert_equal(rotations[0], 0, "Fallback should be 0°", test_name)

## ============================================================================
## AUTO-DETECTION TESTS
## ============================================================================

func test_auto_detect_full_asymmetry() -> void:
	var test_name = "Auto-detect full asymmetry (L-shape)"
	var tile = _create_l_shaped_tile()
	tile.rotation_symmetry = Tile.RotationSymmetry.AUTO
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 4, "L-shaped tile should have 4 unique rotations", test_name)

func test_auto_detect_quarter_symmetry() -> void:
	var test_name = "Auto-detect quarter symmetry (cross)"
	var tile = _create_cross_shaped_tile()
	tile.rotation_symmetry = Tile.RotationSymmetry.AUTO
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 1, "Cross-shaped tile should have only 1 rotation", test_name)

func test_auto_detect_half_symmetry() -> void:
	var test_name = "Auto-detect half symmetry (I-beam)"
	var tile = _create_i_beam_tile()
	tile.rotation_symmetry = Tile.RotationSymmetry.AUTO
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 2, "I-beam tile should have 2 unique rotations", test_name)

func test_auto_detect_no_sockets() -> void:
	var test_name = "Auto-detect with no sockets"
	var tile = Tile.new()
	tile.rotation_symmetry = Tile.RotationSymmetry.AUTO
	tile.sockets.clear()
	
	var rotations = tile.get_unique_rotations()
	assert_equal(rotations.size(), 1, "Tile with no sockets should return [0]", test_name)

## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _create_l_shaped_tile() -> Tile:
	"""Create an L-shaped tile with asymmetric sockets (4 unique rotations)."""
	var tile = Tile.new()
	tile.name = "L-Shape"
	
	var type_a = SocketType.new()
	type_a.type_id = "a"
	var type_b = SocketType.new()
	type_b.type_id = "b"
	
	# L-shape: sockets on RIGHT and BACK only
	var socket_right = Socket.new()
	socket_right.direction = Vector3i.RIGHT
	socket_right.socket_type = type_a
	
	var socket_back = Socket.new()
	socket_back.direction = Vector3i.BACK
	socket_back.socket_type = type_b
	
	tile.sockets.append(socket_right)
	tile.sockets.append(socket_back)
	
	return tile

func _create_cross_shaped_tile() -> Tile:
	"""Create a cross-shaped tile with all sides identical (1 unique rotation)."""
	var tile = Tile.new()
	tile.name = "Cross"
	
	var type_a = SocketType.new()
	type_a.type_id = "a"
	
	# Cross: same socket type on all 4 horizontal sides
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		var socket = Socket.new()
		socket.direction = dir
		socket.socket_type = type_a
		tile.sockets.append(socket)
	
	return tile

func _create_i_beam_tile() -> Tile:
	"""Create an I-beam tile with 180° symmetry (2 unique rotations)."""
	var tile = Tile.new()
	tile.name = "I-Beam"
	
	var type_a = SocketType.new()
	type_a.type_id = "a"
	
	# I-beam: sockets on opposing sides (RIGHT/LEFT)
	var socket_right = Socket.new()
	socket_right.direction = Vector3i.RIGHT
	socket_right.socket_type = type_a
	
	var socket_left = Socket.new()
	socket_left.direction = Vector3i.LEFT
	socket_left.socket_type = type_a
	
	tile.sockets.append(socket_right)
	tile.sockets.append(socket_left)
	
	return tile

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
