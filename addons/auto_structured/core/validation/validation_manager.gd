@tool
class_name ValidationManager extends RefCounted

## Manages validation of tiles, libraries, and requirements.
## Aggregates results from multiple validators and provides filtering.

const ValidationResult = preload("res://addons/auto_structured/core/validation/validation_result.gd")
const TileValidator = preload("res://addons/auto_structured/core/validation/tile_validator.gd")
const LibraryValidator = preload("res://addons/auto_structured/core/validation/library_validator.gd")
const RequirementValidator = preload("res://addons/auto_structured/core/validation/requirement_validator.gd")

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

## All validation results from the last run
var all_results: Array[ValidationResult] = []

## Cached validators
var _tile_validator: TileValidator
var _library_validator: LibraryValidator
var _requirement_validator: RequirementValidator

func _init() -> void:
	_tile_validator = TileValidator.new()
	_library_validator = LibraryValidator.new()
	_requirement_validator = RequirementValidator.new()

## Validate a single target (Tile, ModuleLibrary, or Requirement)
func validate(target: Variant) -> Array[ValidationResult]:
	all_results.clear()
	
	if target is Tile:
		all_results = _tile_validator.validate(target)
	elif target is ModuleLibrary:
		all_results = _library_validator.validate(target)
	elif target is Requirement:
		all_results = _requirement_validator.validate(target)
	else:
		var error = ValidationResult.new(
			ValidationResult.Severity.ERROR,
			"Unknown target type for validation: %s" % str(typeof(target)),
			{"type": str(typeof(target))}
		)
		all_results.append(error)
	
	return all_results

## Validate a ModuleLibrary including all its tiles and their requirements
func validate_library_deep(library: ModuleLibrary) -> Array[ValidationResult]:
	all_results.clear()
	
	# Validate the library itself
	all_results.append_array(_library_validator.validate(library))
	
	# Validate each tile
	for tile in library.tiles:
		if tile == null:
			continue
		
		var tile_results = _tile_validator.validate(tile)
		all_results.append_array(tile_results)
		
		# Validate each requirement in the tile
		for req in tile.requirements:
			if req == null:
				continue
			
			var req_results = _requirement_validator.validate(req)
			all_results.append_array(req_results)
	
	return all_results

## Get only error results
func get_errors() -> Array[ValidationResult]:
	var errors: Array[ValidationResult] = []
	for result in all_results:
		if result.is_error():
			errors.append(result)
	return errors

## Get only warning results
func get_warnings() -> Array[ValidationResult]:
	var warnings: Array[ValidationResult] = []
	for result in all_results:
		if result.is_warning():
			warnings.append(result)
	return warnings

## Get only info results
func get_infos() -> Array[ValidationResult]:
	var infos: Array[ValidationResult] = []
	for result in all_results:
		if result.is_info():
			infos.append(result)
	return infos

## Get results filtered by minimum severity
func get_results_by_severity(min_severity: ValidationResult.Severity) -> Array[ValidationResult]:
	var filtered: Array[ValidationResult] = []
	for result in all_results:
		if result.severity >= min_severity:
			filtered.append(result)
	return filtered

## Check if validation passed (no errors)
func has_errors() -> bool:
	for result in all_results:
		if result.is_error():
			return true
	return false

## Check if validation has warnings
func has_warnings() -> bool:
	for result in all_results:
		if result.is_warning():
			return true
	return false

## Get a summary string of validation results
func get_summary() -> String:
	var error_count = 0
	var warning_count = 0
	var info_count = 0
	
	for result in all_results:
		if result.is_error():
			error_count += 1
		elif result.is_warning():
			warning_count += 1
		elif result.is_info():
			info_count += 1
	
	var parts: Array[String] = []
	if error_count > 0:
		parts.append("%d error(s)" % error_count)
	if warning_count > 0:
		parts.append("%d warning(s)" % warning_count)
	if info_count > 0:
		parts.append("%d info" % info_count)
	
	if parts.is_empty():
		return "Validation passed with no issues"
	
	return "Validation: " + ", ".join(parts)

## Print all validation results to console
func print_results() -> void:
	if all_results.is_empty():
		print("No validation results")
		return
	
	print("\n=== Validation Results ===")
	print(get_summary())
	print()
	
	var errors = get_errors()
	if not errors.is_empty():
		print("ERRORS:")
		for error in errors:
			print("  ", error.to_string())
		print()
	
	var warnings = get_warnings()
	if not warnings.is_empty():
		print("WARNINGS:")
		for warning in warnings:
			print("  ", warning.to_string())
		print()
	
	var infos = get_infos()
	if not infos.is_empty():
		print("INFO:")
		for info in infos:
			print("  ", info.to_string())
		print()
