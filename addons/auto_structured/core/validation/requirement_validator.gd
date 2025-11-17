@tool
extends "res://addons/auto_structured/core/validation/validator.gd"
class_name RequirementValidator

## Validates Requirements for configuration issues.

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
const MaxCountRequirement = preload("res://addons/auto_structured/core/requirements/max_count_requirement.gd")
const AdjacentRequirement = preload("res://addons/auto_structured/core/requirements/adjacent_requirement.gd")
const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
const BoundaryRequirement = preload("res://addons/auto_structured/core/requirements/boundary_requirement.gd")

func validate(target: Variant) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if not target is Requirement:
		results.append(create_error("Target is not a Requirement", {"type": str(typeof(target))}))
		return results
	
	var requirement: Requirement = target as Requirement
	
	# Validate specific requirement types
	if requirement is HeightRequirement:
		_validate_height_requirement(requirement, results)
	elif requirement is MaxCountRequirement:
		_validate_max_count_requirement(requirement, results)
	elif requirement is AdjacentRequirement:
		_validate_adjacent_requirement(requirement, results)
	elif requirement is TagRequirement:
		_validate_tag_requirement(requirement, results)
	elif requirement is BoundaryRequirement:
		_validate_boundary_requirement(requirement, results)
	
	return results

func _validate_height_requirement(req: HeightRequirement, results: Array[ValidationResult]) -> void:
	match req.mode:
		HeightRequirement.HeightMode.EXACT:
			if req.height_value < 0:
				results.append(create_error("Height value cannot be negative", {"height": req.height_value}, req))
		
		HeightRequirement.HeightMode.MIN:
			if req.height_value < 0:
				results.append(create_error("Minimum height cannot be negative", {"height": req.height_value}, req))
		
		HeightRequirement.HeightMode.MAX:
			if req.height_value < 0:
				results.append(create_error("Maximum height cannot be negative", {"height": req.height_value}, req))
		
		HeightRequirement.HeightMode.RANGE:
			if req.min_height < 0:
				results.append(create_error("Minimum height cannot be negative", {"min_height": req.min_height}, req))
			
			if req.max_height < 0:
				results.append(create_error("Maximum height cannot be negative", {"max_height": req.max_height}, req))
			
			if req.min_height > req.max_height:
				results.append(create_error("Minimum height (%d) is greater than maximum height (%d)" % [req.min_height, req.max_height], {"min": req.min_height, "max": req.max_height}, req))
			
			if req.min_height == req.max_height:
				results.append(create_info("Height range has same min and max - consider using EXACT mode instead", {"height": req.min_height}, req))

func _validate_max_count_requirement(req: MaxCountRequirement, results: Array[ValidationResult]) -> void:
	if req.max_count <= 0:
		results.append(create_error("Max count must be positive", {"max_count": req.max_count}, req))
	elif req.max_count == 1:
		results.append(create_info("Max count is 1 - tile will be unique", {}, req))
	elif req.max_count > 1000:
		results.append(create_warning("Max count is very high (%d) - may not be restrictive enough" % req.max_count, {"max_count": req.max_count}, req))

func _validate_adjacent_requirement(req: AdjacentRequirement, results: Array[ValidationResult]) -> void:
	if req.required_tags.is_empty():
		results.append(create_error("Adjacent requirement has no required tags", {}, req))
		return
	
	# Check for duplicate tags
	var seen_tags: Dictionary = {}
	for tag in req.required_tags:
		if tag in seen_tags:
			results.append(create_warning("Duplicate required tag: %s" % tag, {"tag": tag}, req))
		seen_tags[tag] = true
	
	# Check connectivity options
	if not req.check_horizontal and not req.check_vertical:
		results.append(create_error("Adjacent requirement checks neither horizontal nor vertical - will never match", {}, req))
	
	# Validate exact count mode
	if req.mode == AdjacentRequirement.AdjacentMode.EXACT_COUNT:
		if req.exact_count < 0:
			results.append(create_error("Exact count cannot be negative", {"exact_count": req.exact_count}, req))
		elif req.exact_count == 0:
			results.append(create_warning("Exact count is 0 - equivalent to MUST_NOT_HAVE mode", {}, req))
		elif req.exact_count > 26:
			results.append(create_warning("Exact count is very high (%d) - may be impossible to satisfy" % req.exact_count, {"exact_count": req.exact_count}, req))

func _validate_tag_requirement(req: TagRequirement, results: Array[ValidationResult]) -> void:
	if req.required_tags.is_empty():
		results.append(create_error("Tag requirement has no required tags", {}, req))
		return
	
	# Check for duplicate tags
	var seen_tags: Dictionary = {}
	for tag in req.required_tags:
		if tag in seen_tags:
			results.append(create_warning("Duplicate required tag: %s" % tag, {"tag": tag}, req))
		seen_tags[tag] = true
	
	# Mode-specific validation
	if req.mode == TagRequirement.TagMode.HAS_ALL and req.required_tags.size() > 10:
		results.append(create_info("Requirement needs all %d tags - may be overly restrictive" % req.required_tags.size(), {}, req))

func _validate_boundary_requirement(req: BoundaryRequirement, results: Array[ValidationResult]) -> void:
	if not req.check_x_boundaries and not req.check_y_boundaries and not req.check_z_boundaries:
		results.append(create_error("Boundary requirement checks no axes - will always pass", {}, req))
	
	# Mode-specific validation
	match req.mode:
		BoundaryRequirement.BoundaryMode.CORNER_ONLY:
			var axis_count = 0
			if req.check_x_boundaries:
				axis_count += 1
			if req.check_y_boundaries:
				axis_count += 1
			if req.check_z_boundaries:
				axis_count += 1
			
			if axis_count < 2:
				results.append(create_warning("CORNER_ONLY mode with less than 2 axes checked - may not work as expected", {"axes_checked": axis_count}, req))
