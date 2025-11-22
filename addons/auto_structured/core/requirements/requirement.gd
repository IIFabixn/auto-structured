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
	var class_name_str := get_class()
	class_name_str = class_name_str.strip_edges()
	if class_name_str == "Resource" or class_name_str == "Requirement":
		class_name_str = ""
	if class_name_str.ends_with("Requirement"):
		class_name_str = class_name_str.substr(0, class_name_str.length() - "Requirement".length())
	if class_name_str.is_empty():
		var script := get_script()
		if script:
			var script_path: String = script.resource_path
			if not script_path.is_empty():
				class_name_str = script_path.get_file().get_basename()
	if class_name_str.is_empty():
		class_name_str = "Requirement"

	# Convert identifier-style names into Title Case
	var cleaned := class_name_str.replace("_", " ").replace("-", " ")
	var result := ""
	for i in range(cleaned.length()):
		var c := cleaned.substr(i, 1)
		if i > 0:
			var prev := cleaned.substr(i - 1, 1)
			if c != " " and prev != " " and c == c.to_upper() and prev == prev.to_lower():
				result += " "
		result += c
	result = result.strip_edges()
	if result.is_empty():
		result = "Requirement"
	var words := result.split(" ", false)
	for i in range(words.size()):
		var word: String = words[i]
		if not word.is_empty():
			words[i] = word.substr(0, 1).to_upper() + word.substr(1).to_lower()
	if words.is_empty():
		return "Requirement"
	return " ".join(words)

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
