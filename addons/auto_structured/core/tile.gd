@tool
class_name Tile extends Resource

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

@export var name: String = ""
@export var mesh: Mesh = null
@export var scene: PackedScene = null
@export var size: Vector3i = Vector3i.ONE  ## Size of the tile in grid units (default 1x1x1). Must be integer.
@export var tags: Array[String] = []

@export_range(0.01, 100.0, 0.01, "or_greater") var weight: float = 1.0:
	set(value):
		weight = maxf(0.01, value)  ## Weight determines spawn probability in WFC (higher = more common)
	get:
		return weight

@export var requirements: Array[Requirement] = []  ## Placement constraints (e.g., height restrictions, max count)

## Rotation symmetry mode determines which rotations are valid for this tile
enum RotationSymmetry {
	AUTO,        ## Automatically detect symmetry from socket configuration (default)
	FULL,        ## No symmetry - all 4 rotations are unique [0°, 90°, 180°, 270°]
	HALF,        ## 180° symmetry - only 2 rotations needed [0°, 90°]
	QUARTER,     ## 90° symmetry - only 1 rotation needed [0°]
	CUSTOM       ## Use manually specified rotations
}

@export var rotation_symmetry: RotationSymmetry = RotationSymmetry.AUTO
@export var custom_rotations: Array[int] = []  ## Used when rotation_symmetry is CUSTOM (e.g., [0, 90, 180])

@export var sockets: Array[Socket] = []:
	set(value):
		sockets = value
		_rebuild_socket_cache()
		_face_cache_valid = false  ## Invalidate face cache when sockets change

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
	"""Return the list of unique rotations for this tile based on symmetry.
	
	Returns:
		Array of rotation angles in degrees (e.g., [0, 90, 180, 270])
	"""
	match rotation_symmetry:
		RotationSymmetry.AUTO:
			return _detect_rotational_symmetry()
		RotationSymmetry.FULL:
			return [0, 90, 180, 270]
		RotationSymmetry.HALF:
			return [0, 90]
		RotationSymmetry.QUARTER:
			return [0]
		RotationSymmetry.CUSTOM:
			if custom_rotations.is_empty():
				push_warning("Tile '%s' has CUSTOM rotation mode but no custom_rotations defined, using [0]" % name)
				return [0]
			return custom_rotations
	
	return [0]  ## Fallback

func _detect_rotational_symmetry() -> Array[int]:
	"""Automatically detect which rotations produce unique socket configurations.
	
	Checks socket patterns at 0°, 90°, 180°, 270° and returns only unique ones.
	Uses face signatures for fast comparison.
	
	Returns:
		Array of unique rotation angles
	"""
	if sockets.is_empty():
		return [0]  ## No sockets = no rotation matters
	
	## Build face signatures for all 4 cardinal rotations
	var all_rotations = [0, 90, 180, 270]
	var signatures: Array[String] = []
	var unique_rotations: Array[int] = []
	
	for rotation in all_rotations:
		var signature = _get_face_signature_at_rotation(rotation)
		
		## Check if this signature is unique
		if signature not in signatures:
			signatures.append(signature)
			unique_rotations.append(rotation)
	
	return unique_rotations

func _get_face_signature_at_rotation(rotation_degrees: int) -> String:
	"""Generate a string signature representing socket configuration at a specific rotation.
	
	The signature encodes socket types for each face after rotation, allowing
	quick comparison of rotational equivalence.
	
	Args:
		rotation_degrees: Rotation angle (0, 90, 180, 270)
	
	Returns:
		String signature encoding the socket pattern
	"""
	## Check cache first
	if _face_cache_valid and _cached_face_signatures.has(rotation_degrees):
		return _cached_face_signatures[rotation_degrees]
	
	## Rotate each cardinal direction and collect socket types
	var face_data: Array[String] = []
	var cardinal_dirs = [
		Vector3i.RIGHT,   ## +X
		Vector3i.BACK,    ## +Z
		Vector3i.LEFT,    ## -X
		Vector3i.FORWARD, ## -Z
		Vector3i.UP,      ## +Y (doesn't rotate)
		Vector3i.DOWN     ## -Y (doesn't rotate)
	]
	
	for dir in cardinal_dirs:
		## Apply inverse rotation to direction to get original socket
		var rotated_dir = _rotate_direction_y(dir, -rotation_degrees)
		var sockets_in_dir = get_sockets_in_direction(rotated_dir)
		
		if sockets_in_dir.is_empty():
			face_data.append("none")
		else:
			## Sort socket type IDs for consistent comparison
			var socket_types: Array[String] = []
			for socket in sockets_in_dir:
				if socket.socket_type != null:
					socket_types.append(socket.socket_type.type_id)
				else:
					socket_types.append("null")
			socket_types.sort()
			face_data.append(",".join(socket_types))
	
	var signature = "|".join(face_data)
	
	## Cache the result
	_cached_face_signatures[rotation_degrees] = signature
	_face_cache_valid = true
	
	return signature

func _rotate_direction_y(direction: Vector3i, degrees: int) -> Vector3i:
	"""Rotate a direction vector around the Y axis.
	
	Args:
		direction: Direction vector to rotate
		degrees: Rotation angle in degrees (90, 180, 270, or negative)
	
	Returns:
		Rotated direction vector
	"""
	## Normalize degrees to 0-360 range
	var normalized = degrees % 360
	if normalized < 0:
		normalized += 360
	
	## Y axis doesn't rotate
	if direction.y != 0:
		return direction
	
	## Rotate in XZ plane
	match normalized:
		0:
			return direction
		90:
			return Vector3i(-direction.z, 0, direction.x)
		180:
			return Vector3i(-direction.x, 0, -direction.z)
		270:
			return Vector3i(direction.z, 0, -direction.x)
		_:
			push_warning("Unsupported rotation angle: %d, using 0°" % degrees)
			return direction

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
