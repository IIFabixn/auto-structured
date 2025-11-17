@tool
class_name Validator extends RefCounted

## Base class for all validators in the Auto-Structured plugin.
## Validators check for issues in tiles, libraries, requirements, etc.

const ValidationResult = preload("res://addons/auto_structured/core/validation/validation_result.gd")

## Override this method to implement validation logic.
## Returns an array of ValidationResult objects.
func validate(target: Variant) -> Array[ValidationResult]:
	push_error("Validator.validate() must be overridden in subclass: " + get_class())
	var empty: Array[ValidationResult] = []
	return empty

## Helper method to create an error result
func create_error(message: String, context: Dictionary = {}, source: Variant = null) -> ValidationResult:
	return ValidationResult.new(ValidationResult.Severity.ERROR, message, context, source)

## Helper method to create a warning result
func create_warning(message: String, context: Dictionary = {}, source: Variant = null) -> ValidationResult:
	return ValidationResult.new(ValidationResult.Severity.WARNING, message, context, source)

## Helper method to create an info result
func create_info(message: String, context: Dictionary = {}, source: Variant = null) -> ValidationResult:
	return ValidationResult.new(ValidationResult.Severity.INFO, message, context, source)
