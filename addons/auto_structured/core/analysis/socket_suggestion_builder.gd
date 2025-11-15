@tool
class_name SocketSuggestionBuilder

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")
const MeshOutlineAnalyzer := preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")

static func build_suggestions(tile: Tile, library: ModuleLibrary) -> Array:
	if tile == null or library == null:
		return []
	var face_map := MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	if face_map.is_empty():
		return []
	var suggestions: Array = []
	for direction in face_map.keys():
		var face: Dictionary = face_map[direction]
		if face.is_empty():
			continue
		var suggestion := _find_best_match_for_face(tile, direction, face, library)
		if suggestion:
			suggestions.append(suggestion)
	return suggestions

static func _find_best_match_for_face(tile: Tile, direction: Vector3i, face: Dictionary, library: ModuleLibrary) -> Dictionary:
	var opposite := Vector3i(-direction.x, -direction.y, -direction.z)
	var best := {}
	var best_score: float = INF
	for other_tile in library.tiles:
		if other_tile == tile:
			continue
		var other_faces := MeshOutlineAnalyzer.get_face_signatures_for_tile(other_tile)
		if not other_faces.has(opposite):
			continue
		var partner_face: Dictionary = other_faces[opposite]
		if partner_face.is_empty():
			continue
		var score = _compare_faces(face, partner_face)
		if score == null:
			continue
		var partner_socket := other_tile.get_socket_by_direction(opposite)
		if partner_socket == null:
			continue
		var partner_socket_id := partner_socket.socket_id.strip_edges()
		if partner_socket_id == "" or partner_socket_id == "none":
			continue
		if score < best_score:
			best_score = score
			var compatible_ids: Array[String] = []
			compatible_ids.assign(partner_socket.compatible_sockets)
			best = {
				"direction": direction,
				"socket_id": partner_socket_id,
				"compatible": compatible_ids,
				"partner_tile": other_tile,
				"partner_direction": opposite,
				"score": score,
				"face": face,
				"partner_face": partner_face,
				"partner_socket": partner_socket
			}
	if best.is_empty():
		return {}
	return best

static func _compare_faces(face_a: Dictionary, face_b: Dictionary) -> Variant:
	if face_a.is_empty() or face_b.is_empty():
		return null
	var dims_a: Vector2 = face_a.get("dimensions", Vector2.ZERO)
	var dims_b: Vector2 = face_b.get("dimensions", Vector2.ZERO)
	if dims_a.x <= 0.0 or dims_a.y <= 0.0:
		return null
	if dims_b.x <= 0.0 or dims_b.y <= 0.0:
		return null
	var size_scale := max(max(dims_a.x, dims_a.y), max(dims_b.x, dims_b.y))
	var dimension_tolerance := max(0.02, size_scale * 0.05)
	if abs(dims_a.x - dims_b.x) > dimension_tolerance:
		return null
	if abs(dims_a.y - dims_b.y) > dimension_tolerance:
		return null
	var center_a: Vector2 = face_a.get("center", Vector2.ZERO)
	var center_b: Vector2 = face_b.get("center", Vector2.ZERO)
	var center_tolerance := max(0.025, size_scale * 0.05)
	if abs(center_a.x - center_b.x) > center_tolerance:
		return null
	if abs(center_a.y - center_b.y) > center_tolerance:
		return null
	var dimension_diff: float = abs(dims_a.x - dims_b.x) + abs(dims_a.y - dims_b.y)
	var center_diff: float = abs(center_a.x - center_b.x) + abs(center_a.y - center_b.y)
	return dimension_diff + center_diff
