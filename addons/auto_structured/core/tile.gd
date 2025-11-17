@tool
class_name Tile extends Resource

const Socket = preload("res://addons/auto_structured/core/socket.gd")

@export var name: String = ""
@export var mesh: Mesh = null
@export var scene: PackedScene = null
@export var size: Vector3i = Vector3i.ONE  ## Size of the tile in grid units (default 1x1x1). Must be integer.
@export var tags: Array[String] = []

@export var sockets: Array[Socket] = []:
	set(value):
		sockets = value
		_rebuild_socket_cache()

## Precomputed socket cache for O(1) lookups by direction
var _sockets_by_dir: Dictionary = {}

## Cache for face signatures to avoid expensive recomputation
var _cached_face_signatures: Dictionary = {}
var _face_cache_valid: bool = false

func _rebuild_socket_cache() -> void:
	"""Rebuild the socket cache whenever sockets are modified. Called automatically."""
	_sockets_by_dir.clear()
	for s in sockets:
		if not _sockets_by_dir.has(s.direction):
			_sockets_by_dir[s.direction] = []
		_sockets_by_dir[s.direction].append(s)

func get_sockets_in_direction(direction: Vector3i) -> Array[Socket]:
	"""
	Get all sockets on this tile that face the specified direction.
	Optimized: Uses precomputed cache for O(1) lookup instead of O(n) iteration.

	Args:
		direction: The direction to filter sockets by

	Returns:
		An array of Socket instances facing the given direction
	"""
	# Ensure cache is built (in case tile was loaded from disk)
	if _sockets_by_dir.is_empty() and not sockets.is_empty():
		_rebuild_socket_cache()
	
	var result = _sockets_by_dir.get(direction, [])
	var typed_result: Array[Socket] = []
	typed_result.assign(result)
	return typed_result

func add_tag(tag: String) -> bool:
	"""
	Add a tag to this tile if it doesn't already exist.

	Args:
		tag: The tag string to add
	"""
	if tag in tags:
		print("Tag already exists on tile: %s" % tag)
		return false
	
	var tags_copy: Array[String] = []
	tags_copy.assign(tags)
	tags_copy.append(tag)
	tags = tags_copy
	
	return true

func remove_tag(tag: String) -> void:
	"""
	Remove a tag from this tile if it exists.
	Args:
		tag: The tag string to remove
	"""
	if tag not in tags:
		return
	var tags_copy: Array[String] = []
	tags_copy.assign(tags)
	tags_copy.erase(tag)
	tags = tags_copy

func has_tag(tag: String) -> bool:
	"""
	Check if this tile has a specific tag.
	
	Args:
		tag: The tag string to check for
	
	Returns:
		true if the tile has the tag, false otherwise
	"""
	return tag in tags

func has_all_tags(required_tags: Array[String]) -> bool:
	"""
	Check if this tile has all of the specified tags.
	
	Args:
		required_tags: Array of tag strings that must all be present
	
	Returns:
		true if the tile has all required tags, false otherwise
	"""
	if required_tags.is_empty():
		return true
	
	for tag in required_tags:
		if tag not in tags:
			return false
	return true

func has_any_tags(check_tags: Array[String]) -> bool:
	"""
	Check if this tile has at least one of the specified tags.
	
	Args:
		check_tags: Array of tag strings to check
	
	Returns:
		true if the tile has at least one of the tags, false otherwise
	"""
	if check_tags.is_empty():
		return false
	
	for tag in check_tags:
		if tag in tags:
			return true
	return false

func add_socket(socket: Socket) -> void:
	"""
	Add a socket to this tile.
	Args:
		socket: The Socket instance to add
	"""
	var sockets_copy: Array[Socket] = []
	sockets_copy.assign(sockets)
	sockets_copy.append(socket)
	sockets = sockets_copy
	_rebuild_socket_cache()

func remove_socket(socket: Socket) -> void:
	"""
	Remove a socket from this tile.
	Args:
		socket: The Socket instance to remove
	"""
	if socket not in sockets:
		return
	var sockets_copy: Array[Socket] = []
	sockets_copy.assign(sockets)
	sockets_copy.erase(socket)
	sockets = sockets_copy
	_rebuild_socket_cache()

func ensure_all_sockets(library = null) -> void:
	"""
	Ensure this tile has exactly 6 sockets (one for each cardinal direction).
	Creates missing sockets with socket_type = 'none'.
	
	Args:
		library: Optional ModuleLibrary to get the 'none' socket type from
	"""
	var directions = [
		Vector3i.UP,      # (0, 1, 0)
		Vector3i.DOWN,    # (0, -1, 0)
		Vector3i.RIGHT,   # (1, 0, 0)
		Vector3i.LEFT,    # (-1, 0, 0)
		Vector3i.FORWARD, # (0, 0, -1)
		Vector3i.BACK     # (0, 0, 1)
	]
	
	for direction in directions:
		var existing = get_sockets_in_direction(direction)
		if existing.is_empty():
			# Create a 'none' socket for this direction
			var new_socket = Socket.new()
			new_socket.direction = direction
			if library != null:
				new_socket.socket_type = library.get_socket_type_by_id("none")
			add_socket(new_socket)

func get_unique_rotations() -> Array[int]:
	"""Return the list of rotations supported by this tile."""
	return [0]

func get_socket_by_direction(direction: Vector3i) -> Socket:
	"""
	Get the socket for a specific direction.
	
	Args:
		direction: The direction to get the socket for
	
	Returns:
		The Socket instance for that direction, or null if not found
	"""
	var sockets_in_dir = get_sockets_in_direction(direction)
	if not sockets_in_dir.is_empty():
		return sockets_in_dir[0]
	return null
