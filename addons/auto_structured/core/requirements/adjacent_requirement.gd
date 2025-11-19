@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name AdjacentRequirement

## Requires specific tiles or tags to be adjacent to this tile.
## Useful for tiles that must be next to walls, other tiles, etc.

enum AdjacentMode {
	MUST_HAVE,       ## At least one adjacent tile must match
	MUST_NOT_HAVE,   ## No adjacent tiles can match
	EXACT_COUNT      ## Exactly N adjacent tiles must match
}

@export var mode: AdjacentMode = AdjacentMode.MUST_HAVE
@export var required_tags: Array[String] = []  ## Tags that adjacent tiles must have/not have
@export var required_count: int = 1  ## For EXACT_COUNT mode
@export var check_horizontal: bool = true  ## Check X/Z neighbors
@export var check_vertical: bool = false   ## Check Y neighbors

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	if required_tags.is_empty():
		return true
	
	var matching_neighbors = 0
	var directions = []
	
	if check_horizontal:
		directions.append(Vector3i(1, 0, 0))
		directions.append(Vector3i(-1, 0, 0))
		directions.append(Vector3i(0, 0, 1))
		directions.append(Vector3i(0, 0, -1))
	
	if check_vertical:
		directions.append(Vector3i(0, 1, 0))
		directions.append(Vector3i(0, -1, 0))
	
	for dir in directions:
		var neighbor_pos = position + dir
		if not grid.is_valid_position(neighbor_pos):
			continue
		
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if not neighbor_cell or not neighbor_cell.is_collapsed():
			continue
		
		var neighbor_tile = neighbor_cell.get_tile()
		if not neighbor_tile:
			continue
		
		# Check if neighbor has any of the required tags
		for tag in required_tags:
			if tag in neighbor_tile.tags:
				matching_neighbors += 1
				break
	
	match mode:
		AdjacentMode.MUST_HAVE:
			return matching_neighbors > 0
		AdjacentMode.MUST_NOT_HAVE:
			return matching_neighbors == 0
		AdjacentMode.EXACT_COUNT:
			return matching_neighbors == required_count
	
	return true

func get_failure_reason() -> String:
	var tag_str = ", ".join(required_tags)
	match mode:
		AdjacentMode.MUST_HAVE:
			return "Must be adjacent to tile with tags: %s" % tag_str
		AdjacentMode.MUST_NOT_HAVE:
			return "Cannot be adjacent to tile with tags: %s" % tag_str
		AdjacentMode.EXACT_COUNT:
			return "Must have exactly %d adjacent tiles with tags: %s" % [required_count, tag_str]
	return super.get_failure_reason()

func get_description() -> String:
	var tag_str = ", ".join(required_tags)
	var dir_str = ""
	if check_horizontal and check_vertical:
		dir_str = "any adjacent"
	elif check_horizontal:
		dir_str = "horizontally adjacent"
	elif check_vertical:
		dir_str = "vertically adjacent"
	
	match mode:
		AdjacentMode.MUST_HAVE:
			return "Requires %s tile with: %s" % [dir_str, tag_str]
		AdjacentMode.MUST_NOT_HAVE:
			return "Cannot be %s to: %s" % [dir_str, tag_str]
		AdjacentMode.EXACT_COUNT:
			return "Needs exactly %d %s tiles with: %s" % [required_count, dir_str, tag_str]
	return super.get_description()

func get_config_control() -> Control:
	var vbox = VBoxContainer.new()
	
	# Mode selector
	var mode_hbox = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Mode:"
	mode_label.custom_minimum_size.x = 80
	mode_hbox.add_child(mode_label)
	
	var mode_option = OptionButton.new()
	mode_option.add_item("Must Have", AdjacentMode.MUST_HAVE)
	mode_option.add_item("Must Not Have", AdjacentMode.MUST_NOT_HAVE)
	mode_option.add_item("Exact Count", AdjacentMode.EXACT_COUNT)
	mode_option.select(mode)
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.item_selected.connect(func(idx: int): mode = idx)
	mode_hbox.add_child(mode_option)
	vbox.add_child(mode_hbox)
	
	# Required count (for EXACT_COUNT mode)
	var count_hbox = HBoxContainer.new()
	var count_label = Label.new()
	count_label.text = "Count:"
	count_label.custom_minimum_size.x = 80
	count_hbox.add_child(count_label)
	
	var count_spinbox = SpinBox.new()
	count_spinbox.min_value = 1
	count_spinbox.max_value = 6
	count_spinbox.value = required_count
	count_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_spinbox.value_changed.connect(func(val: float): required_count = int(val))
	count_hbox.add_child(count_spinbox)
	vbox.add_child(count_hbox)
	
	# Tags input
	var tags_hbox = HBoxContainer.new()
	var tags_label = Label.new()
	tags_label.text = "Tags:"
	tags_label.custom_minimum_size.x = 80
	tags_hbox.add_child(tags_label)
	
	var tags_edit = LineEdit.new()
	tags_edit.placeholder_text = "tag1, tag2, tag3"
	tags_edit.text = ", ".join(required_tags)
	tags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags_edit.text_changed.connect(func(text: String):
		var tags_array: Array[String] = []
		for tag in text.split(","):
			var trimmed = tag.strip_edges()
			if not trimmed.is_empty():
				tags_array.append(trimmed)
		required_tags = tags_array
	)
	tags_hbox.add_child(tags_edit)
	vbox.add_child(tags_hbox)
	
	# Check horizontal
	var horiz_check = CheckBox.new()
	horiz_check.text = "Check Horizontal (X/Z)"
	horiz_check.button_pressed = check_horizontal
	horiz_check.toggled.connect(func(pressed: bool): check_horizontal = pressed)
	vbox.add_child(horiz_check)
	
	# Check vertical
	var vert_check = CheckBox.new()
	vert_check.text = "Check Vertical (Y)"
	vert_check.button_pressed = check_vertical
	vert_check.toggled.connect(func(pressed: bool): check_vertical = pressed)
	vbox.add_child(vert_check)
	
	return vbox
