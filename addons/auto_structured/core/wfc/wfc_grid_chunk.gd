@tool
class_name WfcGridChunk extends RefCounted

const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")

var coords: Vector3i
var origin: Vector3i
var size: Vector3i
var cells: Array[WfcCell] = []
var uncollapsed_cells: int = 0
var dirty_entropy_hint: bool = true
var _cached_entropy_hint: float = 0.0

func _init(chunk_coords: Vector3i, chunk_origin: Vector3i, chunk_size: Vector3i) -> void:
	coords = chunk_coords
	origin = chunk_origin
	size = chunk_size
	cells = []
	uncollapsed_cells = 0
	dirty_entropy_hint = true
	_cached_entropy_hint = 0.0

func add_cell(cell: WfcCell) -> void:
	if cell == null:
		return
	cells.append(cell)
	if not cell.is_collapsed():
		uncollapsed_cells += 1
	dirty_entropy_hint = true

func contains_position(pos: Vector3i) -> bool:
	return (
		pos.x >= origin.x and pos.x < origin.x + size.x
		and pos.y >= origin.y and pos.y < origin.y + size.y
		and pos.z >= origin.z and pos.z < origin.z + size.z
	)

func on_cell_collapsed(cell: WfcCell) -> void:
	uncollapsed_cells = max(uncollapsed_cells - 1, 0)
	dirty_entropy_hint = true

func recompute_uncollapsed_count() -> void:
	uncollapsed_cells = 0
	for cell in cells:
		if cell != null and not cell.is_collapsed():
			uncollapsed_cells += 1
	dirty_entropy_hint = true

func mark_entropy_dirty() -> void:
	dirty_entropy_hint = true

func get_entropy_hint() -> float:
	if dirty_entropy_hint:
		_cached_entropy_hint = _compute_entropy_hint()
		dirty_entropy_hint = false
	return _cached_entropy_hint

func _compute_entropy_hint() -> float:
	if cells.is_empty():
		return 0.0
	var entropy_sum := 0.0
	var samples := 0
	for cell in cells:
		if cell == null or cell.is_collapsed():
			continue
		if cell._entropy_valid:
			entropy_sum += cell._cached_entropy
		else:
			entropy_sum += max(cell.get_entropy(), 0.0)
		samples += 1
	if samples == 0:
		return 0.0
	return entropy_sum / float(samples)
