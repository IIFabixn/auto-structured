@tool
class_name ModuleLibrary extends Resource

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

@export var library_name: String = "My Building Set"
@export var tiles: Array[Tile] = []
@export var socket_types: Array[SocketType] = []  ## Registered socket types for this library
@export var cell_world_size: Vector3 = Vector3(1, 1, 1)  ## Size of each grid cell in world units

func ensure_defaults() -> void:
	"""
	Ensure default socket types exist in the library.
	Call this explicitly when setting up the library, not in _init.
	"""
	# Create "none" socket type if it doesn't exist
	if get_socket_type_by_id("none") == null:
		var none_type = SocketType.new()
		none_type.type_id = "none"
		socket_types.append(none_type)
	
	# Create "any" socket type if it doesn't exist
	if get_socket_type_by_id("any") == null:
		var any_type = SocketType.new()
		any_type.type_id = "any"
		socket_types.append(any_type)

	# Ensure cell size has sane defaults
	if cell_world_size.x <= 0.0 or cell_world_size.y <= 0.0 or cell_world_size.z <= 0.0:
		cell_world_size = Vector3(2, 3, 2)

func get_tile_by_name(name: String) -> Tile:
	for tile in tiles:
		if tile.name == name:
			return tile
	return null

func get_tiles_with_tag(tag: String) -> Array[Tile]:
	return tiles.filter(func(t): return t.tags.has(tag))

func get_all_unique_socket_ids() -> Array[String]:
	"""
	Get all unique socket type IDs from all tiles in this library.
	
	Returns:
		A sorted array of unique socket type ID strings
	"""
	var socket_ids: Array[String] = []
	var unique_ids: Dictionary = {}
	
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_type != null and socket.socket_type.type_id and not unique_ids.has(socket.socket_type.type_id):
				unique_ids[socket.socket_type.type_id] = true
				socket_ids.append(socket.socket_type.type_id)
	
	socket_ids.sort()
	return socket_ids

func register_socket_type(type) -> SocketType:
	"""
	Register a new socket type in this library.

	Args:
		type: SocketType resource or String ID to register

	Returns:
		The SocketType resource registered (existing or newly created)
	"""
	var socket_type: SocketType = null
	if type is SocketType:
		socket_type = type
	elif type is String:
		var clean := String(type).strip_edges()
		if clean.is_empty():
			return null
		socket_type = get_socket_type_by_id(clean)
		if socket_type:
			return socket_type
		socket_type = SocketType.new()
		socket_type.type_id = clean
	else:
		return null

	if socket_type == null or socket_type.type_id.strip_edges().is_empty():
		return null

	for existing in socket_types:
		if existing.type_id == socket_type.type_id:
			return existing

	socket_types.append(socket_type)
	return socket_type

func get_socket_types() -> Array[String]:
	"""Get the list of registered socket type IDs (legacy compatibility)."""
	return get_socket_type_ids()

func get_socket_type_resources() -> Array[SocketType]:
	"""Get all socket type resources registered in this library."""
	var types: Array[SocketType] = []
	types.assign(socket_types)
	return types

func get_socket_type_by_id(id: String) -> SocketType:
	"""
	Get a socket type by its ID.
	
	Args:
		id: The socket type ID to look up
	
	Returns:
		The SocketType with that ID, or null if not found
	"""
	for t in socket_types:
		if t.type_id == id:
			return t
	return null

func ensure_socket_type(id: String) -> SocketType:
	"""Ensure a socket type with the given ID exists and return it."""
	var clean_id := id.strip_edges()
	if clean_id.is_empty():
		return null
	return register_socket_type(clean_id)

func rename_socket_type(old_id: String, new_id: String) -> bool:
	"""Rename a socket type and update compatibility references."""
	var type := get_socket_type_by_id(old_id)
	if type == null:
		return false
	var clean_new := new_id.strip_edges()
	if clean_new.is_empty():
		return false
	if old_id == clean_new:
		return true
	if get_socket_type_by_id(clean_new) != null:
		return false
	# Update compatibility references before renaming
	for other in socket_types:
		if old_id in other.compatible_types:
			var compat := other.compatible_types.duplicate()
			compat.erase(old_id)
			compat.append(clean_new)
			compat.sort()
			other.compatible_types = compat
	# Rename the socket type
	type.type_id = clean_new
	return true

func delete_socket_type(id: String, fallback_id: String = "none") -> bool:
	"""Delete a socket type from the library and migrate sockets to fallback."""
	var type := get_socket_type_by_id(id)
	if type == null:
		return false
	var normalized_id := id.strip_edges()
	# Prevent removing required defaults
	if normalized_id == "none" or normalized_id == "any":
		return false
	var fallback := ensure_socket_type(fallback_id)
	if fallback == null:
		return false
	socket_types.erase(type)
	# Update sockets referencing this type
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_type == type:
				socket.socket_type = fallback
	# Remove compatibility references from other types
	for other in socket_types:
		if normalized_id in other.compatible_types:
			var compat := other.compatible_types.duplicate()
			compat.erase(normalized_id)
			other.compatible_types = compat
	return true

func validate_socket_id(socket_id: String) -> bool:
	"""
	Check if a socket ID is registered in this library.
	
	Args:
		socket_id: The socket ID to validate
	
	Returns:
		true if the socket ID is registered, false otherwise
	"""
	return get_socket_type_by_id(socket_id) != null

func get_socket_type_ids() -> Array[String]:
	"""
	Get a list of all registered socket type IDs.
	
	Returns:
		An array of socket type ID strings
	"""
	var ids: Array[String] = []
	for t in socket_types:
		ids.append(t.type_id)
	return ids

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
			# Check if socket has a valid type
			if socket.socket_type == null:
				issues.append("Socket on tile '%s' (direction %s) has no socket_type" % [tile.name, socket.direction])
			elif socket.socket_type.type_id.strip_edges().is_empty():
				issues.append("Socket on tile '%s' (direction %s) has empty type_id" % [tile.name, socket.direction])
			elif not validate_socket_id(socket.socket_type.type_id):
				issues.append("Socket type '%s' on tile '%s' is not registered in socket_types" % [socket.socket_type.type_id, tile.name])
			
			# Check if socket type's compatible types exist
			if socket.socket_type != null:
				for compat_id in socket.socket_type.compatible_types:
					if compat_id not in all_socket_ids and not validate_socket_id(compat_id):
						issues.append("Socket type '%s' on tile '%s' references unknown socket type '%s'" % [socket.socket_type.type_id, tile.name, compat_id])
	
	return {"valid": issues.is_empty(), "issues": issues}
