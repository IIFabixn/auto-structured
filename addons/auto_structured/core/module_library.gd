@tool
class_name ModuleLibrary extends Resource

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")
const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")

## Emitted when a tile is added to the library
signal tile_added(tile: Tile)

## Emitted when a tile is removed from the library
signal tile_removed(tile: Tile)

## Emitted when a tile is modified (name, tags, sockets, etc.)
signal tile_modified(tile: Tile, property: String)

## Emitted when a socket type is added
signal socket_type_added(socket_type_id: String)

## Emitted when a socket type is removed
signal socket_type_removed(socket_type_id: String)

## Emitted when a socket type is renamed
signal socket_type_renamed(old_id: String, new_id: String)

## Emitted when socket compatibility changes
signal socket_compatibility_changed

## Emitted when the library is modified in any way
signal library_changed

@export var library_name: String = "My Building Set"
@export var tiles: Array[Tile] = []
@export var socket_types: Array[String] = []  ## Registered socket type IDs for this library
@export var available_tags: Array[String] = []  ## Available tags for tiles in this library
@export var cell_world_size: Vector3 = Vector3(1, 1, 1)  ## Size of each grid cell in world units
@export var custom_socket_templates: Array[SocketTemplate] = []
@export var hidden_builtin_template_names: Array[String] = []

func ensure_defaults() -> void:
	"""
	Ensure default socket types exist in the library.
	Call this explicitly when setting up the library, not in _init.
	"""
	# Create "none" socket type if it doesn't exist
	if "none" not in socket_types:
		socket_types.append("none")
	
	# Create "any" socket type if it doesn't exist
	if "any" not in socket_types:
		socket_types.append("any")
	
	socket_types.sort()

	# Ensure cell size has sane defaults
	if cell_world_size.x <= 0.0 or cell_world_size.y <= 0.0 or cell_world_size.z <= 0.0:
		cell_world_size = Vector3(2, 3, 2)

func convert_legacy_socket_compatibility() -> bool:
	"""Convert legacy type-based compatibility strings into GUID references."""
	var sockets_by_type: Dictionary = {}
	var converted := false
	for tile in tiles:
		for socket in tile.sockets:
			if socket == null:
				continue
			socket.ensure_guid()
			var type_name := String(socket.socket_id).strip_edges()
			if type_name == "":
				continue
			if not sockets_by_type.has(type_name):
				sockets_by_type[type_name] = []
			sockets_by_type[type_name].append(socket)
	for tile in tiles:
		for socket in tile.sockets:
			if socket == null:
				continue
			var legacy_types: Array[String] = []
			var guid_entries: Array[String] = []
			if socket.has_meta("legacy_compat_types"):
				var meta_list: Array = socket.get_meta("legacy_compat_types")
				socket.set_meta("legacy_compat_types", null)
				for type_name in meta_list:
					var clean_meta := String(type_name).strip_edges()
					if clean_meta != "":
						legacy_types.append(clean_meta)
			for compat_entry in socket.compatible_sockets:
				var clean_entry := String(compat_entry).strip_edges()
				if clean_entry == "":
					continue
				if _looks_like_guid(clean_entry):
					guid_entries.append(clean_entry)
				else:
					legacy_types.append(clean_entry)
			if legacy_types.is_empty():
				continue
			converted = true
			socket.compatible_sockets.clear()
			for guid in guid_entries:
				socket.add_compatible_socket(guid)
			for type_name in legacy_types:
				var targets: Array = sockets_by_type.get(type_name, [])
				for target in targets:
					if target and target != socket:
						socket.add_compatible_socket(target.socket_guid)
	return converted

static func _looks_like_guid(value: String) -> bool:
	var clean := String(value).strip_edges()
	if clean.length() != 36:
		return false
	var hyphen_positions := [8, 13, 18, 23]
	for pos in hyphen_positions:
		if clean[pos] != "-":
			return false
	for i in range(clean.length()):
		if i in hyphen_positions:
			continue
		var char_code := clean[i].unicode_at(0)
		var is_digit := char_code >= 48 and char_code <= 57
		var is_lower := char_code >= 97 and char_code <= 102
		var is_upper := char_code >= 65 and char_code <= 70
		if not (is_digit or is_lower or is_upper):
			return false
	return true

func get_tile_by_name(name: String) -> Tile:
	for tile in tiles:
		if tile.name == name:
			return tile
	return null

func get_tiles_with_tag(tag: String) -> Array[Tile]:
	return tiles.filter(func(t): return t.tags.has(tag))

func add_available_tag(tag: String) -> void:
	"""Add a tag to the available tags pool."""
	var clean_tag = tag.strip_edges()
	if not clean_tag.is_empty() and not available_tags.has(clean_tag):
		available_tags.append(clean_tag)
		available_tags.sort()
		library_changed.emit()

func remove_available_tag(tag: String, remove_from_tiles: bool = true) -> bool:
	"""Remove a tag from the available pool and optionally from all tiles."""
	var clean_tag := String(tag).strip_edges()
	if clean_tag.is_empty():
		return false

	if not available_tags.has(clean_tag):
		return false

	available_tags.erase(clean_tag)
	available_tags.sort()

	var modified_tiles := false
	if remove_from_tiles:
		for tile in tiles:
			if tile.has_tag(clean_tag):
				tile.remove_tag(clean_tag)
				notify_tile_modified(tile, "tags")
				modified_tiles = true

	if not modified_tiles:
		library_changed.emit()

	return true

func rename_available_tag(old_name: String, new_name: String) -> bool:
	"""Rename an available tag and update all tiles using it."""
	var clean_old := String(old_name).strip_edges()
	var clean_new := String(new_name).strip_edges()

	if clean_old.is_empty() or clean_new.is_empty():
		return false

	if clean_old == clean_new:
		return true

	if not available_tags.has(clean_old):
		return false

	if available_tags.has(clean_new):
		return false

	var index := available_tags.find(clean_old)
	if index == -1:
		return false

	available_tags[index] = clean_new
	available_tags.sort()

	var modified_tiles := false
	for tile in tiles:
		if tile.has_tag(clean_old):
			tile.remove_tag(clean_old)
			if not tile.has_tag(clean_new):
				tile.add_tag(clean_new)
			notify_tile_modified(tile, "tags")
			modified_tiles = true

	if not modified_tiles:
		library_changed.emit()

	return true

func get_available_tags() -> Array[String]:
	"""Get all available tags for this library."""
	return available_tags.duplicate()

## ============================================================================
## Socket Templates
## ============================================================================

static func _normalize_template_key(name: String) -> String:
	return String(name).strip_edges().to_lower()

func get_socket_templates(include_builtin: bool = true) -> Array[SocketTemplate]:
	var templates: Array[SocketTemplate] = []
	var override_keys: Dictionary = {}
	for template in custom_socket_templates:
		if template == null:
			continue
		var key = _normalize_template_key(template.template_name)
		if key != "":
			override_keys[key] = true
	if include_builtin:
		var builtin = LibraryPresets.get_socket_templates()
		for template in builtin:
			if template == null:
				continue
			var key = _normalize_template_key(template.template_name)
			if key == "":
				continue
			if is_builtin_template_hidden(template.template_name):
				continue
			if override_keys.has(key):
				continue
			templates.append(template)
	for template in custom_socket_templates:
		if template:
			templates.append(template)
	return templates

func get_custom_socket_templates() -> Array[SocketTemplate]:
	var templates: Array[SocketTemplate] = []
	for template in custom_socket_templates:
		if template:
			templates.append(template)
	return templates

func add_custom_socket_template(template: SocketTemplate) -> void:
	if template == null:
		return
	custom_socket_templates.append(template)
	library_changed.emit()

func remove_custom_socket_template(template: SocketTemplate) -> bool:
	if template == null:
		return false
	var index := custom_socket_templates.find(template)
	if index == -1:
		return false
	custom_socket_templates.remove_at(index)
	library_changed.emit()
	return true

func is_builtin_template_hidden(template_name: String) -> bool:
	var key = _normalize_template_key(template_name)
	if key == "":
		return false
	return hidden_builtin_template_names.has(key)

func hide_builtin_template(template_name: String) -> bool:
	var key = _normalize_template_key(template_name)
	if key == "":
		return false
	if hidden_builtin_template_names.has(key):
		return false
	hidden_builtin_template_names.append(key)
	library_changed.emit()
	return true

func restore_all_builtin_templates() -> void:
	if hidden_builtin_template_names.is_empty():
		return
	hidden_builtin_template_names.clear()
	library_changed.emit()

func has_hidden_builtin_templates() -> bool:
	return not hidden_builtin_template_names.is_empty()

func get_all_unique_socket_ids() -> Array[String]:
	"""
	Get all unique socket type IDs from all tiles in this library.
	
	Returns:
		A sorted array of unique socket type ID strings
	"""
	var socket_ids: Array[String] = []
	var unique_ids: Dictionary = {}
	
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_id and not unique_ids.has(socket.socket_id):
				unique_ids[socket.socket_id] = true
				socket_ids.append(socket.socket_id)
	
	socket_ids.sort()
	return socket_ids

func register_socket_type(socket_id: String) -> void:
	"""
	Register a new socket type ID in this library.

	Args:
		socket_id: The socket type ID to register
	"""
	var normalized_id = socket_id.strip_edges()
	if normalized_id.is_empty():
		return
	
	if normalized_id in socket_types:
		return
	
	socket_types.append(normalized_id)
	socket_types.sort()
	socket_type_added.emit(normalized_id)
	library_changed.emit()

func has_socket_type(socket_id: String) -> bool:
	"""
	Check if a socket type ID exists in this library.
	
	Args:
		socket_id: The socket ID to check
	
	Returns:
		true if the socket type exists, false otherwise
	"""
	return socket_id in socket_types

func ensure_socket_type(socket_id: String) -> void:
	"""
	Ensure a socket type ID exists in the library, registering it if needed.
	
	Args:
		socket_id: The socket ID to ensure exists
	"""
	register_socket_type(socket_id)

func get_socket_type_ids() -> Array[String]:
	"""
	Get all registered socket type IDs.
	
	Returns:
		A copy of the socket types array
	"""
	var ids: Array[String] = []
	ids.assign(socket_types)
	return ids

func validate_socket_id(socket_id: String) -> bool:
	"""
	Check if a socket ID is registered in this library.
	
	Args:
		socket_id: The socket ID to validate
	
	Returns:
		true if the socket ID is registered, false otherwise
	"""
	return socket_id in socket_types

func get_socket_types() -> Array[String]:
	"""
	Get a copy of all registered socket type IDs.
	
	Returns:
		A sorted array of registered socket type IDs
	"""
	var types_copy: Array[String] = []
	types_copy.assign(socket_types)
	return types_copy

func rename_socket_type(old_id: String, new_id: String) -> bool:
	"""Rename a socket type and update all references in tiles."""
	if old_id not in socket_types:
		return false
	var clean_new := new_id.strip_edges()
	if clean_new.is_empty():
		return false
	if old_id == clean_new:
		return true
	if clean_new in socket_types:
		return false
	
	# Update the socket_types array
	var index = socket_types.find(old_id)
	if index >= 0:
		socket_types[index] = clean_new
	socket_types.sort()
	
	# Update all sockets that use this socket ID
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_id == old_id:
				socket.socket_id = clean_new
	
	socket_type_renamed.emit(old_id, clean_new)
	library_changed.emit()
	return true

func delete_socket_type(id: String, fallback_id: String = "none") -> bool:
	"""Delete a socket type from the library and migrate sockets to fallback."""
	var normalized_id := id.strip_edges()
	if normalized_id not in socket_types:
		return false
	
	# Prevent removing required defaults
	if normalized_id == "none" or normalized_id == "any":
		return false
	
	# Ensure fallback exists
	register_socket_type(fallback_id)
	
	# Remove from socket_types array
	socket_types.erase(normalized_id)
	
	# Update sockets referencing this type
	for tile in tiles:
		for socket in tile.sockets:
			if socket.socket_id == normalized_id:
				socket.socket_id = fallback_id
	
	socket_type_removed.emit(normalized_id)
	library_changed.emit()
	return true

func validate_library() -> Dictionary:
	"""
	Validate the library for issues like orphan socket references.
	
	Returns:
		Dictionary with keys:
		- "valid" (bool): true if no issues found
		- "issues" (Array[String]): List of validation issues
	"""
	convert_legacy_socket_compatibility()
	var all_socket_ids = get_all_unique_socket_ids()
	var socket_guid_map: Dictionary = {}
	for tile in tiles:
		for socket in tile.sockets:
			if socket == null:
				continue
			socket.ensure_guid()
			socket_guid_map[socket.socket_guid] = true
	var issues: Array[String] = []
	
	for tile in tiles:
		for socket in tile.sockets:
			# Check if socket ID is empty
			if socket.socket_id.strip_edges().is_empty():
				issues.append("Tile '%s' has a socket with empty socket_id" % tile.name)
				continue
			
			# Check if socket ID is registered
			if socket.socket_id and not validate_socket_id(socket.socket_id):
				issues.append("Socket '%s' on tile '%s' is not registered in socket_types" % [socket.socket_id, tile.name])
			
			# Check if any compatible socket doesn't exist in library
			for compat_guid in socket.compatible_sockets:
				var clean := String(compat_guid).strip_edges()
				if clean == "":
					issues.append("Socket '%s' on tile '%s' has an empty compatibility entry" % [socket.socket_id, tile.name])
					continue
				if not socket_guid_map.has(clean):
					issues.append("Socket '%s' on tile '%s' references unknown socket GUID '%s'" % [socket.socket_id, tile.name, clean])
	
	return {"valid": issues.is_empty(), "issues": issues}

func get_socket_by_guid(guid: String) -> Socket:
	"""Find any socket in the library by its GUID."""
	var clean := String(guid).strip_edges()
	if clean == "":
		return null
	for tile in tiles:
		var socket := tile.get_socket_by_guid(clean)
		if socket:
			return socket
	return null


## Add a tile to the library and emit event
func add_tile(tile: Tile) -> void:
	if tile in tiles:
		return
	tiles.append(tile)
	tile_added.emit(tile)
	library_changed.emit()


## Remove a tile from the library and emit event
func remove_tile(tile: Tile) -> bool:
	if tile not in tiles:
		return false
	tiles.erase(tile)
	tile_removed.emit(tile)
	library_changed.emit()
	return true


## Notify that a tile was modified (call this after changing tile properties)
func notify_tile_modified(tile: Tile, property: String = "") -> void:
	if tile not in tiles:
		return
	tile_modified.emit(tile, property)
	library_changed.emit()


## Notify that socket compatibility changed
func notify_socket_compatibility_changed() -> void:
	socket_compatibility_changed.emit()
	library_changed.emit()
