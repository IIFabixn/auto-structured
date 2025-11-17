@tool
class_name SocketSuggestionBuilder

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")
const SocketType := preload("res://addons/auto_structured/core/socket_type.gd")
const MeshOutlineAnalyzer := preload("res://addons/auto_structured/core/analysis/mesh_outline_analyzer.gd")

static func build_suggestions(tile: Tile, library: ModuleLibrary, allow_self_match: bool = false) -> Array:
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
		var suggestion := _find_best_match_for_face(tile, direction, face, library, allow_self_match)
		if suggestion:
			suggestions.append(suggestion)
	return suggestions

static func analyze_faces(tile: Tile, library: ModuleLibrary, allow_self_match: bool = false) -> Dictionary:
	var result: Dictionary = {}
	if tile == null or library == null:
		return result
	var face_map := MeshOutlineAnalyzer.get_face_signatures_for_tile(tile)
	if face_map.is_empty():
		return result
	for direction in face_map.keys():
		var face: Dictionary = face_map[direction]
		var info := {
			"direction": direction,
			"has_socket": tile.get_socket_by_direction(direction) != null,
			"suggestion": {},
			"within_tolerance": false,
			"best_candidate": null,
			"issues": []
		}
		var candidates := _gather_candidates(tile, direction, face, library, allow_self_match)
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
			info["suggestion"] = _candidate_to_suggestion(direction, best_within)
			info["within_tolerance"] = true
			info["best_candidate"] = best_within
		else:
			info["best_candidate"] = best_any if not best_any.is_empty() else null
		info["issues"] = _build_analysis_issues(info, face)
		result[direction] = info
	return result

static func _find_best_match_for_face(tile: Tile, direction: Vector3i, face: Dictionary, library: ModuleLibrary, allow_self_match: bool) -> Dictionary:
	var candidates := _gather_candidates(tile, direction, face, library, allow_self_match)
	var best_candidate: Dictionary = {}
	var best_score: float = INF
	for candidate in candidates:
		var detail: Dictionary = candidate.get("detail", {})
		if not detail.get("within_tolerance", false):
			continue
		var score := float(detail.get("score", INF))
		if score < best_score:
			best_score = score
			best_candidate = candidate
	if best_candidate.is_empty():
		return {}
	return _candidate_to_suggestion(direction, best_candidate)

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
		if not allow_self_match and other_tile == tile:
			continue
		var other_faces := MeshOutlineAnalyzer.get_face_signatures_for_tile(other_tile)
		if not other_faces.has(opposite):
			continue
		var partner_face: Dictionary = other_faces[opposite]
		if partner_face.is_empty():
			continue
		var detail := _compare_faces_detailed(face, partner_face)
		if detail.is_empty():
			continue
		var partner_socket := other_tile.get_socket_by_direction(opposite)
		var candidate := {
			"tile": other_tile,
			"opposite": opposite,
			"partner_face": partner_face,
			"partner_socket": partner_socket,
			"detail": detail,
			"face": face
		}
		candidates.append(candidate)
	return candidates

static func _candidate_to_suggestion(direction: Vector3i, candidate: Dictionary) -> Dictionary:
	var partner_socket: Socket = candidate.get("partner_socket")
	if partner_socket == null:
		return {}
	var partner_socket_id := partner_socket.socket_id.strip_edges()
	if partner_socket_id == "" or partner_socket_id == "none":
		return {}
	var compatible_ids: Array[String] = []
	compatible_ids.assign(partner_socket.compatible_sockets)
	return {
		"direction": direction,
		"socket_id": partner_socket_id,
		"compatible": compatible_ids,
		"partner_tile": candidate.get("tile"),
		"partner_direction": candidate.get("opposite"),
		"score": candidate.get("detail", {}).get("score", INF),
		"face": candidate.get("face"),
		"partner_face": candidate.get("partner_face"),
		"partner_socket": partner_socket,
		"detail": candidate.get("detail")
	}

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
