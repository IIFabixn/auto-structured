@tool
class_name TileItem extends VBoxContainer

const Tile = preload("res://addons/auto_structured/core/tile.gd")

signal tile_selected(tile: Tile)
signal tile_deleted(tile: Tile)

@onready var tileImage: TextureRect = %TileImage
@onready var tileNameLabel: Label = %TileNameLabel
@onready var popupMenu: PopupMenu = %PopupMenu

const DELETE = 0

var _tile: Tile
@export var tile: Tile:
	get: 
		return _tile
	set(value): 
		_tile = value
		_update_ui()


func _ready() -> void:
	popupMenu.add_item("Delete Tile", DELETE)
	popupMenu.id_pressed.connect(_on_popup_menu_id_pressed)

func _gui_input(event: InputEvent) -> void:
	if not _tile:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tile_selected.emit(_tile)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var global_pos = get_global_mouse_position()
			popupMenu.position = global_pos
			popupMenu.popup()

func _on_popup_menu_id_pressed(id: int) -> void:
	if id == DELETE and _tile:
		tile_deleted.emit(_tile)
		queue_free()

func _update_ui() -> void:
	if not is_node_ready():
		return
		
	if _tile:
		tileNameLabel.text = _tile.name
		_generate_thumbnail()
	else:
		tileNameLabel.text = "No Tile"
		if tileImage:
			tileImage.texture = null

func _get_visual_aabb(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	"""Calculate the visual bounding box of a node and its children in world space."""
	if not node is Node3D:
		return AABB()
	
	var node_3d = node as Node3D
	var global_transform = parent_transform * node_3d.transform
	
	var aabb = AABB()
	var first = true
	
	if node is MeshInstance3D:
		var mesh_aabb = node.get_aabb()
		if mesh_aabb.size != Vector3.ZERO:
			# Transform AABB to world space
			var corners = [
				mesh_aabb.position,
				mesh_aabb.position + Vector3(mesh_aabb.size.x, 0, 0),
				mesh_aabb.position + Vector3(0, mesh_aabb.size.y, 0),
				mesh_aabb.position + Vector3(0, 0, mesh_aabb.size.z),
				mesh_aabb.position + Vector3(mesh_aabb.size.x, mesh_aabb.size.y, 0),
				mesh_aabb.position + Vector3(mesh_aabb.size.x, 0, mesh_aabb.size.z),
				mesh_aabb.position + Vector3(0, mesh_aabb.size.y, mesh_aabb.size.z),
				mesh_aabb.position + mesh_aabb.size
			]
			for corner in corners:
				var world_pos = global_transform * corner
				if first:
					aabb = AABB(world_pos, Vector3.ZERO)
					first = false
				else:
					aabb = aabb.expand(world_pos)
	
	# Include children
	for child in node.get_children():
		var child_aabb = _get_visual_aabb(child, global_transform)
		if child_aabb.size != Vector3.ZERO:
			if first:
				aabb = child_aabb
				first = false
			else:
				aabb = aabb.merge(child_aabb)
	
	# If no valid AABB found, use a default size
	if first:
		aabb = AABB(global_transform.origin - Vector3(0.5, 0.5, 0.5), Vector3.ONE)
	
	return aabb

func _generate_thumbnail() -> void:
	"""Generate a thumbnail image for the tile."""
	if not _tile or not tileImage:
		return
	
	# Get the 3D instance (either from scene or mesh)
	var instance: Node3D = null
	if _tile.scene:
		instance = _tile.scene.instantiate()
	elif _tile.mesh:
		# Create a MeshInstance3D for mesh-only tiles
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = _tile.mesh
		instance = mesh_instance
	
	if not instance:
		return
	
	# Create a SubViewport for rendering
	var viewport = SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true  # Each viewport gets its own isolated 3D world
	
	# Add to tree first
	add_child(viewport)
	viewport.add_child(instance)
	
	# Wait a frame for the instance to be ready
	await get_tree().process_frame
	
	# Calculate the bounding box to frame the object
	var aabb = _get_visual_aabb(instance)
	var center = aabb.get_center()
	var size = aabb.size
	
	# Use the radius of a sphere that contains the AABB for better framing
	var radius = size.length() / 2.0
	if radius < 0.1:
		radius = 1.0  # Default if too small
	
	# Setup camera - must be added to tree before positioning
	var camera = Camera3D.new()
	camera.fov = 50.0
	viewport.add_child(camera)
	
	# Calculate distance to fit the sphere in view
	var distance = radius / tan(deg_to_rad(camera.fov / 2.0))
	distance *= 1.4  # Add 40% padding for better framing
	
	# Position camera at an angle (35 degrees from top for better perspective)
	var angle_h = deg_to_rad(45)  # Horizontal angle
	var angle_v = deg_to_rad(35)  # Vertical angle from horizontal
	var camera_offset = Vector3(
		cos(angle_v) * cos(angle_h),
		sin(angle_v),
		cos(angle_v) * sin(angle_h)
	) * distance
	
	camera.position = center + camera_offset
	camera.look_at(center, Vector3.UP)
	camera.current = true
	camera.force_update_transform()
	
	# Add multiple lights for better visibility
	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -30, 0)
	key_light.light_energy = 0.8
	viewport.add_child(key_light)
	
	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30, 150, 0)
	fill_light.light_energy = 0.3
	viewport.add_child(fill_light)
	
	var back_light = DirectionalLight3D.new()
	back_light.rotation_degrees = Vector3(30, 180, 0)
	back_light.light_energy = 0.2
	viewport.add_child(back_light)
	
	# Wait for multiple frames to ensure rendering is complete
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	# Get the texture
	var texture = viewport.get_texture()
	if texture:
		var img = texture.get_image()
		if img:
			tileImage.texture = ImageTexture.create_from_image(img)
	
	# Cleanup
	viewport.queue_free()