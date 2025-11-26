@tool
class_name Socket extends Resource

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

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

	ensure_guid()
	var other_guid := String(other.socket_guid).strip_edges()
	if other_guid == "":
		return false
	return other_guid in compatible_sockets

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