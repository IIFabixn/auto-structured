@tool
class_name Viewport3DGrid extends Node3D

## A 3D grid and origin axis gizmo for viewport visualization.
## Automatically creates a grid on the XZ plane and RGB axis indicators at the origin.

@export var grid_size: int = 20:  ## Number of grid lines in each direction
	set(value):
		grid_size = value
		if is_node_ready():
			_recreate_grid()

@export var grid_spacing: float = 1.0:  ## Space between grid lines
	set(value):
		grid_spacing = value
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

@export var grid_center_color: Color = Color(0.7, 0.7, 0.7, 0.8)  ## Color for center grid lines
@export var grid_line_color: Color = Color(0.4, 0.4, 0.4, 0.5)  ## Color for regular grid lines
@export var axis_length: float = 2.0  ## Length of the origin axis arrows

var grid_mesh_instance: MeshInstance3D = null
var origin_mesh_instance: MeshInstance3D = null


func _ready() -> void:
	_create_grid()
	_create_origin()


func _recreate_grid() -> void:
	"""Recreate the grid with updated parameters"""
	if grid_mesh_instance:
		grid_mesh_instance.queue_free()
		grid_mesh_instance = null
	_create_grid()


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
