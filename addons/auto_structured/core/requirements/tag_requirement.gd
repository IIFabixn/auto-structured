@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name TagRequirement

## Requires that the tile has (or does not have) specific tags.
## Useful in combination with other systems that set tags dynamically.

enum TagMode {
	HAS_ALL,         ## Tile must have all specified tags
	HAS_ANY,         ## Tile must have at least one specified tag
	HAS_NONE         ## Tile must not have any specified tags
}

@export var mode: TagMode = TagMode.HAS_ALL
@export var required_tags: Array[String] = []

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	if required_tags.is_empty():
		return true
	
	match mode:
		TagMode.HAS_ALL:
			for tag in required_tags:
				if tag not in tile.tags:
					return false
			return true
		
		TagMode.HAS_ANY:
			for tag in required_tags:
				if tag in tile.tags:
					return true
			return false
		
		TagMode.HAS_NONE:
			for tag in required_tags:
				if tag in tile.tags:
					return false
			return true
	
	return true

func get_failure_reason() -> String:
	var tag_str = ", ".join(required_tags)
	match mode:
		TagMode.HAS_ALL:
			return "Tile must have all tags: %s" % tag_str
		TagMode.HAS_ANY:
			return "Tile must have at least one tag: %s" % tag_str
		TagMode.HAS_NONE:
			return "Tile must not have tags: %s" % tag_str
	return super.get_failure_reason()

func get_description() -> String:
	var tag_str = ", ".join(required_tags)
	match mode:
		TagMode.HAS_ALL:
			return "Must have: %s" % tag_str
		TagMode.HAS_ANY:
			return "Must have any: %s" % tag_str
		TagMode.HAS_NONE:
			return "Must not have: %s" % tag_str
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
	mode_option.add_item("Has All", TagMode.HAS_ALL)
	mode_option.add_item("Has Any", TagMode.HAS_ANY)
	mode_option.add_item("Has None", TagMode.HAS_NONE)
	mode_option.select(mode)
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.item_selected.connect(func(idx: int): mode = idx)
	mode_hbox.add_child(mode_option)
	vbox.add_child(mode_hbox)
	
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
	
	return vbox
