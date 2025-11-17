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
