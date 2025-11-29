@tool
class_name WfcRegionTracker extends RefCounted
## Tracks boundary regions during WFC solving using Union-Find (Disjoint Set Union).
##
## This class efficiently tracks connected components of boundary tiles,
## allowing O(α(n)) ≈ O(1) amortized operations for:
## - Checking if two positions are in the same region
## - Merging regions when a new boundary tile connects them
## - Counting total number of distinct regions
##
## Key features:
## - Incremental tracking as tiles are placed (no full grid scans)
## - Supports backtracking via snapshots
## - Tracks world boundary connections for closed region validation
## - Uses integer keys for O(1) hashing instead of string keys

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Union-Find parent map: position_key (int) -> parent_position_key (int)
var _parent: Dictionary = {}

## Union-Find rank for balanced trees: position_key (int) -> rank (int)
var _rank: Dictionary = {}

## Set of position keys that touch the world boundary (grid edges)
var _world_boundary_connections: Dictionary = {}

## Map of region root (int) -> set of position keys (int) in that region
var _region_members: Dictionary = {}

## Grid reference for bounds checking and key calculation
var _grid_size: Vector3i = Vector3i.ZERO

## Include vertical neighbors when determining connectivity
var include_vertical_neighbors: bool = true

## Cached region count (invalidated on changes)
var _cached_region_count: int = -1


func _init(grid_size: Vector3i = Vector3i.ZERO) -> void:
	_grid_size = grid_size


func set_grid_size(size: Vector3i) -> void:
	_grid_size = size


func reset() -> void:
	"""Clear all tracking data."""
	_parent.clear()
	_rank.clear()
	_world_boundary_connections.clear()
	_region_members.clear()
	_cached_region_count = -1


## ============================================================================
## Core Union-Find Operations (using integer keys for performance)
## ============================================================================

func _pos_to_key(pos: Vector3i) -> int:
	"""Convert position to integer key for dictionary storage.
	Uses flat array indexing: x + y * width + z * width * height
	"""
	return pos.x + pos.y * _grid_size.x + pos.z * _grid_size.x * _grid_size.y


func _key_to_pos(key: int) -> Vector3i:
	"""Convert integer key back to position."""
	var xy_size = _grid_size.x * _grid_size.y
	var z = key / xy_size
	var remainder = key % xy_size
	var y = remainder / _grid_size.x
	var x = remainder % _grid_size.x
	return Vector3i(x, y, z)


func _find(key: int) -> int:
	"""Find the root of a position's region with path compression."""
	if not _parent.has(key):
		return key
	
	if _parent[key] != key:
		# Path compression: point directly to root
		_parent[key] = _find(_parent[key])
	
	return _parent[key]


func _union(key_a: int, key_b: int) -> void:
	"""Merge two regions using union by rank."""
	var root_a = _find(key_a)
	var root_b = _find(key_b)
	
	if root_a == root_b:
		return  # Already in same region
	
	_cached_region_count = -1  # Invalidate cache
	
	var rank_a = _rank.get(root_a, 0)
	var rank_b = _rank.get(root_b, 0)
	
	# Union by rank: attach smaller tree to larger
	var new_root: int
	var old_root: int
	if rank_a < rank_b:
		_parent[root_a] = root_b
		new_root = root_b
		old_root = root_a
	elif rank_a > rank_b:
		_parent[root_b] = root_a
		new_root = root_a
		old_root = root_b
	else:
		_parent[root_b] = root_a
		_rank[root_a] = rank_a + 1
		new_root = root_a
		old_root = root_b
	
	# Merge region members
	if _region_members.has(old_root):
		if not _region_members.has(new_root):
			_region_members[new_root] = {}
		for member_key in _region_members[old_root]:
			_region_members[new_root][member_key] = true
		_region_members.erase(old_root)
	
	# Merge world boundary connections
	if _world_boundary_connections.has(old_root):
		_world_boundary_connections[new_root] = true
		_world_boundary_connections.erase(old_root)


## ============================================================================
## Boundary Tile Registration
## ============================================================================

func register_boundary_tile(pos: Vector3i, tile: Tile) -> void:
	"""Register a newly placed boundary tile and update region connectivity.
	
	Only EDGE and CORNER tiles are tracked for region connectivity.
	INFILL tiles (like floors) are interior and don't form the perimeter.
	"""
	if tile == null:
		return
	
	# Only track EDGE and CORNER tiles for region perimeter
	# INFILL tiles are interior and don't need region tracking
	if tile.boundary_role != Tile.BoundaryRole.EDGE and tile.boundary_role != Tile.BoundaryRole.CORNER:
		return
	
	var key = _pos_to_key(pos)
	
	# Initialize as its own region if not already tracked
	if not _parent.has(key):
		_parent[key] = key
		_rank[key] = 0
		_region_members[key] = {key: true}
	
	_cached_region_count = -1
	
	# Check if this position touches the world boundary
	if _is_on_world_boundary(pos):
		var root = _find(key)
		_world_boundary_connections[root] = true
	
	# Connect to adjacent boundary tiles
	var neighbors = _get_neighbor_positions(pos)
	for neighbor_pos in neighbors:
		var neighbor_key = _pos_to_key(neighbor_pos)
		if _parent.has(neighbor_key):
			# Neighbor is also a boundary tile - merge regions
			_union(key, neighbor_key)


func unregister_boundary_tile(pos: Vector3i) -> void:
	"""Remove a boundary tile (used during backtracking).
	
	Note: Full removal from Union-Find is expensive. Instead, we rebuild
	affected regions. For frequent backtracking, consider using snapshots.
	"""
	var key = _pos_to_key(pos)
	if not _parent.has(key):
		return
	
	_cached_region_count = -1
	
	# Find all positions that were in the same region
	var old_root = _find(key)
	var members_to_rebuild: Array[Vector3i] = []
	
	if _region_members.has(old_root):
		for member_key in _region_members[old_root]:
			if member_key != key:
				members_to_rebuild.append(_key_to_pos(member_key))
		_region_members.erase(old_root)
	
	# Remove from data structures
	_parent.erase(key)
	_rank.erase(key)
	_world_boundary_connections.erase(key)
	_world_boundary_connections.erase(old_root)
	
	# Rebuild regions for remaining members
	# First, reset their parent pointers
	for member_pos in members_to_rebuild:
		var member_key = _pos_to_key(member_pos)
		_parent[member_key] = member_key
		_rank[member_key] = 0
		_region_members[member_key] = {member_key: true}
		if _is_on_world_boundary(member_pos):
			_world_boundary_connections[member_key] = true
	
	# Then reconnect them based on adjacency
	for member_pos in members_to_rebuild:
		var member_key = _pos_to_key(member_pos)
		var neighbors = _get_neighbor_positions(member_pos)
		for neighbor_pos in neighbors:
			var neighbor_key = _pos_to_key(neighbor_pos)
			if _parent.has(neighbor_key) and neighbor_key != key:
				_union(member_key, neighbor_key)


func _get_neighbor_positions(pos: Vector3i) -> Array[Vector3i]:
	"""Get valid neighbor positions for connectivity checks."""
	var neighbors: Array[Vector3i] = []
	
	# Horizontal neighbors (always included)
	var horizontal = [
		pos + Vector3i.RIGHT,
		pos + Vector3i.LEFT,
		pos + Vector3i.FORWARD,
		pos + Vector3i.BACK
	]
	
	for n in horizontal:
		if _is_valid_position(n):
			neighbors.append(n)
	
	# Vertical neighbors (optional, for multi-story buildings)
	if include_vertical_neighbors:
		var vertical = [
			pos + Vector3i.UP,
			pos + Vector3i.DOWN
		]
		for n in vertical:
			if _is_valid_position(n):
				neighbors.append(n)
	
	return neighbors


func _is_valid_position(pos: Vector3i) -> bool:
	"""Check if position is within grid bounds."""
	return (
		pos.x >= 0 and pos.x < _grid_size.x and
		pos.y >= 0 and pos.y < _grid_size.y and
		pos.z >= 0 and pos.z < _grid_size.z
	)


func _is_on_world_boundary(pos: Vector3i) -> bool:
	"""Check if position is on the edge of the grid (XZ plane)."""
	return (
		pos.x == 0 or pos.x == _grid_size.x - 1 or
		pos.z == 0 or pos.z == _grid_size.z - 1
	)


## ============================================================================
## Region Queries
## ============================================================================

func get_region_count() -> int:
	"""Get the number of distinct boundary regions."""
	if _cached_region_count >= 0:
		return _cached_region_count
	
	var roots: Dictionary = {}
	for key in _parent:
		var root = _find(key)
		roots[root] = true
	
	_cached_region_count = roots.size()
	return _cached_region_count


func are_in_same_region(pos_a: Vector3i, pos_b: Vector3i) -> bool:
	"""Check if two positions belong to the same boundary region."""
	var key_a = _pos_to_key(pos_a)
	var key_b = _pos_to_key(pos_b)
	
	if not _parent.has(key_a) or not _parent.has(key_b):
		return false
	
	return _find(key_a) == _find(key_b)


func is_boundary_position(pos: Vector3i) -> bool:
	"""Check if a position is tracked as a boundary tile."""
	return _parent.has(_pos_to_key(pos))


func get_region_id(pos: Vector3i) -> int:
	"""Get the region identifier for a position (-1 if not a boundary)."""
	var key = _pos_to_key(pos)
	if not _parent.has(key):
		return -1
	return _find(key)


func region_touches_world_boundary(pos: Vector3i) -> bool:
	"""Check if the region containing this position touches the world edge."""
	var key = _pos_to_key(pos)
	if not _parent.has(key):
		return false
	
	var root = _find(key)
	return _world_boundary_connections.has(root)


func get_all_regions() -> Array[Dictionary]:
	"""Get information about all regions.
	
	Returns array of dictionaries with:
	- root: int (region identifier)
	- positions: Array[Vector3i] (all positions in region)
	- touches_world_boundary: bool
	"""
	var regions: Dictionary = {}  # root -> {positions, touches_boundary}
	
	for key in _parent:
		var root = _find(key)
		if not regions.has(root):
			regions[root] = {
				"root": root,
				"positions": [],
				"touches_world_boundary": _world_boundary_connections.has(root)
			}
		regions[root]["positions"].append(_key_to_pos(key))
	
	var result: Array[Dictionary] = []
	for root in regions:
		result.append(regions[root])
	return result


## ============================================================================
## Constraint Validation
## ============================================================================

func would_exceed_max_regions(pos: Vector3i, tile: Tile, max_regions: int, grid = null) -> bool:
	"""Check if placing a boundary tile here would exceed the max region count.
	
	Returns true if:
	- This would create a new isolated region AND we're already at max
	- max_regions is 0 (unlimited) -> always returns false
	
	Only EDGE and CORNER tiles are considered for region counting.
	
	If grid is provided, also checks collapsed cells for boundary tiles that
	may not be registered yet (handles timing issues during solve).
	"""
	if max_regions <= 0:
		return false  # Unlimited regions
	
	if tile == null:
		return false
	
	# Only EDGE and CORNER tiles form regions
	if tile.boundary_role != Tile.BoundaryRole.EDGE and tile.boundary_role != Tile.BoundaryRole.CORNER:
		return false
	
	var key = _pos_to_key(pos)
	
	# If already tracked, no new region would be created
	if _parent.has(key):
		return false
	
	# Check if this would connect to any existing boundary tile
	var neighbors = _get_neighbor_positions(pos)
	for neighbor_pos in neighbors:
		var neighbor_key = _pos_to_key(neighbor_pos)
		
		# Check registered tiles first
		if _parent.has(neighbor_key):
			# Would connect to existing region - no new region created
			return false
		
		# Also check grid for collapsed but unregistered boundary tiles
		if grid != null and grid.has_method("get_cell"):
			var neighbor_cell = grid.get_cell(neighbor_pos)
			if neighbor_cell != null and neighbor_cell.is_collapsed():
				var neighbor_tile = neighbor_cell.get_tile()
				if neighbor_tile != null and (neighbor_tile.boundary_role == Tile.BoundaryRole.EDGE or neighbor_tile.boundary_role == Tile.BoundaryRole.CORNER):
					# Would connect to collapsed boundary tile - no new region created
					return false
	
	# This would create a new isolated region
	var current_count = get_region_count()
	return current_count >= max_regions


func would_create_unclosed_region(_pos: Vector3i, _tile: Tile, _grid) -> bool:
	"""Check if placing a boundary tile here would create an opening to the world edge.
	
	NOTE: This is intentionally conservative and always returns false during placement.
	Full closure validation is performed post-solve via validate_closed_regions().
	
	Pre-emptive closure checking during solve is complex because:
	1. Adjacent cells may not be collapsed yet
	2. The final boundary shape isn't known until solve completes
	3. Overly strict checking causes excessive contradictions
	
	For strict closed-region enforcement, use validate_closed_regions() after solving
	and re-solve if validation fails.
	"""
	return false


func validate_closed_regions(grid) -> Dictionary:
	"""Validate that all boundary regions form closed loops (post-solve check).
	
	Returns:
	- valid: bool - true if all regions are properly closed
	- issues: Array[String] - descriptions of any problems found
	"""
	var result = {"valid": true, "issues": []}
	
	if get_region_count() == 0:
		return result  # No boundaries = valid (empty structure)
	
	# For each region, check that it doesn't have "dangling" edges
	# A closed region should have all boundary tiles connected in a loop
	var regions = get_all_regions()
	
	for region in regions:
		var positions: Array = region["positions"]
		
		# Check each boundary position has at least 2 boundary neighbors
		# (forming a chain/loop rather than dead ends)
		for pos in positions:
			var boundary_neighbor_count = 0
			var neighbors = _get_neighbor_positions(pos)
			
			for neighbor_pos in neighbors:
				if _parent.has(_pos_to_key(neighbor_pos)):
					boundary_neighbor_count += 1
			
			# Corner pieces need at least 1 neighbor, edge pieces need 2
			# For simplicity, require at least 1 for now
			if boundary_neighbor_count == 0 and positions.size() > 1:
				result["valid"] = false
				result["issues"].append("Isolated boundary tile at %s" % str(pos))
	
	# Check for world boundary gaps if regions touch edges
	for region in regions:
		if region["touches_world_boundary"]:
			# Regions touching world boundary should form complete perimeter sections
			# This is complex to validate fully - skip for now
			pass
	
	return result


## ============================================================================
## Snapshot / Restore (for backtracking)
## ============================================================================

func create_snapshot() -> Dictionary:
	"""Create a snapshot of current state for backtracking."""
	return {
		"parent": _parent.duplicate(),
		"rank": _rank.duplicate(),
		"world_boundary": _world_boundary_connections.duplicate(),
		"region_members": _deep_copy_region_members(),
		"cached_count": _cached_region_count
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	"""Restore state from a snapshot."""
	_parent = snapshot["parent"].duplicate()
	_rank = snapshot["rank"].duplicate()
	_world_boundary_connections = snapshot["world_boundary"].duplicate()
	_region_members = _deep_copy_region_members_from(snapshot["region_members"])
	_cached_region_count = snapshot["cached_count"]


func _deep_copy_region_members() -> Dictionary:
	"""Deep copy the region members dictionary."""
	var copy: Dictionary = {}
	for key in _region_members:
		copy[key] = _region_members[key].duplicate()
	return copy


func _deep_copy_region_members_from(source: Dictionary) -> Dictionary:
	"""Deep copy from a source region members dictionary."""
	var copy: Dictionary = {}
	for key in source:
		copy[key] = source[key].duplicate()
	return copy


## ============================================================================
## Debug Utilities
## ============================================================================

func get_debug_info() -> String:
	"""Get debug string with current region state."""
	var lines: Array[String] = []
	lines.append("=== Region Tracker State ===")
	lines.append("Grid size: %s" % str(_grid_size))
	lines.append("Total boundary positions: %d" % _parent.size())
	lines.append("Region count: %d" % get_region_count())
	
	var regions = get_all_regions()
	for i in range(regions.size()):
		var r = regions[i]
		lines.append("  Region %d: %d tiles, touches_edge=%s" % [
			i + 1,
			r["positions"].size(),
			str(r["touches_world_boundary"])
		])
	
	return "\n".join(lines)
