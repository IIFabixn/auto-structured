extends SceneTree

const WfcSolverTests := preload("res://addons/auto_structured/tests/test_wfc_solver.gd")
const WfcStrategyTests := preload("res://addons/auto_structured/tests/test_wfc_strategies.gd")
const SocketTemplateTests := preload("res://addons/auto_structured/tests/test_socket_templates.gd")
const SocketConsistencyTests := preload("res://addons/auto_structured/tests/test_socket_consistency.gd")
const SocketInferenceTests := preload("res://addons/auto_structured/tests/test_socket_inference.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")

var _floor_scene: PackedScene = null

func _initialize() -> void:
	print("Running auto_structured test suite...\n")
	_ensure_sample_library()

	var solver_suite := WfcSolverTests.new()
	var solver_results := solver_suite.run_all()

	var strategy_suite := WfcStrategyTests.new()
	var strategy_results := strategy_suite.run_all()

	var template_suite := SocketTemplateTests.new()
	var template_results := template_suite.run_all()

	var consistency_suite := SocketConsistencyTests.new()
	var consistency_results := consistency_suite.run_all()

	var inference_suite := SocketInferenceTests.new()
	var inference_results := inference_suite.run_all()

	var total: int = int(solver_results["total"]) + int(strategy_results["total"]) + int(template_results["total"]) + int(consistency_results["total"]) + int(inference_results["total"])
	var failures: Array = []
	failures.append_array(solver_results["failures"])
	failures.append_array(strategy_results["failures"])
	failures.append_array(template_results["failures"])
	failures.append_array(consistency_results["failures"])
	failures.append_array(inference_results["failures"])

	if failures.is_empty():
		print("\nAll %d tests passed!" % total)
		quit(0)
	else:
		print("\n%d/%d tests failed:" % [failures.size(), total])
		for failure in failures:
			print("  - ", failure)
		quit(1)

func _ensure_sample_library() -> void:
	var library_path := "res://module_library.tres"
	var library: ModuleLibrary = ResourceLoader.load(library_path)
	var created_library := false
	if library == null:
		library = ModuleLibrary.new()
		library.library_name = "Sample Module Library"
		created_library = true

	var changed := created_library
	var floor_tile := library.get_tile_by_name("floor")
	if floor_tile == null:
		floor_tile = Tile.new()
		floor_tile.name = "floor"
		floor_tile.size = Vector3i.ONE
		floor_tile.symmetry = Tile.Symmetry.NONE
		floor_tile.tags = ["floor"]
		changed = true
	else:
		if not floor_tile.tags.has("floor"):
			var tags_copy: Array[String] = []
			tags_copy.assign(floor_tile.tags)
			tags_copy.append("floor")
			floor_tile.tags = tags_copy
			changed = true

	var floor_scene := _get_floor_scene()
	if floor_scene and floor_tile.scene != floor_scene:
		floor_tile.scene = floor_scene
		changed = true

	if _ensure_floor_sockets(floor_tile, library):
		changed = true

	if library.get_tile_by_name("floor") == null:
		var tiles_copy: Array[Tile] = []
		tiles_copy.assign(library.tiles)
		tiles_copy.append(floor_tile)
		library.tiles = tiles_copy
		changed = true

	if _ensure_socket_types(library):
		changed = true

	library.ensure_defaults()
	if changed:
		var err := ResourceSaver.save(library, library_path)
		if err != OK:
			push_error("Failed to ensure sample library: %s" % err)

func _ensure_floor_sockets(floor_tile: Tile, library: ModuleLibrary) -> bool:
	var required := [
		{ "direction": Vector3i.RIGHT, "id": "floor_side", "compat": ["floor_side"] },
		{ "direction": Vector3i.LEFT, "id": "floor_side", "compat": ["floor_side"] },
		{ "direction": Vector3i.FORWARD, "id": "floor_side", "compat": ["floor_side"] },
		{ "direction": Vector3i.BACK, "id": "floor_side", "compat": ["floor_side"] },
		{ "direction": Vector3i.UP, "id": "floor_top", "compat": [] },
		{ "direction": Vector3i.DOWN, "id": "floor_bottom", "compat": [] }
	]

	var changed := false
	for entry in required:
		var direction: Vector3i = entry["direction"]
		var socket := floor_tile.get_socket_by_direction(direction)
		if socket == null:
			socket = Socket.new()
			socket.direction = direction
			floor_tile.add_socket(socket)
			changed = true

		var socket_id := String(entry["id"])
		if socket.socket_id != socket_id:
			socket.socket_id = socket_id
			changed = true

		var expected_compat: Array[String] = []
		expected_compat.assign(entry["compat"])
		expected_compat.sort()
		var current_compat: Array[String] = []
		current_compat.assign(socket.compatible_sockets)
		current_compat.sort()
		if current_compat != expected_compat:
			socket.compatible_sockets = expected_compat
			changed = true

		for compat_id in expected_compat:
			library.register_socket_type(compat_id)
		library.register_socket_type(socket_id)

	return changed

func _ensure_socket_types(library: ModuleLibrary) -> bool:
	var required := ["any", "none", "floor_side", "floor_top", "floor_bottom"]
	var changed := false
	for socket_id in required:
		if socket_id not in library.socket_types:
			library.register_socket_type(socket_id)
			changed = true
	return changed

func _get_floor_scene() -> PackedScene:
	if _floor_scene:
		return _floor_scene
	_floor_scene = ResourceLoader.load("res://sample/modules/floor.tscn")
	return _floor_scene
