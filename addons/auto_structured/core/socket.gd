@tool
class_name Socket extends Resource

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

## Unique identifier for this socket type (e.g., "wall", "floor", "door")
@export var socket_id: String = "":
	set(value):
		socket_id = value.strip_edges() if value else ""

## List of socket IDs that are compatible with this socket
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
		other: The socket to check compatibility against

	Returns:
		true if compatible, false otherwise
	"""
	if other == null:
		return false
	
	# Check if this socket's compatible list includes the other's ID
	return other.socket_id in compatible_sockets

func add_compatible_socket(id: String) -> void:
	"""
	Add a socket ID to the compatibility list.
	
	Args:
		id: The socket ID to add
	"""
	var clean := String(id).strip_edges()
	if clean == "" or clean in compatible_sockets:
		return
	compatible_sockets.append(clean)
	compatible_sockets.sort()

func remove_compatible_socket(id: String) -> void:
	"""
	Remove a socket ID from the compatibility list.
	
	Args:
		id: The socket ID to remove
	"""
	var clean := String(id).strip_edges()
	if clean in compatible_sockets:
		compatible_sockets.erase(clean)