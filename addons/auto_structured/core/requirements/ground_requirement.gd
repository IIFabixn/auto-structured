class_name GroundRequirement extends Requirement
## Requires module to be placed on the ground level (y = 0)

func evaluate(cell_position: Vector3i, _context: Dictionary) -> bool:
	if not enabled:
		return true
	return cell_position.y == 0
