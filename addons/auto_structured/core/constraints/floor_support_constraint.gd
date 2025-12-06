@tool
class_name FloorSupportConstraint extends "res://addons/auto_structured/core/constraints/structural_constraint.gd"
## Ensures floors have proper structural support below them.
##
## Validates that:
## - Ground floors rest on foundation or ground surface
## - Upper floors have load-bearing support below
## - Floating floors are prevented
## - Multi-story buildings maintain vertical alignment
##
## This prevents unsupported or floating floor segments.

## Whether to enforce support for ground-level floors (y=0)
var require_ground_support: bool = false

## Whether upper floors must have support directly below
var require_vertical_support: bool = true

## Tiles that count as valid support (walls, columns, other floors)
var valid_support_roles: Array[Tile.StructuralRole] = [
	Tile.StructuralRole.LOAD_BEARING_WALL,
	Tile.StructuralRole.EXTERIOR_WALL,
	Tile.StructuralRole.INTERIOR_WALL,
	Tile.StructuralRole.GROUND_FLOOR,
	Tile.StructuralRole.UPPER_FLOOR,
	Tile.StructuralRole.FOUNDATION,
]

func _init():
	constraint_name = "FloorSupport"

func validate_cell(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> bool:
	if not enabled or cell == null or grid == null:
		return true
	
	# Only validate cells that contain floor tiles requiring support
	var has_floor_needing_support := false
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _is_floor(tile) and tile.requires_support_below:
			has_floor_needing_support = true
			break
	
	if not has_floor_needing_support:
		return true  # No floor requiring support
	
	# Ground level (y=0) may not need support depending on config
	if cell.position.y == 0 and not require_ground_support:
		return true
	
	# Check if there's support below
	if not require_vertical_support:
		return true
	
	var below_pos = cell.position + Vector3i(0, -1, 0)
	
	# If at grid bottom, no support needed
	if not grid.is_valid_position(below_pos):
		return true
	
	var below_cell = grid.get_cell(below_pos)
	if below_cell == null or below_cell.has_contradiction():
		return false  # No cell below = no support
	
	# Check if cell below can provide support
	var has_support := false
	for variant in below_cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		
		# Check if tile can support weight above
		if tile.can_support_above:
			has_support = true
			break
		
		# Check if tile has valid support role
		if tile.structural_role in valid_support_roles:
			has_support = true
			break
	
	return has_support

func get_violation_reason(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> String:
	if cell == null:
		return "Null cell"
	
	var below_pos = cell.position + Vector3i(0, -1, 0)
	
	if not grid.is_valid_position(below_pos):
		return "Floor at %s has no support below (grid boundary)" % cell.position
	
	var below_cell = grid.get_cell(below_pos)
	if below_cell == null:
		return "Floor at %s has null cell below" % cell.position
	
	if below_cell.has_contradiction():
		return "Floor at %s has contradicted cell below" % cell.position
	
	var support_tiles: Array[String] = []
	for variant in below_cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile:
			support_tiles.append(tile.name)
	
	return "Floor at %s has no valid support below. Below tiles: [%s]" % [cell.position, ", ".join(support_tiles)]
