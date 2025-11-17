extends RefCounted

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing ModuleLibrary ===")
	
	test_library_initialization()
	test_library_ensure_defaults()
	test_library_get_tile_by_name()
	test_library_get_tiles_with_tag()
	test_library_register_socket_type()
	test_library_get_socket_type_by_id()
	test_library_ensure_socket_type()
	test_library_get_socket_type_ids()
	test_library_get_all_unique_socket_ids()
	test_library_rename_socket_type()
	test_library_delete_socket_type()
	test_library_validate_socket_id()
	test_library_validate_library()
	test_library_cell_world_size()
	
	print_summary()

func test_library_initialization() -> void:
	var test_name = "Library initialization"
	
	var library = ModuleLibrary.new()
	assert_not_null(library, "Library should be created", test_name)
	assert_equal(library.library_name, "My Building Set", "Should have default library name", test_name)
	assert_equal(library.tiles.size(), 0, "Should have no tiles initially", test_name)
	assert_equal(library.socket_types.size(), 0, "Should have no socket types initially", test_name)
	assert_equal(library.cell_world_size, Vector3(1, 1, 1), "Should have default cell size", test_name)

func test_library_ensure_defaults() -> void:
	var test_name = "Library ensure defaults"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Check "none" socket type was created
	var none_type = library.get_socket_type_by_id("none")
	assert_not_null(none_type, "Should create 'none' socket type", test_name)
	assert_equal(none_type.type_id, "none", "'none' type should have correct id", test_name)
	
	# Check "any" socket type was created
	var any_type = library.get_socket_type_by_id("any")
	assert_not_null(any_type, "Should create 'any' socket type", test_name)
	assert_equal(any_type.type_id, "any", "'any' type should have correct id", test_name)
	
	# Check cell size was set to defaults if invalid
	assert_true(library.cell_world_size.x > 0, "Cell size X should be positive", test_name)
	assert_true(library.cell_world_size.y > 0, "Cell size Y should be positive", test_name)
	assert_true(library.cell_world_size.z > 0, "Cell size Z should be positive", test_name)
	
	# Test ensure_defaults is idempotent
	var socket_count = library.socket_types.size()
	library.ensure_defaults()
	assert_equal(library.socket_types.size(), socket_count, "ensure_defaults should not add duplicates", test_name)

func test_library_get_tile_by_name() -> void:
	var test_name = "Library get tile by name"
	
	var library = ModuleLibrary.new()
	
	var tile1 = Tile.new()
	tile1.name = "Wall"
	var tile2 = Tile.new()
	tile2.name = "Floor"
	var tile3 = Tile.new()
	tile3.name = "Ceiling"
	
	var tiles_array: Array[Tile] = [tile1, tile2, tile3]
	library.tiles = tiles_array
	
	# Test finding existing tiles
	var found_wall = library.get_tile_by_name("Wall")
	assert_not_null(found_wall, "Should find Wall tile", test_name)
	assert_equal(found_wall.name, "Wall", "Found tile should have correct name", test_name)
	
	var found_floor = library.get_tile_by_name("Floor")
	assert_equal(found_floor.name, "Floor", "Should find Floor tile", test_name)
	
	# Test not finding non-existent tile
	var not_found = library.get_tile_by_name("NonExistent")
	assert_null(not_found, "Should return null for non-existent tile", test_name)

func test_library_get_tiles_with_tag() -> void:
	var test_name = "Library get tiles with tag"
	
	var library = ModuleLibrary.new()
	
	var tile1 = Tile.new()
	tile1.name = "Wall1"
	tile1.add_tag("wall")
	tile1.add_tag("structural")
	
	var tile2 = Tile.new()
	tile2.name = "Wall2"
	tile2.add_tag("wall")
	
	var tile3 = Tile.new()
	tile3.name = "Floor"
	tile3.add_tag("floor")
	
	var tiles_array: Array[Tile] = [tile1, tile2, tile3]
	library.tiles = tiles_array
	
	# Test finding tiles with "wall" tag
	var wall_tiles = library.get_tiles_with_tag("wall")
	assert_equal(wall_tiles.size(), 2, "Should find 2 wall tiles", test_name)
	
	# Test finding tiles with "floor" tag
	var floor_tiles = library.get_tiles_with_tag("floor")
	assert_equal(floor_tiles.size(), 1, "Should find 1 floor tile", test_name)
	
	# Test finding tiles with "structural" tag
	var structural_tiles = library.get_tiles_with_tag("structural")
	assert_equal(structural_tiles.size(), 1, "Should find 1 structural tile", test_name)
	
	# Test finding tiles with non-existent tag
	var no_tiles = library.get_tiles_with_tag("nonexistent")
	assert_equal(no_tiles.size(), 0, "Should find 0 tiles with non-existent tag", test_name)

func test_library_register_socket_type() -> void:
	var test_name = "Library register socket type"
	
	var library = ModuleLibrary.new()
	
	# Test registering by string
	var type1 = library.register_socket_type("wall")
	assert_not_null(type1, "Should register socket type from string", test_name)
	assert_equal(type1.type_id, "wall", "Registered type should have correct id", test_name)
	assert_equal(library.socket_types.size(), 1, "Should have 1 socket type", test_name)
	
	# Test registering duplicate (should return existing)
	var type1_again = library.register_socket_type("wall")
	assert_equal(type1_again, type1, "Should return existing type for duplicate", test_name)
	assert_equal(library.socket_types.size(), 1, "Should still have 1 socket type", test_name)
	
	# Test registering SocketType resource
	var type2 = SocketType.new()
	type2.type_id = "floor"
	var registered = library.register_socket_type(type2)
	assert_equal(registered, type2, "Should register SocketType resource", test_name)
	assert_equal(library.socket_types.size(), 2, "Should have 2 socket types", test_name)
	
	# Test registering empty string (should return null)
	var type_empty = library.register_socket_type("")
	assert_null(type_empty, "Should return null for empty string", test_name)
	
	# Test registering whitespace (should trim and register)
	var type3 = library.register_socket_type("  ceiling  ")
	assert_not_null(type3, "Should register trimmed type", test_name)
	assert_equal(type3.type_id, "ceiling", "Should trim whitespace from type_id", test_name)

func test_library_get_socket_type_by_id() -> void:
	var test_name = "Library get socket type by id"
	
	var library = ModuleLibrary.new()
	library.register_socket_type("wall")
	library.register_socket_type("floor")
	
	# Test finding existing type
	var wall_type = library.get_socket_type_by_id("wall")
	assert_not_null(wall_type, "Should find wall type", test_name)
	assert_equal(wall_type.type_id, "wall", "Found type should have correct id", test_name)
	
	# Test not finding non-existent type
	var not_found = library.get_socket_type_by_id("nonexistent")
	assert_null(not_found, "Should return null for non-existent type", test_name)

func test_library_ensure_socket_type() -> void:
	var test_name = "Library ensure socket type"
	
	var library = ModuleLibrary.new()
	
	# Test ensuring new type (should create it)
	var type1 = library.ensure_socket_type("wall")
	assert_not_null(type1, "Should create new socket type", test_name)
	assert_equal(type1.type_id, "wall", "Created type should have correct id", test_name)
	
	# Test ensuring existing type (should return it)
	var type1_again = library.ensure_socket_type("wall")
	assert_equal(type1_again, type1, "Should return existing type", test_name)
	
	# Test ensuring empty string (should return null)
	var type_empty = library.ensure_socket_type("")
	assert_null(type_empty, "Should return null for empty string", test_name)
	
	# Test ensuring whitespace (should trim)
	var type2 = library.ensure_socket_type("  floor  ")
	assert_equal(type2.type_id, "floor", "Should trim whitespace", test_name)

func test_library_get_socket_type_ids() -> void:
	var test_name = "Library get socket type ids"
	
	var library = ModuleLibrary.new()
	library.register_socket_type("wall")
	library.register_socket_type("floor")
	library.register_socket_type("ceiling")
	
	var ids = library.get_socket_type_ids()
	assert_equal(ids.size(), 3, "Should have 3 socket type ids", test_name)
	assert_true("wall" in ids, "Should contain wall", test_name)
	assert_true("floor" in ids, "Should contain floor", test_name)
	assert_true("ceiling" in ids, "Should contain ceiling", test_name)

func test_library_get_all_unique_socket_ids() -> void:
	var test_name = "Library get all unique socket ids"
	
	var library = ModuleLibrary.new()
	
	# Create socket types
	var wall_type = SocketType.new()
	wall_type.type_id = "wall"
	var floor_type = SocketType.new()
	floor_type.type_id = "floor"
	
	# Create tiles with sockets
	var tile1 = Tile.new()
	tile1.name = "Wall"
	var socket1 = Socket.new()
	socket1.socket_type = wall_type
	socket1.direction = Vector3i.UP
	tile1.sockets.append(socket1)
	
	var tile2 = Tile.new()
	tile2.name = "Floor"
	var socket2 = Socket.new()
	socket2.socket_type = floor_type
	socket2.direction = Vector3i.UP
	tile2.sockets.append(socket2)
	
	var socket3 = Socket.new()
	socket3.socket_type = wall_type  # Duplicate wall type
	socket3.direction = Vector3i.DOWN
	tile2.sockets.append(socket3)
	
	var tiles_array: Array[Tile] = [tile1, tile2]
	library.tiles = tiles_array
	
	var unique_ids = library.get_all_unique_socket_ids()
	assert_equal(unique_ids.size(), 2, "Should have 2 unique socket ids", test_name)
	assert_true("wall" in unique_ids, "Should contain wall", test_name)
	assert_true("floor" in unique_ids, "Should contain floor", test_name)

func test_library_rename_socket_type() -> void:
	var test_name = "Library rename socket type"
	
	var library = ModuleLibrary.new()
	
	# Register types
	library.register_socket_type("old_name")
	var type2 = library.register_socket_type("other")
	type2.set_compatible_types(["old_name"])
	
	# Test successful rename
	var result = library.rename_socket_type("old_name", "new_name")
	assert_true(result, "Rename should succeed", test_name)
	
	var renamed = library.get_socket_type_by_id("new_name")
	assert_not_null(renamed, "Should find renamed type", test_name)
	
	var old = library.get_socket_type_by_id("old_name")
	assert_null(old, "Should not find old name", test_name)
	
	# Check compatibility references were updated
	var other = library.get_socket_type_by_id("other")
	assert_true("new_name" in other.compatible_types, "Compatibility should be updated to new name", test_name)
	assert_false("old_name" in other.compatible_types, "Compatibility should not have old name", test_name)
	
	# Test rename to existing name (should fail)
	library.register_socket_type("existing")
	var fail_result = library.rename_socket_type("new_name", "existing")
	assert_false(fail_result, "Rename to existing name should fail", test_name)
	
	# Test rename non-existent type (should fail)
	var fail_result2 = library.rename_socket_type("nonexistent", "anything")
	assert_false(fail_result2, "Rename non-existent type should fail", test_name)

func test_library_delete_socket_type() -> void:
	var test_name = "Library delete socket type"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Register a type to delete
	var to_delete = library.register_socket_type("deleteme")
	var keep_type = library.register_socket_type("keepme")
	keep_type.set_compatible_types(["deleteme"])
	
	# Create tile with socket referencing the type
	var tile = Tile.new()
	tile.name = "TestTile"
	var socket = Socket.new()
	socket.socket_type = to_delete
	socket.direction = Vector3i.UP
	tile.sockets.append(socket)
	
	var tiles_array: Array[Tile] = [tile]
	library.tiles = tiles_array
	
	var initial_count = library.socket_types.size()
	
	# Test successful delete
	var result = library.delete_socket_type("deleteme", "none")
	assert_true(result, "Delete should succeed", test_name)
	assert_equal(library.socket_types.size(), initial_count - 1, "Should have one less socket type", test_name)
	
	var deleted = library.get_socket_type_by_id("deleteme")
	assert_null(deleted, "Deleted type should not be found", test_name)
	
	# Check socket was migrated to fallback
	var none_type = library.get_socket_type_by_id("none")
	assert_equal(tile.sockets[0].socket_type, none_type, "Socket should be migrated to fallback", test_name)
	
	# Check compatibility references were removed
	var keep = library.get_socket_type_by_id("keepme")
	assert_false("deleteme" in keep.compatible_types, "Compatibility reference should be removed", test_name)
	
	# Test deleting "none" (should fail)
	var fail_result = library.delete_socket_type("none")
	assert_false(fail_result, "Deleting 'none' should fail", test_name)
	
	# Test deleting "any" (should fail)
	var fail_result2 = library.delete_socket_type("any")
	assert_false(fail_result2, "Deleting 'any' should fail", test_name)
	
	# Test deleting non-existent type (should fail)
	var fail_result3 = library.delete_socket_type("nonexistent")
	assert_false(fail_result3, "Deleting non-existent type should fail", test_name)

func test_library_validate_socket_id() -> void:
	var test_name = "Library validate socket id"
	
	var library = ModuleLibrary.new()
	library.register_socket_type("wall")
	library.register_socket_type("floor")
	
	# Test valid ids
	assert_true(library.validate_socket_id("wall"), "wall should be valid", test_name)
	assert_true(library.validate_socket_id("floor"), "floor should be valid", test_name)
	
	# Test invalid id
	assert_false(library.validate_socket_id("nonexistent"), "nonexistent should be invalid", test_name)

func test_library_validate_library() -> void:
	var test_name = "Library validate library"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Create valid tile
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	var tile1 = Tile.new()
	tile1.name = "ValidTile"
	var socket1 = Socket.new()
	socket1.socket_type = wall_type
	socket1.direction = Vector3i.UP
	tile1.sockets.append(socket1)
	
	var tiles_array: Array[Tile] = [tile1]
	library.tiles = tiles_array
	
	# Test valid library
	var result1 = library.validate_library()
	assert_true(result1["valid"], "Valid library should pass validation", test_name)
	assert_equal(result1["issues"].size(), 0, "Should have no issues", test_name)
	
	# Add tile with null socket_type
	var tile2 = Tile.new()
	tile2.name = "InvalidTile"
	var socket2 = Socket.new()
	socket2.socket_type = null
	socket2.direction = Vector3i.UP
	tile2.sockets.append(socket2)
	tiles_array.append(tile2)
	library.tiles = tiles_array
	
	var result2 = library.validate_library()
	assert_false(result2["valid"], "Invalid library should fail validation", test_name)
	assert_true(result2["issues"].size() > 0, "Should have issues", test_name)

func test_library_cell_world_size() -> void:
	var test_name = "Library cell world size"
	
	var library = ModuleLibrary.new()
	
	# Test default size
	assert_equal(library.cell_world_size, Vector3(1, 1, 1), "Should have default size", test_name)
	
	# Test setting custom size
	library.cell_world_size = Vector3(2, 3, 2)
	assert_equal(library.cell_world_size, Vector3(2, 3, 2), "Should have custom size", test_name)
	
	# Test ensure_defaults fixes invalid size
	library.cell_world_size = Vector3(0, 0, 0)
	library.ensure_defaults()
	assert_true(library.cell_world_size.x > 0, "ensure_defaults should fix invalid X", test_name)
	assert_true(library.cell_world_size.y > 0, "ensure_defaults should fix invalid Y", test_name)
	assert_true(library.cell_world_size.z > 0, "ensure_defaults should fix invalid Z", test_name)

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
	print("\n--- ModuleLibrary Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
