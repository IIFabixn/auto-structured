extends RefCounted

const LibraryExporter = preload("res://addons/auto_structured/core/io/library_exporter.gd")
const LibraryImporter = preload("res://addons/auto_structured/core/io/library_importer.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0
var test_dir = "user://test_exports/"

func run_all_tests() -> void:
	print("=== Testing Import/Export System ===")
	
	# Setup
	DirAccess.make_dir_recursive_absolute(test_dir)
	
	# Run tests
	test_export_resource()
	test_export_json()
	test_import_resource()
	test_import_json()
	test_roundtrip()
	test_markdown_export()
	
	# Cleanup
	cleanup_test_files()
	
	print_summary()

func cleanup_test_files():
	var dir = DirAccess.open(test_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func create_test_library() -> ModuleLibrary:
	var library = ModuleLibrary.new()
	library.library_name = "Test Library"
	library.cell_world_size = Vector3(2.0, 2.0, 2.0)
	
	# Create socket types
	var wall_socket = SocketType.new()
	wall_socket.type_id = "wall"
	wall_socket.display_name = "Wall"
	wall_socket.compatible_types.append("wall")
	library.socket_types.append(wall_socket)
	
	# Create test tile
	var tile = Tile.new()
	tile.name = "Wall Piece"
	tile.size = Vector3i(1, 2, 1)
	tile.weight = 10.0
	tile.rotation_symmetry = Tile.RotationSymmetry.HALF
	tile.tags.append("wall")
	tile.tags.append("structure")
	
	# Add socket
	var socket1 = Socket.new()
	socket1.direction = Vector3i.RIGHT
	socket1.socket_type = wall_socket
	tile.sockets.append(socket1)
	
	library.tiles.append(tile)
	
	return library

## ============================================================================
## EXPORT TESTS
## ============================================================================

func test_export_resource():
	var test_name = "Export as resource"
	var library = create_test_library()
	var file_path = test_dir + "test_library.tres"
	
	var error = LibraryExporter.export_library(library, file_path, LibraryExporter.ExportFormat.GODOT_RESOURCE)
	
	assert_equal(error, OK, "Export should succeed", test_name)
	assert_true(FileAccess.file_exists(file_path), "File should exist", test_name)

func test_export_json():
	var test_name = "Export as JSON"
	var library = create_test_library()
	var file_path = test_dir + "test_library.json"
	
	var error = LibraryExporter.export_library(library, file_path, LibraryExporter.ExportFormat.JSON)
	assert_equal(error, OK, "Export should succeed", test_name)
	assert_true(FileAccess.file_exists(file_path), "JSON file should exist", test_name)
	
	# Verify JSON structure
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var data = json.data
	assert_true(data.has("library_name"), "Should have library_name", test_name)
	assert_true(data.has("tiles"), "Should have tiles", test_name)
	assert_equal(data["library_name"], "Test Library", "Library name should match", test_name)

func test_markdown_export():
	var test_name = "Export as Markdown"
	var library = create_test_library()
	var file_path = test_dir + "test_library.md"
	
	var error = LibraryExporter.export_library(library, file_path, LibraryExporter.ExportFormat.MARKDOWN)
	assert_equal(error, OK, "Export should succeed", test_name)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	assert_true(content.contains("# Test Library"), "Should have library name as heading", test_name)
	assert_true(content.contains("Wall Piece"), "Should contain tile name", test_name)

## ============================================================================
## IMPORT TESTS
## ============================================================================

func test_import_resource():
	var test_name = "Import from resource"
	var library = create_test_library()
	var file_path = test_dir + "test_library.tres"
	
	# Export first
	LibraryExporter.export_library(library, file_path, LibraryExporter.ExportFormat.GODOT_RESOURCE)
	
	# Import
	var imported = LibraryImporter.import_library(file_path)
	
	assert_not_null(imported, "Import should succeed", test_name)
	assert_equal(imported.library_name, "Test Library", "Library name should match", test_name)
	assert_equal(imported.tiles.size(), 1, "Should have one tile", test_name)

func test_import_json():
	var test_name = "Import from JSON"
	var library = create_test_library()
	var file_path = test_dir + "test_library.json"
	
	# Export first
	LibraryExporter.export_library(library, file_path, LibraryExporter.ExportFormat.JSON)
	
	# Import
	var imported = LibraryImporter.import_library(file_path)
	
	assert_not_null(imported, "Import should succeed", test_name)
	assert_equal(imported.library_name, "Test Library", "Library name should match", test_name)
	assert_equal(imported.tiles.size(), 1, "Should have one tile", test_name)
	assert_equal(imported.socket_types.size(), 1, "Should have one socket type", test_name)

func test_roundtrip():
	var test_name = "Roundtrip JSON export and import"
	var original = create_test_library()
	var file_path = test_dir + "roundtrip.json"
	
	# Export
	LibraryExporter.export_library(original, file_path, LibraryExporter.ExportFormat.JSON)
	
	# Import
	var imported = LibraryImporter.import_library(file_path)
	
	# Verify
	assert_not_null(imported, "Import should succeed", test_name)
	assert_equal(imported.library_name, original.library_name, "Library name should match", test_name)
	assert_equal(imported.tiles.size(), original.tiles.size(), "Tile count should match", test_name)
	
	# Check tile details
	var orig_tile = original.tiles[0]
	var imp_tile = imported.tiles[0]
	assert_equal(imp_tile.name, orig_tile.name, "Tile names should match", test_name)
	assert_equal(imp_tile.weight, orig_tile.weight, "Tile weights should match", test_name)
	assert_equal(imp_tile.size, orig_tile.size, "Tile sizes should match", test_name)

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
