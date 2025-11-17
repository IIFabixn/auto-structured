@tool
class_name ValidationResult extends RefCounted

## Represents a single validation message with severity level.

enum Severity {
	INFO,    ## Informational message
	WARNING, ## Potential issue that should be reviewed
	ERROR    ## Critical issue that will cause problems
}

## The severity level of this validation result
var severity: Severity

## Human-readable message describing the validation result
var message: String

## Optional context (e.g., tile name, requirement index, socket direction)
var context: Dictionary = {}

## Optional reference to the object that caused the validation issue
var source_object: Variant = null

func _init(p_severity: Severity, p_message: String, p_context: Dictionary = {}, p_source: Variant = null) -> void:
	severity = p_severity
	message = p_message
	context = p_context
	source_object = p_source

func is_error() -> bool:
	return severity == Severity.ERROR

func is_warning() -> bool:
	return severity == Severity.WARNING

func is_info() -> bool:
	return severity == Severity.INFO

func get_severity_string() -> String:
	match severity:
		Severity.ERROR:
			return "ERROR"
		Severity.WARNING:
			return "WARNING"
		Severity.INFO:
			return "INFO"
	return "UNKNOWN"

func to_string() -> String:
	var result = "[%s] %s" % [get_severity_string(), message]
	if not context.is_empty():
		result += " (%s)" % _format_context()
	return result

func _format_context() -> String:
	var parts: Array[String] = []
	for key in context.keys():
		parts.append("%s: %s" % [key, str(context[key])])
	return ", ".join(parts)
