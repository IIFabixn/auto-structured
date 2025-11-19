@tool
class_name StructureViewport extends Control

const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")
const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")

@onready var module_library_control: ModuleLibraryPanel = %ModuleLibraryPanel
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

var undo_redo_manager: AutoStructuredUndoRedo
var selection_manager: SelectionManager

func _ready() -> void:
	"""Initialize the viewport and create shared systems."""
	selection_manager = SelectionManager.new()
	
	if is_node_ready():
		_propagate_systems()
	else:
		ready.connect(_propagate_systems, CONNECT_ONE_SHOT)

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
	"""
	Initialize the undo/redo system for this viewport and all child panels.
	Should be called by the plugin after instantiation.
	"""
	undo_redo_manager = undo_redo
	
	# Propagate to child panels when they're ready
	if is_node_ready():
		_propagate_systems()
	else:
		ready.connect(_propagate_systems, CONNECT_ONE_SHOT)

func _propagate_systems() -> void:
	"""Propagate undo/redo manager and selection manager to all child panels."""
	if module_library_control:
		if module_library_control.has_method("setup_undo_redo"):
			module_library_control.setup_undo_redo(undo_redo_manager)
		if module_library_control.has_method("setup_selection_manager"):
			module_library_control.setup_selection_manager(selection_manager)
		
		# Connect to library changes to update details panel
		if not module_library_control.library_loaded.is_connected(_on_library_loaded):
			module_library_control.library_loaded.connect(_on_library_loaded)
	
	if details_panel:
		if details_panel.has_method("setup_undo_redo"):
			details_panel.setup_undo_redo(undo_redo_manager)
		if details_panel.has_method("setup_selection_manager"):
			details_panel.setup_selection_manager(selection_manager)
	
	if viewport_panel:
		if viewport_panel.has_method("setup_undo_redo"):
			viewport_panel.setup_undo_redo(undo_redo_manager)
		if viewport_panel.has_method("setup_selection_manager"):
			viewport_panel.setup_selection_manager(selection_manager)

func _on_library_loaded(library: ModuleLibrary) -> void:
	"""Handle library loaded event - propagate to details panel."""
	if details_panel and details_panel.has_method("setup_library"):
		details_panel.setup_library(library)
