@tool
class_name Requirement extends Resource

## Base class for tile placement requirements/constraints.
## Requirements are evaluated during WFC generation to determine if a tile can be placed at a specific position.

## Optional display name for UI (auto-generated from class name if empty)
@export var display_name: String = ""

## Whether this requirement is currently active
@export var enabled: bool = true

func _init() -> void:
	if display_name.is_empty():
		display_name = _generate_display_name()

func _generate_display_name() -> String:
	"""Generate a readable display name from the class name."""
	var class_name_str = get_class()
	if class_name_str.ends_with("Requirement"):
		class_name_str = class_name_str.substr(0, class_name_str.length() - "Requirement".length())
	
	# Convert PascalCase to Title Case
	var result = ""
	for i in range(class_name_str.length()):
		var c = class_name_str[i]
		if i > 0 and c == c.to_upper() and class_name_str[i-1] == class_name_str[i-1].to_lower():
			result += " "
		result += c
	
	return result

## Override this method to implement the requirement logic.
## Returns true if the tile can be placed at the given position, false otherwise.
func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	push_error("Requirement.evaluate() must be overridden in subclass: " + get_class())
	return true

## Override to provide a human-readable description of why the requirement failed.
## Called after evaluate() returns false for debugging/UI purposes.
func get_failure_reason() -> String:
	return "Requirement not satisfied"

## Override to provide a detailed description of what this requirement does.
func get_description() -> String:
	return "No description available"

func get_config_control() -> Control:
	"""
	Return a Control node for configuring this requirement's parameters in the UI.
	Override in subclasses to provide custom configuration UI.
	"""
	var label = Label.new()
	label.text = "No configuration available for " + display_name
	return label
