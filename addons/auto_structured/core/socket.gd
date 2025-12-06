@tool
class_name Socket extends Resource

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

## Socket types define semantic connection types for structural generation
enum SocketType {
	GENERIC = 0,              ## Generic connection (old behavior)
	WALL_EXTERIOR_EDGE = 1,   ## Exterior wall edge (connects to other exterior walls)
	WALL_INTERIOR_EDGE = 2,   ## Interior wall edge (connects to other interior walls)
	FLOOR_TOP_SURFACE = 3,    ## Top surface of floor (connects to objects above)
	FLOOR_BOTTOM_SUPPORT = 4, ## Bottom of floor (needs support below)
	DOOR_OPENING = 5,         ## Opening for door frame
	WINDOW_OPENING = 6,       ## Opening for window frame
	ROOF_EDGE = 7,            ## Roof connection edge
	FOUNDATION_BASE = 8,      ## Foundation/ground connection
	CORNER_EXTERIOR = 9,      ## Exterior corner connection
	CORNER_INTERIOR = 10,     ## Interior corner connection
	PASSAGE_FRAME = 11,       ## Frame for passages (doors/archways)
	GROUND_SURFACE = 12,      ## Outside ground surface
}

## Socket type classification for structural constraints
@export var socket_type: SocketType = SocketType.GENERIC

## Compatible socket types (what can connect to this socket)
@export var compatible_types: Array[SocketType] = []

## Unique identifier for this socket type (e.g., "wall", "floor", "door")
@export var socket_id: String = "":
	set(value):
		socket_id = value.strip_edges() if value else ""

## Stable GUID for this specific socket instance (used for compatibility links)
@export var socket_guid: String = "":
	set(value):
		var clean := String(value).strip_edges()
		socket_guid = clean if clean != "" else _generate_guid()

## List of socket GUIDs that are compatible with this socket
@export var compatible_sockets: Array[String] = []

## Requirements that the neighboring tile must satisfy to connect to this socket
@export var requirements: Array[Requirement] = []

## Direction this socket is facing (must be one of the 6 cardinal directions)
@export var direction: Vector3i = Vector3i.UP:
	set(value):
		if is_valid_direction(value):
			direction = value
		else:
			push_warning("Socket: Invalid direction %s. Must be cardinal direction." % value)
			direction = Vector3i.UP

static func is_valid_direction(dir: Vector3i) -> bool:
	"""Check if direction is one of the 6 cardinal directions."""
	return dir in [
		Vector3i.RIGHT, # (1, 0, 0)
		Vector3i.LEFT, # (-1, 0, 0)
		Vector3i.UP, # (0, 1, 0)
		Vector3i.DOWN, # (0, -1, 0)
		Vector3i.FORWARD, # (0, 0, -1)
		Vector3i.BACK # (0, 0, 1)
	]

func is_compatible_with(other: Socket) -> bool:
	"""
	Check if this socket is compatible with another socket.

	Args:
		other: The socket to check compatibility against (compatibility is defined
			by this socket's compatible_sockets list)

	Returns:
		true if compatible, false otherwise
	"""
	if other == null:
		return false

	# First check typed socket compatibility (new system)
	if socket_type != SocketType.GENERIC or other.socket_type != SocketType.GENERIC:
		return is_type_compatible_with(other)
	
	# Fall back to GUID-based compatibility (legacy system)
	ensure_guid()
	var other_guid := String(other.socket_guid).strip_edges()
	if other_guid == "":
		return false
	return other_guid in compatible_sockets

func is_type_compatible_with(other: Socket) -> bool:
	"""
	Check type-based socket compatibility using SocketType enum.
	This provides semantic matching for structural generation.
	"""
	if other == null:
		return false
	
	# If either socket uses GENERIC, fall back to GUID compatibility
	if socket_type == SocketType.GENERIC or other.socket_type == SocketType.GENERIC:
		ensure_guid()
		var other_guid := String(other.socket_guid).strip_edges()
		if other_guid == "":
			return false
		return other_guid in compatible_sockets
	
	# Check if other's type is in our compatible list
	if not compatible_types.is_empty():
		return other.socket_type in compatible_types
	
	# Default compatibility rules for common cases
	return _has_default_type_compatibility(socket_type, other.socket_type)

func _has_default_type_compatibility(type_a: SocketType, type_b: SocketType) -> bool:
	"""Default compatibility rules when compatible_types is not specified."""
	# Matching types are always compatible
	if type_a == type_b:
		return true
	
	# Specific compatibility rules
	match type_a:
		SocketType.WALL_EXTERIOR_EDGE:
			return type_b in [SocketType.WALL_EXTERIOR_EDGE, SocketType.CORNER_EXTERIOR, SocketType.DOOR_OPENING]
		SocketType.WALL_INTERIOR_EDGE:
			return type_b in [SocketType.WALL_INTERIOR_EDGE, SocketType.CORNER_INTERIOR, SocketType.DOOR_OPENING]
		SocketType.FLOOR_TOP_SURFACE:
			return type_b == SocketType.FLOOR_BOTTOM_SUPPORT
		SocketType.FLOOR_BOTTOM_SUPPORT:
			return type_b in [SocketType.FLOOR_TOP_SURFACE, SocketType.FOUNDATION_BASE, SocketType.GROUND_SURFACE]
		SocketType.DOOR_OPENING:
			return type_b in [SocketType.WALL_EXTERIOR_EDGE, SocketType.WALL_INTERIOR_EDGE, SocketType.PASSAGE_FRAME]
		SocketType.WINDOW_OPENING:
			return type_b in [SocketType.WALL_EXTERIOR_EDGE, SocketType.WALL_INTERIOR_EDGE]
		SocketType.CORNER_EXTERIOR:
			return type_b in [SocketType.WALL_EXTERIOR_EDGE, SocketType.CORNER_EXTERIOR]
		SocketType.CORNER_INTERIOR:
			return type_b in [SocketType.WALL_INTERIOR_EDGE, SocketType.CORNER_INTERIOR]
		SocketType.ROOF_EDGE:
			return type_b == SocketType.ROOF_EDGE
		SocketType.GROUND_SURFACE:
			return type_b in [SocketType.GROUND_SURFACE, SocketType.FLOOR_BOTTOM_SUPPORT]
	
	return false

func add_compatible_socket(id: String) -> void:
	"""
	Add a socket GUID to the compatibility list.
	
	Args:
		id: The socket GUID to add
	"""
	var clean := String(id).strip_edges()
	if clean == "" or clean in compatible_sockets:
		return
	compatible_sockets.append(clean)
	compatible_sockets.sort()

func remove_compatible_socket(id: String) -> void:
	"""
	Remove a socket GUID from the compatibility list.
	
	Args:
		id: The socket GUID to remove
	"""
	var clean := String(id).strip_edges()
	if clean in compatible_sockets:
		compatible_sockets.erase(clean)

func ensure_guid() -> void:
	"""Guarantee this socket has a valid GUID."""
	if String(socket_guid).strip_edges() == "":
		socket_guid = _generate_guid()

func _generate_guid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(bytes.size()):
		bytes[i] = rng.randi() & 0xFF
	var hex := ""
	for value in bytes:
		hex += "%02x" % value
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]