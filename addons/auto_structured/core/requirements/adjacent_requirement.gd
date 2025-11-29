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

enum TagMatchMode {
	ANY,  ## Tile must have at least one of the listed tags
	ALL   ## Tile must have all of the listed tags
}

enum NeighborMatchState {
	NONE,
	POTENTIAL,
	CONFIRMED
}

@export var mode: AdjacentMode = AdjacentMode.MUST_HAVE
@export var tag_match_mode: TagMatchMode = TagMatchMode.ANY
@export var required_tags: Array[String] = []  ## Tags that adjacent tiles must have/not have
@export var required_count: int = 1  ## For EXACT_COUNT mode
@export var check_horizontal: bool = true  ## Check X/Z neighbors
@export var check_vertical: bool = false   ## Check Y neighbors

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	if required_tags.is_empty():
		return true
	
	var match_counts: Dictionary = _count_neighbor_matches(position, grid)
	match mode:
		AdjacentMode.MUST_HAVE:
			return (match_counts["confirmed"] + match_counts["potential"]) > 0
		AdjacentMode.MUST_NOT_HAVE:
			return match_counts["confirmed"] == 0
		AdjacentMode.EXACT_COUNT:
			if match_counts["confirmed"] > required_count:
				return false
			var max_possible: int = match_counts["confirmed"] + match_counts["potential"]
			if max_possible < required_count:
				return false
			return true
	
	return true

func _count_neighbor_matches(position: Vector3i, grid) -> Dictionary:
	var directions := _get_directions()
	var result: Dictionary = {
		"confirmed": 0,
		"potential": 0
	}
	for dir in directions:
		var neighbor_pos: Vector3i = position + dir
		if not grid.is_valid_position(neighbor_pos):
			continue
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null:
			continue
		var state := _get_neighbor_match_state(neighbor_cell)
		if state == NeighborMatchState.CONFIRMED:
			result["confirmed"] += 1
		elif state == NeighborMatchState.POTENTIAL:
			result["potential"] += 1
	return result

func _get_directions() -> Array:
	var dirs: Array[Vector3i] = []
	if check_horizontal:
		dirs.append(Vector3i(1, 0, 0))
		dirs.append(Vector3i(-1, 0, 0))
		dirs.append(Vector3i(0, 0, 1))
		dirs.append(Vector3i(0, 0, -1))
	if check_vertical:
		dirs.append(Vector3i(0, 1, 0))
		dirs.append(Vector3i(0, -1, 0))
	return dirs

func _get_neighbor_match_state(neighbor_cell) -> int:
	if neighbor_cell.is_collapsed():
		var tile: Tile = neighbor_cell.get_tile()
		return NeighborMatchState.CONFIRMED if _tile_matches_required_tags(tile) else NeighborMatchState.NONE
	for variant in neighbor_cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if _tile_matches_required_tags(tile):
			return NeighborMatchState.POTENTIAL
	return NeighborMatchState.NONE

func _tile_matches_required_tags(tile: Tile) -> bool:
	if tile == null:
		return false
	if required_tags.is_empty():
		return false
	
	match tag_match_mode:
		TagMatchMode.ANY:
			# Tile must have at least one of the required tags
			for tag in required_tags:
				if tag in tile.tags:
					return true
			return false
		TagMatchMode.ALL:
			# Tile must have all of the required tags
			for tag in required_tags:
				if tag not in tile.tags:
					return false
			return true
	
	return false

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
	var match_str = "ANY" if tag_match_mode == TagMatchMode.ANY else "ALL"
	var dir_str = ""
	if check_horizontal and check_vertical:
		dir_str = "any adjacent"
	elif check_horizontal:
		dir_str = "horizontally adjacent"
	elif check_vertical:
		dir_str = "vertically adjacent"
	
	match mode:
		AdjacentMode.MUST_HAVE:
			return "Requires %s tile with %s of: %s" % [dir_str, match_str, tag_str]
		AdjacentMode.MUST_NOT_HAVE:
			return "Cannot be %s to tiles with %s of: %s" % [dir_str, match_str, tag_str]
		AdjacentMode.EXACT_COUNT:
			return "Needs exactly %d %s tiles with %s of: %s" % [required_count, dir_str, match_str, tag_str]
	return super.get_description()

func get_config_control(_tile: Tile = null) -> Control:
	var vbox = VBoxContainer.new()
	
	# Mode selector
	var mode_hbox = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Modus:"
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
	
	# Tag match mode selector
	var tag_mode_hbox = HBoxContainer.new()
	var tag_mode_label = Label.new()
	tag_mode_label.text = "Tag Match:"
	tag_mode_label.custom_minimum_size.x = 80
	tag_mode_hbox.add_child(tag_mode_label)
	
	var tag_mode_option = OptionButton.new()
	tag_mode_option.add_item("ANY (at least one)", TagMatchMode.ANY)
	tag_mode_option.add_item("ALL (must have all)", TagMatchMode.ALL)
	tag_mode_option.select(int(tag_match_mode) if tag_match_mode != null else TagMatchMode.ANY)
	tag_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_mode_option.item_selected.connect(func(idx: int): tag_match_mode = idx)
	tag_mode_hbox.add_child(tag_mode_option)
	vbox.add_child(tag_mode_hbox)
	
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
