class_name Socket extends Resource

## Unique identifier for this socket type
@export var socket_id: String = ""

## Direction this socket is facing (must be one of the 6 cardinal directions)
@export var direction: Vector3i = Vector3i.UP:
	set(value):
		if is_valid_direction(value):
			direction = value
		else:
			push_warning("Socket: Invalid direction %s. Must be cardinal direction." % value)
			direction = Vector3i.UP

## List of socket IDs that are compatible with this socket
@export var compatible_sockets: Array[String] = []

static func is_valid_direction(dir: Vector3i) -> bool:
	"""Check if direction is one of the 6 cardinal directions."""
	return dir in [
		Vector3i.RIGHT,   # (1, 0, 0)
		Vector3i.LEFT,    # (-1, 0, 0)
		Vector3i.UP,      # (0, 1, 0)
		Vector3i.DOWN,    # (0, -1, 0)
		Vector3i.FORWARD, # (0, 0, -1)
		Vector3i.BACK     # (0, 0, 1)
	]

func is_compatible_with(other_socket: Socket) -> bool:
	"""
	Check if this socket is compatible with another socket.

	Args:
		other_socket: The socket to check compatibility against

	Returns:
		true if compatible, false otherwise
	"""
	return other_socket.socket_id in compatible_sockets