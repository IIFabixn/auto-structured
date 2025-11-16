@tool
class_name SocketTemplateLibrary

const USER_TEMPLATE_DIR := "user://auto_structured/socket_templates"
const TEMPLATE_EXTENSION := ".tres"
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

static func get_builtin_templates() -> Array[SocketTemplate]:
	var templates: Array[SocketTemplate] = []

	var floor_template := SocketTemplate.new()
	floor_template.template_name = "Floor - 4 Way"
	floor_template.description = "Creates four horizontal sockets for floor tiles."
	floor_template.entries = [
		SocketTemplate.create_entry(Vector3i.RIGHT, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.LEFT, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.FORWARD, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.BACK, "floor_side", ["floor_side"]),
		SocketTemplate.create_entry(Vector3i.UP, "floor_top", []),
		SocketTemplate.create_entry(Vector3i.DOWN, "floor_bottom", [])
	]
	templates.append(floor_template)

	var wall_template := SocketTemplate.new()
	_configure_wall_template(wall_template)
	templates.append(wall_template)

	var corner_template := SocketTemplate.new()
	corner_template.template_name = "Corner - L Shape"
	corner_template.description = "Two perpendicular sockets for corner fillers."
	corner_template.entries = [
		SocketTemplate.create_entry(Vector3i.RIGHT, "corner_side", ["corner_side", "wall_side"]),
		SocketTemplate.create_entry(Vector3i.FORWARD, "corner_side", ["corner_side", "wall_side"]),
		SocketTemplate.create_entry(Vector3i.LEFT, "corner_block", []),
		SocketTemplate.create_entry(Vector3i.BACK, "corner_block", [])
	]
	templates.append(corner_template)

	return templates

static func _configure_wall_template(wall_template: SocketTemplate) -> void:
	wall_template.template_name = "Wall - Straight"
	wall_template.description = "Forward/back sockets for wall strip plus left/right wall links."
	wall_template.entries = [
		SocketTemplate.create_entry(Vector3i.FORWARD, "wall_forward", ["wall_forward", "floor_side"], 0),
		SocketTemplate.create_entry(Vector3i.BACK, "wall_forward", ["wall_forward", "floor_side"], 0),
		SocketTemplate.create_entry(Vector3i.RIGHT, "wall_side", ["wall_side", "corner_side"], 90),
		SocketTemplate.create_entry(Vector3i.LEFT, "wall_side", ["wall_side", "corner_side"], 90),
		SocketTemplate.create_entry(Vector3i.UP, "wall_top", []),
		SocketTemplate.create_entry(Vector3i.DOWN, "floor_side", ["floor_side"])
	]

static func get_user_templates() -> Array[SocketTemplate]:
	var templates: Array[SocketTemplate] = []
	var dir := DirAccess.open(USER_TEMPLATE_DIR)
	if dir == null:
		return templates
	if dir.list_dir_begin() != OK:
		return templates
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(TEMPLATE_EXTENSION):
			continue
		var path := USER_TEMPLATE_DIR + "/" + file_name
		var res := ResourceLoader.load(path)
		if res and res is SocketTemplate:
			templates.append(res)
	dir.list_dir_end()
	return templates

static func get_all_templates() -> Array[SocketTemplate]:
	var templates := get_builtin_templates()
	templates.append_array(get_user_templates())
	return templates

static func save_user_template(template: SocketTemplate) -> int:
	if template == null:
		return ERR_INVALID_PARAMETER
	var dir := DirAccess.open(USER_TEMPLATE_DIR)
	if dir == null:
		var err := DirAccess.make_dir_recursive_absolute(USER_TEMPLATE_DIR)
		if err != OK:
			return err
	var safe_name := template.template_name.strip_edges().to_lower().replace(" ", "_")
	if safe_name == "":
		safe_name = "template_%d" % Time.get_ticks_msec()
	var path := USER_TEMPLATE_DIR + "/" + safe_name + TEMPLATE_EXTENSION
	return ResourceSaver.save(template, path)

static func delete_user_template(template_name: String) -> int:
	var file_path := USER_TEMPLATE_DIR + "/" + template_name + TEMPLATE_EXTENSION
	return DirAccess.remove_absolute(file_path)

static func apply_template(tile: Tile, template: SocketTemplate, library: ModuleLibrary) -> void:
	if tile == null or template == null:
		return
	var normalized_entries: Dictionary = {}
	for raw_entry in template.entries:
		var entry := SocketTemplate.normalize_entry(raw_entry)
		normalized_entries[entry["direction"]] = entry

	var directions = [
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.RIGHT,
		Vector3i.LEFT,
		Vector3i.FORWARD,
		Vector3i.BACK
	]

	for direction in directions:
		var socket := tile.get_socket_by_direction(direction)
		if socket == null:
			socket = Socket.new()
			socket.direction = direction
			tile.add_socket(socket)

	for direction in directions:
		var socket := tile.get_socket_by_direction(direction)
		var entry: Dictionary = normalized_entries.get(direction, {})
		if not entry.is_empty():
			var socket_id: String = str(entry["socket_id"])
			var socket_type: SocketType = null
			if library:
				socket_type = library.get_socket_type_by_id(socket_id)
				if socket_type == null:
					# Create new socket type
					socket_type = SocketType.new()
					socket_type.type_id = socket_id
					library.register_socket_type(socket_type)
			else:
				socket_type = SocketType.new()
				socket_type.type_id = socket_id
			
			# Add compatible types to the socket type
			for compat_id in entry["compatible"]:
				socket_type.add_compatible_type(str(compat_id))
			
			socket.socket_type = socket_type
			_apply_rotation_requirement(socket, int(entry["minimum_rotation_degrees"]))
		else:
			if library:
				socket.socket_type = library.get_socket_type_by_id("none")
			_apply_rotation_requirement(socket, 0)

	# Force cache rebuild by reassigning sockets array
	var sockets_copy: Array[Socket] = []
	sockets_copy.assign(tile.sockets)
	tile.sockets = sockets_copy

static func _apply_rotation_requirement(socket: Socket, minimum_rotation_degrees: int) -> void:
	var requirements_copy: Array[Requirement] = []
	requirements_copy.assign(socket.requirements)

	var existing_index := -1
	for i in range(requirements_copy.size()):
		if requirements_copy[i] is RotationRequirement:
			existing_index = i
			break

	if minimum_rotation_degrees <= 0:
		if existing_index != -1:
			requirements_copy.remove_at(existing_index)
			socket.requirements = requirements_copy
		return

	var rotation_requirement: RotationRequirement = null
	if existing_index == -1:
		rotation_requirement = RotationRequirement.new()
		requirements_copy.append(rotation_requirement)
	else:
		rotation_requirement = requirements_copy[existing_index]

	rotation_requirement.minimum_rotation_degrees = minimum_rotation_degrees
	socket.requirements = requirements_copy
