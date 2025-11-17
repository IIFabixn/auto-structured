@tool
class_name StructureViewport extends Control

const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

@onready var module_library_control: ModuleLibraryPanel = %ModuleLibraryPanel
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

var undo_redo_manager: AutoStructuredUndoRedo

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
	"""
	Initialize the undo/redo system for this viewport and all child panels.
	Should be called by the plugin after instantiation.
	"""
	undo_redo_manager = undo_redo
	
	# Propagate to child panels when they're ready
	if is_node_ready():
		_propagate_undo_redo()
	else:
		ready.connect(_propagate_undo_redo, CONNECT_ONE_SHOT)

func _propagate_undo_redo() -> void:
	"""Propagate undo/redo manager to all child panels."""
	if module_library_control and module_library_control.has_method("setup_undo_redo"):
		module_library_control.setup_undo_redo(undo_redo_manager)
	
	if details_panel and details_panel.has_method("setup_undo_redo"):
		details_panel.setup_undo_redo(undo_redo_manager)
	
	if viewport_panel and viewport_panel.has_method("setup_undo_redo"):
		viewport_panel.setup_undo_redo(undo_redo_manager)
