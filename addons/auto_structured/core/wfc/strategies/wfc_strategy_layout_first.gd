@tool
class_name WfcLayoutFirstStrategy extends WfcSolveStrategy
## Layout-first strategy that expands from the grid's perimeter toward the center.
##
## The strategy maintains a frontier of cells (initially the outer shell) and
## collapses low-entropy cells along this frontier before falling back to the
## default entropy heuristic. As propagation reduces entropy deeper in the grid,
## the frontier automatically widens to carve zones in a predictable order.

var _frontier_cells: Array = []
var _frontier_lookup: Dictionary = {}
var _grid_ref = null

func get_id() -> String:
	return "layout_first"

func get_display_name() -> String:
	return "Layout-First (Zones)"

func configure(solver, _config) -> void:
	if solver:
		_grid_ref = solver.grid

func prepare_grid(grid, _solver) -> void:
	_grid_ref = grid
	_frontier_cells.clear()
	_frontier_lookup.clear()
	if grid == null:
		return
	for cell in grid.get_all_cells():
		if cell == null or cell.is_collapsed():
			continue
		if _is_outer_shell(cell.position, grid.size):
			_queue_cell(cell)

func on_cell_collapsed(cell) -> void:
	if cell == null or _grid_ref == null:
		return
	_frontier_lookup.erase(cell.position)
	for neighbor in _grid_ref.get_neighbors(cell.position):
		if neighbor and not neighbor.is_collapsed():
			_queue_cell(neighbor)

func after_propagation(_cell, _solver, changed_cells: Array = []) -> void:
	for updated in changed_cells:
		if updated and not updated.is_collapsed():
			_queue_cell(updated)

func inject_constraints(grid, _solver) -> void:
	if grid:
		_grid_ref = grid
	_prune_frontier()

func pick_next_cell(solver) -> Variant:
	_prune_frontier()
	var candidate = _get_lowest_entropy_frontier_cell()
	if candidate:
		return candidate
	return super.pick_next_cell(solver)

func _queue_cell(cell) -> void:
	if cell == null:
		return
	if _frontier_lookup.has(cell.position):
		return
	_frontier_cells.append(cell)
	_frontier_lookup[cell.position] = true

func _prune_frontier() -> void:
	if _frontier_cells.is_empty():
		return
	var cleaned: Array = []
	for cell in _frontier_cells:
		if cell == null or cell.is_collapsed() or cell.has_contradiction():
			if cell:
				_frontier_lookup.erase(cell.position)
			continue
		cleaned.append(cell)
	_frontier_cells = cleaned

func _get_lowest_entropy_frontier_cell() -> WfcCell:
	var best: WfcCell = null
	var best_entropy := INF
	for cell in _frontier_cells:
		if cell == null or cell.is_collapsed():
			continue
		var entropy = cell.get_entropy()
		if best == null or entropy < best_entropy:
			best = cell
			best_entropy = entropy
	return best

func _is_outer_shell(pos: Vector3i, size: Vector3i) -> bool:
	if size == Vector3i.ZERO:
		return true
	return (
		pos.x == 0 or pos.y == 0 or pos.z == 0 or
		pos.x == size.x - 1 or pos.y == size.y - 1 or pos.z == size.z - 1
	)
