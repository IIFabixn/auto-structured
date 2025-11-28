@tool
class_name WfcCenterOutStrategy extends WfcSolveStrategy
## Picks cells by entropy but biases toward the geometric center of the grid.

var _ordered_cells: Array = []
var _center_point: Vector3 = Vector3.ZERO
var _grid_cell_count: int = 0

func get_id() -> String:
	return "center_out"

func get_display_name() -> String:
	return "Center-Out Expansion"

func configure(solver, _config) -> void:
	if solver == null or solver.grid == null:
		return
	var size: Vector3i = solver.grid.size
	_center_point = Vector3(size.x - 1, size.y - 1, size.z - 1) * 0.5
	_ordered_cells = solver.grid.get_all_cells().duplicate()
	_grid_cell_count = _ordered_cells.size()
	_ordered_cells.sort_custom(Callable(self, "_sort_by_distance"))

func pick_next_cell(solver) -> Variant:
	if solver == null or solver.grid == null:
		return null
	if _ordered_cells.is_empty() or _grid_cell_count != solver.grid.get_cell_count():
		configure(solver, null)
	var best_cell = null
	var best_entropy: int = 2147483647
	for cell in _ordered_cells:
		if cell == null or cell.is_collapsed() or cell.has_contradiction():
			continue
		var entropy: int = cell.possible_tile_variants.size()
		if best_cell == null or entropy < best_entropy or (entropy == best_entropy and _distance_sq(cell) < _distance_sq(best_cell)):
			best_cell = cell
			best_entropy = entropy
			if entropy <= 1:
				break
	if best_cell:
		return best_cell
	return solver.grid.get_lowest_entropy_cell()

func _sort_by_distance(a, b) -> bool:
	return _distance_sq(a) < _distance_sq(b)

func _distance_sq(cell) -> float:
	if cell == null:
		return INF
	var pos = cell.position
	var pos_vec = Vector3(pos.x, pos.y, pos.z)
	return pos_vec.distance_squared_to(_center_point)
