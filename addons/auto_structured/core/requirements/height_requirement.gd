class_name HeightRequirement extends Requirement
## Constrains module placement based on vertical position in the grid

@export var min_height: int = 0
@export var max_height: int = 999

func evaluate(cell_position: Vector3i, _context: Dictionary) -> bool:
	if not enabled:
		return true
	return cell_position.y >= min_height and cell_position.y <= max_height
