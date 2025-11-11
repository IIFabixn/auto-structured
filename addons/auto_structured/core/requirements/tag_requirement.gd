@tool
class_name TagRequirement extends Requirement
## Requires or excludes modules with specific tags

@export var required_tag: String = ""
@export var exclude_mode: bool = false  ## If true, excludes modules with this tag

func evaluate(_cell_position: Vector3i, context: Dictionary) -> bool:
	if not enabled:
		return true

	var tags = context.get("tags", [])
	var has_tag = tags.has(required_tag)

	if exclude_mode:
		return not has_tag
	return has_tag
