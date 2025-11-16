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
	
	# Build a map of socket type ID to SocketType
	var types_by_id := {}
	for socket_type in library.socket_types:
		types_by_id[socket_type.type_id] = socket_type
	
	# Check reciprocal compatibility at the SocketType level
	for socket_type in library.socket_types:
		var source_id := socket_type.type_id.strip_edges()
		if source_id == "" or source_id == "none":
			continue
		
		for partner_id in socket_type.compatible_types:
			var partner_id_clean := str(partner_id).strip_edges()
			if partner_id_clean == "" or partner_id_clean == "none":
				continue
			
			# Check if partner type exists
			var partner_type = types_by_id.get(partner_id_clean)
			if partner_type == null:
				return "SocketType '%s' references non-existent type '%s'" % [source_id, partner_id_clean]
			
			# Check reciprocal entry
			if source_id not in partner_type.compatible_types:
				return "SocketType '%s' lists '%s' as compatible, but '%s' doesn't list '%s' (missing reciprocal entry)" % [
					source_id, partner_id_clean, partner_id_clean, source_id
				]
	
	return null

func _find_sockets_with_id(library: ModuleLibrary, socket_id: String) -> Array:
	var results: Array = []
	for tile: Tile in library.tiles:
		if tile == null:
			continue
		for socket: Socket in tile.sockets:
			if socket == null:
				continue
			if socket.socket_type != null and socket.socket_type.type_id.strip_edges() == socket_id:
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
