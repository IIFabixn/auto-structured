class_name PositionRequirement extends Requirement
## Forces a specific module at a specific position

@export var target_position: Vector3i = Vector3i.ZERO
@export var module_id: String = ""

func evaluate(cell_position: Vector3i, context: Dictionary) -> bool:
	if not enabled:
		return true

	# Only apply constraint at the target position
	if cell_position != target_position:
		return true

	# Check if the module being considered matches the required module
	var module = context.get("module")
	if module == null:
		return false

	# Assuming module has an 'id' property
	return module.get("id", "") == module_id
