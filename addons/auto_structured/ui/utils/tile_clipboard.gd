@tool
class_name TileClipboard
extends Object

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

static var _tile_payload: Dictionary = {}
static var _tile_source: String = ""
static var _has_tile_payload := false

static var _tags_payload: Array = []
static var _tags_source: String = ""
static var _has_tags_payload := false

static var _requirements_payload: Array = []
static var _requirements_source: String = ""
static var _has_requirements_payload := false

static var _sockets_payload: Dictionary = {}
static var _sockets_source: String = ""
static var _has_sockets_payload := false

static var _single_socket_payload: Dictionary = {}
static var _single_socket_source: String = ""
static var _has_single_socket_payload := false

static func clear_all() -> void:
	_tile_payload.clear()
	_tile_source = ""
	_has_tile_payload = false

	_tags_payload.clear()
	_tags_source = ""
	_has_tags_payload = false

	_requirements_payload.clear()
	_requirements_source = ""
	_has_requirements_payload = false

	_sockets_payload.clear()
	_sockets_source = ""
	_has_sockets_payload = false

	_single_socket_payload.clear()
	_single_socket_source = ""
	_has_single_socket_payload = false

static func copy_tile(tile: Tile) -> void:
	if not tile:
		return
	tile.ensure_all_sockets()
	_tile_payload = build_payload(tile)
	_tile_source = tile.name
	_has_tile_payload = true

	# Also prime specific clipboards for convenience
	_tags_payload = _duplicate_tags(tile.tags)
	_tags_source = tile.name
	_has_tags_payload = true

	_requirements_payload = _duplicate_requirements(tile.requirements)
	_requirements_source = tile.name
	_has_requirements_payload = true

	_sockets_payload = _serialize_all_sockets(tile)
	_sockets_source = tile.name
	_has_sockets_payload = true

static func paste_tile(tile: Tile, library: ModuleLibrary) -> bool:
	if not tile or not _has_tile_payload:
		return false
	return apply_payload(tile, library, _tile_payload)

static func copy_tags(tile: Tile) -> void:
	if not tile:
		return
	_tags_payload = _duplicate_tags(tile.tags)
	_tags_source = tile.name
	_has_tags_payload = true

static func paste_tags(tile: Tile) -> bool:
	if not tile or not _has_tags_payload:
		return false
	var tags_copy: Array[String] = _duplicate_tags(_tags_payload)
	tile.tags = tags_copy
	return true

static func copy_requirements(tile: Tile) -> void:
	if not tile:
		return
	_requirements_payload = _duplicate_requirements(tile.requirements)
	_requirements_source = tile.name
	_has_requirements_payload = true

static func paste_requirements(tile: Tile) -> bool:
	if not tile or not _has_requirements_payload:
		return false
	tile.requirements = _duplicate_requirements(_requirements_payload)
	return true

static func copy_all_sockets(tile: Tile) -> void:
	if not tile:
		return
	tile.ensure_all_sockets()
	_sockets_payload = _serialize_all_sockets(tile)
	_sockets_source = tile.name
	_has_sockets_payload = true

static func paste_all_sockets(tile: Tile, library: ModuleLibrary) -> bool:
	if not tile or not _has_sockets_payload:
		return false
	var socket_map: Dictionary = {}
	for key in _sockets_payload.keys():
		socket_map[key] = (_sockets_payload[key] as Socket).duplicate(true)
	var new_sockets: Array[Socket] = []
	for direction in _canonical_directions():
		var dir_key := _direction_key(direction)
		var socket_copy: Socket
		if socket_map.has(dir_key):
			socket_copy = socket_map[dir_key]
			socket_copy.direction = direction
		else:
			socket_copy = Socket.new()
			socket_copy.direction = direction
			socket_copy.socket_id = "none"
		new_sockets.append(socket_copy)
		_register_socket_types(library, socket_copy)
	tile.sockets = new_sockets
	tile.ensure_all_sockets()
	return true

static func copy_socket(socket: Socket, owner_tile_name: String = "") -> void:
	if not socket:
		return
	var socket_copy := socket.duplicate(true)
	_single_socket_payload = {
		"socket": socket_copy
	}
	_single_socket_source = owner_tile_name
	_has_single_socket_payload = true

static func paste_socket(target_socket: Socket, library: ModuleLibrary) -> bool:
	if not target_socket or not _has_single_socket_payload:
		return false
	var stored: Socket = _single_socket_payload.get("socket", null)
	if not stored:
		return false
	var socket_copy := stored.duplicate(true)
	target_socket.socket_id = socket_copy.socket_id
	target_socket.compatible_sockets = socket_copy.compatible_sockets.duplicate()
	target_socket.requirements = _duplicate_requirements(socket_copy.requirements)
	_register_socket_types(library, target_socket)
	return true

static func build_payload(tile: Tile) -> Dictionary:
	if not tile:
		return {}
	var payload: Dictionary = {}
	payload["size"] = tile.size
	payload["symmetry"] = int(tile.symmetry)
	payload["tags"] = _duplicate_tags(tile.tags)
	payload["requirements"] = _duplicate_requirements(tile.requirements)
	payload["sockets"] = _serialize_all_sockets(tile)
	return payload

static func apply_payload(tile: Tile, library: ModuleLibrary, payload: Dictionary) -> bool:
	if not tile or payload.is_empty():
		return false
	if payload.has("size"):
		var size_value = payload["size"]
		if size_value is Vector3i:
			tile.size = size_value
	if payload.has("symmetry"):
		var symmetry_value = int(payload["symmetry"])
		tile.symmetry = symmetry_value
	if payload.has("tags"):
		var tag_array: Array = payload["tags"]
		tile.tags = _duplicate_tags(tag_array)
	if payload.has("requirements"):
		var req_array: Array = payload["requirements"]
		tile.requirements = _duplicate_requirements(req_array)
	if payload.has("sockets"):
		var socket_map: Dictionary = payload["sockets"]
		var new_sockets: Array[Socket] = []
		for direction in _canonical_directions():
			var dir_key := _direction_key(direction)
			var socket_copy: Socket
			if socket_map.has(dir_key):
				socket_copy = (socket_map[dir_key] as Socket).duplicate(true)
				socket_copy.direction = direction
			else:
				socket_copy = Socket.new()
				socket_copy.direction = direction
				socket_copy.socket_id = "none"
			new_sockets.append(socket_copy)
			_register_socket_types(library, socket_copy)
		tile.sockets = new_sockets
		tile.ensure_all_sockets()
	return true

static func payload_to_tile_resource(payload: Dictionary) -> Tile:
	var tile := Tile.new()
	if payload.is_empty():
		tile.ensure_all_sockets()
		return tile
	if payload.has("size"):
		tile.size = payload["size"]
	if payload.has("symmetry"):
		tile.symmetry = int(payload["symmetry"])
	if payload.has("tags"):
		tile.tags = _duplicate_tags(payload["tags"])
	if payload.has("requirements"):
		tile.requirements = _duplicate_requirements(payload["requirements"])
	var new_sockets: Array[Socket] = []
	if payload.has("sockets"):
		var socket_map: Dictionary = payload["sockets"]
		for direction in _canonical_directions():
			var dir_key := _direction_key(direction)
			var socket_copy: Socket
			if socket_map.has(dir_key):
				socket_copy = (socket_map[dir_key] as Socket).duplicate(true)
				socket_copy.direction = direction
			else:
				socket_copy = Socket.new()
				socket_copy.direction = direction
				socket_copy.socket_id = "none"
			new_sockets.append(socket_copy)
	else:
		for direction in _canonical_directions():
			var socket_copy := Socket.new()
			socket_copy.direction = direction
			socket_copy.socket_id = "none"
			new_sockets.append(socket_copy)
	tile.sockets = new_sockets
	tile.ensure_all_sockets()
	return tile

static func payload_from_tile_resource(tile_resource: Tile) -> Dictionary:
	return build_payload(tile_resource)

static func has_tile_payload() -> bool:
	return _has_tile_payload

static func has_tags_payload() -> bool:
	return _has_tags_payload

static func has_requirements_payload() -> bool:
	return _has_requirements_payload

static func has_sockets_payload() -> bool:
	return _has_sockets_payload

static func has_single_socket_payload() -> bool:
	return _has_single_socket_payload

static func tile_source_label() -> String:
	return _tile_source

static func tags_source_label() -> String:
	return _tags_source

static func requirements_source_label() -> String:
	return _requirements_source

static func sockets_source_label() -> String:
	return _sockets_source

static func single_socket_source_label() -> String:
	return _single_socket_source

static func _serialize_all_sockets(tile: Tile) -> Dictionary:
	var socket_map: Dictionary = {}
	for socket in tile.sockets:
		if socket is Socket:
			var key := _direction_key(socket.direction)
			socket_map[key] = socket.duplicate(true)
	return socket_map

static func _duplicate_requirements(reqs: Array) -> Array[Requirement]:
	var result: Array[Requirement] = []
	for requirement in reqs:
		if requirement is Requirement:
			result.append((requirement as Requirement).duplicate(true))
	return result

static func _duplicate_tags(tags: Array) -> Array[String]:
	var result: Array[String] = []
	for tag in tags:
		if tag is String:
			result.append(tag)
	return result

static func _register_socket_types(library: ModuleLibrary, socket: Socket) -> void:
	if not library or not socket:
		return
	library.register_socket_type("none")
	if socket.socket_id and socket.socket_id != "":
		library.register_socket_type(socket.socket_id)
	for compat in socket.compatible_sockets:
		if compat is String and compat != "":
			library.register_socket_type(compat)

static func _canonical_directions() -> Array:
	return [
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.RIGHT,
		Vector3i.LEFT,
		Vector3i.FORWARD,
		Vector3i.BACK
	]

static func _direction_key(direction: Vector3i) -> String:
	return "%d,%d,%d" % [direction.x, direction.y, direction.z]
