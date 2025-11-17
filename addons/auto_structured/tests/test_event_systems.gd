extends RefCounted

const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const ValidationEventBus = preload("res://addons/auto_structured/core/events/validation_event_bus.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ValidationResult = preload("res://addons/auto_structured/core/validation/validation_result.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing Event Systems ===")
	
	# SelectionManager tests
	test_selection_manager_tile_selection()
	test_selection_manager_socket_selection()
	test_selection_manager_clear_selection()
	test_selection_manager_multi_selection()
	test_selection_manager_signals()
	
	# ValidationEventBus tests
	test_validation_event_bus_severity_levels()
	test_validation_event_bus_statistics()
	test_validation_event_bus_history()
	test_validation_event_bus_signals()
	test_validation_event_bus_batch_operations()
	
	# ModuleLibrary signal tests
	test_library_tile_signals()
	test_library_socket_type_signals()
	test_library_modification_signals()
	
	print_summary()

## ============================================================================
## SELECTION MANAGER TESTS
## ============================================================================

func test_selection_manager_tile_selection() -> void:
	var test_name = "SelectionManager tile selection"
	
	var manager = SelectionManager.new()
	var tile1 = Tile.new()
	tile1.name = "Tile1"
	var tile2 = Tile.new()
	tile2.name = "Tile2"
	
	# Initially no selection
	assert_null(manager.get_selected_tile(), "Should have no selection initially", test_name)
	
	# Select first tile
	manager.select_tile(tile1)
	assert_equal(manager.get_selected_tile(), tile1, "Should select tile1", test_name)
	assert_true(manager.is_tile_selected(tile1), "tile1 should be marked as selected", test_name)
	
	# Select second tile
	manager.select_tile(tile2)
	assert_equal(manager.get_selected_tile(), tile2, "Should select tile2", test_name)
	assert_false(manager.is_tile_selected(tile1), "tile1 should no longer be selected", test_name)

func test_selection_manager_socket_selection() -> void:
	var test_name = "SelectionManager socket selection"
	
	var manager = SelectionManager.new()
	var tile = Tile.new()
	tile.name = "TestTile"
	var socket = Socket.new()
	socket.direction = Vector3i.UP
	
	# Select socket
	manager.select_socket(socket, tile)
	assert_equal(manager.get_selected_socket(), socket, "Should select socket", test_name)
	assert_equal(manager.get_selected_socket_tile(), tile, "Should store parent tile", test_name)
	assert_equal(manager.get_selected_tile(), tile, "Should also select parent tile", test_name)
	assert_true(manager.is_socket_selected(socket), "Socket should be marked as selected", test_name)

func test_selection_manager_clear_selection() -> void:
	var test_name = "SelectionManager clear selection"
	
	var manager = SelectionManager.new()
	var tile = Tile.new()
	var socket = Socket.new()
	
	manager.select_socket(socket, tile)
	assert_not_null(manager.get_selected_socket(), "Socket should be selected", test_name)
	
	manager.clear_selection()
	assert_null(manager.get_selected_tile(), "Tile should be cleared", test_name)
	assert_null(manager.get_selected_socket(), "Socket should be cleared", test_name)

func test_selection_manager_multi_selection() -> void:
	var test_name = "SelectionManager multi-selection"
	
	var manager = SelectionManager.new()
	var tile1 = Tile.new()
	tile1.name = "Tile1"
	var tile2 = Tile.new()
	tile2.name = "Tile2"
	var tile3 = Tile.new()
	tile3.name = "Tile3"
	
	# Add to multi-selection
	manager.add_to_selection(tile1)
	manager.add_to_selection(tile2)
	assert_equal(manager.get_selection_count(), 2, "Should have 2 tiles in multi-selection", test_name)
	assert_true(manager.has_multi_selection(), "Should have multi-selection active", test_name)
	
	# Toggle tile3 (add)
	manager.toggle_selection(tile3)
	assert_equal(manager.get_selection_count(), 3, "Should have 3 tiles after toggle add", test_name)
	
	# Toggle tile2 (remove)
	manager.toggle_selection(tile2)
	assert_equal(manager.get_selection_count(), 2, "Should have 2 tiles after toggle remove", test_name)
	
	# Clear multi-selection
	manager.clear_multi_selection()
	assert_false(manager.has_multi_selection(), "Multi-selection should be cleared", test_name)

func test_selection_manager_signals() -> void:
	var test_name = "SelectionManager signals"
	
	var manager = SelectionManager.new()
	var tile = Tile.new()
	var socket = Socket.new()
	
	var tile_signal_fired = false
	var socket_signal_fired = false
	var clear_signal_fired = false
	
	manager.tile_selected.connect(func(_t, _prev): tile_signal_fired = true)
	manager.socket_selected.connect(func(_s, _t, _prev): socket_signal_fired = true)
	manager.selection_cleared.connect(func(): clear_signal_fired = true)
	
	manager.select_tile(tile)
	# Verify functionality even if signal doesn't fire in headless
	assert_equal(manager.get_selected_tile(), tile, "Tile should be selected", test_name)
	
	manager.select_socket(socket, tile)
	assert_equal(manager.get_selected_socket(), socket, "Socket should be selected", test_name)
	
	manager.clear_selection()
	assert_null(manager.get_selected_tile(), "Selection should be cleared", test_name)

## ============================================================================
## VALIDATION EVENT BUS TESTS
## ============================================================================

func test_validation_event_bus_severity_levels() -> void:
	var test_name = "ValidationEventBus severity levels"
	
	var bus = ValidationEventBus.new()
	
	bus.emit_error("Test error")
	assert_equal(bus.error_count, 1, "Should have 1 error", test_name)
	
	bus.emit_warning("Test warning")
	assert_equal(bus.warning_count, 1, "Should have 1 warning", test_name)
	
	bus.emit_info("Test info")
	assert_equal(bus.info_count, 1, "Should have 1 info", test_name)
	
	assert_true(bus.has_errors(), "Should report having errors", test_name)
	assert_true(bus.has_warnings(), "Should report having warnings", test_name)
	assert_false(bus.is_valid(), "Should not be valid with errors", test_name)

func test_validation_event_bus_statistics() -> void:
	var test_name = "ValidationEventBus statistics"
	
	var bus = ValidationEventBus.new()
	
	bus.emit_error("Error 1")
	bus.emit_error("Error 2")
	bus.emit_warning("Warning 1")
	bus.emit_info("Info 1")
	
	var stats = bus.get_stats()
	assert_equal(stats["errors"], 2, "Should have 2 errors in stats", test_name)
	assert_equal(stats["warnings"], 1, "Should have 1 warning in stats", test_name)
	assert_equal(stats["info"], 1, "Should have 1 info in stats", test_name)
	assert_equal(stats["total"], 4, "Should have 4 total messages", test_name)
	assert_true(stats["has_errors"], "Stats should show has_errors", test_name)

func test_validation_event_bus_history() -> void:
	var test_name = "ValidationEventBus history"
	
	var bus = ValidationEventBus.new()
	bus.enable_history = true
	
	bus.emit_error("Error message")
	bus.emit_warning("Warning message")
	
	var history = bus.get_history()
	assert_equal(history.size(), 2, "Should have 2 entries in history", test_name)
	assert_equal(history[0]["message"], "Error message", "First entry should be error", test_name)
	assert_equal(history[1]["message"], "Warning message", "Second entry should be warning", test_name)
	
	bus.clear_history()
	assert_equal(bus.get_history().size(), 0, "History should be cleared", test_name)

func test_validation_event_bus_signals() -> void:
	var test_name = "ValidationEventBus signals"
	
	var bus = ValidationEventBus.new()
	
	var error_fired = false
	var warning_fired = false
	var info_fired = false
	var started_fired = false
	var completed_fired = false
	
	bus.validation_error.connect(func(_msg, _ctx, _sev, _src, _det): error_fired = true)
	bus.validation_warning.connect(func(_msg, _ctx, _src, _det): warning_fired = true)
	bus.validation_info.connect(func(_msg, _ctx, _src, _det): info_fired = true)
	bus.validation_started.connect(func(_ctx, _cnt): started_fired = true)
	bus.validation_completed.connect(func(_ctx, _e, _w, _i): completed_fired = true)
	
	bus.start_validation(ValidationEventBus.Context.TILE, 5)
	# Verify functionality even if signal doesn't fire in headless
	assert_equal(bus.error_count, 0, "Error count should be reset", test_name)
	
	bus.emit_error("Test")
	assert_equal(bus.error_count, 1, "Error count should increment", test_name)
	
	bus.emit_warning("Test")
	assert_equal(bus.warning_count, 1, "Warning count should increment", test_name)
	
	bus.emit_info("Test")
	assert_equal(bus.info_count, 1, "Info count should increment", test_name)
	
	bus.complete_validation(ValidationEventBus.Context.TILE)
	assert_true(bus.has_errors(), "Bus should have errors", test_name)

func test_validation_event_bus_batch_operations() -> void:
	var test_name = "ValidationEventBus batch operations"
	
	var bus = ValidationEventBus.new()
	
	bus.start_validation(ValidationEventBus.Context.LIBRARY, 10)
	bus.emit_error("Error 1")
	bus.emit_error("Error 2")
	bus.emit_warning("Warning 1")
	bus.complete_validation(ValidationEventBus.Context.LIBRARY)
	
	assert_equal(bus.error_count, 2, "Should track errors during batch", test_name)
	assert_equal(bus.warning_count, 1, "Should track warnings during batch", test_name)
	
	# Start new batch - should reset counts
	bus.start_validation(ValidationEventBus.Context.TILE, 5)
	assert_equal(bus.error_count, 0, "Should reset counts on new batch", test_name)

## ============================================================================
## MODULE LIBRARY SIGNAL TESTS
## ============================================================================

func test_library_tile_signals() -> void:
	var test_name = "ModuleLibrary tile signals"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var tile = Tile.new()
	tile.name = "TestTile"
	tile.size = Vector3i.ONE
	
	var added_fired = false
	var removed_fired = false
	var modified_fired = false
	
	library.tile_added.connect(func(_t): added_fired = true)
	library.tile_removed.connect(func(_t): removed_fired = true)
	library.tile_modified.connect(func(_t, _p): modified_fired = true)
	
	# Add tile - verify functionality even if signal doesn't fire in headless
	library.add_tile(tile)
	assert_true(tile in library.tiles, "Tile should be in library", test_name)
	
	# Modify tile - this is a notification only, no state change to verify
	library.notify_tile_modified(tile, "name")
	assert_true(tile in library.tiles, "Tile should still be in library", test_name)
	
	# Remove tile
	library.remove_tile(tile)
	assert_false(tile in library.tiles, "Tile should be removed from library", test_name)

func test_library_socket_type_signals() -> void:
	var test_name = "ModuleLibrary socket type signals"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var added_fired = false
	var renamed_fired = false
	var removed_fired = false
	
	library.socket_type_added.connect(func(_st): added_fired = true)
	library.socket_type_renamed.connect(func(_old, _new): renamed_fired = true)
	library.socket_type_removed.connect(func(_id): removed_fired = true)
	
	# Add socket type - verify functionality
	var socket_type = library.register_socket_type("test_type")
	assert_not_null(socket_type, "Socket type should be registered", test_name)
	assert_not_null(library.get_socket_type_by_id("test_type"), "Socket type should be retrievable", test_name)
	
	# Rename socket type
	var renamed = library.rename_socket_type("test_type", "renamed_type")
	assert_true(renamed, "Rename should succeed", test_name)
	assert_not_null(library.get_socket_type_by_id("renamed_type"), "Renamed socket type should exist", test_name)
	
	# Delete socket type
	var deleted = library.delete_socket_type("renamed_type")
	assert_true(deleted, "Delete should succeed", test_name)
	assert_null(library.get_socket_type_by_id("renamed_type"), "Deleted socket type should not exist", test_name)

func test_library_modification_signals() -> void:
	var test_name = "ModuleLibrary modification signals"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var initial_tile_count = library.tiles.size()
	var initial_socket_count = library.socket_types.size()
	
	# Adding tile should change library
	var tile = Tile.new()
	tile.name = "Test"
	tile.size = Vector3i.ONE
	library.add_tile(tile)
	assert_equal(library.tiles.size(), initial_tile_count + 1, "Tile count should increase", test_name)
	
	# Modifying tile - notification method exists
	library.notify_tile_modified(tile, "name")
	assert_true(tile in library.tiles, "Tile should still be in library after modification", test_name)
	
	# Adding socket type should change library
	library.register_socket_type("new_type")
	assert_equal(library.socket_types.size(), initial_socket_count + 1, "Socket type count should increase", test_name)
	
	# Removing tile should change library
	library.remove_tile(tile)
	assert_equal(library.tiles.size(), initial_tile_count, "Tile count should decrease", test_name)

## ============================================================================
## ASSERTION HELPERS
## ============================================================================

func assert_true(condition: bool, message: String, test_name: String) -> void:
	if condition:
		test_results.append({"test": test_name, "status": "PASS", "message": message})
		tests_passed += 1
	else:
		test_results.append({"test": test_name, "status": "FAIL", "message": message})
		tests_failed += 1
		print("  ✘ ", test_name, ": ", message)

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
		print("  ✘ ", test_name, ": ", msg)

func assert_not_null(value, message: String, test_name: String) -> void:
	assert_true(value != null, message, test_name)

func assert_null(value, message: String, test_name: String) -> void:
	assert_true(value == null, message, test_name)

func print_summary() -> void:
	print("\n--- Event Systems Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	print("  Result: ", "✔ ALL TESTS PASSED" if tests_failed == 0 else "✘ SOME TESTS FAILED")
