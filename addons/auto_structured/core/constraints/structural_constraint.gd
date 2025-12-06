@tool
class_name StructuralConstraint extends RefCounted
## Base class for structural constraints that ensure architectural validity.
##
## Structural constraints validate that tiles form coherent structures:
## - Walls form closed loops
## - Doors have proper support
## - Floors have load-bearing support below
## - Multi-story buildings have proper vertical alignment
##
## Unlike requirements which filter individual tiles, constraints validate
## relationships between multiple tiles and overall structural integrity.

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")

## Constraint name for debugging
var constraint_name: String = "StructuralConstraint"

## Whether this constraint is enabled
var enabled: bool = true

## ============================================================================
## Abstract Methods - Subclasses MUST implement
## ============================================================================

func validate_cell(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> bool:
	"""
	Validate a single cell against this constraint.
	
	Args:
		cell: The cell to validate
		grid: The full grid for neighbor access
		context: Additional context data
	
	Returns:
		true if valid, false if constraint violated
	"""
	push_error("StructuralConstraint.validate_cell() must be implemented by subclass")
	return true

func get_violation_reason(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> String:
	"""
	Return human-readable explanation of why constraint was violated.
	Used for debugging and visualization.
	"""
	return "Unknown constraint violation"

## ============================================================================
## Helper Methods
## ============================================================================

func _is_wall(tile: Tile) -> bool:
	"""Check if a tile is any type of wall."""
	if tile == null:
		return false
	return tile.structural_role in [
		Tile.StructuralRole.EXTERIOR_WALL,
		Tile.StructuralRole.INTERIOR_WALL,
		Tile.StructuralRole.LOAD_BEARING_WALL,
		Tile.StructuralRole.PARTITION_WALL,
	] or tile.boundary_role == Tile.BoundaryRole.EDGE

func _is_corner(tile: Tile) -> bool:
	"""Check if a tile is a corner piece."""
	if tile == null:
		return false
	return tile.structural_role in [
		Tile.StructuralRole.CORNER_EXTERIOR,
		Tile.StructuralRole.CORNER_INTERIOR,
	] or tile.boundary_role == Tile.BoundaryRole.CORNER

func _is_door(tile: Tile) -> bool:
	"""Check if a tile is a door or passage."""
	if tile == null:
		return false
	return tile.structural_role == Tile.StructuralRole.DOOR_FRAME or \
		tile.boundary_role == Tile.BoundaryRole.PASSAGE

func _is_floor(tile: Tile) -> bool:
	"""Check if a tile is a floor surface."""
	if tile == null:
		return false
	return tile.structural_role in [
		Tile.StructuralRole.GROUND_FLOOR,
		Tile.StructuralRole.UPPER_FLOOR,
	]

func _get_horizontal_neighbors(position: Vector3i) -> Array[Vector3i]:
	"""Get the 4 horizontal neighbor positions (X and Z axes)."""
	return [
		position + Vector3i(1, 0, 0),   # East
		position + Vector3i(-1, 0, 0),  # West
		position + Vector3i(0, 0, 1),   # South
		position + Vector3i(0, 0, -1),  # North
	]

func _get_vertical_neighbors(position: Vector3i) -> Array[Vector3i]:
	"""Get the 2 vertical neighbor positions (Y axis)."""
	return [
		position + Vector3i(0, 1, 0),   # Up
		position + Vector3i(0, -1, 0),  # Down
	]

func _get_all_neighbors(position: Vector3i) -> Array[Vector3i]:
	"""Get all 6 cardinal neighbor positions."""
	var neighbors: Array[Vector3i] = []
	neighbors.append_array(_get_horizontal_neighbors(position))
	neighbors.append_array(_get_vertical_neighbors(position))
	return neighbors
