extends RefCounted

const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}
	_run_test(results, "Library sockets have reciprocal compatibility", _test_reciprocal_compatibility)
	return results

func _run_test(results: Dictionary, name: String, fn: Callable) -> void:
	results["total"] += 1
	var outcome = fn.call()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func _test_reciprocal_compatibility() -> Variant:
	var library: ModuleLibrary = ResourceLoader.load("res://module_library.tres")
	if library == null:
		return "Failed to load module_library.tres"
	for tile: Tile in library.tiles:
		if tile == null:
			continue
		for socket: Socket in tile.sockets:
			if socket == null:
				continue
			var source_id := socket.socket_id.strip_edges()
			if source_id == "" or source_id == "none":
				continue
			for raw_partner_id in socket.compatible_sockets:
				var partner_id := str(raw_partner_id).strip_edges()
				if partner_id == "" or partner_id == "none":
					continue
				var matches := _find_sockets_with_id(library, partner_id)
				if matches.is_empty():
					return _format_issue(tile, socket, partner_id, "no sockets with id")
				var reciprocal_found := false
				for partner in matches:
					var partner_socket: Socket = partner["socket"]
					if partner_socket == null:
						continue
					if partner_socket.compatible_sockets.has(source_id):
						reciprocal_found = true
						break
				if not reciprocal_found:
					return _format_issue(tile, socket, partner_id, "missing reciprocal entry")
	return null

func _find_sockets_with_id(library: ModuleLibrary, socket_id: String) -> Array:
	var results: Array = []
	for tile: Tile in library.tiles:
		if tile == null:
			continue
		for socket: Socket in tile.sockets:
			if socket == null:
				continue
			if socket.socket_id.strip_edges() == socket_id:
				results.append({
					"tile": tile,
					"socket": socket
				})
	return results

func _format_issue(tile: Tile, socket: Socket, partner_id: String, message: String) -> String:
	return "%s[%s] expects '%s' (%s)" % [
		tile.name,
		_direction_to_label(socket.direction),
		partner_id,
		message
	]

func _direction_to_label(direction: Vector3i) -> String:
	match direction:
		Vector3i.UP:
			return "Up"
		Vector3i.DOWN:
			return "Down"
		Vector3i.RIGHT:
			return "Right"
		Vector3i.LEFT:
			return "Left"
		Vector3i.FORWARD:
			return "Forward"
		Vector3i.BACK:
			return "Back"
		_:
			return str(direction)
