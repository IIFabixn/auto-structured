@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name HeightRequirement

## Restricts tile placement based on Y coordinate (height).
## Useful for tiles that should only appear at ground level, upper floors, etc.

enum HeightMode {
	EXACT,           ## Tile must be at exactly the specified height
	MIN,             ## Tile must be at or above the specified height
	MAX,             ## Tile must be at or below the specified height
	RANGE            ## Tile must be within the specified range (inclusive)
}

@export var mode: HeightMode = HeightMode.MIN
@export var height_value: int = 0  ## For EXACT, MIN, or MAX modes
@export var min_height: int = 0    ## For RANGE mode
@export var max_height: int = 10   ## For RANGE mode

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	var y = position.y
	
	match mode:
		HeightMode.EXACT:
			return y == height_value
		HeightMode.MIN:
			return y >= height_value
		HeightMode.MAX:
			return y <= height_value
		HeightMode.RANGE:
			return y >= min_height and y <= max_height
	
	return true

func get_failure_reason() -> String:
	match mode:
		HeightMode.EXACT:
			return "Tile must be at height Y=%d" % height_value
		HeightMode.MIN:
			return "Tile must be at or above Y=%d" % height_value
		HeightMode.MAX:
			return "Tile must be at or below Y=%d" % height_value
		HeightMode.RANGE:
			return "Tile must be between Y=%d and Y=%d" % [min_height, max_height]
	return super.get_failure_reason()

func get_description() -> String:
	match mode:
		HeightMode.EXACT:
			return "Only at Y=%d" % height_value
		HeightMode.MIN:
			return "Y >= %d" % height_value
		HeightMode.MAX:
			return "Y <= %d" % height_value
		HeightMode.RANGE:
			return "Y between %d and %d" % [min_height, max_height]
	return super.get_description()
