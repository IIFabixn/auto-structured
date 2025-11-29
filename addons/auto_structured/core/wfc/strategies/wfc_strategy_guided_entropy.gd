@tool
class_name WfcGuidedEntropyStrategy extends WfcSolveStrategy
const Tile = preload("res://addons/auto_structured/core/tile.gd")
## Guided entropy strategy that prioritizes anchor cells and tag-weighted tiles.
##
## Configuration dictionary keys:
## - "anchors": Array[Vector3i|Vector3|Dictionary] positions to prioritize. Dictionaries may
##   contain a "position" key with Vector3/Vector3i values.
## - "anchor_tags": Array[String] of tile tags to boost when collapsing anchor cells.

var anchor_positions: Array[Vector3i] = []
var anchor_tags: Array[String] = []

var _anchor_cells: Array = []
var _grid_ref = null

func get_id() -> String:
	return "guided_entropy"

func get_display_name() -> String:
	return "Guided Entropy"

func configure(solver, config) -> void:
	if solver:
		_grid_ref = solver.grid
	anchor_positions = []
	anchor_tags = []
	if config == null:
		return
	if config.has("anchors"):
		anchor_positions = _normalize_anchor_positions(config["anchors"])
	if config.has("anchor_tags"):
		for tag in config["anchor_tags"]:
			anchor_tags.append(str(tag))

func prepare_grid(grid, _solver) -> void:
	_grid_ref = grid
	_anchor_cells.clear()
	if grid == null:
		return
	for pos in anchor_positions:
		if not grid.is_valid_position(pos):
			continue
		var cell = grid.get_cell(pos)
		if cell:
			_anchor_cells.append(cell)

func inject_constraints(grid, _solver) -> void:
	if grid == null:
		return
	for cell in _anchor_cells:
		if cell == null or cell.is_collapsed():
			continue
		_remove_fallback_variants(cell)

func pick_next_cell(solver) -> Variant:
	var anchor = _pick_anchor_cell()
	if anchor:
		return anchor
	return super.pick_next_cell(solver)

func before_collapse(cell, solver) -> void:
	super.before_collapse(cell, solver)
	if cell == null:
		return
	if anchor_tags.is_empty():
		return
	if not _anchor_cells.has(cell):
		return
	_adjust_anchor_weights(cell)

func _pick_anchor_cell() -> WfcCell:
	var best: WfcCell = null
	var best_entropy := INF
	for cell in _anchor_cells:
		if cell == null or cell.is_collapsed() or cell.has_contradiction():
			continue
		var entropy = cell.get_entropy()
		if best == null or entropy < best_entropy:
			best = cell
			best_entropy = entropy
	return best

func _remove_fallback_variants(cell: WfcCell) -> void:
	var filtered: Array = []
	var removed := false
	for variant in cell.possible_tile_variants:
		if variant.get("is_internal_fallback", false):
			removed = true
			continue
		filtered.append(variant)
	if removed and not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false
		if cell.mask_enabled():
			cell.rebuild_variant_mask()

func _adjust_anchor_weights(cell: WfcCell) -> void:
	var boosted := false
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _tile_matches_tags(tile):
			variant["weight"] = variant.get("weight", 1.0) * 3.0
			boosted = true
		else:
			variant["weight"] = variant.get("weight", 1.0) * 0.5
	if boosted:
		cell._entropy_valid = false

func _tile_matches_tags(tile: Tile) -> bool:
	if tile == null or anchor_tags.is_empty():
		return false
	for tag in anchor_tags:
		if tile.has_tag(tag):
			return true
	return false

func _normalize_anchor_positions(raw_list) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if raw_list == null:
		return result
	for entry in raw_list:
		match typeof(entry):
			TYPE_VECTOR3I:
				result.append(entry)
			TYPE_VECTOR3:
				result.append(Vector3i(entry.x, entry.y, entry.z))
			TYPE_DICTIONARY:
				if entry.has("position"):
					result.append(_dictionary_to_vec3i(entry["position"]))
	return result

func _dictionary_to_vec3i(value) -> Vector3i:
	if typeof(value) == TYPE_VECTOR3I:
		return value
	if typeof(value) == TYPE_VECTOR3:
		return Vector3i(value.x, value.y, value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO
