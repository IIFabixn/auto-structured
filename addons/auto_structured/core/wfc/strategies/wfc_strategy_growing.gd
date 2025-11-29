@tool
class_name WfcGrowingStrategy extends WfcSolveStrategy
## A structure-aware solve strategy that grows boundaries outward from a seed.
##
## This strategy prioritizes creating coherent, closed boundary structures by:
## 1. Starting from a corner seed position
## 2. Growing along the boundary frontier (cells adjacent to placed walls)
## 3. Preferring cells that would close loops or continue wall lines
## 4. Filling interior cells only after boundary is established
##
## Best used with boundary_role tiles (EDGE, CORNER) and region tracking enabled.

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Configuration
@export var prefer_perimeter_start: bool = true  ## Start seed at grid perimeter
@export var closure_bonus: float = 100.0  ## Score bonus for cells that would close a loop
@export var continuation_bonus: float = 20.0  ## Score bonus per adjacent wall neighbor
@export var interior_delay_factor: float = 0.5  ## How much to delay interior cell selection
@export var boundary_weight_multiplier: float = 10.0  ## How much to boost boundary tile weights on frontier

## Internal state
var _grid_ref = null
var _solver_ref = null
var _boundary_frontier: Array[Vector3i] = []  ## Cells adjacent to placed boundary tiles
var _frontier_set: Dictionary = {}  ## Fast lookup: pos_key -> true
var _placed_boundaries: Dictionary = {}  ## pos_key -> true for all placed boundary tiles
var _seed_placed: bool = false
var _seed_position: Vector3i = Vector3i.ZERO
var _target_closure_pos: Vector3i = Vector3i.ZERO  ## Where we're trying to connect back to
var _phase: int = 0  ## 0=seed, 1=boundary growth, 2=interior fill


func get_id() -> String:
	return "growing"


func get_display_name() -> String:
	return "Growing Structure"


func configure(solver, _config) -> void:
	if solver == null or solver.grid == null:
		return
	_solver_ref = solver
	_grid_ref = solver.grid
	_reset_state()


func on_reset(_solver) -> void:
	_reset_state()


func on_cell_collapsed(cell) -> void:
	if cell == null or _grid_ref == null:
		return
	
	var tile: Tile = cell.get_tile()
	if tile == null:
		return
	
	var pos = cell.position
	var pos_key = _pos_to_key(pos)
	
	# Track boundary tile placements
	if _is_boundary_tile(tile):
		_placed_boundaries[pos_key] = true
		
		# Remove from frontier (it's now placed)
		if _frontier_set.has(pos_key):
			_frontier_set.erase(pos_key)
			_boundary_frontier.erase(pos)
		
		# Add neighbors to frontier
		_add_neighbors_to_frontier(pos)
		
		# Update closure target (farthest boundary tile from seed)
		if _seed_placed:
			var dist_to_seed = (pos - _seed_position).length()
			var current_dist = (_target_closure_pos - _seed_position).length()
			if dist_to_seed > current_dist:
				_target_closure_pos = pos


func adjust_weights_for_cell(cell, _solver) -> void:
	"""Boost boundary tile weights when collapsing frontier cells.
	
	This is the key to making the growing strategy work - it's not enough
	to just pick frontier cells, we need to bias the tile selection too.
	"""
	if cell == null:
		return
	
	var pos = cell.position
	var pos_key = _pos_to_key(pos)
	
	# Only boost on frontier cells or during seed placement
	var is_frontier = _frontier_set.has(pos_key)
	var is_seed = not _seed_placed
	var is_perimeter = _is_on_grid_perimeter(pos)
	
	if not is_frontier and not is_seed and not is_perimeter:
		return  # Don't modify interior cell weights
	
	# Calculate boost factor based on context
	var boost_factor = boundary_weight_multiplier
	
	# Extra boost for cells that would close loops
	if _would_help_close_loop(pos):
		boost_factor *= 2.0
	
	# Extra boost for cells with wall neighbors (continue lines)
	var wall_neighbors = _count_boundary_neighbors(pos)
	if wall_neighbors >= 2:
		boost_factor *= 1.5  # Strong continuation bonus
	elif wall_neighbors == 1:
		boost_factor *= 1.2  # Mild continuation bonus
	
	# Apply boost to boundary tile variants
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _is_boundary_tile(tile):
			var current_weight = variant.get("weight", 1.0)
			variant["weight"] = current_weight * boost_factor


func pick_next_cell(solver) -> Variant:
	if solver == null or solver.grid == null:
		return null
	
	if _grid_ref != solver.grid:
		configure(solver, null)
	
	# Phase 0: Place initial seed (corner)
	if not _seed_placed:
		return _place_seed()
	
	# Phase 1: Grow boundary from frontier
	var boundary_cell = _pick_best_frontier_cell()
	if boundary_cell != null:
		return boundary_cell
	
	# Phase 2: Fill remaining cells (interior/air)
	return _pick_interior_cell()


## ============================================================================
## Seed Placement
## ============================================================================

func _place_seed() -> Variant:
	if _grid_ref == null:
		return null
	
	var seed_pos: Vector3i
	
	if prefer_perimeter_start:
		# Pick a corner position on the ground floor
		seed_pos = Vector3i(0, 0, 0)
	else:
		# Pick center
		seed_pos = Vector3i(
			_grid_ref.size.x / 2,
			0,
			_grid_ref.size.z / 2
		)
	
	var cell = _grid_ref.get_cell(seed_pos)
	if cell == null or cell.is_collapsed():
		# Find first uncollapsed cell on perimeter
		cell = _find_uncollapsed_perimeter_cell()
	
	if cell != null:
		_seed_placed = true
		_seed_position = cell.position
		_target_closure_pos = _seed_position
		_add_neighbors_to_frontier(cell.position)
	
	return cell


func _find_uncollapsed_perimeter_cell() -> Variant:
	"""Find an uncollapsed cell on the grid perimeter."""
	var size = _grid_ref.size
	
	# Check edges of ground floor
	for x in range(size.x):
		for z in [0, size.z - 1]:
			var cell = _grid_ref.get_cell(Vector3i(x, 0, z))
			if cell and not cell.is_collapsed():
				return cell
	
	for z in range(size.z):
		for x in [0, size.x - 1]:
			var cell = _grid_ref.get_cell(Vector3i(x, 0, z))
			if cell and not cell.is_collapsed():
				return cell
	
	return null


## ============================================================================
## Frontier-Based Boundary Growth
## ============================================================================

func _pick_best_frontier_cell() -> Variant:
	"""Select the best frontier cell for boundary growth."""
	if _boundary_frontier.is_empty():
		return null
	
	var best_cell = null
	var best_score: float = -INF
	
	# Clean up frontier first (remove collapsed cells)
	var valid_frontier: Array[Vector3i] = []
	for pos in _boundary_frontier:
		var cell = _grid_ref.get_cell(pos)
		if cell and not cell.is_collapsed() and not cell.has_contradiction():
			# Only include if it can still become a boundary tile
			if _can_be_boundary(cell):
				valid_frontier.append(pos)
	
	_boundary_frontier = valid_frontier
	
	for pos in _boundary_frontier:
		var cell = _grid_ref.get_cell(pos)
		if cell == null:
			continue
		
		var score = _score_frontier_cell(pos, cell)
		if score > best_score:
			best_score = score
			best_cell = cell
	
	return best_cell


func _score_frontier_cell(pos: Vector3i, cell) -> float:
	"""Score a frontier cell based on how good it is for boundary growth."""
	var score: float = 0.0
	
	# Base score from position on grid (prefer edges for buildings)
	if _is_on_grid_perimeter(pos):
		score += 10.0
	
	# Bonus for cells with more boundary neighbors (continue wall lines)
	var wall_neighbors = _count_boundary_neighbors(pos)
	score += wall_neighbors * continuation_bonus
	
	# Bonus for cells that would close a loop
	if _would_help_close_loop(pos):
		score += closure_bonus
	
	# Bonus for cells closer to completing the perimeter
	# (distance to closure target, inverted so closer = higher)
	var dist_to_target = (pos - _target_closure_pos).length()
	if dist_to_target > 0:
		score += 50.0 / dist_to_target
	
	# Slight preference for lower entropy (more constrained = more determined)
	var entropy = cell.get_entropy() if cell.has_method("get_entropy") else 10.0
	score += 5.0 / max(1.0, entropy)
	
	return score


func _would_help_close_loop(pos: Vector3i) -> bool:
	"""Check if placing a boundary here would help close a loop."""
	# Count how many separate boundary "chains" this would connect
	var adjacent_boundaries: Array[Vector3i] = []
	
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor_pos = pos + dir
		if _placed_boundaries.has(_pos_to_key(neighbor_pos)):
			adjacent_boundaries.append(neighbor_pos)
	
	# If this would connect 2+ separate boundary tiles, it helps close
	if adjacent_boundaries.size() >= 2:
		# Check if the neighbors are in different "chains" 
		# (simplified: just check if they're not adjacent to each other)
		if adjacent_boundaries.size() == 2:
			var dist = (adjacent_boundaries[0] - adjacent_boundaries[1]).length()
			if dist > 1.5:  # Not directly adjacent, so this bridges them
				return true
	
	# Also check if we're connecting back near the seed
	var dist_to_seed = (pos - _seed_position).length()
	if dist_to_seed <= 2.0 and _placed_boundaries.size() > 4:
		return true
	
	return false


func _can_be_boundary(cell) -> bool:
	"""Check if this cell can still become a boundary tile."""
	if cell == null or cell.is_collapsed():
		return false
	
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _is_boundary_tile(tile):
			return true
	
	return false


## ============================================================================
## Interior Fill Phase
## ============================================================================

func _pick_interior_cell() -> Variant:
	"""Pick the next interior cell to fill after boundaries are placed."""
	# Fall back to entropy-based selection for interior
	if _grid_ref == null:
		return null
	
	# Prefer cells adjacent to collapsed cells (natural fill pattern)
	var best_cell = null
	var best_score: float = -INF
	
	for x in range(_grid_ref.size.x):
		for y in range(_grid_ref.size.y):
			for z in range(_grid_ref.size.z):
				var pos = Vector3i(x, y, z)
				var cell = _grid_ref.get_cell(pos)
				
				if cell == null or cell.is_collapsed() or cell.has_contradiction():
					continue
				
				var score = _score_interior_cell(pos, cell)
				if score > best_score:
					best_score = score
					best_cell = cell
	
	# If no scored cell, fall back to lowest entropy
	if best_cell == null:
		return _grid_ref.get_lowest_entropy_cell()
	
	return best_cell


func _score_interior_cell(pos: Vector3i, cell) -> float:
	"""Score an interior cell for fill order."""
	var score: float = 0.0
	
	# Prefer cells with more collapsed neighbors (natural flood fill)
	var collapsed_neighbors = _count_collapsed_neighbors(pos)
	score += collapsed_neighbors * 10.0
	
	# Prefer lower entropy (more constrained)
	var entropy = cell.get_entropy() if cell.has_method("get_entropy") else 10.0
	score += 20.0 / max(1.0, entropy)
	
	# Slight preference for ground floor
	if pos.y == 0:
		score += 5.0
	
	return score


## ============================================================================
## Helper Functions
## ============================================================================

func _reset_state() -> void:
	_boundary_frontier.clear()
	_frontier_set.clear()
	_placed_boundaries.clear()
	_seed_placed = false
	_seed_position = Vector3i.ZERO
	_target_closure_pos = Vector3i.ZERO
	_phase = 0


func _add_neighbors_to_frontier(pos: Vector3i) -> void:
	"""Add uncollapsed neighbors to the boundary frontier."""
	if _grid_ref == null:
		return
	
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor_pos = pos + dir
		
		if not _grid_ref.is_valid_position(neighbor_pos):
			continue
		
		var key = _pos_to_key(neighbor_pos)
		if _frontier_set.has(key) or _placed_boundaries.has(key):
			continue
		
		var neighbor_cell = _grid_ref.get_cell(neighbor_pos)
		if neighbor_cell and not neighbor_cell.is_collapsed():
			_frontier_set[key] = true
			_boundary_frontier.append(neighbor_pos)


func _is_boundary_tile(tile: Tile) -> bool:
	"""Check if a tile is a boundary tile (EDGE or CORNER role)."""
	if tile == null:
		return false
	return tile.boundary_role == Tile.BoundaryRole.EDGE or tile.boundary_role == Tile.BoundaryRole.CORNER


func _count_boundary_neighbors(pos: Vector3i) -> int:
	"""Count how many adjacent cells have boundary tiles placed."""
	var count := 0
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor_pos = pos + dir
		if _placed_boundaries.has(_pos_to_key(neighbor_pos)):
			count += 1
	return count


func _count_collapsed_neighbors(pos: Vector3i) -> int:
	"""Count how many adjacent cells are collapsed."""
	if _grid_ref == null:
		return 0
	
	var count := 0
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP, Vector3i.DOWN]:
		var neighbor_pos = pos + dir
		if not _grid_ref.is_valid_position(neighbor_pos):
			continue
		var cell = _grid_ref.get_cell(neighbor_pos)
		if cell and cell.is_collapsed():
			count += 1
	return count


func _is_on_grid_perimeter(pos: Vector3i) -> bool:
	"""Check if position is on the XZ perimeter of the grid."""
	if _grid_ref == null:
		return false
	return (
		pos.x == 0 or pos.x == _grid_ref.size.x - 1 or
		pos.z == 0 or pos.z == _grid_ref.size.z - 1
	)


func _pos_to_key(pos: Vector3i) -> int:
	"""Convert position to integer key for dictionary storage."""
	if _grid_ref == null:
		return 0
	return pos.x + pos.y * _grid_ref.size.x + pos.z * _grid_ref.size.x * _grid_ref.size.y
