@tool
class_name PreviewPanel extends Control

const RESUME_DELAY: float = 2.0  # seconds before auto-rotate resumes

var camera_distance: float = 10.0
var camera_rotation: Vector2 = Vector2(15, 45)  # pitch, yaw in degrees
var camera_target: Vector3 = Vector3.ZERO
var is_rotating: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2
var viewport_rect: Rect2

# Viewport options
var auto_rotate: bool = true
var auto_rotate_paused: bool = false
var resume_timer: float = 0.0

@onready var viewport: SubViewport = %PreviewViewport
@onready var camera: Camera3D = %PreviewCamera
@onready
var viewport_container: SubViewportContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/Panel/SubViewportContainer
@onready var viewport_options: MenuButton = %ViewportOptions


func _ready() -> void:
	update_camera_transform()
	viewport_container.gui_input.connect(_on_viewport_gui_input)
	viewport_rect = viewport_container.get_global_rect()
	_add_test_cube()

	# Connect viewport options menu
	var popup = viewport_options.get_popup()
	popup.id_pressed.connect(_on_viewport_option_selected)
	popup.set_item_checked(0, auto_rotate)


func _process(delta: float) -> void:
	# Handle auto-rotate resume timer
	if auto_rotate_paused:
		resume_timer -= delta
		if resume_timer <= 0.0:
			auto_rotate_paused = false

	# Apply auto-rotation
	if auto_rotate and not auto_rotate_paused and not is_rotating and not is_panning:
		camera_rotation.y += delta * 15.0  # Rotate 15 degrees per second
		update_camera_transform()


func _on_viewport_option_selected(id: int) -> void:
	var popup = viewport_options.get_popup()
	match id:
		0:  # Auto Rotate
			auto_rotate = !auto_rotate
			popup.set_item_checked(0, auto_rotate)
		1:  # Reset Camera
			frame_structure()


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				viewport_rect = viewport_container.get_global_rect()
				# Pause auto-rotation during interaction
				auto_rotate_paused = true
				# Check shift directly from Input singleton
				if Input.is_key_pressed(KEY_SHIFT):
					is_panning = true
				else:
					is_rotating = true
				last_mouse_pos = get_global_mouse_position()
				viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			else:
				is_rotating = false
				is_panning = false
				viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Start resume timer
				resume_timer = RESUME_DELAY

		# Zoom with scroll wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(2.0, camera_distance - 1.0)
			update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(50.0, camera_distance + 1.0)
			update_camera_transform()

	elif event is InputEventMouseMotion:
		if is_rotating or is_panning:
			# Update mode based on current shift state
			var shift_now = Input.is_key_pressed(KEY_SHIFT)
			if shift_now and not is_panning:
				is_panning = true
				is_rotating = false
			elif not shift_now and not is_rotating:
				is_rotating = true
				is_panning = false

			var current_mouse = get_global_mouse_position()
			var delta = current_mouse - last_mouse_pos

			if is_rotating:
				camera_rotation.y -= delta.x * 0.5
				camera_rotation.x = clamp(camera_rotation.x - delta.y * 0.5, -89, 89)
				update_camera_transform()

			elif is_panning:
				delta *= 0.01
				var right = camera.global_transform.basis.x
				var up = Vector3.UP
				camera_target -= right * delta.x * camera_distance * 0.1
				camera_target += up * delta.y * camera_distance * 0.1
				update_camera_transform()

			# Wrap cursor at viewport edges
			var wrapped_pos = current_mouse
			var wrapped = false

			if current_mouse.x <= viewport_rect.position.x:
				wrapped_pos.x = viewport_rect.end.x - 2
				wrapped = true
			elif current_mouse.x >= viewport_rect.end.x:
				wrapped_pos.x = viewport_rect.position.x + 2
				wrapped = true

			if current_mouse.y <= viewport_rect.position.y:
				wrapped_pos.y = viewport_rect.end.y - 2
				wrapped = true
			elif current_mouse.y >= viewport_rect.end.y:
				wrapped_pos.y = viewport_rect.position.y + 2
				wrapped = true

			if wrapped:
				get_viewport().warp_mouse(wrapped_pos)
				last_mouse_pos = wrapped_pos
			else:
				last_mouse_pos = current_mouse


func update_camera_transform() -> void:
	"""Update camera position based on orbit controls"""
	if not camera:
		return

	var pitch_rad = deg_to_rad(camera_rotation.x)
	var yaw_rad = deg_to_rad(camera_rotation.y)

	var offset = (
		Vector3(cos(pitch_rad) * sin(yaw_rad), sin(pitch_rad), cos(pitch_rad) * cos(yaw_rad))
		* camera_distance
	)

	camera.global_position = camera_target + offset
	camera.look_at(camera_target, Vector3.UP)


func frame_structure() -> void:
	"""Frame the camera to show the entire structure"""
	# TODO: Calculate bounds of all structure nodes and adjust camera
	camera_target = Vector3.ZERO
	camera_distance = 10.0
	camera_rotation = Vector2(15, 45)  # Reset to default pitch and yaw
	update_camera_transform()


func add_structure_node(node: Node3D) -> void:
	"""Add a generated structure to the viewport for preview"""
	viewport.add_child(node)


func display_tile_preview(tile: Tile) -> void:
	"""Display a preview of the given tile in the viewport"""
	clear_structure()

	if tile.scene != null:
		var instance = tile.scene.instantiate()
		if instance is Node3D:
			add_structure_node(instance)
			frame_structure()
			return

		push_error("Tile %s scene is not a Node3D" % tile.name)
		return

	if tile.mesh != null:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = tile.mesh
		add_structure_node(mesh_instance)
		frame_structure()
		return

	push_error("Tile has no scene assigned")


func clear_structure() -> void:
	"""Remove all structure nodes from the viewport"""
	for child in viewport.get_children():
		if child is Node3D and child != camera:
			child.queue_free()


func get_viewport_world() -> World3D:
	"""Get the 3D world of the preview viewport"""
	return viewport.world_3d


func _add_test_cube() -> void:
	"""Add a test cube to the viewport for testing camera controls"""
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 2, 2)
	mesh_instance.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.4, 0.2)
	mesh_instance.material_override = material

	mesh_instance.position = Vector3(0, 0, 0)
	viewport.add_child(mesh_instance)
