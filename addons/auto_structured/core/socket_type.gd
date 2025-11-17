@tool
class_name SocketType extends Resource

## Unique identifier for this socket type
@export var type_id: String = ""

## Optional human-friendly name shown in editors
@export var display_name: String = ""

## Optional category/group label (e.g. "Floor", "Wall")
@export var category: String = ""

## Optional descriptive text shown in tooltips
@export_multiline var description: String = ""

## Optional tint color used by UI (defaults to neutral gray)
@export var color: Color = Color(0.65, 0.65, 0.7, 1.0)

## IDs of other types this type can connect to
@export var compatible_types: Array[String] = []

func add_compatible_type(id: String) -> void:
	var clean := String(id).strip_edges()
	if clean == "":
		return
	if clean in compatible_types:
		return
	var cp: Array[String] = []
	cp.assign(compatible_types)
	cp.append(clean)
	cp.sort()
	compatible_types = cp

func remove_compatible_type(id: String) -> void:
	var clean := String(id).strip_edges()
	if clean not in compatible_types:
		return
	var cp: Array[String] = []
	cp.assign(compatible_types)
	cp.erase(clean)
	compatible_types = cp

func set_compatible_types(ids: Array[String]) -> void:
	var sanitized: Array[String] = []
	var seen: Dictionary = {}
	for id in ids:
		var clean := String(id).strip_edges()
		if clean == "":
			continue
		if seen.has(clean):
			continue
		seen[clean] = true
		sanitized.append(clean)
	sanitized.sort()
	compatible_types = sanitized

func get_display_name() -> String:
	var clean := display_name.strip_edges()
	return clean if clean != "" else type_id

func get_description() -> String:
	return description.strip_edges()

func is_compatible_with(other: SocketType) -> bool:
	return other != null and other.type_id in compatible_types
