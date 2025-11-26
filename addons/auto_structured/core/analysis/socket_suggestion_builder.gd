@tool
class_name SocketSuggestionBuilder

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")

const MeshOutlineAnalyzer := preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")

static func build_suggestions(tile: Tile, library: ModuleLibrary, allow_self_match: bool = false) -> Array:
	if tile == null or library == null:
		return []
	var guid_index := _build_socket_guid_index(library)
	var analysis := analyze_faces(tile, library, allow_self_match, guid_index)
	if analysis.is_empty():
		return []
	var suggestions: Array = []
	for direction in analysis.keys():
		var info: Dictionary = analysis.get(direction, {})
		var candidates: Array = info.get("candidates", [])
		for candidate in candidates:
			var detail: Dictionary = candidate.get("detail", {})
			if not detail.get("within_tolerance", false):
				continue
			var suggestion := _candidate_to_suggestion(direction, candidate, guid_index)
			if suggestion.is_empty():
				continue
			suggestions.append(suggestion)
	return suggestions

static func analyze_faces(tile: Tile, library: ModuleLibrary, allow_self_match: bool = false, guid_index: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if tile == null or library == null:
		return result
	var face_map := MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	if face_map.is_empty():
		return result
	var index := guid_index
	if index.is_empty():
		index = _build_socket_guid_index(library)
	for direction in face_map.keys():
		var face: Dictionary = face_map[direction]
		var info := {
			"direction": direction,
			"has_socket": not tile.get_sockets_in_direction(direction).is_empty(),
			"suggestion": {},
			"within_tolerance": false,
			"best_candidate": null,
			"issues": [],
			"candidates": []
		}
		var candidates := _gather_candidates(tile, direction, face, library, allow_self_match)
		info["candidates"] = candidates
		var best_within: Dictionary = {}
		var best_any: Dictionary = {}
		for candidate in candidates:
			var detail: Dictionary = candidate.get("detail", {})
			if best_any.is_empty() or float(detail.get("score", INF)) < float(best_any.get("detail", {}).get("score", INF)):
				best_any = candidate
			if detail.get("within_tolerance", false):
				if best_within.is_empty() or float(detail.get("score", INF)) < float(best_within.get("detail", {}).get("score", INF)):
					best_within = candidate
		if not best_within.is_empty():
			info["suggestion"] = _candidate_to_suggestion(direction, best_within, index)
			info["within_tolerance"] = true
			info["best_candidate"] = best_within
		else:
			info["best_candidate"] = best_any if not best_any.is_empty() else null
		info["issues"] = _build_analysis_issues(info, face)
		result[direction] = info
	return result

static func _compare_faces(face_a: Dictionary, face_b: Dictionary) -> Variant:
	var detail := _compare_faces_detailed(face_a, face_b)
	if detail == null:
		return null
	if not detail.get("within_tolerance", false):
		return null
	return detail.get("score", null)

static func _compare_faces_detailed(face_a: Dictionary, face_b: Dictionary) -> Dictionary:
	if face_a.is_empty() or face_b.is_empty():
		return {}
	var dims_a: Vector2 = face_a.get("dimensions", Vector2.ZERO)
	var dims_b: Vector2 = face_b.get("dimensions", Vector2.ZERO)
	if dims_a.x <= 0.0 or dims_a.y <= 0.0:
		return {}
	if dims_b.x <= 0.0 or dims_b.y <= 0.0:
		return {}
	var size_scale := max(max(dims_a.x, dims_a.y), max(dims_b.x, dims_b.y))
	var dimension_tolerance := max(0.02, size_scale * 0.05)
	var dim_delta := Vector2(abs(dims_a.x - dims_b.x), abs(dims_a.y - dims_b.y))
	var within_dimension: bool = dim_delta.x <= dimension_tolerance and dim_delta.y <= dimension_tolerance
	var center_a: Vector2 = face_a.get("center", Vector2.ZERO)
	var center_b: Vector2 = face_b.get("center", Vector2.ZERO)
	var center_tolerance := max(0.025, size_scale * 0.05)
	var center_delta := Vector2(abs(center_a.x - center_b.x), abs(center_a.y - center_b.y))
	var within_center: bool = center_delta.x <= center_tolerance and center_delta.y <= center_tolerance
	var dimension_diff: float = dim_delta.x + dim_delta.y
	var center_diff: float = center_delta.x + center_delta.y
	return {
		"score": dimension_diff + center_diff,
		"dimension_delta": dim_delta,
		"center_delta": center_delta,
		"dimension_tolerance": Vector2(dimension_tolerance, dimension_tolerance),
		"center_tolerance": Vector2(center_tolerance, center_tolerance),
		"within_tolerance": within_dimension and within_center,
		"within_dimension": within_dimension,
		"within_center": within_center
	}

static func _gather_candidates(tile: Tile, direction: Vector3i, face: Dictionary, library: ModuleLibrary, allow_self_match: bool) -> Array:
	var opposite := Vector3i(-direction.x, -direction.y, -direction.z)
	var candidates: Array = []
	for other_tile in library.tiles:
		if other_tile == null:
			continue
		var is_self := other_tile == tile
		if is_self and not allow_self_match:
			continue
		var rotations := other_tile.get_unique_rotations()
		if rotations.is_empty():
			rotations = [0]
		for rotation in rotations:
			if is_self and not allow_self_match:
				continue
			var use_cache := rotation == 0
			var other_faces := MeshOutlineAnalyzer.get_face_signatures_for_tile(other_tile, use_cache, rotation)
			if other_faces.is_empty():
				continue
			if not other_faces.has(opposite):
				continue
			var partner_face: Dictionary = other_faces[opposite]
			if partner_face.is_empty():
				continue
			var detail := _compare_faces_detailed(face, partner_face)
			if detail.is_empty():
				continue
			var partner_sockets: Array = _rotated_sockets_in_direction(other_tile, rotation, opposite)
			if partner_sockets.is_empty():
				continue
			for partner_socket in partner_sockets:
				if partner_socket == null:
					continue
				var type_id: String = partner_socket.socket_id.strip_edges()
				if type_id == "" or type_id == "none":
					continue
				var candidate := {
					"tile": other_tile,
					"partner_direction": opposite,
					"partner_face": partner_face,
					"partner_socket": partner_socket,
					"detail": detail.duplicate(true),
					"face": face,
					"rotation_degrees": rotation
				}
				candidates.append(candidate)
	return candidates

static func _candidate_to_suggestion(direction: Vector3i, candidate: Dictionary, guid_index: Dictionary) -> Dictionary:
	var partner_socket: Socket = candidate.get("partner_socket")
	if partner_socket == null or partner_socket.socket_id.is_empty():
		return {}
	partner_socket.ensure_guid()
	var partner_socket_id := partner_socket.socket_id.strip_edges()
	if partner_socket_id == "" or partner_socket_id == "none":
		return {}
	# Socket ID is already registered in the library through the socket itself
	var compatible_ids := _clean_compatibility_list(partner_socket, guid_index)
	return {
		"direction": direction,
		"socket_id": partner_socket_id,
		"compatible": compatible_ids,
		"partner_tile": candidate.get("tile"),
		"partner_direction": candidate.get("partner_direction"),
		"partner_rotation": candidate.get("rotation_degrees", 0),
		"score": candidate.get("detail", {}).get("score", INF),
		"face": candidate.get("face"),
		"partner_face": candidate.get("partner_face"),
		"partner_socket": partner_socket,
		"detail": candidate.get("detail")
	}

static func _clean_compatibility_list(partner_socket: Socket, guid_index: Dictionary) -> Array[String]:
	var cleaned: Array[String] = []
	if partner_socket == null:
		return cleaned
	var seen: Dictionary = {}
	for compat_guid in partner_socket.compatible_sockets:
		var clean := String(compat_guid).strip_edges()
		if clean == "" or seen.has(clean):
			continue
		if not guid_index.is_empty() and not guid_index.has(clean):
			continue
		seen[clean] = true
		cleaned.append(clean)
	cleaned.sort()
	return cleaned

static func _build_socket_guid_index(library: ModuleLibrary) -> Dictionary:
	var index: Dictionary = {}
	if library == null:
		return index
	for tile in library.tiles:
		if tile == null:
			continue
		for socket in tile.sockets:
			if socket == null:
				continue
			socket.ensure_guid()
			var guid := String(socket.socket_guid).strip_edges()
			if guid == "":
				continue
			index[guid] = true
	return index


static func _build_analysis_issues(info: Dictionary, face: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	if not info.get("has_socket", false):
		issues.append("No socket defined on this face; connections will be skipped.")
	if info.get("suggestion", {}).is_empty():
		var best_candidate := info.get("best_candidate", null)
		if best_candidate == null:
			issues.append("No compatible faces detected in the library.")
		else:
			var detail: Dictionary = best_candidate.get("detail", {})
			if not detail.get("within_dimension", true):
				var delta: Vector2 = detail.get("dimension_delta", Vector2.ZERO)
				issues.append("Outline dimensions differ by %.3f / %.3f units." % [delta.x, delta.y])
			if not detail.get("within_center", true):
				var center_delta: Vector2 = detail.get("center_delta", Vector2.ZERO)
				issues.append("Socket centers offset by %.3f / %.3f units." % [center_delta.x, center_delta.y])
	else:
		var suggestion := info.get("suggestion")
		var detail: Dictionary = suggestion.get("detail", {})
		if detail and not detail.get("within_center", true):
			var center_delta: Vector2 = detail.get("center_delta", Vector2.ZERO)
			issues.append("Accepted match has center offset %.3f / %.3f units." % [center_delta.x, center_delta.y])
	return issues

static func _rotated_sockets_in_direction(tile: Tile, rotation_degrees: int, direction: Vector3i) -> Array:
	var sockets_in_direction: Array = []
	if tile == null:
		return sockets_in_direction
	var normalized := int(round(rotation_degrees)) % 360
	if normalized < 0:
		normalized += 360
	for socket in tile.sockets:
		if socket == null:
			continue
		var rotated_dir := _rotate_direction_y(socket.direction, normalized)
		if rotated_dir == direction:
			sockets_in_direction.append(socket)
	return sockets_in_direction

static func _rotate_direction_y(direction: Vector3i, degrees: int) -> Vector3i:
	var normalized := degrees % 360
	if normalized < 0:
		normalized += 360
	if direction == Vector3i.ZERO:
		return direction
	if direction.y != 0 and direction.x == 0 and direction.z == 0:
		return direction
	if normalized == 0:
		return direction
	var basis := Basis().rotated(Vector3.UP, deg_to_rad(float(normalized)))
	var rotated := basis * Vector3(direction)
	return Vector3i(
		int(round(rotated.x)),
		int(round(rotated.y)),
		int(round(rotated.z))
	)
