@tool
class_name StructureViewport extends Control

const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")
const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const ValidationEventBus = preload("res://addons/auto_structured/core/events/validation_event_bus.gd")

@onready var module_library_control: ModuleLibraryPanel = %ModuleLibraryPanel
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

var undo_redo_manager: AutoStructuredUndoRedo
var selection_manager: SelectionManager
var validation_bus: ValidationEventBus

func _ready() -> void:
	"""Initialize the viewport and create shared systems."""
	selection_manager = SelectionManager.new()
	validation_bus = ValidationEventBus.new()
	
	# Connect to validation events for centralized display
	if validation_bus:
		validation_bus.validation_error.connect(_on_validation_error)
		validation_bus.validation_warning.connect(_on_validation_warning)
		validation_bus.validation_info.connect(_on_validation_info)
		validation_bus.validation_cleared.connect(_on_validation_cleared)
	
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
		
		# If library is already loaded, propagate it now
		if module_library_control.current_library and details_panel:
			if details_panel.has_method("setup_library"):
				details_panel.setup_library(module_library_control.current_library)
	
	if details_panel:
		if details_panel.has_method("setup_undo_redo"):
			details_panel.setup_undo_redo(undo_redo_manager)
		if details_panel.has_method("setup_selection_manager"):
			details_panel.setup_selection_manager(selection_manager)
		if details_panel.has_method("setup_validation_bus"):
			details_panel.setup_validation_bus(validation_bus)
		
		# Connect tile_modified signal to save changes
		if not details_panel.tile_modified.is_connected(_on_tile_modified_in_details):
			details_panel.tile_modified.connect(_on_tile_modified_in_details)
	
	if viewport_panel:
		if viewport_panel.has_method("setup_undo_redo"):
			viewport_panel.setup_undo_redo(undo_redo_manager)
		if viewport_panel.has_method("setup_selection_manager"):
			viewport_panel.setup_selection_manager(selection_manager)

func _on_library_loaded(library: ModuleLibrary) -> void:
	"""Handle library loaded event - propagate to details panel."""
	if details_panel and details_panel.has_method("setup_library"):
		details_panel.setup_library(library)

func _on_tile_modified_in_details(tile: Tile) -> void:
	"""Handle tile modification from details panel - trigger library save."""
	if module_library_control and module_library_control.has_method("_save_library"):
		module_library_control._save_library()

func _on_validation_error(message: String, context: int, severity: int, source: Variant, details: Dictionary) -> void:
	"""Handle validation error events."""
	_display_validation(message, context, ValidationEventBus.Severity.ERROR)

func _on_validation_warning(message: String, context: int, source: Variant, details: Dictionary) -> void:
	"""Handle validation warning events."""
	_display_validation(message, context, ValidationEventBus.Severity.WARNING)

func _on_validation_info(message: String, context: int, source: Variant, details: Dictionary) -> void:
	"""Handle validation info events."""
	_display_validation(message, context, ValidationEventBus.Severity.INFO)

func _display_validation(message: String, context: int, severity: int) -> void:
	"""Display a validation message using Godot notifications."""
	var severity_name = ValidationEventBus.get_severity_name(severity)
	var context_name = ValidationEventBus.get_context_name(context)
	
	# Log to output with color coding
	var log_message = "[%s] [%s] %s" % [severity_name, context_name, message]
	match severity:
		ValidationEventBus.Severity.ERROR:
			push_error(log_message)
		ValidationEventBus.Severity.WARNING:
			push_warning(log_message)
		_:
			print(log_message)

func _on_validation_cleared(_context: int) -> void:
	"""Handle validation cleared event."""
	pass  # Notifications auto-dismiss
