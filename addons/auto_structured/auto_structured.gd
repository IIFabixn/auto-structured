@tool
extends EditorPlugin

const StructureViewportScene = preload("res://addons/auto_structured/ui/structure_viewport.tscn")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")
const AutoStructuredSettings = preload("res://addons/auto_structured/utils/auto_structured_settings.gd")

var structure_viewport: StructureViewport
var undo_redo_manager: AutoStructuredUndoRedo
var _editor_settings: EditorSettings = null

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	print("Auto Structured Plugin Enabled")
	AutoStructuredSettings.ensure_defaults()
	AutoStructuredSettings.sync_editor_preference_to_project()
	if Engine.is_editor_hint():
		_editor_settings = get_editor_interface().get_editor_settings()
		if _editor_settings and not _editor_settings.settings_changed.is_connected(_on_editor_settings_changed):
			_editor_settings.settings_changed.connect(_on_editor_settings_changed)
	
	# Initialize undo/redo manager
	undo_redo_manager = AutoStructuredUndoRedo.new(self)
	
	# Initialization of the plugin goes here.
	structure_viewport = StructureViewportScene.instantiate()
	structure_viewport.setup_undo_redo(undo_redo_manager)
	add_control_to_bottom_panel(structure_viewport, "Auto Structured")

func _exit_tree() -> void:
	print("Auto Structured Plugin Disabled")
	# Cleanup of the plugin goes here.
	remove_control_from_bottom_panel(structure_viewport)
	structure_viewport.queue_free()
	undo_redo_manager = null
	if _editor_settings and _editor_settings.settings_changed.is_connected(_on_editor_settings_changed):
		_editor_settings.settings_changed.disconnect(_on_editor_settings_changed)
	_editor_settings = null

func _on_editor_settings_changed() -> void:
	AutoStructuredSettings.sync_editor_preference_to_project()
