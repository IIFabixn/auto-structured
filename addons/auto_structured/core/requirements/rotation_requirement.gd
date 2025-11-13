@tool
class_name RotationRequirement extends Requirement
## Requires the neighboring tile to be rotated by at least a minimum angle.
## Useful for corner pieces that should only connect when properly rotated.

## Minimum rotation required (in degrees, Y-axis only)
## 0 = any rotation allowed
## 90 = must be rotated at least 90°
## 180 = must be rotated 180° or more
@export_range(0, 180, 90) var minimum_rotation_degrees: int = 90

func evaluate(_cell_position: Vector3i, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	# Get the rotation angle of the neighboring tile from context
	# Context should contain "rotation_degrees" key set by the WFC algorithm
	var rotation_degrees = context.get("rotation_degrees", 0)
	
	# Normalize to 0-180 range (since Y-axis rotations are symmetrical)
	var normalized_rotation = abs(rotation_degrees)
	if normalized_rotation > 180:
		normalized_rotation = 360 - normalized_rotation
	
	# Round to nearest 90° increment for comparison
	var rounded_rotation = round(normalized_rotation / 90.0) * 90.0
	
	# Check if rotation meets minimum requirement
	return rounded_rotation >= minimum_rotation_degrees
