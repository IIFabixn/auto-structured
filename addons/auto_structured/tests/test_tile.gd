extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Tile ===")
	
	test_tile_initialization()
	test_tile_name_and_properties()
	test_tile_add_tag()
	test_tile_remove_tag()
	test_tile_has_tag()
	test_tile_has_all_tags()
	test_tile_has_any_tags()
	test_tile_add_socket()
	test_tile_remove_socket()
	test_tile_get_socket_by_direction()
	test_tile_get_sockets_in_direction()
	test_tile_socket_cache_rebuild()
	test_tile_ensure_all_sockets()
	test_tile_get_unique_rotations()
	test_tile_face_cache_properties()
	
	print_summary()

func test_tile_initialization() -> void:
	var test_name = "Tile initialization"
	
	var tile = Tile.new()
	assert_not_null(tile, "Tile should be created", test_name)
	assert_equal(tile.name, "", "Should have empty name by default", test_name)
	assert_null(tile.mesh, "Should have no mesh by default", test_name)
	assert_null(tile.scene, "Should have no scene by default", test_name)
	assert_equal(tile.size, Vector3i.ONE, "Should have default size of (1,1,1)", test_name)
	assert_equal(tile.tags.size(), 0, "Should have no tags by default", test_name)
	assert_equal(tile.sockets.size(), 0, "Should have no sockets by default", test_name)

func test_tile_name_and_properties() -> void:
	var test_name = "Tile name and properties"
	
	var tile = Tile.new()
	tile.name = "WallTile"
	assert_equal(tile.name, "WallTile", "Should set name", test_name)
	
	tile.size = Vector3i(2, 3, 1)
	assert_equal(tile.size, Vector3i(2, 3, 1), "Should set size", test_name)

func test_tile_add_tag() -> void:
	var test_name = "Tile add tag"
	
	var tile = Tile.new()
	
	# Add first tag
	var result1 = tile.add_tag("wall")
	assert_true(result1, "Should add tag successfully", test_name)
	assert_equal(tile.tags.size(), 1, "Should have 1 tag", test_name)
	assert_true("wall" in tile.tags, "Should contain 'wall' tag", test_name)
	
	# Add second tag
	tile.add_tag("structural")
	assert_equal(tile.tags.size(), 2, "Should have 2 tags", test_name)
	assert_true("structural" in tile.tags, "Should contain 'structural' tag", test_name)
	
	# Try to add duplicate tag
	var result2 = tile.add_tag("wall")
	assert_false(result2, "Should not add duplicate tag", test_name)
	assert_equal(tile.tags.size(), 2, "Should still have 2 tags", test_name)

func test_tile_remove_tag() -> void:
	var test_name = "Tile remove tag"
	
	var tile = Tile.new()
	tile.add_tag("wall")
	tile.add_tag("floor")
	tile.add_tag("corner")
	
	# Remove existing tag
	tile.remove_tag("floor")
	assert_equal(tile.tags.size(), 2, "Should have 2 tags after removal", test_name)
	assert_false("floor" in tile.tags, "Should not contain 'floor' tag", test_name)
	assert_true("wall" in tile.tags, "Should still contain 'wall' tag", test_name)
	assert_true("corner" in tile.tags, "Should still contain 'corner' tag", test_name)
	
	# Remove non-existent tag (should not crash)
	tile.remove_tag("nonexistent")
	assert_equal(tile.tags.size(), 2, "Should still have 2 tags", test_name)

func test_tile_has_tag() -> void:
	var test_name = "Tile has tag"
	
	var tile = Tile.new()
	tile.add_tag("wall")
	tile.add_tag("brick")
	
	assert_true(tile.has_tag("wall"), "Should have 'wall' tag", test_name)
	assert_true(tile.has_tag("brick"), "Should have 'brick' tag", test_name)
	assert_false(tile.has_tag("floor"), "Should not have 'floor' tag", test_name)
	assert_false(tile.has_tag(""), "Should not have empty tag", test_name)

func test_tile_has_all_tags() -> void:
	var test_name = "Tile has all tags"
	
	var tile = Tile.new()
	tile.add_tag("wall")
	tile.add_tag("brick")
	tile.add_tag("corner")
	
	# Test with all matching tags
	var tags1: Array[String] = ["wall", "brick"]
	assert_true(tile.has_all_tags(tags1), "Should have all tags in subset", test_name)
	
	# Test with all tags
	var tags2: Array[String] = ["wall", "brick", "corner"]
	assert_true(tile.has_all_tags(tags2), "Should have all tags", test_name)
	
	# Test with some missing tags
	var tags3: Array[String] = ["wall", "floor"]
	assert_false(tile.has_all_tags(tags3), "Should not have all tags when one is missing", test_name)
	
	# Test with empty array
	var tags4: Array[String] = []
	assert_true(tile.has_all_tags(tags4), "Empty tag list should return true", test_name)
	
	# Test with only non-existent tags
	var tags5: Array[String] = ["floor", "ceiling"]
	assert_false(tile.has_all_tags(tags5), "Should not have non-existent tags", test_name)

func test_tile_has_any_tags() -> void:
	var test_name = "Tile has any tags"
	
	var tile = Tile.new()
	tile.add_tag("wall")
	tile.add_tag("brick")
	
	# Test with some matching tags
	var tags1: Array[String] = ["wall", "floor"]
	assert_true(tile.has_any_tags(tags1), "Should have at least one matching tag", test_name)
	
	# Test with all matching tags
	var tags2: Array[String] = ["wall", "brick"]
	assert_true(tile.has_any_tags(tags2), "Should have matching tags", test_name)
	
	# Test with no matching tags
	var tags3: Array[String] = ["floor", "ceiling"]
	assert_false(tile.has_any_tags(tags3), "Should not have any matching tags", test_name)
	
	# Test with empty array
	var tags4: Array[String] = []
	assert_false(tile.has_any_tags(tags4), "Empty tag list should return false", test_name)

func test_tile_add_socket() -> void:
	var test_name = "Tile add socket"
	
	var tile = Tile.new()
	var socket_type = SocketType.new()
	socket_type.type_id = "wall"
	
	var socket1 = Socket.new()
	socket1.direction = Vector3i.UP
	socket1.socket_type = socket_type
	
	tile.add_socket(socket1)
	assert_equal(tile.sockets.size(), 1, "Should have 1 socket", test_name)
	assert_true(socket1 in tile.sockets, "Should contain the socket", test_name)
	
	# Add another socket
	var socket2 = Socket.new()
	socket2.direction = Vector3i.DOWN
	socket2.socket_type = socket_type
	
	tile.add_socket(socket2)
	assert_equal(tile.sockets.size(), 2, "Should have 2 sockets", test_name)

func test_tile_remove_socket() -> void:
	var test_name = "Tile remove socket"
	
	var tile = Tile.new()
	var socket_type = SocketType.new()
	socket_type.type_id = "wall"
	
	var socket1 = Socket.new()
	socket1.direction = Vector3i.UP
	socket1.socket_type = socket_type
	
	var socket2 = Socket.new()
	socket2.direction = Vector3i.DOWN
	socket2.socket_type = socket_type
	
	tile.add_socket(socket1)
	tile.add_socket(socket2)
	
	# Remove first socket
	tile.remove_socket(socket1)
	assert_equal(tile.sockets.size(), 1, "Should have 1 socket after removal", test_name)
	assert_false(socket1 in tile.sockets, "Should not contain removed socket", test_name)
	assert_true(socket2 in tile.sockets, "Should still contain second socket", test_name)
	
	# Try to remove non-existent socket (should not crash)
	var socket3 = Socket.new()
	tile.remove_socket(socket3)
	assert_equal(tile.sockets.size(), 1, "Should still have 1 socket", test_name)

func test_tile_get_socket_by_direction() -> void:
	var test_name = "Tile get socket by direction"
	
	var tile = Tile.new()
	var socket_type = SocketType.new()
	socket_type.type_id = "wall"
	
	var socket_up = Socket.new()
	socket_up.direction = Vector3i.UP
	socket_up.socket_type = socket_type
	
	var socket_down = Socket.new()
	socket_down.direction = Vector3i.DOWN
	socket_down.socket_type = socket_type
	
	tile.add_socket(socket_up)
	tile.add_socket(socket_down)
	
	# Test finding existing sockets
	var found_up = tile.get_socket_by_direction(Vector3i.UP)
	assert_not_null(found_up, "Should find UP socket", test_name)
	assert_equal(found_up.direction, Vector3i.UP, "Found socket should have UP direction", test_name)
	
	var found_down = tile.get_socket_by_direction(Vector3i.DOWN)
	assert_equal(found_down.direction, Vector3i.DOWN, "Should find DOWN socket", test_name)
	
	# Test not finding non-existent socket
	var not_found = tile.get_socket_by_direction(Vector3i.LEFT)
	assert_null(not_found, "Should return null for non-existent direction", test_name)

func test_tile_get_sockets_in_direction() -> void:
	var test_name = "Tile get sockets in direction"
	
	var tile = Tile.new()
	var socket_type = SocketType.new()
	socket_type.type_id = "wall"
	
	# Add two sockets in the same direction
	var socket1 = Socket.new()
	socket1.direction = Vector3i.UP
	socket1.socket_type = socket_type
	
	var socket2 = Socket.new()
	socket2.direction = Vector3i.UP
	socket2.socket_type = socket_type
	
	var socket3 = Socket.new()
	socket3.direction = Vector3i.DOWN
	socket3.socket_type = socket_type
	
	tile.add_socket(socket1)
	tile.add_socket(socket2)
	tile.add_socket(socket3)
	
	# Test getting multiple sockets in same direction
	var up_sockets = tile.get_sockets_in_direction(Vector3i.UP)
	assert_equal(up_sockets.size(), 2, "Should find 2 UP sockets", test_name)
	
	var down_sockets = tile.get_sockets_in_direction(Vector3i.DOWN)
	assert_equal(down_sockets.size(), 1, "Should find 1 DOWN socket", test_name)
	
	# Test direction with no sockets
	var left_sockets = tile.get_sockets_in_direction(Vector3i.LEFT)
	assert_equal(left_sockets.size(), 0, "Should find 0 LEFT sockets", test_name)

func test_tile_socket_cache_rebuild() -> void:
	var test_name = "Tile socket cache rebuild"
	
	var tile = Tile.new()
	var socket_type = SocketType.new()
	socket_type.type_id = "wall"
	
	var socket = Socket.new()
	socket.direction = Vector3i.UP
	socket.socket_type = socket_type
	
	# Add socket and check cache
	tile.add_socket(socket)
	var cached_sockets = tile.get_sockets_in_direction(Vector3i.UP)
	assert_equal(cached_sockets.size(), 1, "Cache should contain socket after add", test_name)
	
	# Remove socket and check cache
	tile.remove_socket(socket)
	var cached_after_remove = tile.get_sockets_in_direction(Vector3i.UP)
	assert_equal(cached_after_remove.size(), 0, "Cache should be updated after remove", test_name)
	
	# Directly set sockets array (triggers cache rebuild)
	var socket2 = Socket.new()
	socket2.direction = Vector3i.DOWN
	socket2.socket_type = socket_type
	
	var sockets_array: Array[Socket] = [socket2]
	tile.sockets = sockets_array
	
	var cached_after_set = tile.get_sockets_in_direction(Vector3i.DOWN)
	assert_equal(cached_after_set.size(), 1, "Cache should rebuild after direct assignment", test_name)

func test_tile_ensure_all_sockets() -> void:
	var test_name = "Tile ensure all sockets"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var tile = Tile.new()
	
	# Initially no sockets
	assert_equal(tile.sockets.size(), 0, "Should start with no sockets", test_name)
	
	# Ensure all 6 cardinal directions have sockets
	tile.ensure_all_sockets(library)
	assert_equal(tile.sockets.size(), 6, "Should have 6 sockets after ensure_all_sockets", test_name)
	
	# Check all directions are present
	assert_not_null(tile.get_socket_by_direction(Vector3i.UP), "Should have UP socket", test_name)
	assert_not_null(tile.get_socket_by_direction(Vector3i.DOWN), "Should have DOWN socket", test_name)
	assert_not_null(tile.get_socket_by_direction(Vector3i.LEFT), "Should have LEFT socket", test_name)
	assert_not_null(tile.get_socket_by_direction(Vector3i.RIGHT), "Should have RIGHT socket", test_name)
	assert_not_null(tile.get_socket_by_direction(Vector3i.FORWARD), "Should have FORWARD socket", test_name)
	assert_not_null(tile.get_socket_by_direction(Vector3i.BACK), "Should have BACK socket", test_name)
	
	# Check that default sockets use "none" type
	var up_socket = tile.get_socket_by_direction(Vector3i.UP)
	if up_socket.socket_type != null:
		assert_equal(up_socket.socket_type.type_id, "none", "Default socket should use 'none' type", test_name)
	
	# Call again - should not create duplicates
	tile.ensure_all_sockets(library)
	assert_equal(tile.sockets.size(), 6, "Should still have 6 sockets after second call", test_name)

func test_tile_get_unique_rotations() -> void:
	var test_name = "Tile get unique rotations"
	
	var tile = Tile.new()
	var rotations = tile.get_unique_rotations()
	
	assert_not_null(rotations, "Should return rotations array", test_name)
	assert_equal(rotations.size(), 1, "Should have 1 rotation by default", test_name)
	assert_equal(rotations[0], 0, "Default rotation should be 0", test_name)

func test_tile_face_cache_properties() -> void:
	var test_name = "Tile face cache properties"
	
	var tile = Tile.new()
	
	# Check initial state
	assert_false(tile._face_cache_valid, "Face cache should be invalid initially", test_name)
	assert_true(tile._cached_face_signatures.is_empty(), "Cached signatures should be empty initially", test_name)
	
	# Simulate cache population (as done by MeshOutlineAnalyzer)
	tile._cached_face_signatures = {
		Vector3i.UP: {"dimensions": Vector2(1, 1), "center": Vector2(0, 0)}
	}
	tile._face_cache_valid = true
	
	assert_true(tile._face_cache_valid, "Cache should be valid after setting", test_name)
	assert_false(tile._cached_face_signatures.is_empty(), "Cache should contain data", test_name)

# Assertion helper methods
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
	print("\n--- Tile Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
