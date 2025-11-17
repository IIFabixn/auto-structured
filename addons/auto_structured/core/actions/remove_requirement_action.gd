@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name RemoveRequirementAction

## Action to remove a requirement from a tile with undo/redo support

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

var _tile: Tile
var _requirement: Requirement
var _index: int

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, requirement: Requirement) -> void:
	super(undo_redo, "Remove Requirement")
	_tile = tile
	_requirement = requirement
	_index = tile.requirements.find(requirement)

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_remove_requirement", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_restore_requirement", [])

func _remove_requirement() -> void:
	_tile.requirements.erase(_requirement)

func _restore_requirement() -> void:
	if _index >= 0 and _index <= _tile.requirements.size():
		_tile.requirements.insert(_index, _requirement)
	else:
		_tile.requirements.append(_requirement)
