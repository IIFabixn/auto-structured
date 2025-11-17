extends RefCounted

const ValidationResult = preload("res://addons/auto_structured/core/validation/validation_result.gd")
const ValidationManager = preload("res://addons/auto_structured/core/validation/validation_manager.gd")
const TileValidator = preload("res://addons/auto_structured/core/validation/tile_validator.gd")
const LibraryValidator = preload("res://addons/auto_structured/core/validation/library_validator.gd")
const RequirementValidator = preload("res://addons/auto_structured/core/validation/requirement_validator.gd")

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
const MaxCountRequirement = preload("res://addons/auto_structured/core/requirements/max_count_requirement.gd")
const AdjacentRequirement = preload("res://addons/auto_structured/core/requirements/adjacent_requirement.gd")
const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
const BoundaryRequirement = preload("res://addons/auto_structured/core/requirements/boundary_requirement.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Validation System ===")
	
	# ValidationResult tests
	test_validation_result_creation()
	test_validation_result_severity_checks()
	test_validation_result_to_string()
	
	# TileValidator tests
	test_tile_validator_empty_name()
	test_tile_validator_invalid_size()
	test_tile_validator_invalid_weight()
	test_tile_validator_no_sockets()
	test_tile_validator_valid_tile()
	test_tile_validator_duplicate_socket_directions()
	
	# LibraryValidator tests
	test_library_validator_empty_library()
	test_library_validator_duplicate_tile_names()
	test_library_validator_no_socket_types()
	test_library_validator_unused_socket_types()
	test_library_validator_isolated_tiles()
	
	# RequirementValidator tests
	test_requirement_validator_height_negative()
	test_requirement_validator_height_range_invalid()
	test_requirement_validator_max_count_zero()
	test_requirement_validator_adjacent_no_tags()
	test_requirement_validator_tag_no_tags()
	test_requirement_validator_boundary_no_axes()
	
	# ValidationManager tests
	test_validation_manager_validate_tile()
	test_validation_manager_validate_library_deep()
	test_validation_manager_filtering()
	
	print_summary()

## ============================================================================
## VALIDATION RESULT TESTS
## ============================================================================

func test_validation_result_creation() -> void:
	var test_name = "ValidationResult creation"
	var result = ValidationResult.new(ValidationResult.Severity.ERROR, "Test error", {"key": "value"})
	
	assert_equal(result.severity, ValidationResult.Severity.ERROR, "Severity should match", test_name)
	assert_equal(result.message, "Test error", "Message should match", test_name)
	assert_true(result.context.has("key"), "Context should have key", test_name)

func test_validation_result_severity_checks() -> void:
	var test_name = "ValidationResult severity checks"
	var error = ValidationResult.new(ValidationResult.Severity.ERROR, "Error")
	var warning = ValidationResult.new(ValidationResult.Severity.WARNING, "Warning")
	var info = ValidationResult.new(ValidationResult.Severity.INFO, "Info")
	
	assert_true(error.is_error(), "Should identify as error", test_name)
	assert_false(error.is_warning(), "Should not identify as warning", test_name)
	
	assert_true(warning.is_warning(), "Should identify as warning", test_name)
	assert_false(warning.is_error(), "Should not identify as error", test_name)
	
	assert_true(info.is_info(), "Should identify as info", test_name)

func test_validation_result_to_string() -> void:
	var test_name = "ValidationResult to_string"
	var result = ValidationResult.new(ValidationResult.Severity.ERROR, "Test message")
	var result_str = result.to_string()
	
	assert_true(result_str.contains("ERROR"), "Should contain severity", test_name)
	assert_true(result_str.contains("Test message"), "Should contain message", test_name)

## ============================================================================
## TILE VALIDATOR TESTS
## ============================================================================

func test_tile_validator_empty_name() -> void:
	var test_name = "TileValidator detects empty name"
	var tile = Tile.new()
	tile.name = ""
	tile.size = Vector3i.ONE
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	var has_name_error = false
	for result in results:
		if result.is_error() and result.message.contains("name"):
			has_name_error = true
			break
	
	assert_true(has_name_error, "Should detect empty tile name", test_name)

func test_tile_validator_invalid_size() -> void:
	var test_name = "TileValidator detects invalid size"
	var tile = Tile.new()
	tile.name = "TestTile"
	tile.size = Vector3i(-1, 1, 1)
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	var has_size_error = false
	for result in results:
		if result.is_error() and result.message.contains("size"):
			has_size_error = true
			break
	
	assert_true(has_size_error, "Should detect invalid tile size", test_name)

func test_tile_validator_invalid_weight() -> void:
	var test_name = "TileValidator detects high weight"
	var tile = _create_basic_tile("TestTile")
	tile.weight = 75.0  # High weight should trigger info message
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	# Note: Weight setter clamps to minimum 0.01, so we test high weight instead
	var has_weight_info = false
	for result in results:
		if result.severity == ValidationResult.Severity.INFO and result.message.contains("weight"):
			has_weight_info = true
			break
	
	assert_true(has_weight_info, "Should detect high weight", test_name)

func test_tile_validator_no_sockets() -> void:
	var test_name = "TileValidator detects missing sockets"
	var tile = Tile.new()
	tile.name = "TestTile"
	tile.size = Vector3i.ONE
	tile.sockets.clear()
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	var has_socket_error = false
	for result in results:
		if result.is_error() and result.message.contains("socket"):
			has_socket_error = true
			break
	
	assert_true(has_socket_error, "Should detect missing sockets", test_name)

func test_tile_validator_valid_tile() -> void:
	var test_name = "TileValidator accepts valid tile"
	var tile = _create_basic_tile("ValidTile")
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	var has_errors = false
	for result in results:
		if result.is_error():
			has_errors = true
			break
	
	assert_false(has_errors, "Valid tile should have no errors", test_name)

func test_tile_validator_duplicate_socket_directions() -> void:
	var test_name = "TileValidator detects duplicate socket directions"
	var tile = _create_basic_tile("TestTile")
	
	var socket_type = SocketType.new()
	socket_type.type_id = "test"
	
	# Add duplicate socket in same direction
	var duplicate_socket = Socket.new()
	duplicate_socket.direction = Vector3i.RIGHT
	duplicate_socket.socket_type = socket_type
	tile.sockets.append(duplicate_socket)
	
	var validator = TileValidator.new()
	var results = validator.validate(tile)
	
	var has_duplicate_warning = false
	for result in results:
		if result.is_warning() and result.message.contains("Multiple sockets"):
			has_duplicate_warning = true
			break
	
	assert_true(has_duplicate_warning, "Should detect duplicate socket directions", test_name)

## ============================================================================
## LIBRARY VALIDATOR TESTS
## ============================================================================

func test_library_validator_empty_library() -> void:
	var test_name = "LibraryValidator detects empty library"
	var library = ModuleLibrary.new()
	library.tiles.clear()
	
	var validator = LibraryValidator.new()
	var results = validator.validate(library)
	
	var has_tile_error = false
	for result in results:
		if result.is_error() and result.message.contains("no tiles"):
			has_tile_error = true
			break
	
	assert_true(has_tile_error, "Should detect empty tile list", test_name)

func test_library_validator_duplicate_tile_names() -> void:
	var test_name = "LibraryValidator detects duplicate tile names"
	var library = ModuleLibrary.new()
	
	var tile1 = _create_basic_tile("DuplicateName")
	var tile2 = _create_basic_tile("DuplicateName")
	
	library.tiles.append(tile1)
	library.tiles.append(tile2)
	library.socket_types.append(_create_socket_type("any"))
	
	var validator = LibraryValidator.new()
	var results = validator.validate(library)
	
	var has_duplicate_error = false
	for result in results:
		if result.is_error() and result.message.contains("Duplicate"):
			has_duplicate_error = true
			break
	
	assert_true(has_duplicate_error, "Should detect duplicate tile names", test_name)

func test_library_validator_no_socket_types() -> void:
	var test_name = "LibraryValidator detects missing socket types"
	var library = ModuleLibrary.new()
	library.tiles.append(_create_basic_tile("TestTile"))
	library.socket_types.clear()
	
	var validator = LibraryValidator.new()
	var results = validator.validate(library)
	
	var has_socket_type_error = false
	for result in results:
		if result.is_error() and result.message.contains("no socket types"):
			has_socket_type_error = true
			break
	
	assert_true(has_socket_type_error, "Should detect missing socket types", test_name)

func test_library_validator_unused_socket_types() -> void:
	var test_name = "LibraryValidator detects unused socket types"
	var library = ModuleLibrary.new()
	
	var tile = _create_basic_tile("TestTile")
	library.tiles.append(tile)
	
	# Add an extra socket type that's not used
	var used_type = _create_socket_type("used")
	var unused_type = _create_socket_type("unused")
	library.socket_types.assign([used_type, unused_type])
	
	# Make sure tile uses 'used' type
	for socket in tile.sockets:
		socket.socket_type = used_type
	
	var validator = LibraryValidator.new()
	var results = validator.validate(library)
	
	var has_unused_warning = false
	for result in results:
		if result.is_warning() and result.message.contains("not used"):
			has_unused_warning = true
			break
	
	assert_true(has_unused_warning, "Should detect unused socket types", test_name)

func test_library_validator_isolated_tiles() -> void:
	var test_name = "LibraryValidator detects isolated tiles"
	var library = ModuleLibrary.new()
	
	var socket_type1 = _create_socket_type("type1")
	var socket_type2 = _create_socket_type("type2")
	
	var tile1 = _create_basic_tile("Tile1")
	var tile2 = _create_basic_tile("Tile2")
	
	# Give tiles different socket types so they can't connect
	for socket in tile1.sockets:
		socket.socket_type = socket_type1
	for socket in tile2.sockets:
		socket.socket_type = socket_type2
	
	library.tiles.append(tile1)
	library.tiles.append(tile2)
	library.socket_types.assign([socket_type1, socket_type2])
	
	var validator = LibraryValidator.new()
	var results = validator.validate(library)
	
	var has_isolated_warning = false
	for result in results:
		if result.is_warning() and result.message.contains("cannot connect"):
			has_isolated_warning = true
			break
	
	assert_true(has_isolated_warning, "Should detect isolated tiles", test_name)

## ============================================================================
## REQUIREMENT VALIDATOR TESTS
## ============================================================================

func test_requirement_validator_height_negative() -> void:
	var test_name = "RequirementValidator detects negative height"
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.EXACT
	req.height_value = -5
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("negative"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect negative height", test_name)

func test_requirement_validator_height_range_invalid() -> void:
	var test_name = "RequirementValidator detects invalid height range"
	var req = HeightRequirement.new()
	req.mode = HeightRequirement.HeightMode.RANGE
	req.min_height = 10
	req.max_height = 5
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("greater than"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect invalid height range", test_name)

func test_requirement_validator_max_count_zero() -> void:
	var test_name = "RequirementValidator detects zero max count"
	var req = MaxCountRequirement.new()
	req.max_count = 0
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("positive"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect zero max count", test_name)

func test_requirement_validator_adjacent_no_tags() -> void:
	var test_name = "RequirementValidator detects adjacent requirement with no tags"
	var req = AdjacentRequirement.new()
	req.required_tags.clear()
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("no required tags"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect missing required tags", test_name)

func test_requirement_validator_tag_no_tags() -> void:
	var test_name = "RequirementValidator detects tag requirement with no tags"
	var req = TagRequirement.new()
	req.required_tags.clear()
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("no required tags"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect missing required tags", test_name)

func test_requirement_validator_boundary_no_axes() -> void:
	var test_name = "RequirementValidator detects boundary requirement with no axes"
	var req = BoundaryRequirement.new()
	req.check_x_boundaries = false
	req.check_y_boundaries = false
	req.check_z_boundaries = false
	
	var validator = RequirementValidator.new()
	var results = validator.validate(req)
	
	var has_error = false
	for result in results:
		if result.is_error() and result.message.contains("no axes"):
			has_error = true
			break
	
	assert_true(has_error, "Should detect no axes checked", test_name)

## ============================================================================
## VALIDATION MANAGER TESTS
## ============================================================================

func test_validation_manager_validate_tile() -> void:
	var test_name = "ValidationManager validates tile"
	var manager = ValidationManager.new()
	var tile = _create_basic_tile("TestTile")
	
	var results = manager.validate(tile)
	
	assert_not_null(results, "Should return results", test_name)
	assert_false(manager.has_errors(), "Valid tile should have no errors", test_name)

func test_validation_manager_validate_library_deep() -> void:
	var test_name = "ValidationManager validates library deeply"
	var manager = ValidationManager.new()
	var library = ModuleLibrary.new()
	
	var tile = _create_basic_tile("TestTile")
	library.tiles.append(tile)
	library.socket_types.append(_create_socket_type("any"))
	
	var results = manager.validate_library_deep(library)
	
	assert_not_null(results, "Should return results", test_name)

func test_validation_manager_filtering() -> void:
	var test_name = "ValidationManager filters results by severity"
	var manager = ValidationManager.new()
	
	# Create a tile with issues
	var tile = Tile.new()
	tile.name = ""  # Will cause error
	tile.size = Vector3i.ONE
	tile.weight = 75.0  # Will cause info
	tile.sockets.clear()  # Will cause error
	
	manager.validate(tile)
	
	var errors = manager.get_errors()
	var warnings = manager.get_warnings()
	
	assert_true(errors.size() > 0, "Should have errors", test_name)
	assert_true(manager.has_errors(), "Should detect errors", test_name)

## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _create_basic_tile(tile_name: String) -> Tile:
	var tile = Tile.new()
	tile.name = tile_name
	tile.size = Vector3i.ONE
	tile.weight = 1.0
	
	var socket_type = _create_socket_type("any")
	
	# Add basic sockets in all 6 directions
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP, Vector3i.DOWN]:
		var socket = Socket.new()
		socket.direction = dir
		socket.socket_type = socket_type
		tile.sockets.append(socket)
	
	return tile

func _create_socket_type(type_id: String) -> SocketType:
	var socket_type = SocketType.new()
	socket_type.type_id = type_id
	return socket_type

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

func assert_not_null(value, message: String, test_name: String) -> void:
	assert_true(value != null, message, test_name)

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
