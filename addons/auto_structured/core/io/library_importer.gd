@tool
class_name LibraryImporter extends RefCounted

## Handles importing module libraries from various formats.

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
const MaxCountRequirement = preload("res://addons/auto_structured/core/requirements/max_count_requirement.gd")
const AdjacentRequirement = preload("res://addons/auto_structured/core/requirements/adjacent_requirement.gd")
const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
const BoundaryRequirement = preload("res://addons/auto_structured/core/requirements/boundary_requirement.gd")

## Import a library from a file
static func import_library(file_path: String) -> ModuleLibrary:
	if file_path.ends_with(".tres"):
		return _import_from_resource(file_path)
	elif file_path.ends_with(".json"):
		return _import_from_json(file_path)
	
	push_error("Unsupported import format: %s" % file_path)
	return null

## Import from Godot resource (.tres)
static func _import_from_resource(file_path: String) -> ModuleLibrary:
	var resource = ResourceLoader.load(file_path)
	if resource is ModuleLibrary:
		return resource
	
	push_error("Resource is not a ModuleLibrary: %s" % file_path)
	return null

## Import from JSON
static func _import_from_json(file_path: String) -> ModuleLibrary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: %s" % file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return null
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON root is not a dictionary")
		return null
	
	return _dict_to_library(data)

## Convert dictionary to library
static func _dict_to_library(data: Dictionary) -> ModuleLibrary:
	var library = ModuleLibrary.new()
	
	# Basic properties
	library.library_name = data.get("library_name", "Imported Library")
	
	if data.has("cell_world_size"):
		var cws = data["cell_world_size"]
		library.cell_world_size = Vector3(
			cws.get("x", 1.0),
			cws.get("y", 1.0),
			cws.get("z", 1.0)
		)
	
	# Import socket types
	var socket_type_map = {}
	if data.has("socket_types"):
		for st_data in data["socket_types"]:
			var type_id: String = ""
			
			# Handle both old format (dict with type_id) and new format (string)
			if st_data is String:
				type_id = st_data
			elif st_data is Dictionary:
				type_id = st_data.get("type_id", "")
			
			if not type_id.is_empty():
				library.register_socket_type(type_id)
				socket_type_map[type_id] = type_id
	
	# Import tiles
	if data.has("tiles"):
		for tile_data in data["tiles"]:
			var tile = _dict_to_tile(tile_data, socket_type_map)
			if tile:
				library.tiles.append(tile)

	library.convert_legacy_socket_compatibility()
	
	return library

## Convert dictionary to tile
static func _dict_to_tile(data: Dictionary, socket_type_map: Dictionary) -> Tile:
	var tile = Tile.new()
	
	tile.name = data.get("name", "Unnamed Tile")
	tile.weight = data.get("weight", 1.0)
	
	# Size
	if data.has("size"):
		var s = data["size"]
		tile.size = Vector3i(
			s.get("x", 1),
			s.get("y", 1),
			s.get("z", 1)
		)
	
	# Rotation symmetry
	if data.has("rotation_symmetry"):
		tile.rotation_symmetry = _string_to_rotation_symmetry(data["rotation_symmetry"])
	
	if data.has("custom_rotations"):
		tile.custom_rotations.assign(data["custom_rotations"])
	
	# Tags
	if data.has("tags"):
		tile.tags.assign(data["tags"])
	
	# Mesh/Scene paths
	if data.has("mesh_path") and not data["mesh_path"].is_empty():
		tile.mesh = load(data["mesh_path"])
	
	if data.has("scene_path") and not data["scene_path"].is_empty():
		tile.scene = load(data["scene_path"])
	
	# Sockets
	if data.has("sockets"):
		for socket_data in data["sockets"]:
			var socket = Socket.new()
			
			if socket_data.has("direction"):
				var d = socket_data["direction"]
				socket.direction = Vector3i(
					d.get("x", 0),
					d.get("y", 0),
					d.get("z", 0)
				)
			
			var socket_type_id = socket_data.get("socket_type_id", "")
			socket.socket_id = socket_type_id
			
			socket.socket_guid = socket_data.get("socket_guid", "")
			# Import compatible sockets if present
			var legacy_types: Array = []
			# Prefer GUID-based compatibility arrays
			if socket_data.has("compatible_socket_guids"):
				for compat_guid in socket_data["compatible_socket_guids"]:
					socket.add_compatible_socket(compat_guid)
			elif socket_data.has("compatible_sockets"):
				legacy_types.assign(socket_data["compatible_sockets"])
			if not legacy_types.is_empty():
				socket.set_meta("legacy_compat_types", legacy_types)
			tile.sockets.append(socket)
	
	# Requirements (basic import - might need expansion)
	if data.has("requirements"):
		for req_data in data["requirements"]:
			var req = _dict_to_requirement(req_data)
			if req:
				tile.requirements.append(req)
	
	return tile

## Convert dictionary to requirement (basic version)
static func _dict_to_requirement(data: Dictionary) -> Requirement:
	var type = data.get("type", "")
	var req: Requirement = null
	
	match type:
		"HeightRequirement":
			req = HeightRequirement.new()
		"MaxCountRequirement":
			req = MaxCountRequirement.new()
		"AdjacentRequirement":
			req = AdjacentRequirement.new()
		"TagRequirement":
			req = TagRequirement.new()
		"BoundaryRequirement":
			req = BoundaryRequirement.new()
	
	if req:
		req.enabled = data.get("enabled", true)
		req.display_name = data.get("display_name", "")
	
	return req

## Helper to convert string to rotation symmetry enum
static func _string_to_rotation_symmetry(value: String) -> Tile.RotationSymmetry:
	match value.to_lower():
		"auto":
			return Tile.RotationSymmetry.AUTO
		"full":
			return Tile.RotationSymmetry.FULL
		"half":
			return Tile.RotationSymmetry.HALF
		"quarter":
			return Tile.RotationSymmetry.QUARTER
		"custom":
			return Tile.RotationSymmetry.CUSTOM
	return Tile.RotationSymmetry.AUTO
