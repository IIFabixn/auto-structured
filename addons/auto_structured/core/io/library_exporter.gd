@tool
class_name LibraryExporter extends RefCounted

## Handles exporting module libraries to various formats.

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

enum ExportFormat {
	GODOT_RESOURCE,  ## Native .tres format
	JSON,            ## JSON format for external tools
	MARKDOWN         ## Human-readable documentation
}

## Export a library to a file
static func export_library(library: ModuleLibrary, file_path: String, format: ExportFormat = ExportFormat.GODOT_RESOURCE) -> Error:
	match format:
		ExportFormat.GODOT_RESOURCE:
			return _export_as_resource(library, file_path)
		ExportFormat.JSON:
			return _export_as_json(library, file_path)
		ExportFormat.MARKDOWN:
			return _export_as_markdown(library, file_path)
	
	return ERR_INVALID_PARAMETER

## Export as Godot resource (.tres)
static func _export_as_resource(library: ModuleLibrary, file_path: String) -> Error:
	if not file_path.ends_with(".tres"):
		file_path += ".tres"
	
	return ResourceSaver.save(library, file_path)

## Export as JSON
static func _export_as_json(library: ModuleLibrary, file_path: String) -> Error:
	if not file_path.ends_with(".json"):
		file_path += ".json"
	
	var data = _library_to_dict(library)
	var json_string = JSON.stringify(data, "\t")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(json_string)
	file.close()
	
	return OK

## Export as Markdown documentation
static func _export_as_markdown(library: ModuleLibrary, file_path: String) -> Error:
	if not file_path.ends_with(".md"):
		file_path += ".md"
	
	var md = _library_to_markdown(library)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(md)
	file.close()
	
	return OK

## Convert library to dictionary for JSON export
static func _library_to_dict(library: ModuleLibrary) -> Dictionary:
	var data = {
		"library_name": library.library_name,
		"cell_world_size": {
			"x": library.cell_world_size.x,
			"y": library.cell_world_size.y,
			"z": library.cell_world_size.z
		},
		"socket_types": [],
		"tiles": []
	}
	
	# Export socket types
	for socket_type in library.socket_types:
		data["socket_types"].append({
			"type_id": socket_type.type_id,
			"display_name": socket_type.display_name,
			"compatible_types": socket_type.compatible_types.duplicate()
		})
	
	# Export tiles
	for tile in library.tiles:
		var tile_data = {
			"name": tile.name,
			"size": {
				"x": tile.size.x,
				"y": tile.size.y,
				"z": tile.size.z
			},
			"weight": tile.weight,
			"rotation_symmetry": _rotation_symmetry_to_string(tile.rotation_symmetry),
			"custom_rotations": tile.custom_rotations.duplicate(),
			"tags": tile.tags.duplicate(),
			"sockets": [],
			"requirements": [],
			"mesh_path": tile.mesh.resource_path if tile.mesh else "",
			"scene_path": tile.scene.resource_path if tile.scene else ""
		}
		
		# Export sockets
		for socket in tile.sockets:
			tile_data["sockets"].append({
				"direction": {
					"x": socket.direction.x,
					"y": socket.direction.y,
					"z": socket.direction.z
				},
				"socket_type_id": socket.socket_type.type_id if socket.socket_type else ""
			})
		
		# Export requirements (basic info)
		for req in tile.requirements:
			tile_data["requirements"].append({
				"type": req.get_class(),
				"enabled": req.enabled,
				"display_name": req.display_name
			})
		
		data["tiles"].append(tile_data)
	
	return data

## Convert library to Markdown documentation
static func _library_to_markdown(library: ModuleLibrary) -> String:
	var md = "# %s\n\n" % library.library_name
	
	# Library info
	md += "## Library Information\n\n"
	md += "- **Tile Count**: %d\n" % library.tiles.size()
	md += "- **Socket Types**: %d\n" % library.socket_types.size()
	md += "- **Cell World Size**: %.2f × %.2f × %.2f\n\n" % [
		library.cell_world_size.x,
		library.cell_world_size.y,
		library.cell_world_size.z
	]
	
	# Socket types
	md += "## Socket Types\n\n"
	for socket_type in library.socket_types:
		md += "### %s\n\n" % (socket_type.display_name if not socket_type.display_name.is_empty() else socket_type.type_id)
		md += "- **ID**: `%s`\n" % socket_type.type_id
		md += "- **Compatible With**: %s\n\n" % (", ".join(socket_type.compatible_types) if not socket_type.compatible_types.is_empty() else "None")
	
	# Tiles
	md += "## Tiles\n\n"
	for tile in library.tiles:
		md += "### %s\n\n" % tile.name
		md += "- **Size**: %d × %d × %d\n" % [tile.size.x, tile.size.y, tile.size.z]
		md += "- **Weight**: %.2f\n" % tile.weight
		md += "- **Rotation Symmetry**: %s\n" % _rotation_symmetry_to_string(tile.rotation_symmetry)
		md += "- **Unique Rotations**: %s\n" % str(tile.get_unique_rotations())
		
		if not tile.tags.is_empty():
			md += "- **Tags**: %s\n" % ", ".join(tile.tags)
		
		if not tile.sockets.is_empty():
			md += "- **Sockets**: %d\n" % tile.sockets.size()
			for socket in tile.sockets:
				var dir_name = _direction_to_string(socket.direction)
				var socket_type_name = socket.socket_type.type_id if socket.socket_type else "none"
				md += "  - %s: `%s`\n" % [dir_name, socket_type_name]
		
		if not tile.requirements.is_empty():
			md += "- **Requirements**: %d\n" % tile.requirements.size()
			for req in tile.requirements:
				md += "  - %s (%s)\n" % [req.get_class(), "enabled" if req.enabled else "disabled"]
		
		md += "\n"
	
	return md

## Helper to convert rotation symmetry enum to string
static func _rotation_symmetry_to_string(symmetry: Tile.RotationSymmetry) -> String:
	match symmetry:
		Tile.RotationSymmetry.AUTO:
			return "Auto"
		Tile.RotationSymmetry.FULL:
			return "Full"
		Tile.RotationSymmetry.HALF:
			return "Half"
		Tile.RotationSymmetry.QUARTER:
			return "Quarter"
		Tile.RotationSymmetry.CUSTOM:
			return "Custom"
	return "Unknown"

## Helper to convert direction vector to string
static func _direction_to_string(direction: Vector3i) -> String:
	if direction == Vector3i.RIGHT:
		return "Right (+X)"
	elif direction == Vector3i.LEFT:
		return "Left (-X)"
	elif direction == Vector3i.FORWARD:
		return "Forward (-Z)"
	elif direction == Vector3i.BACK:
		return "Back (+Z)"
	elif direction == Vector3i.UP:
		return "Up (+Y)"
	elif direction == Vector3i.DOWN:
		return "Down (-Y)"
	return "Custom (%d, %d, %d)" % [direction.x, direction.y, direction.z]
