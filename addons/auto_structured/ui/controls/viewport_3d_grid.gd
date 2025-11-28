@tool
class_name Viewport3DGrid extends Node3D

## A 3D grid and origin axis gizmo for viewport visualization.
## Automatically creates a grid on the XZ plane and RGB axis indicators at the origin.

@export var grid_size: int = 20:  ## Number of grid lines in each direction
	set(value):
		var clamped := max(1, value)
		if grid_size == clamped:
			return
		grid_size = clamped
		if is_node_ready():
			_recreate_grid()


@export var grid_spacing: float = 1.0:  ## Space between grid lines
	set(value):
		var clamped := max(0.001, value)
		if is_equal_approx(grid_spacing, clamped):
			return
		grid_spacing = clamped
		if is_node_ready():
			_recreate_grid()

@export var show_grid: bool = true:  ## Show/hide the grid
	set(value):
		show_grid = value
		if grid_mesh_instance:
			grid_mesh_instance.visible = show_grid

@export var show_origin: bool = true:  ## Show/hide the origin axis gizmo
	set(value):
		show_origin = value
		if origin_mesh_instance:
			origin_mesh_instance.visible = show_origin

@export var grid_center_color: Color = Color(0.7, 0.7, 0.7, 0.8):
	set(value):
		grid_center_color = value
		if is_node_ready():
			_recreate_grid()

@export var grid_line_color: Color = Color(0.4, 0.4, 0.4, 0.5):
	set(value):
		grid_line_color = value
		if is_node_ready():
			_recreate_grid()

@export var axis_length: float = 2.0:
	set(value):
		var clamped := max(0.01, value)
		if is_equal_approx(axis_length, clamped):
			return
		axis_length = clamped
		if is_node_ready():
			_recreate_origin()

@export var show_bounds: bool = true:
	set(value):
		show_bounds = value
		if bounds_mesh_instance:
			bounds_mesh_instance.visible = show_bounds and _has_bounds()

@export var bounds_color: Color = Color(0.9, 0.6, 0.1, 0.9):
	set(value):
		bounds_color = value
		if is_node_ready():
			_recreate_bounds()

var grid_mesh_instance: MeshInstance3D = null
var origin_mesh_instance: MeshInstance3D = null
var bounds_mesh_instance: MeshInstance3D = null
var _bounds_size: Vector3 = Vector3.ZERO


func _ready() -> void:
	_create_grid()
	_create_origin()
	_create_bounds()

func set_world_bounds(size: Vector3) -> void:
	var clamped := Vector3(
		max(0.0, size.x),
		max(0.0, size.y),
		max(0.0, size.z)
	)
	if _bounds_size == clamped:
		return
	_bounds_size = clamped
	if is_node_ready():
		_recreate_bounds()


func _recreate_grid() -> void:
	"""Recreate the grid with updated parameters"""
	if grid_mesh_instance:
		grid_mesh_instance.queue_free()
		grid_mesh_instance = null
	_create_grid()

func _recreate_origin() -> void:
	"""Recreate the origin gizmo with updated parameters"""
	if origin_mesh_instance:
		origin_mesh_instance.queue_free()
		origin_mesh_instance = null
	_create_origin()

func _recreate_bounds() -> void:
	"""Recreate the bounds outline with updated parameters"""
	if bounds_mesh_instance:
		bounds_mesh_instance.queue_free()
		bounds_mesh_instance = null
	_create_bounds()


func _create_grid() -> void:
	"""Create a grid mesh for the viewport floor"""
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	# Create grid lines
	for i in range(-grid_size, grid_size + 1):
		var offset = i * grid_spacing
		
		# Determine color (center lines are brighter)
		var color = grid_center_color if i == 0 else grid_line_color
		
		# Lines parallel to X axis
		surface_tool.set_color(color)
		surface_tool.add_vertex(Vector3(-grid_size * grid_spacing, 0, offset))
		surface_tool.set_color(color)
		surface_tool.add_vertex(Vector3(grid_size * grid_spacing, 0, offset))
		
		# Lines parallel to Z axis
		surface_tool.set_color(color)
		surface_tool.add_vertex(Vector3(offset, 0, -grid_size * grid_spacing))
		surface_tool.set_color(color)
		surface_tool.add_vertex(Vector3(offset, 0, grid_size * grid_spacing))
	
	var grid_mesh = surface_tool.commit()
	
	# Create material for the grid
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	material.disable_receive_shadows = true
	material.albedo_color = Color.WHITE
	
	# Create mesh instance
	grid_mesh_instance = MeshInstance3D.new()
	grid_mesh_instance.mesh = grid_mesh
	grid_mesh_instance.material_override = material
	grid_mesh_instance.name = "Grid"
	grid_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_mesh_instance.visible = show_grid
	
	add_child(grid_mesh_instance)


func _create_origin() -> void:
	"""Create an origin indicator (axis gizmo) at world origin"""
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	# X axis (Red)
	surface_tool.set_color(Color.RED)
	surface_tool.add_vertex(Vector3.ZERO)
	surface_tool.set_color(Color.RED)
	surface_tool.add_vertex(Vector3(axis_length, 0, 0))
	
	# Y axis (Green)
	surface_tool.set_color(Color.GREEN)
	surface_tool.add_vertex(Vector3.ZERO)
	surface_tool.set_color(Color.GREEN)
	surface_tool.add_vertex(Vector3(0, axis_length, 0))
	
	# Z axis (Blue)
	surface_tool.set_color(Color.BLUE)
	surface_tool.add_vertex(Vector3.ZERO)
	surface_tool.set_color(Color.BLUE)
	surface_tool.add_vertex(Vector3(0, 0, axis_length))
	
	var origin_mesh = surface_tool.commit()
	
	# Create material for the origin
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true  # Always visible through objects
	material.disable_receive_shadows = true
	material.albedo_color = Color.WHITE
	
	# Create mesh instance
	origin_mesh_instance = MeshInstance3D.new()
	origin_mesh_instance.mesh = origin_mesh
	origin_mesh_instance.material_override = material
	origin_mesh_instance.name = "Origin"
	origin_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	origin_mesh_instance.visible = show_origin
	
	add_child(origin_mesh_instance)


func _create_bounds() -> void:
	"""Create a rectangular outline representing the configured grid bounds."""
	if not _has_bounds():
		return
	var half_x = _bounds_size.x * 0.5
	var half_z = _bounds_size.z * 0.5
	var height = _bounds_size.y
	var corners = [
		Vector3(-half_x, 0, -half_z),
		Vector3(half_x, 0, -half_z),
		Vector3(half_x, 0, half_z),
		Vector3(-half_x, 0, half_z)
	]
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	for i in range(corners.size()):
		var start = corners[i]
		var finish = corners[(i + 1) % corners.size()]
		surface_tool.set_color(bounds_color)
		surface_tool.add_vertex(start)
		surface_tool.set_color(bounds_color)
		surface_tool.add_vertex(finish)
	if height > 0.0:
		for corner in corners:
			var top_corner = corner + Vector3.UP * height
			surface_tool.set_color(bounds_color)
			surface_tool.add_vertex(corner)
			surface_tool.set_color(bounds_color)
			surface_tool.add_vertex(top_corner)
		var top_corners = _get_top_corners(corners, height)
		for i in range(top_corners.size()):
			var start_top = top_corners[i]
			var end_top = top_corners[(i + 1) % top_corners.size()]
			surface_tool.set_color(bounds_color)
			surface_tool.add_vertex(start_top)
			surface_tool.set_color(bounds_color)
			surface_tool.add_vertex(end_top)
	var bounds_mesh = surface_tool.commit()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	material.disable_receive_shadows = true
	material.albedo_color = Color.WHITE
	bounds_mesh_instance = MeshInstance3D.new()
	bounds_mesh_instance.name = "GridBounds"
	bounds_mesh_instance.mesh = bounds_mesh
	bounds_mesh_instance.material_override = material
	bounds_mesh_instance.visible = show_bounds and _has_bounds()
	add_child(bounds_mesh_instance)


func _get_top_corners(base_corners: Array, height: float) -> Array:
	var arr: Array = []
	for corner in base_corners:
		arr.append(corner + Vector3.UP * height)
	return arr

func _has_bounds() -> bool:
	return _bounds_size != Vector3.ZERO
