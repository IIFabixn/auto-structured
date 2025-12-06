@tool
class_name DoorPlacementConstraint extends "res://addons/auto_structured/core/constraints/structural_constraint.gd"
## Ensures doors are placed in valid wall segments with proper support.
##
## Validates that:
## - Doors only appear in walls (not floating in air)
## - Doors have walls on their sides for structural support
## - Doors don't appear in corners (unless explicitly allowed)
## - Door openings are properly framed
##
## This prevents doors from appearing in invalid locations.

## Whether doors can appear in corner positions
var allow_corner_doors: bool = false

## Minimum number of adjacent walls required to support a door
var min_adjacent_walls: int = 2

## Whether to check that door has floor below (if multi-story)
var require_floor_below: bool = true

func _init():
	constraint_name = "DoorPlacement"

func validate_cell(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> bool:
	if not enabled or cell == null or grid == null:
		return true
	
	# Only validate cells that could contain doors
	var has_door := false
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and _is_door(tile):
			has_door = true
			break
	
	if not has_door:
		return true  # Not a door, constraint doesn't apply
	
	# Check adjacent walls
	var adjacent_walls := 0
	var horizontal_neighbors = _get_horizontal_neighbors(cell.position)
	
	for neighbor_pos in horizontal_neighbors:
		if not grid.is_valid_position(neighbor_pos):
			continue
		
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null or neighbor_cell.has_contradiction():
			continue
		
		# Check if neighbor is or could be a wall
		for variant in neighbor_cell.possible_tile_variants:
			var tile: Tile = variant.get("tile")
			if tile and (_is_wall(tile) or _is_corner(tile)):
				adjacent_walls += 1
				break
	
	# Door needs sufficient wall support
	if adjacent_walls < min_adjacent_walls:
		return false
	
	# Check for corner placement
	if not allow_corner_doors:
		var corner_count := 0
		for neighbor_pos in horizontal_neighbors:
			if not grid.is_valid_position(neighbor_pos):
				continue
			var neighbor_cell = grid.get_cell(neighbor_pos)
			if neighbor_cell == null:
				continue
			for variant in neighbor_cell.possible_tile_variants:
				var tile: Tile = variant.get("tile")
				if tile and _is_corner(tile):
					corner_count += 1
					break
		
		# If surrounded by corners, likely in corner position
		if corner_count >= 2:
			return false
	
	# Check for floor support below (for ground-level doors)
	if require_floor_below and cell.position.y > 0:
		var below_pos = cell.position + Vector3i(0, -1, 0)
		if grid.is_valid_position(below_pos):
			var below_cell = grid.get_cell(below_pos)
			if below_cell != null and not below_cell.has_contradiction():
				var has_support := false
				for variant in below_cell.possible_tile_variants:
					var tile: Tile = variant.get("tile")
					if tile and (_is_floor(tile) or tile.can_support_above):
						has_support = true
						break
				
				if not has_support:
					return false
	
	return true

func get_violation_reason(cell: WfcCell, grid: WfcGrid, context: Dictionary = {}) -> String:
	if cell == null:
		return "Null cell"
	
	var adjacent_walls := 0
	for neighbor_pos in _get_horizontal_neighbors(cell.position):
		if not grid.is_valid_position(neighbor_pos):
			continue
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null:
			continue
		for variant in neighbor_cell.possible_tile_variants:
			var tile: Tile = variant.get("tile")
			if tile and (_is_wall(tile) or _is_corner(tile)):
				adjacent_walls += 1
				break
	
	if adjacent_walls < min_adjacent_walls:
		return "Door at %s has only %d adjacent walls (needs %d)" % [cell.position, adjacent_walls, min_adjacent_walls]
	
	if require_floor_below and cell.position.y > 0:
		var below_pos = cell.position + Vector3i(0, -1, 0)
		if grid.is_valid_position(below_pos):
			var below_cell = grid.get_cell(below_pos)
			if below_cell != null:
				var has_support := false
				for variant in below_cell.possible_tile_variants:
					var tile: Tile = variant.get("tile")
					if tile and (_is_floor(tile) or tile.can_support_above):
						has_support = true
						break
				if not has_support:
					return "Door at %s has no floor support below" % cell.position
	
	return "Door at %s in invalid position" % cell.position
