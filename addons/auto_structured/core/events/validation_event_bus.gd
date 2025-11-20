@tool
class_name ValidationEventBus extends RefCounted

## Real-time validation event system with severity levels.
##
## Provides centralized validation feedback for tiles, sockets, libraries, and requirements.
## Components can subscribe to validation events to display errors/warnings in real-time.
##
## Usage:
##   var bus = ValidationEventBus.new()
##   bus.validation_error.connect(_on_error)
##   bus.emit_error("Tile has no sockets", tile)

const ValidationResult = preload("res://addons/auto_structured/core/validation/validation_result.gd")

## Validation severity levels
enum Severity {
	ERROR,   ## Critical issue that blocks functionality
	WARNING, ## Non-critical issue that should be addressed
	INFO     ## Informational message (e.g., suggestions)
}

## Validation context types
enum Context {
	TILE,        ## Tile validation
	SOCKET,      ## Socket validation
	LIBRARY,     ## Library-wide validation
	REQUIREMENT, ## Requirement validation
	GENERATION,  ## WFC generation validation
	IMPORT       ## Import/export validation
}

## Emitted when a validation error occurs
## Parameters: message (String), context (Context), severity (Severity), source (Variant), details (Dictionary)
signal validation_error(message: String, context: int, severity: int, source: Variant, details: Dictionary)

## Emitted when a validation warning occurs
signal validation_warning(message: String, context: int, source: Variant, details: Dictionary)

## Emitted when a validation info message occurs
signal validation_info(message: String, context: int, source: Variant, details: Dictionary)

## Emitted when validation starts for a batch operation
signal validation_started(context: int, item_count: int)

## Emitted when validation completes for a batch operation
## Parameters: context (Context), total_errors (int), total_warnings (int), total_info (int)
signal validation_completed(context: int, total_errors: int, total_warnings: int, total_info: int)

## Emitted when validation is cleared/reset
signal validation_cleared(context: int)

## Statistics for current validation session
var error_count: int = 0
var warning_count: int = 0
var info_count: int = 0

## History of validation events (optional, can be disabled for performance)
var enable_history: bool = false
var validation_history: Array[Dictionary] = []
var max_history_size: int = 100


## Emit a validation error
func emit_error(message: String, source: Variant = null, context: int = Context.TILE, details: Dictionary = {}) -> void:
	error_count += 1
	_add_to_history(message, context, Severity.ERROR, source, details)
	validation_error.emit(message, context, Severity.ERROR, source, details)


## Emit a validation warning
func emit_warning(message: String, source: Variant = null, context: int = Context.TILE, details: Dictionary = {}) -> void:
	warning_count += 1
	_add_to_history(message, context, Severity.WARNING, source, details)
	validation_warning.emit(message, context, source, details)


## Emit a validation info message
func emit_info(message: String, source: Variant = null, context: int = Context.TILE, details: Dictionary = {}) -> void:
	info_count += 1
	_add_to_history(message, context, Severity.INFO, source, details)
	validation_info.emit(message, context, source, details)


## Emit a validation result from the validation system
func emit_validation_result(result: ValidationResult, context: int = Context.TILE) -> void:
	if result == null:
		return
	
	var severity = Severity.ERROR
	if result.is_warning():
		severity = Severity.WARNING
	elif result.is_info():
		severity = Severity.INFO
	
	var details = result.metadata.duplicate() if result.metadata else {}
	
	match severity:
		Severity.ERROR:
			emit_error(result.message, result.source, context, details)
		Severity.WARNING:
			emit_warning(result.message, result.source, context, details)
		Severity.INFO:
			emit_info(result.message, result.source, context, details)


## Emit multiple validation results (e.g., from a validator)
func emit_validation_results(results: Array, context: int = Context.TILE) -> void:
	for result in results:
		if result is ValidationResult:
			emit_validation_result(result, context)


## Start a validation batch
func start_validation(context: int = Context.TILE, item_count: int = 0) -> void:
	_reset_counts()
	validation_started.emit(context, item_count)


## Complete a validation batch
func complete_validation(context: int = Context.TILE) -> void:
	validation_completed.emit(context, error_count, warning_count, info_count)


## Clear validation state for a context
func clear_validation(context: int = Context.TILE) -> void:
	_reset_counts()
	if enable_history:
		validation_history.clear()
	validation_cleared.emit(context)


## Get validation statistics
func get_stats() -> Dictionary:
	return {
		"errors": error_count,
		"warnings": warning_count,
		"info": info_count,
		"total": error_count + warning_count + info_count,
		"has_errors": error_count > 0,
		"has_warnings": warning_count > 0,
		"has_info": info_count > 0
	}


## Check if there are any errors
func has_errors() -> bool:
	return error_count > 0


## Check if there are any warnings
func has_warnings() -> bool:
	return warning_count > 0


## Check if validation passed (no errors)
func is_valid() -> bool:
	return error_count == 0


## Get validation history (if enabled)
func get_history() -> Array[Dictionary]:
	return validation_history.duplicate()


## Clear validation history
func clear_history() -> void:
	validation_history.clear()


## Reset all counts
func _reset_counts() -> void:
	error_count = 0
	warning_count = 0
	info_count = 0


## Add entry to history (if enabled)
func _add_to_history(message: String, context: int, severity: int, source: Variant, details: Dictionary) -> void:
	if not enable_history:
		return
	
	var entry = {
		"timestamp": Time.get_ticks_msec(),
		"message": message,
		"context": context,
		"severity": severity,
		"source": source,
		"details": details
	}
	
	validation_history.append(entry)
	
	# Limit history size
	if validation_history.size() > max_history_size:
		validation_history.pop_front()


## Get human-readable severity name
static func get_severity_name(severity: int) -> String:
	match severity:
		Severity.ERROR:
			return "Error"
		Severity.WARNING:
			return "Warning"
		Severity.INFO:
			return "Info"
		_:
			return "Unknown"


## Get human-readable context name
static func get_context_name(context: int) -> String:
	match context:
		Context.TILE:
			return "Tile"
		Context.SOCKET:
			return "Socket"
		Context.LIBRARY:
			return "Library"
		Context.REQUIREMENT:
			return "Requirement"
		Context.GENERATION:
			return "Generation"
		Context.IMPORT:
			return "Import"
		_:
			return "Unknown"
