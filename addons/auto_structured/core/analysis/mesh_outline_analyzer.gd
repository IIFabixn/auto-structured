@tool
class_name MeshOutlineAnalyzer

const Tile := preload("res://addons/auto_structured/core/tile.gd")

static var _directions := [
	Vector3i.RIGHT,
	Vector3i.LEFT,
	Vector3i.UP,
	Vector3i.DOWN,
	Vector3i.FORWARD,
	Vector3i.BACK
]

static func get_face_signatures_for_tile(tile: Tile) -> Dictionary:
	if tile == null:
		return {}
	var vertices := _extract_vertices_from_tile(tile)
	if vertices.is_empty():
		return {}
	return _compute_face_signatures(vertices)

static func _extract_vertices_from_tile(tile: Tile) -> Array[Vector3]:
	var vertices: Array[Vector3] = []
	if tile.mesh:
		_append_mesh_vertices(tile.mesh, Transform3D.IDENTITY, vertices)
	if tile.scene:
		var instance := tile.scene.instantiate()
		if instance:
			_collect_scene_vertices(instance, Transform3D.IDENTITY, vertices)
			instance.queue_free()
	return vertices

static func _append_mesh_vertices(mesh: Mesh, transform: Transform3D, into: Array[Vector3]) -> void:
	if mesh == null:
		return
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertex_array: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertex_array.is_empty():
			continue
		for vertex in vertex_array:
			if vertex is Vector3:
				into.append(transform * vertex)

static func _collect_scene_vertices(node: Node, parent_transform: Transform3D, into: Array[Vector3]) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			_append_mesh_vertices(mesh_instance.mesh, current_transform, into)
	if node is MultiMeshInstance3D:
		var multi_mesh_instance := node as MultiMeshInstance3D
		if multi_mesh_instance.multimesh:
			_append_multimesh_vertices(multi_mesh_instance, current_transform, into)
	for child in node.get_children():
		_collect_scene_vertices(child, current_transform, into)

static func _append_multimesh_vertices(instance: MultiMeshInstance3D, parent_transform: Transform3D, into: Array[Vector3]) -> void:
	var multimesh := instance.multimesh
	if multimesh == null or multimesh.mesh == null:
		return
	var mesh := multimesh.mesh
	for i in range(multimesh.instance_count):
		var transform := parent_transform * multimesh.get_instance_transform(i)
		_append_mesh_vertices(mesh, transform, into)

static func _compute_face_signatures(points: Array[Vector3]) -> Dictionary:
	if points.is_empty():
		return {}
	var min_bounds := Vector3(INF, INF, INF)
	var max_bounds := Vector3(-INF, -INF, -INF)
	for point in points:
		min_bounds.x = min(min_bounds.x, point.x)
		min_bounds.y = min(min_bounds.y, point.y)
		min_bounds.z = min(min_bounds.z, point.z)
		max_bounds.x = max(max_bounds.x, point.x)
		max_bounds.y = max(max_bounds.y, point.y)
		max_bounds.z = max(max_bounds.z, point.z)
	var size := max_bounds - min_bounds
	var base_tolerance := max(size.length() * 0.002, 0.001)
	var signatures := {}
	for direction in _directions:
		var face := _analyze_face(points, direction, min_bounds, max_bounds, base_tolerance)
		if not face.is_empty():
			signatures[direction] = face
	return signatures

static func _analyze_face(points: Array[Vector3], direction: Vector3i, min_bounds: Vector3, max_bounds: Vector3, base_tolerance: float) -> Dictionary:
	var axis := _axis_from_direction(direction)
	var sign := _sign_from_direction(direction)
	var extreme := -INF if sign >= 0 else INF
	var found := false
	for point in points:
		var value := _value_on_axis(point, axis)
		if sign >= 0:
			if value > extreme:
				extreme = value
				found = true
		else:
			if value < extreme:
				extreme = value
				found = true
	if not found:
		return {}
	var axis_length := _axis_length(min_bounds, max_bounds, axis)
	var tolerance := max(base_tolerance, axis_length * 0.02)
	var face_points: Array[Vector3] = []
	for point in points:
		var value := _value_on_axis(point, axis)
		if abs(value - extreme) <= tolerance:
			face_points.append(point)
	if face_points.size() < 3:
		return {}
	var min_u := INF
	var max_u := -INF
	var min_v := INF
	var max_v := -INF
	for point in face_points:
		var plane_point := _project_to_plane(point, axis)
		min_u = min(min_u, plane_point.x)
		max_u = max(max_u, plane_point.x)
		min_v = min(min_v, plane_point.y)
		max_v = max(max_v, plane_point.y)
	var width := max_u - min_u
	var height := max_v - min_v
	if width <= 0.0001 or height <= 0.0001:
		return {}
	var face := {
		"axis": axis,
		"sign": sign,
		"extreme": extreme,
		"dimensions": Vector2(width, height),
		"center": Vector2(min_u + width * 0.5, min_v + height * 0.5),
		"bounds": Rect2(Vector2(min_u, min_v), Vector2(width, height)),
		"point_count": face_points.size(),
		"tolerance": tolerance
	}
	return face

static func _axis_from_direction(direction: Vector3i) -> int:
	if abs(direction.x) == 1:
		return 0
	if abs(direction.y) == 1:
		return 1
	return 2

static func _sign_from_direction(direction: Vector3i) -> int:
	if abs(direction.x) == 1:
		return direction.x
	if abs(direction.y) == 1:
		return direction.y
	return direction.z

static func _value_on_axis(point: Vector3, axis: int) -> float:
	match axis:
		0:
			return point.x
		1:
			return point.y
		_:
			return point.z

static func _axis_length(min_bounds: Vector3, max_bounds: Vector3, axis: int) -> float:
	match axis:
		0:
			return max_bounds.x - min_bounds.x
		1:
			return max_bounds.y - min_bounds.y
		_:
			return max_bounds.z - min_bounds.z

static func _project_to_plane(point: Vector3, axis: int) -> Vector2:
	match axis:
		0:
			return Vector2(point.y, point.z)
		1:
			return Vector2(point.x, point.z)
		_:
			return Vector2(point.x, point.y)
