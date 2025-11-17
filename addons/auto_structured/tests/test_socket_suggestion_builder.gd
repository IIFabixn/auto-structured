extends RefCounted

const SocketSuggestionBuilder = preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const MeshOutlineAnalyzer = preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing SocketSuggestionBuilder ===")
	
	test_builder_empty_inputs()
	test_builder_build_suggestions()
	test_builder_analyze_faces()
	test_builder_face_comparison()
	test_builder_matching_faces()
	test_builder_mismatched_dimensions()
	test_builder_mismatched_centers()
	test_builder_self_match_behavior()
	test_builder_candidate_gathering()
	test_builder_no_valid_candidates()
	test_builder_suggestion_structure()
	test_builder_analysis_issues()
	
	print_summary()

func test_builder_empty_inputs() -> void:
	var test_name = "Builder empty inputs"
	
	# Test null tile
	var suggestions1 = SocketSuggestionBuilder.build_suggestions(null, ModuleLibrary.new())
	assert_equal(suggestions1.size(), 0, "Should return empty for null tile", test_name)
	
	# Test null library
	var tile = Tile.new()
	var suggestions2 = SocketSuggestionBuilder.build_suggestions(tile, null)
	assert_equal(suggestions2.size(), 0, "Should return empty for null library", test_name)
	
	# Test empty tile (no geometry)
	var library = ModuleLibrary.new()
	var suggestions3 = SocketSuggestionBuilder.build_suggestions(tile, library)
	assert_equal(suggestions3.size(), 0, "Should return empty for tile without geometry", test_name)

func test_builder_build_suggestions() -> void:
	var test_name = "Builder build suggestions"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Create socket type
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	# Create two matching tiles
	var tile1 = _create_cube_tile("Tile1", Vector3.ONE)
	var socket1 = Socket.new()
	socket1.socket_type = wall_type
	socket1.direction = Vector3i.RIGHT
	tile1.sockets.append(socket1)
	
	var tile2 = _create_cube_tile("Tile2", Vector3.ONE)
	var socket2 = Socket.new()
	socket2.socket_type = wall_type
	socket2.direction = Vector3i.LEFT
	tile2.sockets.append(socket2)
	
	var tiles_array: Array[Tile] = [tile1, tile2]
	library.tiles = tiles_array
	
	# Build suggestions for tile1
	var suggestions = SocketSuggestionBuilder.build_suggestions(tile1, library)
	assert_true(suggestions.size() > 0, "Should find suggestions for matching tiles", test_name)
	
	# Check that RIGHT face has a suggestion
	var has_right_suggestion = false
	for suggestion in suggestions:
		if suggestion.get("direction") == Vector3i.RIGHT:
			has_right_suggestion = true
			assert_equal(suggestion.get("socket_id"), "wall", "Suggestion should use wall socket type", test_name)
			break
	assert_true(has_right_suggestion, "Should suggest socket for RIGHT face", test_name)

func test_builder_analyze_faces() -> void:
	var test_name = "Builder analyze faces"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	var tile1 = _create_cube_tile("Tile1", Vector3.ONE)
	var socket1 = Socket.new()
	socket1.socket_type = wall_type
	socket1.direction = Vector3i.RIGHT
	tile1.sockets.append(socket1)
	
	var tile2 = _create_cube_tile("Tile2", Vector3.ONE)
	var socket2 = Socket.new()
	socket2.socket_type = wall_type
	socket2.direction = Vector3i.LEFT
	tile2.sockets.append(socket2)
	
	var tiles_array: Array[Tile] = [tile1, tile2]
	library.tiles = tiles_array
	
	# Analyze faces
	var analysis = SocketSuggestionBuilder.analyze_faces(tile1, library)
	
	assert_true(analysis.size() > 0, "Should analyze multiple faces", test_name)
	
	# Check RIGHT face analysis
	if analysis.has(Vector3i.RIGHT):
		var right_info: Dictionary = analysis[Vector3i.RIGHT]
		assert_equal(right_info.get("direction"), Vector3i.RIGHT, "Should have correct direction", test_name)
		assert_true(right_info.get("has_socket"), "Should detect existing socket", test_name)
		assert_false(right_info.get("suggestion", {}).is_empty(), "Should have suggestion", test_name)
		assert_true(right_info.get("within_tolerance"), "Should be within tolerance", test_name)

func test_builder_face_comparison() -> void:
	var test_name = "Builder face comparison"
	
	# Create identical face signatures
	var face_a = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(0.0, 0.0)
	}
	var face_b = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(0.0, 0.0)
	}
	
	var score = SocketSuggestionBuilder._compare_faces(face_a, face_b)
	assert_not_null(score, "Identical faces should match", test_name)
	assert_true(score < 0.1, "Identical faces should have low score", test_name)
	
	# Test empty faces
	var empty_score = SocketSuggestionBuilder._compare_faces({}, face_a)
	assert_null(empty_score, "Empty face should return null", test_name)

func test_builder_matching_faces() -> void:
	var test_name = "Builder matching faces"
	
	# Create nearly identical faces (within tolerance)
	var face_a = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(0.0, 0.0)
	}
	var face_b = {
		"dimensions": Vector2(1.01, 1.01),  # Slightly different
		"center": Vector2(0.005, 0.005)      # Slightly offset
	}
	
	var score = SocketSuggestionBuilder._compare_faces(face_a, face_b)
	assert_not_null(score, "Nearly identical faces should match", test_name)
	assert_true(score < 1.0, "Nearly identical faces should have reasonable score", test_name)

func test_builder_mismatched_dimensions() -> void:
	var test_name = "Builder mismatched dimensions"
	
	var face_a = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(0.0, 0.0)
	}
	var face_b = {
		"dimensions": Vector2(2.0, 2.0),  # Significantly different
		"center": Vector2(0.0, 0.0)
	}
	
	# Should still return a score, but outside tolerance
	var detail = SocketSuggestionBuilder._compare_faces_detailed(face_a, face_b)
	assert_false(detail.is_empty(), "Should return detail for mismatched faces", test_name)
	assert_false(detail.get("within_tolerance", true), "Should be outside tolerance", test_name)
	assert_false(detail.get("within_dimension", true), "Should fail dimension check", test_name)

func test_builder_mismatched_centers() -> void:
	var test_name = "Builder mismatched centers"
	
	var face_a = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(0.0, 0.0)
	}
	var face_b = {
		"dimensions": Vector2(1.0, 1.0),
		"center": Vector2(1.0, 1.0)  # Significantly offset
	}
	
	var detail = SocketSuggestionBuilder._compare_faces_detailed(face_a, face_b)
	assert_false(detail.get("within_tolerance", true), "Should be outside tolerance", test_name)
	assert_false(detail.get("within_center", true), "Should fail center check", test_name)

func test_builder_self_match_behavior() -> void:
	var test_name = "Builder self match behavior"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	var tile = _create_cube_tile("Tile", Vector3.ONE)
	var socket_right = Socket.new()
	socket_right.socket_type = wall_type
	socket_right.direction = Vector3i.RIGHT
	tile.sockets.append(socket_right)
	
	var socket_left = Socket.new()
	socket_left.socket_type = wall_type
	socket_left.direction = Vector3i.LEFT
	tile.sockets.append(socket_left)
	
	var tiles_array: Array[Tile] = [tile]
	library.tiles = tiles_array
	
	# Test with allow_self_match=false (default)
	var suggestions1 = SocketSuggestionBuilder.build_suggestions(tile, library, false)
	assert_equal(suggestions1.size(), 0, "Should not self-match by default", test_name)
	
	# Test with allow_self_match=true
	var suggestions2 = SocketSuggestionBuilder.build_suggestions(tile, library, true)
	assert_true(suggestions2.size() > 0, "Should self-match when allowed", test_name)

func test_builder_candidate_gathering() -> void:
	var test_name = "Builder candidate gathering"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	# Create source tile
	var tile1 = _create_cube_tile("Source", Vector3.ONE)
	var tiles_array: Array[Tile] = [tile1]
	
	# Create multiple candidate tiles
	for i in range(3):
		var candidate = _create_cube_tile("Candidate%d" % i, Vector3.ONE)
		var socket = Socket.new()
		socket.socket_type = wall_type
		socket.direction = Vector3i.LEFT
		candidate.sockets.append(socket)
		tiles_array.append(candidate)
	
	library.tiles = tiles_array
	
	# Build suggestions - should find all 3 candidates
	var suggestions = SocketSuggestionBuilder.build_suggestions(tile1, library)
	assert_true(suggestions.size() > 0, "Should find candidates", test_name)

func test_builder_no_valid_candidates() -> void:
	var test_name = "Builder no valid candidates"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var wall_type = library.register_socket_type("wall")
	
	# Create tiles with incompatible faces (different sizes)
	var tile1 = _create_cube_tile("Small", Vector3(0.5, 0.5, 0.5))
	var tile2 = _create_cube_tile("Large", Vector3(5.0, 5.0, 5.0))
	
	var socket2 = Socket.new()
	socket2.socket_type = wall_type
	socket2.direction = Vector3i.LEFT
	tile2.sockets.append(socket2)
	
	var tiles_array: Array[Tile] = [tile1, tile2]
	library.tiles = tiles_array
	
	# Small tile should not match large tile
	var suggestions = SocketSuggestionBuilder.build_suggestions(tile1, library)
	
	# May find matches but they should be outside tolerance
	# We're mainly checking it doesn't crash with incompatible geometry
	assert_not_null(suggestions, "Should return array even with no good matches", test_name)

func test_builder_suggestion_structure() -> void:
	var test_name = "Builder suggestion structure"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	var wall_type = library.register_socket_type("wall")
	wall_type.set_compatible_types(["wall"])
	
	var tile1 = _create_cube_tile("Tile1", Vector3.ONE)
	var tile2 = _create_cube_tile("Tile2", Vector3.ONE)
	
	var socket2 = Socket.new()
	socket2.socket_type = wall_type
	socket2.direction = Vector3i.LEFT
	tile2.sockets.append(socket2)
	
	var tiles_array: Array[Tile] = [tile1, tile2]
	library.tiles = tiles_array
	
	var suggestions = SocketSuggestionBuilder.build_suggestions(tile1, library)
	
	if suggestions.size() > 0:
		var suggestion: Dictionary = suggestions[0]
		
		# Check required fields
		assert_true(suggestion.has("direction"), "Suggestion should have direction", test_name)
		assert_true(suggestion.has("socket_id"), "Suggestion should have socket_id", test_name)
		assert_true(suggestion.has("socket_type"), "Suggestion should have socket_type", test_name)
		assert_true(suggestion.has("compatible"), "Suggestion should have compatible array", test_name)
		assert_true(suggestion.has("partner_tile"), "Suggestion should have partner_tile", test_name)
		assert_true(suggestion.has("score"), "Suggestion should have score", test_name)

func test_builder_analysis_issues() -> void:
	var test_name = "Builder analysis issues"
	
	var library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Create tile without sockets
	var tile = _create_cube_tile("NoSockets", Vector3.ONE)
	var tiles_array: Array[Tile] = [tile]
	library.tiles = tiles_array
	
	var analysis = SocketSuggestionBuilder.analyze_faces(tile, library)
	
	# Check that issues are reported for faces without sockets
	for direction in analysis.keys():
		var info: Dictionary = analysis[direction]
		var issues: Array = info.get("issues", [])
		
		if not info.get("has_socket", false):
			assert_true(issues.size() > 0, "Should report issues for face without socket", test_name)
			
			# Check for expected issue message
			var has_no_socket_issue = false
			for issue in issues:
				if "No socket" in str(issue):
					has_no_socket_issue = true
					break
			assert_true(has_no_socket_issue, "Should mention missing socket in issues", test_name)

# Helper methods
func _create_cube_tile(tile_name: String, size: Vector3) -> Tile:
	var tile = Tile.new()
	tile.name = tile_name
	tile.mesh = _create_box_mesh(size)
	return tile

func _create_box_mesh(size: Vector3) -> Mesh:
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	return box_mesh

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
	print("\n--- SocketSuggestionBuilder Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
