@tool
class_name ModuleLibrary extends Resource

const Tile = preload("res://addons/auto_structured/core/tile.gd")

@export var library_name: String = "My Building Set"
@export var tiles: Array[Tile] = []
@export var socket_types: Array[String] = []  ## Registered socket type IDs for this library

func ensure_defaults() -> void:
	"""
	Ensure default socket types exist in the library.
	Call this explicitly when setting up the library, not in _init.
	"""
	if "none" not in socket_types:
		socket_types.append("none")
	if "any" not in socket_types:
		socket_types.append("any")
	socket_types.sort()

func get_tile_by_name(name: String) -> Tile:
	for tile in tiles:
		if tile.name == name:
			return tile
	return null

func get_tiles_with_tag(tag: String) -> Array[Tile]:
	return tiles.filter(func(t): return t.tags.has(tag))

func get_all_unique_socket_ids() -> Array[String]:
	"""
	Get all unique socket IDs from all tiles in this library.
	
	Returns:
		A sorted array of unique socket ID strings
	"""
	var socket_ids: Array[String] = []
	var unique_ids: Dictionary = {}
	
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_id and not unique_ids.has(socket.socket_id):
				unique_ids[socket.socket_id] = true
				socket_ids.append(socket.socket_id)
	
	socket_ids.sort()
	return socket_ids

func register_socket_type(socket_id: String) -> void:
	"""
	Register a new socket type ID in this library.
	
	Args:
		socket_id: The socket type ID to register
	"""
	if socket_id.strip_edges().is_empty():
		return
	
	var normalized_id = socket_id.strip_edges()
	if normalized_id not in socket_types:
		socket_types.append(normalized_id)
		socket_types.sort()

func validate_socket_id(socket_id: String) -> bool:
	"""
	Check if a socket ID is registered in this library.
	
	Args:
		socket_id: The socket ID to validate
	
	Returns:
		true if the socket ID is registered, false otherwise
	"""
	return socket_id in socket_types

func get_socket_types() -> Array[String]:
	"""
	Get a copy of all registered socket type IDs.
	
	Returns:
		A sorted array of registered socket type IDs
	"""
	var types_copy: Array[String] = []
	types_copy.assign(socket_types)
	return types_copy

func validate_library() -> Dictionary:
	"""
	Validate the library for issues like orphan socket references.
	
	Returns:
		Dictionary with keys:
		- "valid" (bool): true if no issues found
		- "issues" (Array[String]): List of validation issues
	"""
	var all_socket_ids = get_all_unique_socket_ids()
	var issues: Array[String] = []
	
	for tile in tiles:
		for socket in tile.sockets:
			# Check if socket ID is registered
			if socket.socket_id and not validate_socket_id(socket.socket_id):
				issues.append("Socket '%s' on tile '%s' is not registered in socket_types" % [socket.socket_id, tile.name])
			
			# Check if any compatible socket doesn't exist in library
			for compat_id in socket.compatible_sockets:
				if compat_id not in all_socket_ids:
					issues.append("Socket '%s' on tile '%s' references unknown socket type '%s'" % [socket.socket_id, tile.name, compat_id])
	
	return {"valid": issues.is_empty(), "issues": issues}
