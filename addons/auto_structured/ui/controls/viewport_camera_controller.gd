@tool
class_name ViewportCameraController extends RefCounted

const RESUME_DELAY: float = 2.0 # seconds before auto-rotate resumes
const AUTO_ROTATE_SPEED: float = 12.0 # degrees per second
const MOVEMENT_SPEED: float = 10.0 # units per second
const MOVEMENT_SPEED_FAST: float = 30.0 # units per second with shift
const MOVEMENT_SPEED_SLOW: float = 3.0 # units per second with alt
const TRANSITION_DURATION: float = 2.0 # seconds to transition to orbit mode
const ORBIT_LERP_SPEED: float = 2.0 # smoothing factor for orbit transition
const SETTINGS_FILE_PATH := "user://auto_structured_settings.cfg"
const SETTINGS_SECTION_CAMERA := "viewport_camera"
const SETTINGS_KEY_AUTO_ROTATE := "auto_rotate_enabled"

# Camera state
var orbit_target: Vector3 = Vector3.ZERO # Point to orbit around during auto-rotation
var orbit_distance: float = 10.0 # Distance from orbit target

# Input state
var is_right_clicking: bool = false

# Auto-rotation
var auto_rotate: bool = true
var auto_rotate_manually_disabled: bool = false # Track if user manually disabled auto-rotate
var resume_timer: float = 0.0
var transition_timer: float = 0.0 # tracks transition progress
var transition_start_basis: Basis # Camera orientation at start of transition
var transition_start_position: Vector3 # Camera position at start of transition

# References
var camera: Camera3D = null
var viewport_container: Control = null

func _init(p_camera: Camera3D, p_viewport_container: Control) -> void:
	camera = p_camera
	viewport_container = p_viewport_container

	transition_start_basis = camera.global_transform.basis
	transition_start_position = camera.global_position
	_load_auto_rotate_setting()

## Call this from the parent's _process function
func process(delta: float) -> void:
	if not camera:
		return
	
	# Handle WASD movement when right-clicking
	if is_right_clicking:
		var movement = Vector3.ZERO
		var speed = MOVEMENT_SPEED
		
		# Check for speed modifiers
		if Input.is_key_pressed(KEY_SHIFT):
			speed = MOVEMENT_SPEED_FAST
		elif Input.is_key_pressed(KEY_ALT):
			speed = MOVEMENT_SPEED_SLOW
		
		# Get movement input
		if Input.is_key_pressed(KEY_W):
			movement -= camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_S):
			movement += camera.global_transform.basis.z
		if Input.is_key_pressed(KEY_A):
			movement -= camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_D):
			movement += camera.global_transform.basis.x
		if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
			# Q/E for vertical movement
			if Input.is_key_pressed(KEY_Q):
				movement -= Vector3.UP
			if Input.is_key_pressed(KEY_E):
				movement += Vector3.UP
		
		# Normalize and apply movement
		if movement.length() > 0:
			movement = movement.normalized()
			camera.global_position += movement * speed * delta
	else:
		# Handle resume timer and auto-rotation
		if resume_timer > 0.0:
			resume_timer -= delta
			if resume_timer <= 0.0 and not auto_rotate_manually_disabled:
				auto_rotate = true
				transition_timer = 0.0 # Start transition
				transition_start_basis = camera.global_transform.basis # Store starting orientation
				transition_start_position = camera.global_position # Store starting position
		
		# Auto-rotate around orbit target
		if auto_rotate:
			# Update transition timer
			if transition_timer < TRANSITION_DURATION:
				transition_timer += delta
			
			# Calculate transition progress (0 to 1)
			var transition_progress = clamp(transition_timer / TRANSITION_DURATION, 0.0, 1.0)
			# Use smoothstep for easing
			var smooth_progress = smoothstep(0.0, 1.0, transition_progress)
			
			# Always apply full rotation to current position for orbital movement
			var rotation_angle = deg_to_rad(AUTO_ROTATE_SPEED * delta)
			
			# Get current offset from orbit target
			var offset = camera.global_position - orbit_target
			var current_distance = offset.length()
			
			# Smoothly transition distance to orbit_distance during transition
			var target_distance = orbit_distance
			if transition_progress < 1.0:
				var start_distance = (transition_start_position - orbit_target).length()
				target_distance = lerp(start_distance, orbit_distance, smooth_progress)
			
			# Apply scaled rotation based on transition progress
			var scaled_rotation_angle = rotation_angle * smooth_progress
			var cos_angle = cos(scaled_rotation_angle)
			var sin_angle = sin(scaled_rotation_angle)
			var new_offset = Vector3(
				offset.x * cos_angle - offset.z * sin_angle,
				offset.y,
				offset.x * sin_angle + offset.z * cos_angle
			)
			
			# Normalize and apply target distance
			if new_offset.length() > 0.001:
				new_offset = new_offset.normalized() * target_distance
			
			# Apply new position
			camera.global_position = orbit_target + new_offset
			
			# Calculate target orientation (looking at orbit target)
			# Only update rotation if camera is not at the exact target position
			if camera.global_position.distance_to(orbit_target) > 0.001:
				var target_basis = camera.global_transform.looking_at(orbit_target, Vector3.UP).basis
				
				# Blend between starting orientation and target orientation
				if transition_progress < 1.0:
					# Gradually rotate from start orientation towards target over TRANSITION_DURATION
					camera.global_transform.basis = transition_start_basis.slerp(target_basis, smooth_progress)
				else:
					# After transition, keep looking at target
					camera.global_transform.basis = target_basis

## Process input events from the viewport
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

## Handle mouse button events
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_right_clicking = true
			auto_rotate = false
			# Don't set manually_disabled flag when right-clicking (temporary pause)
			
			viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			is_right_clicking = false
			viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

			# Calculate orbit distance based on current camera position
			var offset = camera.global_position - orbit_target
			orbit_distance = offset.length()
			# Start resume timer only if not manually disabled
			if not auto_rotate_manually_disabled:
				resume_timer = RESUME_DELAY

	# Zoom with scroll wheel (move camera forward/backward)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if camera:
			orbit_distance -= 1.0
			if orbit_distance < 1.0:
				orbit_distance = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if camera:
			orbit_distance += 1.0
			if orbit_distance < 1.0:
				orbit_distance = 1.0

## Handle mouse motion events - rotate camera when right-clicking
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_right_clicking:
		return
	
	# Use the relative motion for smooth rotation
	var delta = event.relative
	
	# Apply rotation to camera
	camera.rotation_degrees.y -= delta.x * 0.1 # Yaw
	camera.rotation_degrees.x -= delta.y * 0.1 # Pitch

## Frame the camera to show the entire structure
func frame_structure() -> void:
	if not camera:
		return
	
	# Reset to default position and rotation
	orbit_target = Vector3.ZERO
	camera.look_at(orbit_target, Vector3.UP)

func _load_auto_rotate_setting() -> void:
	var config := ConfigFile.new()
	var load_err := config.load(SETTINGS_FILE_PATH)
	if load_err == OK:
		var stored_value = config.get_value(SETTINGS_SECTION_CAMERA, SETTINGS_KEY_AUTO_ROTATE, auto_rotate)
		auto_rotate = bool(stored_value)
		auto_rotate_manually_disabled = not auto_rotate
		if auto_rotate:
			resume_timer = 0.0
		else:
			resume_timer = 0.0
			transition_timer = 0.0
	elif load_err != ERR_FILE_NOT_FOUND and load_err != ERR_DOES_NOT_EXIST:
		push_warning("ViewportCameraController: Failed to load camera settings (%s)" % error_string(load_err))

func _save_auto_rotate_setting() -> void:
	var config := ConfigFile.new()
	var load_err := config.load(SETTINGS_FILE_PATH)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND and load_err != ERR_DOES_NOT_EXIST:
		push_warning("ViewportCameraController: Failed to read existing camera settings (%s)" % error_string(load_err))
	config.set_value(SETTINGS_SECTION_CAMERA, SETTINGS_KEY_AUTO_ROTATE, auto_rotate)
	var save_err := config.save(SETTINGS_FILE_PATH)
	if save_err != OK:
		push_warning("ViewportCameraController: Failed to save camera settings (%s)" % error_string(save_err))

## Enable or disable auto-rotation
func set_auto_rotate(enabled: bool) -> void:
	auto_rotate = enabled
	auto_rotate_manually_disabled = not enabled
	resume_timer = 0.0
	if enabled:
		# If manually enabled, start transition
		transition_timer = 0.0
		transition_start_basis = camera.global_transform.basis
		transition_start_position = camera.global_position
	else:
		transition_timer = 0.0
	_save_auto_rotate_setting()

## Get the current auto-rotate state
func get_auto_rotate() -> bool:
	return auto_rotate
