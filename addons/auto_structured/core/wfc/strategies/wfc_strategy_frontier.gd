@tool
class_name WfcFrontierStrategy extends WfcSolveStrategy
## Expands outward from a seed cell while still falling back to entropy when needed.

var _grid_ref
var _center: Vector3i = Vector3i.ZERO
var _frontier: Array[Vector3i] = []
var _queued: Dictionary = {}
var _queue_head: int = 0

func get_id() -> String:
	return "frontier"

func get_display_name() -> String:
	return "Frontier Expansion"

func configure(solver, _config) -> void:
	if solver == null or solver.grid == null:
		return
	_grid_ref = solver.grid
	_center = Vector3i(solver.grid.size.x / 2, solver.grid.size.y / 2, solver.grid.size.z / 2)
	_reset_frontier()

func on_reset(_solver) -> void:
	_reset_frontier()

func on_cell_collapsed(cell) -> void:
	if cell == null:
		return
	_enqueue_neighbors(cell.position)

func pick_next_cell(solver) -> Variant:
	if solver == null or solver.grid == null:
		return null
	if _grid_ref != solver.grid:
		configure(solver, null)
	if _frontier.is_empty() or _queue_head >= _frontier.size():
		_reset_frontier()
	while _queue_head < _frontier.size():
		var pos = _frontier[_queue_head]
		_queue_head += 1
		var cell = solver.grid.get_cell(pos)
		if cell and not cell.is_collapsed() and not cell.has_contradiction():
			return cell
	return solver.grid.get_lowest_entropy_cell()

func _reset_frontier() -> void:
	_frontier.clear()
	_queue_head = 0
	_queued.clear()
	_enqueue(_center)

func _enqueue_neighbors(pos: Vector3i) -> void:
	if _grid_ref == null:
		return
	var neighbors = _grid_ref.get_neighbors(pos)
	for neighbor in neighbors:
		_enqueue(neighbor.position)

func _enqueue(pos: Vector3i) -> void:
	if _grid_ref == null:
		return
	if not _grid_ref.is_valid_position(pos):
		return
	var key = _pos_key(pos)
	if _queued.has(key):
		return
	_queued[key] = true
	_frontier.append(pos)

func _pos_key(pos: Vector3i) -> String:
	return str(pos.x, ":", pos.y, ":", pos.z)
