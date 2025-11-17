@tool
class_name TileImporter extends RefCounted

## Handles importing meshes and scenes as tiles.
## Supports GLTF, FBX, OBJ (via Godot's import system), and .tscn scenes.

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const MeshOutlineAnalyzer = preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")

## Import options for controlling tile creation
class ImportOptions:
	var auto_generate_sockets: bool = true
	var socket_detection_method: String = "outline"  ## "outline", "manual", "none"
	var default_socket_type_id: String = "wall"
	var extract_size_from_mesh: bool = true
	var size_snap_to_grid: bool = true
	var grid_cell_size: float = 1.0
	var name_from_filename: bool = true
	var add_filename_as_tag: bool = true
	var default_weight: float = 1.0
	var rotation_symmetry: Tile.RotationSymmetry = Tile.RotationSymmetry.AUTO

## Import a single file (scene or mesh) as a tile
static func import_file(file_path: String, library: ModuleLibrary, options: ImportOptions = null) -> Tile:
	if options == null:
		options = ImportOptions.new()
	
	if not FileAccess.file_exists(file_path):
		push_error("Import file not found: %s" % file_path)
		return null
	
	var extension = file_path.get_extension().to_lower()
	var tile: Tile = null
	
	match extension:
		"tscn":
			tile = _import_scene(file_path, library, options)
		"gltf", "glb":
			tile = _import_gltf(file_path, library, options)
		"obj", "fbx":
			tile = _import_mesh_file(file_path, library, options)
		_:
			push_error("Unsupported file format: %s" % extension)
			return null
	
	return tile

## Import multiple files at once
static func import_files(file_paths: PackedStringArray, library: ModuleLibrary, options: ImportOptions = null) -> Array[Tile]:
	var tiles: Array[Tile] = []
	
	for path in file_paths:
		var tile = import_file(path, library, options)
		if tile != null:
			tiles.append(tile)
	
	return tiles

## Import a .tscn scene file as a tile
static func _import_scene(file_path: String, library: ModuleLibrary, options: ImportOptions) -> Tile:
	var packed_scene = load(file_path) as PackedScene
	if packed_scene == null:
		push_error("Failed to load scene: %s" % file_path)
		return null
	
	var tile = Tile.new()
	tile.scene = packed_scene
	
	# Set name from filename if requested
	if options.name_from_filename:
		tile.name = file_path.get_file().get_basename()
	
	# Add filename as tag
	if options.add_filename_as_tag:
		tile.add_tag(file_path.get_file().get_basename())
	
	# Try to extract mesh from scene for analysis
	var instance = packed_scene.instantiate()
	if instance:
		var mesh_instance = _find_mesh_instance(instance)
		if mesh_instance and mesh_instance.mesh:
			_process_mesh_data(tile, mesh_instance.mesh, library, options)
		instance.queue_free()
	
	# Set defaults
	tile.weight = options.default_weight
	tile.rotation_symmetry = options.rotation_symmetry
	
	# Ensure tile has sockets
	if options.auto_generate_sockets and tile.sockets.is_empty():
		_generate_default_sockets(tile, library, options)
	
	return tile

## Import a GLTF/GLB file as a tile
static func _import_gltf(file_path: String, library: ModuleLibrary, options: ImportOptions) -> Tile:
	# GLTF files are imported as scenes by Godot
	# Try to load the generated .tscn or .scn file
	var import_path = file_path + ".tscn"
	if not FileAccess.file_exists(import_path):
		import_path = file_path.get_basename() + ".tscn"
	
	if FileAccess.file_exists(import_path):
		return _import_scene(import_path, library, options)
	
	# Fallback: try to load as mesh
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(file_path, gltf_state)
	
	if err != OK:
		push_error("Failed to load GLTF: %s (error: %d)" % [file_path, err])
		return null
	
	var scene_root = gltf_doc.generate_scene(gltf_state)
	if scene_root == null:
		push_error("Failed to generate scene from GLTF: %s" % file_path)
		return null
	
	var tile = Tile.new()
	
	# Store as packed scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(scene_root)
	tile.scene = packed_scene
	
	# Extract mesh for analysis
	var mesh_instance = _find_mesh_instance(scene_root)
	if mesh_instance and mesh_instance.mesh:
		tile.mesh = mesh_instance.mesh
		_process_mesh_data(tile, mesh_instance.mesh, library, options)
	
	scene_root.queue_free()
	
	# Set name
	if options.name_from_filename:
		tile.name = file_path.get_file().get_basename()
	
	if options.add_filename_as_tag:
		tile.add_tag(file_path.get_file().get_basename())
	
	tile.weight = options.default_weight
	tile.rotation_symmetry = options.rotation_symmetry
	
	if options.auto_generate_sockets and tile.sockets.is_empty():
		_generate_default_sockets(tile, library, options)
	
	return tile

## Import a mesh file (OBJ, FBX - after Godot imports it)
static func _import_mesh_file(file_path: String, library: ModuleLibrary, options: ImportOptions) -> Tile:
	var mesh = load(file_path) as Mesh
	if mesh == null:
		push_error("Failed to load mesh: %s" % file_path)
		return null
	
	var tile = Tile.new()
	tile.mesh = mesh
	
	_process_mesh_data(tile, mesh, library, options)
	
	if options.name_from_filename:
		tile.name = file_path.get_file().get_basename()
	
	if options.add_filename_as_tag:
		tile.add_tag(file_path.get_file().get_basename())
	
	tile.weight = options.default_weight
	tile.rotation_symmetry = options.rotation_symmetry
	
	if options.auto_generate_sockets and tile.sockets.is_empty():
		_generate_default_sockets(tile, library, options)
	
	return tile

## Process mesh data to extract size and generate sockets
static func _process_mesh_data(tile: Tile, mesh: Mesh, library: ModuleLibrary, options: ImportOptions) -> void:
	var aabb = _get_mesh_aabb(mesh)
	
	if options.extract_size_from_mesh:
		var size = aabb.size
		
		if options.size_snap_to_grid:
			size.x = roundi(size.x / options.grid_cell_size)
			size.y = roundi(size.y / options.grid_cell_size)
			size.z = roundi(size.z / options.grid_cell_size)
			size.x = maxi(1, int(size.x))
			size.y = maxi(1, int(size.y))
			size.z = maxi(1, int(size.z))
		
		tile.size = Vector3i(int(size.x), int(size.y), int(size.z))
	
	# Generate sockets based on method
	if options.auto_generate_sockets and options.socket_detection_method == "outline":
		var socket_type = library.ensure_socket_type(options.default_socket_type_id)
		var analyzer = MeshOutlineAnalyzer.new()
		var faces = analyzer.analyze(mesh, tile.size)
		
		for face_dir in faces:
			var socket = Socket.new()
			socket.direction = face_dir
			socket.socket_type = socket_type
			tile.add_socket(socket)

## Generate default sockets for all 6 cardinal directions
static func _generate_default_sockets(tile: Tile, library: ModuleLibrary, options: ImportOptions) -> void:
	var socket_type = library.ensure_socket_type(options.default_socket_type_id)
	
	var directions = [
		Vector3i.RIGHT, Vector3i.LEFT,
		Vector3i.FORWARD, Vector3i.BACK,
		Vector3i.UP, Vector3i.DOWN
	]
	
	for dir in directions:
		var socket = Socket.new()
		socket.direction = dir
		socket.socket_type = socket_type
		tile.add_socket(socket)

## Find the first MeshInstance3D in a scene tree
static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null

## Get AABB from mesh
static func _get_mesh_aabb(mesh: Mesh) -> AABB:
	var aabb = AABB()
	var first = true
	
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				if first:
					aabb = AABB(vertex, Vector3.ZERO)
					first = false
				else:
					aabb = aabb.expand(vertex)
	
	return aabb
