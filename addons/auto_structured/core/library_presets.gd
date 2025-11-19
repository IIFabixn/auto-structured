@tool
class_name LibraryPresets
extends RefCounted

## Static utility class providing built-in presets for module libraries.
## Includes socket templates, tag presets, size presets, and socket type sets.

const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

## ============================================================================
## Socket Templates
## ============================================================================

static func get_socket_templates() -> Array[SocketTemplate]:
	"""Get all built-in socket templates."""
	var templates: Array[SocketTemplate] = []
	templates.append(_create_floor_template())
	templates.append(_create_wall_template())
	templates.append(_create_corner_template())
	return templates

static func _create_floor_template() -> SocketTemplate:
	"""Create a floor tile template with horizontal connections."""
	var template = SocketTemplate.new()
	template.template_name = "Floor - 4 Way"
	template.description = "Floor tile with 4 horizontal connections (N/S/E/W) and top/bottom"
	template.entries = [
		SocketTemplate.create_entry(Vector3i.RIGHT, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.LEFT, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.FORWARD, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.BACK, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.UP, "floor_top", ["floor_top"]),
		SocketTemplate.create_entry(Vector3i.DOWN, "floor_bottom", ["floor_bottom"])
	]
	return template

static func _create_wall_template() -> SocketTemplate:
	"""Create a wall tile template with forward/back connections."""
	var template = SocketTemplate.new()
	template.template_name = "Wall - Straight"
	template.description = "Wall tile with forward/back connections and side/top sockets"
	template.entries = [
		SocketTemplate.create_entry(Vector3i.FORWARD, "wall_forward", ["wall_forward"]),
		SocketTemplate.create_entry(Vector3i.BACK, "wall_forward", ["wall_forward"]),
		SocketTemplate.create_entry(Vector3i.LEFT, "wall_side", ["wall_side"]),
		SocketTemplate.create_entry(Vector3i.RIGHT, "wall_side", ["wall_side"]),
		SocketTemplate.create_entry(Vector3i.UP, "wall_top", ["wall_top"]),
		SocketTemplate.create_entry(Vector3i.DOWN, "floor_side", ["floor_side"])
	]
	return template

static func _create_corner_template() -> SocketTemplate:
	"""Create a corner tile template with L-shaped connections."""
	var template = SocketTemplate.new()
	template.template_name = "Corner - L Shape"
	template.description = "Corner tile with two perpendicular connections"
	template.entries = [
		SocketTemplate.create_entry(Vector3i.RIGHT, "corner_side", ["corner_side"]),
		SocketTemplate.create_entry(Vector3i.FORWARD, "corner_side", ["corner_side"]),
		SocketTemplate.create_entry(Vector3i.LEFT, "corner_block", ["corner_block"]),
		SocketTemplate.create_entry(Vector3i.BACK, "corner_block", ["corner_block"])
	]
	return template

static func apply_socket_template(tile: Tile, template: SocketTemplate, library) -> void:
	"""
	Apply a socket template to a tile.
	
	Args:
		tile: The tile to apply the template to
		template: The socket template to apply
		library: The module library (for registering socket types)
	"""
	if not tile or not template or not library:
		return
	
	# Clear existing sockets
	tile.sockets.clear()
	
	# Ensure all 6 directions are covered
	var covered_directions: Dictionary = {}
	
	# Apply template entries
	for entry_data in template.entries:
		var entry = SocketTemplate.normalize_entry(entry_data)
		var direction: Vector3i = entry["direction"]
		var socket_id: String = entry["socket_id"]
		var compatible: Array = entry["compatible"]
		
		# Register socket type in library
		var socket_type = library.ensure_socket_type(socket_id)
		if socket_type:
			# Update compatibility
			for compat_id in compatible:
				if not socket_type.compatible_types.has(compat_id):
					socket_type.compatible_types.append(compat_id)
		
		# Create socket
		var socket = Socket.new()
		socket.socket_type = socket_type
		socket.direction = direction
		tile.sockets.append(socket)
		
		covered_directions[direction] = true
	
	# Fill in missing directions with "none" type
	var all_directions = [
		Vector3i.UP, Vector3i.DOWN,
		Vector3i.LEFT, Vector3i.RIGHT,
		Vector3i.FORWARD, Vector3i.BACK
	]
	
	var none_type = library.ensure_socket_type("none")
	for direction in all_directions:
		if not covered_directions.has(direction):
			var socket = Socket.new()
			socket.socket_type = none_type
			socket.direction = direction
			tile.sockets.append(socket)

## ============================================================================
## Tag Presets
## ============================================================================

static func get_tag_presets() -> Dictionary:
	"""
	Get predefined tag collections organized by theme.
	
	Returns:
		Dictionary with theme names as keys and Array[String] of tags as values
	"""
	return {
		"architectural": [
			"interior", "exterior", "structural", "decorative",
			"floor", "wall", "ceiling", "corner", "edge"
		],
		"materials": [
			"stone", "wood", "brick", "metal", "concrete",
			"glass", "plastic", "fabric", "organic"
		],
		"medieval": [
			"dungeon", "castle", "village", "ruins",
			"cobblestone", "timber", "thatch"
		],
		"nature": [
			"grass", "dirt", "rock", "water", "sand",
			"mud", "snow", "ice", "lava"
		],
		"gameplay": [
			"walkable", "climbable", "destructible", "interactive",
			"hazard", "cover", "spawn_point", "objective"
		],
		"size": [
			"small", "medium", "large", "huge",
			"1x1", "2x2", "4x4"
		],
		"orientation": [
			"horizontal", "vertical", "diagonal",
			"straight", "corner", "T_junction", "cross"
		]
	}

static func get_all_preset_tags() -> Array[String]:
	"""Get a flat array of all unique tags from all presets."""
	var all_tags: Dictionary = {}
	var presets = get_tag_presets()
	
	for theme in presets.values():
		for tag in theme:
			all_tags[tag] = true
	
	var result: Array[String] = []
	for tag in all_tags.keys():
		result.append(tag)
	result.sort()
	return result

## ============================================================================
## Size Presets
## ============================================================================

static func get_size_presets() -> Dictionary:
	"""
	Get predefined tile size presets.
	
	Returns:
		Dictionary with preset names as keys and Vector3i sizes as values
	"""
	return {
		"Small (1x1x1)": Vector3i(1, 1, 1),
		"Floor Tile (1x1x1)": Vector3i(1, 1, 1),
		"Wall Segment (1x2x1)": Vector3i(1, 2, 1),
		"Door (1x3x1)": Vector3i(1, 3, 1),
		"Platform (2x1x2)": Vector3i(2, 1, 2),
		"Room (4x3x4)": Vector3i(4, 3, 4),
		"Large (2x2x2)": Vector3i(2, 2, 2),
		"Corridor (1x2x3)": Vector3i(1, 2, 3)
	}

## ============================================================================
## Socket Type Sets
## ============================================================================

static func get_socket_type_sets() -> Dictionary:
	"""
	Get predefined socket type sets with compatibility.
	
	Returns:
		Dictionary with set names as keys and socket type definitions as values.
		Each definition is an Array of Dictionaries with 'id', 'compatible', and 'description'.
	"""
	return {
		"Basic Set": [
			{"id": "none", "compatible": [], "description": "No connection allowed"},
			{"id": "any", "compatible": ["any"], "description": "Connects to anything"}
		],
		
		"Architectural Floor": [
			{"id": "floor_side", "compatible": ["floor_side", "wall_bottom"], "description": "Side edge of floor"},
			{"id": "floor_top", "compatible": ["floor_top"], "description": "Top surface of floor"},
			{"id": "floor_bottom", "compatible": ["floor_bottom"], "description": "Bottom surface of floor"}
		],
		
		"Architectural Wall": [
			{"id": "wall_forward", "compatible": ["wall_forward"], "description": "Front/back of wall"},
			{"id": "wall_side", "compatible": ["wall_side"], "description": "Left/right side of wall"},
			{"id": "wall_top", "compatible": ["wall_top", "ceiling_bottom"], "description": "Top of wall"},
			{"id": "wall_bottom", "compatible": ["wall_bottom", "floor_side"], "description": "Bottom of wall"}
		],
		
		"Corner Pieces": [
			{"id": "corner_side", "compatible": ["corner_side"], "description": "Open side of corner"},
			{"id": "corner_block", "compatible": ["corner_block"], "description": "Blocked side of corner"}
		],
		
		"Modular Grid": [
			{"id": "grid_connection", "compatible": ["grid_connection"], "description": "Standard grid connection"},
			{"id": "grid_edge", "compatible": ["grid_edge"], "description": "Edge boundary"},
			{"id": "grid_corner", "compatible": ["grid_corner"], "description": "Corner piece"}
		],
		
		"Dungeon Builder": [
			{"id": "dungeon_corridor", "compatible": ["dungeon_corridor", "dungeon_door"], "description": "Corridor connection"},
			{"id": "dungeon_room", "compatible": ["dungeon_room", "dungeon_door"], "description": "Room connection"},
			{"id": "dungeon_door", "compatible": ["dungeon_corridor", "dungeon_room"], "description": "Door connection"},
			{"id": "dungeon_wall", "compatible": [], "description": "Solid wall"}
		]
	}

static func apply_socket_type_set(library, set_name: String) -> bool:
	"""
	Apply a socket type set to a library.
	
	Args:
		library: The ModuleLibrary to add socket types to
		set_name: Name of the socket type set to apply
	
	Returns:
		true if successful, false if set_name not found
	"""
	var sets = get_socket_type_sets()
	if not sets.has(set_name):
		return false
	
	var socket_defs = sets[set_name]
	for def in socket_defs:
		var socket_type = library.ensure_socket_type(def["id"])
		if socket_type:
			socket_type.display_name = def.get("description", "")
			# Set compatibility
			var compatible: Array = def.get("compatible", [])
			for compat_id in compatible:
				if not socket_type.compatible_types.has(compat_id):
					socket_type.compatible_types.append(compat_id)
	
	return true

static func get_socket_type_set_names() -> Array[String]:
	"""Get list of available socket type set names."""
	var sets = get_socket_type_sets()
	var names: Array[String] = []
	for name in sets.keys():
		names.append(name)
	return names
