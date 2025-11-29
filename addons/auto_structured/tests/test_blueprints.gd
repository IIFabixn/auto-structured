extends RefCounted
## Tests for the Blueprint system

const BlueprintBase = preload("res://addons/auto_structured/core/blueprints/blueprint_base.gd")
const BuildingBlueprint = preload("res://addons/auto_structured/core/blueprints/building_blueprint.gd")
const WfcBlueprintStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_blueprint.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0


func run_all_tests() -> void:
	print("=== Testing Blueprints ===")
	
	# BlueprintBase tests
	test_blueprint_base_zone_map()
	test_blueprint_base_key_conversion()
	test_blueprint_base_zone_names()
	
	# BuildingBlueprint tests
	test_building_blueprint_rooms()
	test_building_blueprint_zones()
	test_building_blueprint_config()
	test_building_blueprint_wall_facing()
	test_building_blueprint_boundary_roles()
	test_building_blueprint_small_grid()
	test_building_blueprint_guaranteed_doors()
	
	# WfcBlueprintStrategy tests
	test_strategy_prepares_grid()
	test_strategy_filters_cells()
	test_strategy_solver_overrides()
	
	print_summary()


## ============================================================================
## BlueprintBase Tests
## ============================================================================

func test_blueprint_base_zone_map() -> void:
	var test_name = "BlueprintBase zone map operations"
	
	var blueprint = BuildingBlueprint.new()
	blueprint.generate(Vector3i(5, 1, 5))
	
	# Should have zones set
	var zone = blueprint.get_zone(Vector3i(2, 0, 2))
	assert_true(zone != BlueprintBase.Zone.UNKNOWN, "Expected zone to be set, not UNKNOWN", test_name)
	
	# Manual set should work
	blueprint.set_zone(Vector3i(0, 0, 0), BlueprintBase.Zone.DOOR)
	assert_equal(blueprint.get_zone(Vector3i(0, 0, 0)), BlueprintBase.Zone.DOOR, "Manual zone set should work", test_name)


func test_blueprint_base_key_conversion() -> void:
	var test_name = "BlueprintBase position key conversion"
	
	var blueprint = BuildingBlueprint.new()
	blueprint.generate(Vector3i(10, 3, 10))
	
	# Test various positions
	var positions = [
		Vector3i(0, 0, 0),
		Vector3i(5, 1, 5),
		Vector3i(9, 2, 9),
		Vector3i(3, 0, 7),
	]
	
	for pos in positions:
		var key = blueprint._pos_to_key(pos)
		var back = blueprint._key_to_pos(key)
		assert_equal(back, pos, "Key conversion should round-trip for %s" % pos, test_name)


func test_blueprint_base_zone_names() -> void:
	var test_name = "BlueprintBase zone name lookup"
	
	var blueprint = BuildingBlueprint.new()
	
	assert_equal(blueprint.get_zone_name(BlueprintBase.Zone.WALL), "WALL", "Zone name for WALL", test_name)
	assert_equal(blueprint.get_zone_name(BlueprintBase.Zone.INTERIOR), "INTERIOR", "Zone name for INTERIOR", test_name)


## ============================================================================
## BuildingBlueprint Tests
## ============================================================================

func test_building_blueprint_rooms() -> void:
	var test_name = "BuildingBlueprint generates rooms"
	
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"min_room_size": 3, "max_rooms": 2})
	blueprint.generate(Vector3i(12, 1, 12))
	
	var rooms = blueprint.get_rooms()
	assert_true(rooms.size() > 0, "Expected at least one room", test_name)
	
	# Check room bounds
	for room in rooms:
		assert_true(room.size.x >= 3, "Room width should be >= 3", test_name)
		assert_true(room.size.y >= 3, "Room height should be >= 3", test_name)
		assert_true(room.position.x >= 0, "Room X position should be >= 0", test_name)
		assert_true(room.position.y >= 0, "Room Y position should be >= 0", test_name)


func test_building_blueprint_zones() -> void:
	var test_name = "BuildingBlueprint zone classification"
	
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"min_room_size": 3, "max_rooms": 1, "margin": 2})
	blueprint.generate(Vector3i(10, 1, 10))
	
	var rooms = blueprint.get_rooms()
	assert_true(rooms.size() > 0, "Need at least one room for zone test", test_name)
	
	if rooms.is_empty():
		return
	
	var room = rooms[0]
	
	# Check corners are CORNER zone
	var corners = [
		Vector3i(room.position.x, 0, room.position.y),
		Vector3i(room.position.x + room.size.x - 1, 0, room.position.y),
		Vector3i(room.position.x, 0, room.position.y + room.size.y - 1),
		Vector3i(room.position.x + room.size.x - 1, 0, room.position.y + room.size.y - 1),
	]
	
	for corner in corners:
		var zone = blueprint.get_zone(corner)
		assert_equal(zone, BlueprintBase.Zone.CORNER, "Expected CORNER at %s" % corner, test_name)
	
	# Check exterior cells are EXTERIOR
	var exterior_pos = Vector3i(0, 0, 0)
	var zone = blueprint.get_zone(exterior_pos)
	assert_equal(zone, BlueprintBase.Zone.EXTERIOR, "Expected EXTERIOR at (0,0,0)", test_name)


func test_building_blueprint_config() -> void:
	var test_name = "BuildingBlueprint configuration"
	
	var blueprint = BuildingBlueprint.new()
	
	var config = {
		"min_room_size": 5,
		"max_room_size": 10,
		"max_rooms": 6,
		"margin": 3,
		"doors_per_room": 2,
	}
	blueprint.configure(config)
	
	assert_equal(blueprint.min_room_size, 5, "min_room_size should be 5", test_name)
	assert_equal(blueprint.max_room_size, 10, "max_room_size should be 10", test_name)
	assert_equal(blueprint.max_rooms, 6, "max_rooms should be 6", test_name)
	assert_equal(blueprint.margin, 3, "margin should be 3", test_name)
	assert_equal(blueprint.doors_per_room, 2, "doors_per_room should be 2", test_name)


func test_building_blueprint_wall_facing() -> void:
	var test_name = "BuildingBlueprint wall facing"
	
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"min_room_size": 3, "max_rooms": 1, "margin": 2})
	blueprint.generate(Vector3i(10, 1, 10))
	
	var rooms = blueprint.get_rooms()
	if rooms.is_empty():
		assert_true(false, "No rooms generated for wall facing test", test_name)
		return
	
	var room = rooms[0]
	
	# Check wall on left edge faces -X (toward exterior)
	var left_wall = Vector3i(room.position.x, 0, room.position.y + 1)
	var zone = blueprint.get_zone(left_wall)
	assert_equal(zone, BlueprintBase.Zone.WALL, "Expected WALL at left edge", test_name)
	
	var facing = blueprint.get_wall_facing_direction(left_wall)
	assert_equal(facing, Vector3i(-1, 0, 0), "Left wall should face -X", test_name)


func test_building_blueprint_boundary_roles() -> void:
	var test_name = "BuildingBlueprint boundary roles"
	
	var blueprint = BuildingBlueprint.new()
	
	# Test WALL zone allows EDGE
	var wall_roles = blueprint._get_valid_boundary_roles_for_zone(BlueprintBase.Zone.WALL)
	assert_true(Tile.BoundaryRole.EDGE in wall_roles, "WALL zone should allow EDGE", test_name)
	assert_false(Tile.BoundaryRole.NONE in wall_roles, "WALL zone should not allow NONE", test_name)
	
	# Test EXTERIOR zone allows NONE
	var exterior_roles = blueprint._get_valid_boundary_roles_for_zone(BlueprintBase.Zone.EXTERIOR)
	assert_true(Tile.BoundaryRole.NONE in exterior_roles, "EXTERIOR zone should allow NONE", test_name)
	assert_false(Tile.BoundaryRole.EDGE in exterior_roles, "EXTERIOR zone should not allow EDGE", test_name)
	
	# Test CORNER zone allows CORNER
	var corner_roles = blueprint._get_valid_boundary_roles_for_zone(BlueprintBase.Zone.CORNER)
	assert_true(Tile.BoundaryRole.CORNER in corner_roles, "CORNER zone should allow CORNER", test_name)
	
	# Test DOOR zone allows PASSAGE
	var door_roles = blueprint._get_valid_boundary_roles_for_zone(BlueprintBase.Zone.DOOR)
	assert_true(Tile.BoundaryRole.PASSAGE in door_roles, "DOOR zone should allow PASSAGE", test_name)
	assert_false(Tile.BoundaryRole.EDGE in door_roles, "DOOR zone should not allow EDGE", test_name)


func test_building_blueprint_small_grid() -> void:
	var test_name = "BuildingBlueprint small grid handling"
	
	# Test with grid too small for margin
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"min_room_size": 3, "margin": 2})
	blueprint.generate(Vector3i(5, 1, 5))  # Very small grid
	
	var rooms = blueprint.get_rooms()
	assert_true(rooms.size() > 0, "Should generate at least one room even on small grid", test_name)


func test_building_blueprint_guaranteed_doors() -> void:
	var test_name = "BuildingBlueprint guaranteed doors"
	
	var blueprint = BuildingBlueprint.new()
	# doors_per_room = 1 means one door per room
	blueprint.configure({"min_room_size": 4, "max_rooms": 1, "margin": 2, "doors_per_room": 1})
	blueprint.generate(Vector3i(10, 1, 10))
	
	var rooms = blueprint.get_rooms()
	assert_true(rooms.size() > 0, "Should have at least one room", test_name)
	
	# Count DOOR zones - should have exactly one per room with doors_per_room = 1
	var door_count = 0
	for x in range(10):
		for z in range(10):
			if blueprint.get_zone(Vector3i(x, 0, z)) == BlueprintBase.Zone.DOOR:
				door_count += 1
	
	assert_equal(door_count, rooms.size(), "Should have exactly one door per room", test_name)


func test_building_blueprint_single_door_mode() -> void:
	var test_name = "BuildingBlueprint single door mode"
	
	var blueprint = BuildingBlueprint.new()
	# doors_per_room = -1 means exactly one door total (for tiles with Global Max 1)
	blueprint.configure({"min_room_size": 3, "max_rooms": 2, "margin": 1, "doors_per_room": -1})
	blueprint.generate(Vector3i(12, 1, 12))
	
	# Count DOOR zones - should have exactly one total
	var door_count = 0
	for x in range(12):
		for z in range(12):
			if blueprint.get_zone(Vector3i(x, 0, z)) == BlueprintBase.Zone.DOOR:
				door_count += 1
	
	assert_equal(door_count, 1, "Should have exactly one door total in single-door mode", test_name)


## ============================================================================
## WfcBlueprintStrategy Tests
## ============================================================================

func test_strategy_prepares_grid() -> void:
	var test_name = "BlueprintStrategy prepares grid"
	
	var tiles = _create_test_tiles()
	var grid = WfcGrid.new(Vector3i(8, 1, 8), tiles)
	var solver = WfcSolver.new(grid, false)
	
	var strategy = WfcBlueprintStrategy.new()
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"max_rooms": 1, "margin": 1})
	strategy.set_blueprint(blueprint)
	
	# Prepare grid should not throw
	strategy.prepare_grid(grid, solver)
	
	# Blueprint should have zones
	var zone = blueprint.get_zone(Vector3i(0, 0, 0))
	assert_true(zone != BlueprintBase.Zone.UNKNOWN, "Blueprint zones should be generated during prepare_grid", test_name)


func test_strategy_filters_cells() -> void:
	var test_name = "BlueprintStrategy filters cells"
	
	var tiles = _create_test_tiles()
	var grid = WfcGrid.new(Vector3i(10, 1, 10), tiles)
	var solver = WfcSolver.new(grid, false)
	
	var strategy = WfcBlueprintStrategy.new()
	var blueprint = BuildingBlueprint.new()
	blueprint.configure({"max_rooms": 1, "margin": 2, "doors_per_room": 0})
	strategy.set_blueprint(blueprint)
	
	# Get initial variant counts
	var cell = grid.get_cell(Vector3i(0, 0, 0))
	var initial_count = cell.possible_tile_variants.size()
	
	strategy.prepare_grid(grid, solver)
	
	# Exterior cells should have fewer variants (only NONE role tiles)
	var exterior_cell = grid.get_cell(Vector3i(0, 0, 0))
	assert_true(exterior_cell.possible_tile_variants.size() < initial_count, "Exterior cell should have been filtered", test_name)


func test_strategy_solver_overrides() -> void:
	var test_name = "BlueprintStrategy solver overrides"
	
	var strategy = WfcBlueprintStrategy.new()
	var overrides = strategy.get_solver_overrides()
	
	assert_equal(overrides.get("enforce_region_boundaries"), false, "enforce_region_boundaries should be false", test_name)
	assert_equal(overrides.get("require_closed_regions"), false, "require_closed_regions should be false", test_name)


## ============================================================================
## Helper Functions
## ============================================================================

func _create_test_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	
	# Wall tile (EDGE)
	var wall = Tile.new()
	wall.name = "test_wall"
	wall.boundary_role = Tile.BoundaryRole.EDGE
	wall.tags = ["wall"]
	_add_test_sockets(wall)
	tiles.append(wall)
	
	# Corner tile (CORNER)
	var corner = Tile.new()
	corner.name = "test_corner"
	corner.boundary_role = Tile.BoundaryRole.CORNER
	corner.tags = ["corner"]
	_add_test_sockets(corner)
	tiles.append(corner)
	
	# Floor tile (NONE, interior)
	var floor_tile = Tile.new()
	floor_tile.name = "test_floor"
	floor_tile.boundary_role = Tile.BoundaryRole.NONE
	floor_tile.tags = ["floor"]
	_add_test_sockets(floor_tile)
	tiles.append(floor_tile)
	
	# Exterior tile (NONE, exterior)
	var exterior = Tile.new()
	exterior.name = "test_exterior"
	exterior.boundary_role = Tile.BoundaryRole.NONE
	exterior.tags = ["floor", "exterior"]
	_add_test_sockets(exterior)
	tiles.append(exterior)
	
	# Door tile (PASSAGE)
	var door = Tile.new()
	door.name = "test_door"
	door.boundary_role = Tile.BoundaryRole.PASSAGE
	door.tags = ["door"]
	_add_test_sockets(door)
	tiles.append(door)
	
	return tiles


func _add_test_sockets(tile: Tile) -> void:
	var directions = [
		Vector3i.UP, Vector3i.DOWN,
		Vector3i.LEFT, Vector3i.RIGHT,
		Vector3i.FORWARD, Vector3i.BACK
	]
	
	for dir in directions:
		var socket = Socket.new()
		socket.socket_id = "test"
		socket.direction = dir
		socket.compatible_sockets = ["test"]
		tile.add_socket(socket)


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
	print("\n--- Blueprint Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
