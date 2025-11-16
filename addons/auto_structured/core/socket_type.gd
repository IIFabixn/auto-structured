@tool
class_name SocketType extends Resource

## Unique identifier for this socket type
@export var type_id: String = ""

## IDs of other types this type can connect to
@export var compatible_types: Array[String] = []

func add_compatible_type(id: String) -> void:
	if id in compatible_types:
		return
	var cp: Array[String] = []
	cp.assign(compatible_types)
	cp.append(id)
	compatible_types = cp

func remove_compatible_type(id: String) -> void:
	if id not in compatible_types:
		return
	var cp: Array[String] = []
	cp.assign(compatible_types)
	cp.erase(id)
	compatible_types = cp

func is_compatible_with(other: SocketType) -> bool:
	return other != null and other.type_id in compatible_types
