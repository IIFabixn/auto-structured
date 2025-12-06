@tool
class_name WallContinuityConstraint extends "res://addons/auto_structured/core/constraints/structural_constraint.gd"
## Ensures walls form continuous connected segments.
##
## Validates that:
## - Wall tiles connect to other walls or corners on at least 2 sides
## - Isolated wall segments are prevented
## - Wall loops are properly closed
##
## This prevents disconnected or floating wall pieces.

## Minimum number of wall connections required (default: 2 for continuity)
var min_connections: int = 2

## Whether corner tiles count as valid connections
var corners_count_as_walls: bool = true

## Whether door tiles break continuity (false = doors count as connections)
var doors_break_continuity: bool = false

func _init():
	constraint_name = "WallContinuity"

func validate_cell(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> bool:
	if not enabled or cell == null or grid == null:
		return true
	
	# Only validate cells that contain wall tiles
	var has_wall := false
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _is_wall(tile):
			has_wall = true
			break
	
	if not has_wall:
		return true  # Not a wall, constraint doesn't apply
	
	# Count valid wall connections in horizontal directions
	var connections := 0
	for neighbor_pos in _get_horizontal_neighbors(cell.position):
		if not grid.is_valid_position(neighbor_pos):
			continue
		
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null or neighbor_cell.has_contradiction():
			continue
		
		# Check if neighbor could be a wall
		var neighbor_could_be_wall := false
		for variant in neighbor_cell.possible_tile_variants:
			var tile: Tile = variant.get("tile")
			if tile == null:
				continue
			
			if _is_wall(tile):
				neighbor_could_be_wall = true
				break
			
			if corners_count_as_walls and _is_corner(tile):
				neighbor_could_be_wall = true
				break
			
			if not doors_break_continuity and _is_door(tile):
				neighbor_could_be_wall = true
				break
		
		if neighbor_could_be_wall:
			connections += 1
	
	# Wall must have at least min_connections to other walls
	return connections >= min_connections

func get_violation_reason(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> String:
	if cell == null:
		return "Null cell"
	
	var connections := 0
	for neighbor_pos in _get_horizontal_neighbors(cell.position):
		if not grid.is_valid_position(neighbor_pos):
			continue
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null:
			continue
		for variant in neighbor_cell.possible_tile_variants:
			var tile: Tile = variant.get("tile")
			if tile and (_is_wall(tile) or (corners_count_as_walls and _is_corner(tile))):
				connections += 1
				break
	
	return "Wall at %s has only %d connections (needs %d)" % [cell.position, connections, min_connections]
