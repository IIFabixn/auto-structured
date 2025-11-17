@tool
class_name PreviewPanel extends Control

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const Viewport3DGrid = preload("res://addons/auto_structured/ui/controls/viewport_3d_grid.gd")
const ViewportCameraController = preload("res://addons/auto_structured/ui/controls/viewport_camera_controller.gd")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

const CYCLE_DELAY: float = 3.0  # seconds between cycling compatible tiles

@onready var new_button: TextureButton = %NewButton
@onready var edit_button: TextureButton = %EditButton
@onready var step_button: TextureButton = %StepButton
@onready var solve_button: TextureButton = %SolveButton
@onready var menu_button: MenuButton = %MenuButton

@onready var sub_viewport: SubViewport = %PreviewViewport
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var viewport_menu_button: MenuButton = %ViewportMenuButton

var undo_redo_manager: AutoStructuredUndoRedo

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
	"""
	Initialize the undo/redo system for this panel.
	Should be called by the parent viewport after instantiation.
	"""
	undo_redo_manager = undo_redo
