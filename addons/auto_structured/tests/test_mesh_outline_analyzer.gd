extends RefCounted

const MeshOutlineAnalyzer = preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0

func run_all_tests() -> void:
	print("=== Testing MeshOutlineAnalyzer ===")
	
	test_analyzer_empty_tile()
	test_analyzer_cube_faces()
	test_analyzer_face_dimensions()
	test_analyzer_face_center()
	test_analyzer_face_tolerance()
	test_analyzer_cache_behavior()
	test_analyzer_mesh_extraction()
	test_analyzer_face_point_count()
	test_analyzer_degenerate_faces()
	test_analyzer_non_uniform_scale()
	
	print_summary()

func test_analyzer_empty_tile() -> void:
	var test_name = "Analyzer empty tile"
	
	var tile = Tile.new()
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	assert_not_null(faces, "Should return dictionary for empty tile", test_name)
	assert_equal(faces.size(), 0, "Should have no faces for empty tile", test_name)
	
	# Test null tile
	var null_faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(null)
	assert_equal(null_faces.size(), 0, "Should return empty dict for null tile", test_name)

func test_analyzer_cube_faces() -> void:
	var test_name = "Analyzer cube faces"
	
	var tile = _create_cube_tile(Vector3.ONE)
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# A cube should have 6 faces
	assert_equal(faces.size(), 6, "Cube should have 6 faces", test_name)
	
	# Check all cardinal directions are present
	assert_true(faces.has(Vector3i.RIGHT), "Should have RIGHT face", test_name)
	assert_true(faces.has(Vector3i.LEFT), "Should have LEFT face", test_name)
	assert_true(faces.has(Vector3i.UP), "Should have UP face", test_name)
	assert_true(faces.has(Vector3i.DOWN), "Should have DOWN face", test_name)
	assert_true(faces.has(Vector3i.FORWARD), "Should have FORWARD face", test_name)
	assert_true(faces.has(Vector3i.BACK), "Should have BACK face", test_name)

func test_analyzer_face_dimensions() -> void:
	var test_name = "Analyzer face dimensions"
	
	# Create a 2x3x4 box
	var tile = _create_cube_tile(Vector3(2, 3, 4))
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# RIGHT/LEFT faces should be 3x4 (Y x Z)
	var right_face: Dictionary = faces.get(Vector3i.RIGHT, {})
	assert_false(right_face.is_empty(), "RIGHT face should exist", test_name)
	var right_dims: Vector2 = right_face.get("dimensions", Vector2.ZERO)
	assert_true(abs(right_dims.x - 3.0) < 0.1, "RIGHT face width should be ~3", test_name)
	assert_true(abs(right_dims.y - 4.0) < 0.1, "RIGHT face height should be ~4", test_name)
	
	# UP/DOWN faces should be 2x4 (X x Z)
	var up_face: Dictionary = faces.get(Vector3i.UP, {})
	var up_dims: Vector2 = up_face.get("dimensions", Vector2.ZERO)
	assert_true(abs(up_dims.x - 2.0) < 0.1, "UP face width should be ~2", test_name)
	assert_true(abs(up_dims.y - 4.0) < 0.1, "UP face height should be ~4", test_name)
	
	# FORWARD/BACK faces should be 2x3 (X x Y)
	var forward_face: Dictionary = faces.get(Vector3i.FORWARD, {})
	var forward_dims: Vector2 = forward_face.get("dimensions", Vector2.ZERO)
	assert_true(abs(forward_dims.x - 2.0) < 0.1, "FORWARD face width should be ~2", test_name)
	assert_true(abs(forward_dims.y - 3.0) < 0.1, "FORWARD face height should be ~3", test_name)

func test_analyzer_face_center() -> void:
	var test_name = "Analyzer face center"
	
	# Create a cube centered at origin
	var tile = _create_cube_tile(Vector3.ONE)
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# All faces should be centered around 0,0 in their plane
	for direction in faces.keys():
		var face: Dictionary = faces[direction]
		var center: Vector2 = face.get("center", Vector2(INF, INF))
		assert_true(abs(center.x) < 0.1, "Face center X should be ~0 for " + str(direction), test_name)
		assert_true(abs(center.y) < 0.1, "Face center Y should be ~0 for " + str(direction), test_name)

func test_analyzer_face_tolerance() -> void:
	var test_name = "Analyzer face tolerance"
	
	var tile = _create_cube_tile(Vector3.ONE)
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# Check that tolerance values are present and reasonable
	for direction in faces.keys():
		var face: Dictionary = faces[direction]
		var tolerance: float = face.get("tolerance", -1.0)
		assert_true(tolerance > 0.0, "Tolerance should be positive for " + str(direction), test_name)
		assert_true(tolerance < 1.0, "Tolerance should be reasonable for unit cube " + str(direction), test_name)

func test_analyzer_cache_behavior() -> void:
	var test_name = "Analyzer cache behavior"
	
	var tile = _create_cube_tile(Vector3.ONE)
	
	# First call should compute and cache
	var faces1 = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile, true)
	assert_true(tile._face_cache_valid, "Cache should be marked valid", test_name)
	assert_false(tile._cached_face_signatures.is_empty(), "Cached signatures should be stored", test_name)
	
	# Second call should return cached value
	var faces2 = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile, true)
	assert_equal(faces2, faces1, "Should return same cached result", test_name)
	
	# Call with use_cache=false should recompute
	tile._face_cache_valid = false
	var faces3 = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile, false)
	assert_equal(faces3.size(), faces1.size(), "Should have same number of faces", test_name)

func test_analyzer_mesh_extraction() -> void:
	var test_name = "Analyzer mesh extraction"
	
	var tile = Tile.new()
	
	# Test with no mesh or scene
	var faces1 = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	assert_equal(faces1.size(), 0, "Should have no faces without geometry", test_name)
	
	# Test with mesh
	tile.mesh = _create_box_mesh(Vector3.ONE)
	var faces2 = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	assert_true(faces2.size() > 0, "Should detect faces from mesh", test_name)
	
	# Note: PackedScene tests are skipped as scene packing is unreliable in test environment

func test_analyzer_face_point_count() -> void:
	var test_name = "Analyzer face point count"
	
	var tile = _create_cube_tile(Vector3.ONE)
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# Each face should have multiple points
	for direction in faces.keys():
		var face: Dictionary = faces[direction]
		var point_count: int = face.get("point_count", 0)
		assert_true(point_count >= 3, "Face should have at least 3 points for " + str(direction), test_name)

func test_analyzer_degenerate_faces() -> void:
	var test_name = "Analyzer degenerate faces"
	
	# Create a very thin flat mesh (degenerate in one dimension)
	var tile = _create_cube_tile(Vector3(1.0, 1.0, 0.00001))
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# Very thin meshes may have no valid faces or only some faces
	# The analyzer should handle this gracefully without crashing
	assert_not_null(faces, "Should return dict for degenerate geometry", test_name)
	
	# If any faces exist, they should have valid structure
	for direction in faces.keys():
		var face: Dictionary = faces[direction]
		assert_true(face.has("dimensions"), "Face should have dimensions", test_name)
		assert_true(face.has("center"), "Face should have center", test_name)

func test_analyzer_non_uniform_scale() -> void:
	var test_name = "Analyzer non-uniform scale"
	
	# This test verifies the analyzer handles meshes gracefully
	# Non-uniform scale warning is checked in actual usage with scene trees
	# For now, just verify basic mesh analysis doesn't crash
	var tile = _create_cube_tile(Vector3(1.0, 2.0, 1.0))  # Different dimensions
	var faces = MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	
	# Should still produce faces for non-uniform dimensions
	assert_true(faces.size() > 0, "Should analyze mesh with non-uniform dimensions", test_name)
	
	# Faces should have different dimensions
	if faces.has(Vector3i.UP):
		var up_dims: Vector2 = faces[Vector3i.UP].get("dimensions", Vector2.ZERO)
		assert_true(up_dims.x > 0 and up_dims.y > 0, "UP face should have positive dimensions", test_name)

# Helper methods to create test geometry
func _create_cube_tile(size: Vector3) -> Tile:
	var tile = Tile.new()
	tile.name = "TestCube"
	tile.mesh = _create_box_mesh(size)
	return tile

func _create_box_mesh(size: Vector3) -> Mesh:
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	return box_mesh

func _create_mesh_scene(size: Vector3) -> PackedScene:
	var scene = PackedScene.new()
	var root = Node3D.new()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _create_box_mesh(size)
	root.add_child(mesh_instance)
	scene.pack(root)
	root.free()
	return scene

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
	print("\n--- MeshOutlineAnalyzer Test Summary ---")
	print("  Passed: ", tests_passed)
	print("  Failed: ", tests_failed)
	print("  Total: ", tests_passed + tests_failed)
	if tests_failed == 0:
		print("  Result: ✓ ALL TESTS PASSED")
	else:
		print("  Result: ✗ SOME TESTS FAILED")
