@tool
extends "res://addons/auto_structured/core/validation/validator.gd"
class_name LibraryValidator

## Validates ModuleLibrary for consistency issues.

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

func validate(target: Variant) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if not target is ModuleLibrary:
		results.append(create_error("Target is not a ModuleLibrary", {"type": str(typeof(target))}))
		return results
	
	var library: ModuleLibrary = target as ModuleLibrary
	
	# Validate library properties
	_validate_library_name(library, results)
	_validate_tiles(library, results)
	_validate_socket_types(library, results)
	_validate_tile_connectivity(library, results)
	
	return results

func _validate_library_name(library: ModuleLibrary, results: Array[ValidationResult]) -> void:
	if library.library_name.is_empty():
		results.append(create_warning("Library has no name", {}, library))

func _validate_tiles(library: ModuleLibrary, results: Array[ValidationResult]) -> void:
	if library.tiles.is_empty():
		results.append(create_error("Library has no tiles", {}, library))
		return
	
	# Check for duplicate tile names
	var tile_names: Dictionary = {}
	for i in range(library.tiles.size()):
		var tile: Tile = library.tiles[i]
		
		if tile == null:
			results.append(create_error("Tile at index %d is null" % i, {"index": i}, library))
			continue
		
		if tile.name in tile_names:
			results.append(create_error("Duplicate tile name: %s" % tile.name, {"name": tile.name, "indices": [tile_names[tile.name], i]}, library))
		else:
			tile_names[tile.name] = i
	
	if library.tiles.size() == 1:
		results.append(create_warning("Library has only 1 tile - WFC generation will be limited", {}, library))

func _validate_socket_types(library: ModuleLibrary, results: Array[ValidationResult]) -> void:
	if library.socket_types.is_empty():
		results.append(create_error("Library has no socket types", {}, library))
		return
	
	# Check for duplicate socket type IDs
	var type_ids: Dictionary = {}
	for i in range(library.socket_types.size()):
		var socket_type: SocketType = library.socket_types[i]
		
		if socket_type == null:
			results.append(create_error("Socket type at index %d is null" % i, {"index": i}, library))
			continue
		
		if socket_type.type_id.is_empty():
			results.append(create_error("Socket type at index %d has empty type_id" % i, {"index": i}, library))
			continue
		
		if socket_type.type_id in type_ids:
			results.append(create_error("Duplicate socket type ID: %s" % socket_type.type_id, {"type_id": socket_type.type_id, "indices": [type_ids[socket_type.type_id], i]}, library))
		else:
			type_ids[socket_type.type_id] = i
	
	# Check if socket types are actually used by tiles
	_validate_socket_type_usage(library, results)

func _validate_socket_type_usage(library: ModuleLibrary, results: Array[ValidationResult]) -> void:
	# Collect all socket types used by tiles
	var used_type_ids: Dictionary = {}
	
	for tile in library.tiles:
		if tile == null:
			continue
		
		for socket in tile.sockets:
			if socket == null or socket.socket_type == null:
				continue
			
			used_type_ids[socket.socket_type.type_id] = true
	
	# Check for unused socket types
	for socket_type in library.socket_types:
		if socket_type == null or socket_type.type_id.is_empty():
			continue
		
		if socket_type.type_id not in used_type_ids:
			results.append(create_warning("Socket type '%s' is not used by any tile" % socket_type.type_id, {"type_id": socket_type.type_id}, library))

func _validate_tile_connectivity(library: ModuleLibrary, results: Array[ValidationResult]) -> void:
	if library.tiles.size() < 2:
		return
	
	# Build connectivity graph
	var can_connect: Dictionary = {} # tile_index -> [connected_tile_indices]
	
	for i in range(library.tiles.size()):
		can_connect[i] = []
	
	for i in range(library.tiles.size()):
		var tile_a: Tile = library.tiles[i]
		if tile_a == null:
			continue
		
		for j in range(library.tiles.size()):
			if i == j:
				continue
			
			var tile_b: Tile = library.tiles[j]
			if tile_b == null:
				continue
			
			if _tiles_can_connect(tile_a, tile_b):
				can_connect[i].append(j)
	
	# Find isolated tiles (cannot connect to any other tile)
	for i in range(library.tiles.size()):
		if library.tiles[i] == null:
			continue
		
		if can_connect[i].is_empty():
			results.append(create_warning("Tile '%s' cannot connect to any other tile" % library.tiles[i].name, {"tile": library.tiles[i].name, "index": i}, library))

func _tiles_can_connect(tile_a: Tile, tile_b: Tile) -> bool:
	## Check if two tiles can connect via any socket combination
	for socket_a in tile_a.sockets:
		if socket_a == null or socket_a.socket_type == null:
			continue
		
		for socket_b in tile_b.sockets:
			if socket_b == null or socket_b.socket_type == null:
				continue
			
			# Check if sockets can connect (matching types, compatible orientations)
			if socket_a.socket_type.type_id == socket_b.socket_type.type_id:
				# Check if directions are opposite (can connect)
				if socket_a.direction == -socket_b.direction:
					return true
	
	return false
