@tool
class_name Socket extends Resource

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

var socket_id: String:
	set(value):
		_set_socket_id(value)
	get:
		return _get_socket_id()

var compatible_sockets: Array[String]:
	set(value):
		_set_compatible_sockets(value)
	get:
		return _get_compatible_sockets()

func add_compatible_socket(id: String) -> void:
	if socket_type == null:
		socket_type = SocketType.new()
	socket_type.add_compatible_type(String(id))

func remove_compatible_socket(id: String) -> void:
	if socket_type == null:
		return
	socket_type.remove_compatible_type(String(id))

func _get_socket_id() -> String:
	if socket_type == null:
		return ""
	return socket_type.type_id

func _set_socket_id(value: String) -> void:
	var trimmed := String(value).strip_edges()
	if trimmed == "":
		socket_type = null
		return
	if socket_type != null and socket_type.type_id == trimmed:
		return
	var new_type := SocketType.new()
	new_type.type_id = trimmed
	socket_type = new_type

func _get_compatible_sockets() -> Array[String]:
	if socket_type == null:
		return []
	var ids: Array[String] = []
	ids.assign(socket_type.compatible_types)
	return ids

func _set_compatible_sockets(values: Array) -> void:
	if socket_type == null:
		socket_type = SocketType.new()
	var sanitized: Array[String] = []
	var seen: Dictionary = {}
	for value in values:
		var clean := String(value).strip_edges()
		if clean == "":
			continue
		if seen.has(clean):
			continue
		seen[clean] = true
		sanitized.append(clean)
	socket_type.compatible_types = sanitized