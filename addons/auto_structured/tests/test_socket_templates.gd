extends RefCounted

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}
	_run_test(results, "Applying floor template seeds expected socket ids", test_floor_template_assignment)
	_run_test(results, "Wall template adds rotation requirements", test_wall_template_rotation_requirement)
	_run_test(results, "Template resets unspecified sockets to none", test_template_clears_unspecified_sockets)
	return results

func _run_test(results: Dictionary, name: String, callable: Callable) -> void:
	results["total"] += 1
	var outcome = callable.call()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func test_floor_template_assignment() -> Variant:
	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tile := Tile.new()
	tile.name = "Floor"
	var template: SocketTemplate = SocketTemplateLibrary.get_builtin_templates()[0]
	SocketTemplateLibrary.apply_template(tile, template, library)

	var expected_dirs := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]
	for direction in expected_dirs:
		var socket := tile.get_socket_by_direction(direction)
		if socket == null:
			return "Missing socket for direction %s" % [direction]
		if socket.socket_id != "floor_side":
			return "Socket %s expected id 'floor_side' but found '%s'" % [direction, socket.socket_id]
		if not socket.compatible_sockets.has("floor_side"):
			return "Socket %s should be compatible with 'floor_side'" % [direction]
	return null

func test_wall_template_rotation_requirement() -> Variant:
	var library := ModuleLibrary.new()
	var wall_tile := Tile.new()
	wall_tile.name = "Wall"
	var template := SocketTemplateLibrary.get_builtin_templates()[1]
	SocketTemplateLibrary.apply_template(wall_tile, template, library)

	var left_socket := wall_tile.get_socket_by_direction(Vector3i.LEFT)
	if left_socket == null:
		return "Wall template did not create left socket"
	var rotation := _get_rotation_requirement(left_socket)
	if rotation != 90:
		return "Left socket minimum rotation should be 90 but was %d" % rotation
	var down_socket := wall_tile.get_socket_by_direction(Vector3i.DOWN)
	if down_socket == null or not down_socket.compatible_sockets.has("floor_side"):
		return "Wall template should allow connection to floor via down socket"
	return null

func test_template_clears_unspecified_sockets() -> Variant:
	var library := ModuleLibrary.new()
	var tile := Tile.new()
	var initial_socket := Socket.new()
	initial_socket.direction = Vector3i.UP
	initial_socket.socket_id = "custom"
	initial_socket.compatible_sockets = ["custom"]
	var sockets: Array[Socket] = []
	sockets.append(initial_socket)
	tile.sockets = sockets

	var template := SocketTemplate.new()
	template.template_name = "Test"
	template.entries = [SocketTemplate.create_entry(Vector3i.RIGHT, "only_right")]
	SocketTemplateLibrary.apply_template(tile, template, library)

	var up_socket := tile.get_socket_by_direction(Vector3i.UP)
	if up_socket == null:
		return "Template should preserve up socket"
	if up_socket.socket_id != "none":
		return "Sockets not in template should reset to 'none'"
	var right_socket := tile.get_socket_by_direction(Vector3i.RIGHT)
	if right_socket == null or right_socket.socket_id != "only_right":
		return "Template failed to apply to right socket"
	return null

func _get_rotation_requirement(socket: Socket) -> int:
	for requirement in socket.requirements:
		if requirement is RotationRequirement:
			return requirement.minimum_rotation_degrees
	return 0
