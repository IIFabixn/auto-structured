@tool
class_name Socket extends Resource

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

## The type of this socket
@export var socket_type: SocketType = null

## Direction this socket is facing (must be one of the 6 cardinal directions)
@export var direction: Vector3i = Vector3i.UP:
	set(value):
		if is_valid_direction(value):
			direction = value
		else:
			push_warning("Socket: Invalid direction %s. Must be cardinal direction." % value)
			direction = Vector3i.UP

## Requirements that the neighboring tile must satisfy to connect to this socket
## Example: TagRequirement("stone") means only tiles with "stone" tag can connect here
## Use RotationRequirement to require minimum rotation angles
@export var requirements: Array[Requirement] = []

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
	if socket_type == null or other == null or other.socket_type == null:
		return false
	return socket_type.is_compatible_with(other.socket_type)