@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name AddRequirementAction

## Action to add a requirement to a tile with undo/redo support

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

var _tile: Tile
var _requirement: Requirement

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, requirement: Requirement) -> void:
	super(undo_redo, "Add Requirement")
	_tile = tile
	_requirement = requirement

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_add_requirement", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_remove_requirement", [])

func _add_requirement() -> void:
	if not _tile.requirements.has(_requirement):
		_tile.requirements.append(_requirement)

func _remove_requirement() -> void:
	_tile.requirements.erase(_requirement)
