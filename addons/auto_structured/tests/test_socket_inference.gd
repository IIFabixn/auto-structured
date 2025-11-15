extends RefCounted

const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const MeshOutlineAnalyzer := preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")
const SocketSuggestionBuilder := preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}
	_run_test(results, "Outline analyzer extracts face data", test_outline_face_capture)
	_run_test(results, "Suggestion builder matches floor clone", test_floor_clone_suggestions)
	return results

func _run_test(results: Dictionary, name: String, callable: Callable) -> void:
	results["total"] += 1
	var outcome = callable.call()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func test_outline_face_capture() -> Variant:
	var library: ModuleLibrary = ResourceLoader.load("res://module_library.tres")
	if library == null:
		return "Failed to load sample library"
	var floor_tile := library.get_tile_by_name("floor")
	if floor_tile == null:
		return "Sample library missing 'floor' tile"
	var signatures := MeshOutlineAnalyzer.get_face_signatures_for_tile(floor_tile)
	if signatures.is_empty():
		return "No face signatures returned"
	var right_sig: Dictionary = signatures.get(Vector3i.RIGHT, {})
	if right_sig.is_empty():
		return "Right face signature missing"
	var dims: Vector2 = right_sig.get("dimensions", Vector2.ZERO)
	if dims.x <= 0.0 or dims.y <= 0.0:
		return "Right face dimensions invalid: %s" % str(dims)
	return null

func test_floor_clone_suggestions() -> Variant:
	var library: ModuleLibrary = ResourceLoader.load("res://module_library.tres")
	if library == null:
		return "Failed to load sample library"
	var template_tile := library.get_tile_by_name("floor")
	if template_tile == null:
		return "Sample library missing 'floor' tile"
	var new_tile := Tile.new()
	new_tile.name = "floor_clone"
	new_tile.scene = template_tile.scene
	new_tile.mesh = template_tile.mesh
	var suggestions := SocketSuggestionBuilder.build_suggestions(new_tile, library)
	if suggestions.is_empty():
		return "Suggestion builder returned no results"
	var right_suggestion := _find_direction_suggestion(suggestions, Vector3i.RIGHT)
	if right_suggestion.is_empty():
		return "No suggestion generated for right direction"
	var socket_id := str(right_suggestion.get("socket_id", ""))
	if socket_id != "floor_side":
		return "Expected socket_id 'floor_side', got '%s'" % socket_id
	return null

func _find_direction_suggestion(suggestions: Array, direction: Vector3i) -> Dictionary:
	for suggestion in suggestions:
		var entry: Dictionary = suggestion
		if entry.get("direction", Vector3i.ZERO) == direction:
			return entry
	return {}
