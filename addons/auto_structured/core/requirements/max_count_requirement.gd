@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name MaxCountRequirement

## Controls the number of times this tile can appear globally and per-region.
## Useful for controlling tile frequency, uniqueness, or mandatory features.

## Global constraints
@export_group("Global Limits")
@export var use_global_min: bool = false
@export_range(0, 1000) var global_min_count: int = 0
@export var use_global_max: bool = true
@export_range(1, 1000) var global_max_count: int = 1

## Per-region constraints
@export_group("Per-Region Limits")
@export var use_region_min: bool = false
@export_range(0, 100) var region_min_count: int = 1
@export var use_region_max: bool = false
@export_range(1, 100) var region_max_count: int = 10

## Enforcement mode for minimum constraints
@export_group("Enforcement")
@export var strict_min_enforcement: bool = true

## Internal counter tracked during generation (set by solver)
var _current_count: int = 0

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	var tile_id = str(tile.get_instance_id())
	
	# Check global max
	if use_global_max:
		var global_count_key = "tile_count_" + tile_id
		var global_current = context.get(global_count_key, 0)
		if global_current >= global_max_count:
			return false
	
	# Check region max
	if use_region_max:
		var region_id = _get_region_at_position(position, context)
		if region_id >= 0:
			var region_count_key = "tile_count_region_%d_%s" % [region_id, tile_id]
			var region_current = context.get(region_count_key, 0)
			if region_current >= region_max_count:
				return false
	
	return true

func validate_generation(grid, context: Dictionary) -> bool:
	"""Called after generation to verify minimum requirements were met."""
	if not enabled or not strict_min_enforcement:
		return true
	
	var tile_id = str(get_instance_id())
	
	# Check global minimum
	if use_global_min:
		var global_count_key = "tile_count_" + tile_id
		var global_current = context.get(global_count_key, 0)
		if global_current < global_min_count:
			push_warning("Global count %d is below minimum %d" % [global_current, global_min_count])
			return false
	
	# Check region minimums
	if use_region_min:
		var regions = context.get("regions", [])
		for region in regions:
			var region_id = region.get("id", -1)
			if region_id < 0:
				continue
			var region_count_key = "tile_count_region_%d_%s" % [region_id, tile_id]
			var region_current = context.get(region_count_key, 0)
			if region_current < region_min_count:
				push_warning("Region %d has %d instances, needs %d" % [region_id, region_current, region_min_count])
				return false
	
	return true

func get_priority_boost(tile: Tile, position: Vector3i, grid, context: Dictionary) -> float:
	"""Returns a priority boost to encourage placement when minimums aren't met."""
	if not enabled:
		return 0.0
	
	var boost = 0.0
	var tile_id = str(tile.get_instance_id())
	
	# Boost for global minimum
	if use_global_min:
		var global_count_key = "tile_count_" + tile_id
		var global_current = context.get(global_count_key, 0)
		if global_current < global_min_count:
			boost += 10.0 * (global_min_count - global_current)
	
	# Boost for region minimum
	if use_region_min:
		var region_id = _get_region_at_position(position, context)
		if region_id >= 0:
			var region_count_key = "tile_count_region_%d_%s" % [region_id, tile_id]
			var region_current = context.get(region_count_key, 0)
			if region_current < region_min_count:
				boost += 15.0 * (region_min_count - region_current)
	
	return boost

func on_tile_placed(tile: Tile, position: Vector3i, grid, context: Dictionary) -> void:
	"""Called when a tile with this requirement is placed."""
	if not enabled:
		return
	
	var tile_id = str(tile.get_instance_id())
	
	# Update global count
	var global_count_key = "tile_count_" + tile_id
	var global_current = context.get(global_count_key, 0)
	context[global_count_key] = global_current + 1
	
	# Update region count
	var region_id = _get_region_at_position(position, context)
	if region_id >= 0:
		var region_count_key = "tile_count_region_%d_%s" % [region_id, tile_id]
		var region_current = context.get(region_count_key, 0)
		context[region_count_key] = region_current + 1

func _get_region_at_position(position: Vector3i, context: Dictionary) -> int:
	"""Determine which region a position belongs to."""
	var region_map = context.get("region_map", {})
	var pos_key = "%d,%d,%d" % [position.x, position.y, position.z]
	return region_map.get(pos_key, -1)

func get_failure_reason() -> String:
	var parts = []
	if use_global_max:
		parts.append("Global max %d" % global_max_count)
	if use_global_min and strict_min_enforcement:
		parts.append("Global min %d" % global_min_count)
	if use_region_max:
		parts.append("Region max %d" % region_max_count)
	if use_region_min and strict_min_enforcement:
		parts.append("Region min %d" % region_min_count)
	return ", ".join(parts) if not parts.is_empty() else "Count constraint"

func get_description() -> String:
	var parts = []
	if use_global_min:
		parts.append("≥%d global" % global_min_count)
	if use_global_max:
		parts.append("≤%d global" % global_max_count)
	if use_region_min:
		parts.append("≥%d/region" % region_min_count)
	if use_region_max:
		parts.append("≤%d/region" % region_max_count)
	return ", ".join(parts) if not parts.is_empty() else "No constraints"

func reset() -> void:
	"""Reset the counter (called at the start of generation)."""
	_current_count = 0

func get_config_control(_tile: Tile = null) -> Control:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	
	var description_label = Label.new()
	description_label.text = "Control how many times this tile can appear globally and per-region."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(description_label)
	
	# Global limits section
	var global_section = VBoxContainer.new()
	global_section.add_theme_constant_override("separation", 4)
	
	var global_label = Label.new()
	global_label.text = "Global Limits"
	global_label.add_theme_font_size_override("font_size", 14)
	global_section.add_child(global_label)
	
	global_section.add_child(_create_count_row("Global Minimum", use_global_min, global_min_count, 0, 1000,
		func(enabled): use_global_min = enabled,
		func(value): global_min_count = int(value),
		"Minimum number of times this tile must appear in the entire grid"))
	
	global_section.add_child(_create_count_row("Global Maximum", use_global_max, global_max_count, 1, 1000,
		func(enabled): use_global_max = enabled,
		func(value): global_max_count = int(value),
		"Maximum number of times this tile can appear in the entire grid"))
	
	root.add_child(global_section)
	root.add_child(HSeparator.new())
	
	# Region limits section
	var region_section = VBoxContainer.new()
	region_section.add_theme_constant_override("separation", 4)
	
	var region_label = Label.new()
	region_label.text = "Per-Region Limits"
	region_label.add_theme_font_size_override("font_size", 14)
	region_section.add_child(region_label)
	
	region_section.add_child(_create_count_row("Region Minimum", use_region_min, region_min_count, 0, 100,
		func(enabled): use_region_min = enabled,
		func(value): region_min_count = int(value),
		"Minimum number of times this tile must appear in each region"))
	
	region_section.add_child(_create_count_row("Region Maximum", use_region_max, region_max_count, 1, 100,
		func(enabled): use_region_max = enabled,
		func(value): region_max_count = int(value),
		"Maximum number of times this tile can appear in each region"))
	
	root.add_child(region_section)
	root.add_child(HSeparator.new())
	
	# Enforcement options
	var strict_check = CheckButton.new()
	strict_check.text = "Strict Minimum Enforcement"
	strict_check.button_pressed = strict_min_enforcement
	strict_check.tooltip_text = "If enabled, generation will fail if minimums are not met. Otherwise, they're soft preferences."
	strict_check.toggled.connect(func(pressed: bool): strict_min_enforcement = pressed)
	root.add_child(strict_check)
	
	return root

func _create_count_row(label_text: String, enabled: bool, value: int, min_val: int, max_val: int, on_toggle: Callable, on_change: Callable, tooltip: String = "") -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var check = CheckBox.new()
	check.button_pressed = enabled
	check.toggled.connect(on_toggle)
	if not tooltip.is_empty():
		check.tooltip_text = tooltip
	row.add_child(check)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	row.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = 1
	spinbox.value = value
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.value_changed.connect(on_change)
	spinbox.editable = enabled
	if not tooltip.is_empty():
		spinbox.tooltip_text = tooltip
	row.add_child(spinbox)
	
	# Update spinbox editability when checkbox changes
	check.toggled.connect(func(pressed: bool): spinbox.editable = pressed)
	
	return row
