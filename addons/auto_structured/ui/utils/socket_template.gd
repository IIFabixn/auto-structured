@tool
class_name SocketTemplate extends Resource

## Represents a reusable socket layout template that can be applied to a tile.
## Each entry describes the desired socket type, direction, compatibility list,
## and optional rotation requirement that should be imposed on that socket.

@export var template_name: String = ""
@export var description: String = ""
@export var entries: Array = []  # Array of dictionaries with keys described below

static func create_entry(direction: Vector3i, socket_id: String, compatible: Array[String] = [], minimum_rotation_degrees: int = 0) -> Dictionary:
	return {
		"direction": direction,
		"socket_id": socket_id,
		"compatible": compatible.duplicate(),
		"minimum_rotation_degrees": minimum_rotation_degrees
	}

static func normalize_entry(entry: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	normalized["direction"] = entry.get("direction", Vector3i.UP)
	normalized["socket_id"] = str(entry.get("socket_id", "none"))
	var compat: Array[String] = []
	var raw_compat = entry.get("compatible", [])
	for compat_id in raw_compat:
		compat.append(str(compat_id))
	normalized["compatible"] = compat
	normalized["minimum_rotation_degrees"] = int(entry.get("minimum_rotation_degrees", 0))
	return normalized
