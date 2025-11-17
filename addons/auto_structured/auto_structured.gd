@tool
extends EditorPlugin

const StructureViewportScene = preload("res://addons/auto_structured/ui/structure_viewport.tscn")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

var structure_viewport: StructureViewport
var undo_redo_manager: AutoStructuredUndoRedo

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	print("Auto Structured Plugin Enabled")
	
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
