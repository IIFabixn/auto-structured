@tool
extends "res://addons/auto_structured/core/validation/validator.gd"
class_name TileValidator

## Validates individual tiles for common issues.

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

func validate(target: Variant) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if not target is Tile:
		results.append(create_error("Target is not a Tile", {"type": str(typeof(target))}))
		return results
	
	var tile: Tile = target as Tile
	
	# Validate basic properties
	_validate_tile_name(tile, results)
	_validate_tile_size(tile, results)
	_validate_tile_weight(tile, results)
	_validate_tile_rotation_symmetry(tile, results)
	_validate_tile_sockets(tile, results)
	_validate_tile_requirements(tile, results)
	_validate_tile_tags(tile, results)
	
	return results

func _validate_tile_name(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.name.is_empty():
		results.append(create_error("Tile has no name", {}, tile))
	elif tile.name.strip_edges() != tile.name:
		results.append(create_warning("Tile name has leading/trailing whitespace", {"name": tile.name}, tile))

func _validate_tile_size(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.size.x <= 0 or tile.size.y <= 0 or tile.size.z <= 0:
		results.append(create_error("Tile size must be positive in all dimensions", {"size": tile.size}, tile))
	
	if tile.size.x > 10 or tile.size.y > 10 or tile.size.z > 10:
		results.append(create_warning("Tile size is unusually large (>10 in any dimension)", {"size": tile.size}, tile))

func _validate_tile_weight(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.weight < 0.01:
		results.append(create_error("Tile weight must be at least 0.01", {"weight": tile.weight}, tile))
	
	if tile.weight > 100.0:
		results.append(create_warning("Tile weight is very high (>100)", {"weight": tile.weight}, tile))
	elif tile.weight > 50.0:
		results.append(create_info("Tile has high weight (>50), will appear frequently", {"weight": tile.weight}, tile))

func _validate_tile_sockets(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.sockets.is_empty():
		results.append(create_error("Tile has no sockets - cannot connect to other tiles", {}, tile))
		return
	
	# Track socket directions
	var socket_directions: Dictionary = {}
	
	for i in range(tile.sockets.size()):
		var socket: Socket = tile.sockets[i]
		
		if socket == null:
			results.append(create_error("Socket at index %d is null" % i, {"index": i}, tile))
			continue
		
		if socket.socket_type == null:
			results.append(create_error("Socket at index %d has no socket type" % i, {"index": i, "direction": socket.direction}, tile))
		
		# Check for duplicate directions
		var dir_key = str(socket.direction)
		if dir_key in socket_directions:
			results.append(create_warning("Multiple sockets in same direction: %s" % dir_key, {"direction": socket.direction}, tile))
		socket_directions[dir_key] = true
	
	# Check if tile has basic connectivity (at least opposing faces for common directions)
	var has_right = socket_directions.has(str(Vector3i.RIGHT))
	var has_left = socket_directions.has(str(Vector3i.LEFT))
	var has_forward = socket_directions.has(str(Vector3i.FORWARD))
	var has_back = socket_directions.has(str(Vector3i.BACK))
	var has_up = socket_directions.has(str(Vector3i.UP))
	var has_down = socket_directions.has(str(Vector3i.DOWN))
	
	var socket_count = socket_directions.size()
	if socket_count < 2:
		results.append(create_warning("Tile has only %d socket direction(s) - limited connectivity" % socket_count, {}, tile))

func _validate_tile_requirements(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.requirements.is_empty():
		return
	
	var enabled_count = 0
	for i in range(tile.requirements.size()):
		var req = tile.requirements[i]
		
		if req == null:
			results.append(create_error("Requirement at index %d is null" % i, {"index": i}, tile))
			continue
		
		if req.enabled:
			enabled_count += 1
	
	# Check for potential conflicts
	_check_requirement_conflicts(tile, results)
	
	if enabled_count > 5:
		results.append(create_info("Tile has many enabled requirements (%d) - may be overly constrained" % enabled_count, {}, tile))

func _check_requirement_conflicts(tile: Tile, results: Array[ValidationResult]) -> void:
	# Check for conflicting height requirements
	var height_reqs = []
	var max_count_reqs = []
	var boundary_reqs = []
	
	for req in tile.requirements:
		if not req.enabled:
			continue
		
		var req_class = req.get_class()
		if "HeightRequirement" in req_class:
			height_reqs.append(req)
		elif "MaxCountRequirement" in req_class:
			max_count_reqs.append(req)
		elif "BoundaryRequirement" in req_class:
			boundary_reqs.append(req)
	
	# Multiple height requirements might conflict
	if height_reqs.size() > 1:
		results.append(create_warning("Multiple height requirements detected - ensure they don't conflict", {"count": height_reqs.size()}, tile))
	
	# Multiple max count requirements is unusual
	if max_count_reqs.size() > 1:
		results.append(create_warning("Multiple max count requirements detected - only one should be needed", {"count": max_count_reqs.size()}, tile))
	
	# Multiple boundary requirements might conflict
	if boundary_reqs.size() > 1:
		results.append(create_warning("Multiple boundary requirements detected - ensure they don't conflict", {"count": boundary_reqs.size()}, tile))

func _validate_tile_tags(tile: Tile, results: Array[ValidationResult]) -> void:
	if tile.tags.is_empty():
		results.append(create_info("Tile has no tags - consider adding tags for better organization", {}, tile))
	
	# Check for duplicate tags
	var seen_tags: Dictionary = {}
	for tag in tile.tags:
		if tag in seen_tags:
			results.append(create_warning("Duplicate tag: %s" % tag, {"tag": tag}, tile))
		seen_tags[tag] = true
		
		if tag.strip_edges() != tag:
			results.append(create_warning("Tag has whitespace: '%s'" % tag, {"tag": tag}, tile))

func _validate_tile_rotation_symmetry(tile: Tile, results: Array[ValidationResult]) -> void:
	## Validate rotation symmetry configuration
	if tile.rotation_symmetry == Tile.RotationSymmetry.CUSTOM:
		if tile.custom_rotations.is_empty():
			results.append(create_error("Tile has CUSTOM rotation symmetry but no custom rotations defined", {}, tile))
		else:
			# Check that custom rotations are valid (0-360 range, multiples of 90)
			for rotation in tile.custom_rotations:
				if rotation < 0 or rotation >= 360:
					results.append(create_error("Custom rotation %d is out of valid range (0-359)" % rotation, {"rotation": rotation}, tile))
				elif rotation % 90 != 0:
					results.append(create_warning("Custom rotation %d is not a multiple of 90 degrees" % rotation, {"rotation": rotation}, tile))
			
			# Check for duplicates
			var seen_rotations: Dictionary = {}
			for rotation in tile.custom_rotations:
				if rotation in seen_rotations:
					results.append(create_warning("Duplicate custom rotation: %d" % rotation, {"rotation": rotation}, tile))
				seen_rotations[rotation] = true
	
	# Info: Report detected symmetry if using AUTO mode
	if tile.rotation_symmetry == Tile.RotationSymmetry.AUTO:
		var unique_rotations = tile.get_unique_rotations()
		if unique_rotations.size() == 1:
			results.append(create_info("Tile has full 90° symmetry - only 1 rotation needed", {"rotations": unique_rotations}, tile))
		elif unique_rotations.size() == 2:
			results.append(create_info("Tile has 180° symmetry - 2 rotations detected", {"rotations": unique_rotations}, tile))
		elif unique_rotations.size() == 4:
			results.append(create_info("Tile has no symmetry - all 4 rotations are unique", {"rotations": unique_rotations}, tile))
