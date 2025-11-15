@tool
class_name TilePresetStore
extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const TileClipboard = preload("res://addons/auto_structured/ui/utils/tile_clipboard.gd")

const PRESET_DIR := "user://auto_structured_tile_presets/"

static func list_presets() -> Array:
	_ensure_directory()
	var dir := DirAccess.open(PRESET_DIR)
	if not dir:
		return []
	var results: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var preset_id := entry.get_basename()
			var display_name := preset_id
			var resource: Tile = ResourceLoader.load(PRESET_DIR + entry)
			if resource and resource.resource_name != "":
				display_name = resource.resource_name
			results.append({
				"id": preset_id,
				"name": display_name
			})
		entry = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a, b):
		return str(a["name"]).to_lower() < str(b["name"]).to_lower()
	)
	return results

static func save_preset(display_name: String, tile: Tile) -> Error:
	if not tile:
		return ERR_INVALID_PARAMETER
	var sanitized := _sanitize_name(display_name)
	if sanitized.is_empty():
		return ERR_INVALID_PARAMETER
	_ensure_directory()
	var payload := TileClipboard.build_payload(tile)
	var preset_resource := TileClipboard.payload_to_tile_resource(payload)
	preset_resource.resource_name = display_name
	var path := PRESET_DIR + sanitized + ".tres"
	return ResourceSaver.save(preset_resource, path)

static func load_preset(preset_id: String) -> Dictionary:
	if preset_id.is_empty():
		return {}
	var path := PRESET_DIR + preset_id + ".tres"
	if not FileAccess.file_exists(path):
		return {}
	var resource: Tile = ResourceLoader.load(path)
	if not resource:
		return {}
	return TileClipboard.build_payload(resource)

static func delete_preset(preset_id: String) -> Error:
	if preset_id.is_empty():
		return ERR_INVALID_PARAMETER
	var path := PRESET_DIR + preset_id + ".tres"
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path):
		return ERR_DOES_NOT_EXIST
	return DirAccess.remove_absolute(absolute)

static func preset_exists(display_name: String) -> bool:
	var sanitized := _sanitize_name(display_name)
	var path := PRESET_DIR + sanitized + ".tres"
	return FileAccess.file_exists(path)

static func _ensure_directory() -> void:
	var absolute := ProjectSettings.globalize_path(PRESET_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)

static func _sanitize_name(name: String) -> String:
	var cleaned := name.strip_edges()
	if cleaned.is_empty():
		return ""
	var result := ""
	for char in cleaned:
		if _is_ascii_alphanumeric(char) or char in [" ", "_", "-", "."]:
			result += char
		else:
			result += "_"
	return result.strip_edges()

static func _is_ascii_alphanumeric(char: String) -> bool:
	if char.length() != 1:
		return false
	var code := char.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
