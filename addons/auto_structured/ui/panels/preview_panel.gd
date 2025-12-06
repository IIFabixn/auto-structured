@tool
class_name PreviewPanel extends Control

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const WfcSolverConfig = preload("res://addons/auto_structured/core/wfc/wfc_solver_config.gd")
const WfcRegionConfig = preload("res://addons/auto_structured/core/wfc/wfc_region_config.gd")
const WfcSolveJob = preload("res://addons/auto_structured/core/wfc/wfc_solve_job.gd")
const ViewportCameraController = preload("res://addons/auto_structured/ui/controls/viewport_camera_controller.gd")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

const CYCLE_DELAY := 3.0
const PreviewMode := {
    "IDLE": 0,
    "TILE": 1,
    "SOCKET": 2,
    "WFC": 3
}
const DEFAULT_INSTRUCTION := "Select a tile to preview."
const DEFAULT_VIEW_DIRECTION := Vector3(0.45, 0.35, -1.0)
const DEFAULT_BLUEPRINT_CONFIG := {
    "min_room_size": 4,
    "max_room_size": 8,
    "max_rooms": 6,
    "margin": 1,
    "floor_height": 1,
    "num_floors": 1,
    "add_roof": false,
    "doors_per_room": 1,
}

@onready var new_button: TextureButton = %NewButton
@onready var edit_button: TextureButton = %EditButton
@onready var step_button: TextureButton = %StepButton
@onready var solve_button: TextureButton = %SolveButton
@onready var menu_button: MenuButton = %MenuButton

@onready var sub_viewport: SubViewport = %PreviewViewport
@onready var viewport_container: SubViewportContainer = %SubViewportContainer

@onready var viewport_menu_button: MenuButton = %ViewportMenuButton
@onready var socket_cycle_timer: Timer = %SocketCycleTimer
@onready var wfc_setup_dialog: WfcSetupDialog = %WfcSetupDialog
@onready var preview_root: Node3D = %PreviewRoot
@onready var base_tile_root: Node3D = %BaseTileRoot
@onready var socket_preview_root: Node3D = %SocketPreviewRoot
@onready var wfc_root: Node3D = %WfcRoot
@onready var grid_node: Viewport3DGrid = %ViewportGrid
@onready var instructions_label: Label = %Label
@onready var job_status_container: VBoxContainer = %JobStatusContainer
@onready var job_progress_bar: ProgressBar = %JobProgressBar
@onready var job_status_label: Label = %JobStatusLabel
@onready var job_cancel_button: Button = %JobCancelButton
@onready var step_options_container: HBoxContainer = %StepOptionsContainer
@onready var step_options_scroll: ScrollContainer = %ScrollContainer

@onready var camera_controller: ViewportCameraController = %PreviewCamera

var undo_redo_manager: AutoStructuredUndoRedo
var selection_manager: SelectionManager
var current_library: ModuleLibrary
var current_tile: Tile
var preview_mode := PreviewMode.IDLE

var socket_cycle_entries: Array[Dictionary] = []
var socket_cycle_index: int = 0
var socket_cycle_socket: Socket = null

var wfc_grid: WfcGrid
var wfc_solver: WfcSolver
var wfc_cell_size: Vector3 = Vector3.ONE
var wfc_last_config: Dictionary = {}
var wfc_session_active := false
var wfc_waiting_for_choice: Dictionary = {}
var wfc_cell_nodes: Dictionary = {}
var wfc_decision_highlight: MeshInstance3D
var wfc_solve_job: WfcSolveJob
var _wfc_job_progress: Dictionary = {}

func _ready() -> void:
    set_process(true)
    _menu_setup()
    if socket_cycle_timer and not socket_cycle_timer.timeout.is_connected(_on_socket_cycle_timeout):
        socket_cycle_timer.timeout.connect(_on_socket_cycle_timeout)
    if new_button:
        new_button.pressed.connect(_on_new_button_pressed)
    if edit_button:
        edit_button.pressed.connect(_on_edit_button_pressed)
    if step_button:
        step_button.pressed.connect(_on_step_button_pressed)
    if solve_button:
        solve_button.pressed.connect(_on_solve_button_pressed)
    if job_cancel_button and not job_cancel_button.pressed.is_connected(_on_job_cancel_pressed):
        job_cancel_button.pressed.connect(_on_job_cancel_pressed)
    if wfc_setup_dialog:
        if not wfc_setup_dialog.setup_confirmed.is_connected(_on_wfc_setup_confirmed):
            wfc_setup_dialog.setup_confirmed.connect(_on_wfc_setup_confirmed)
        wfc_last_config = _hydrate_wfc_config(wfc_setup_dialog.get_last_config())
    else:
        _ensure_wfc_config_initialized()
    if viewport_container and not viewport_container.gui_input.is_connected(_on_viewport_gui_input):
        viewport_container.gui_input.connect(_on_viewport_gui_input)
    _set_instruction(DEFAULT_INSTRUCTION)
    _show_job_status_ui(false)
    _set_step_options_visible(false)
    _update_buttons_state()

func _on_viewport_gui_input(event: InputEvent) -> void:
    if camera_controller:
        camera_controller.handle_input(event)

func _menu_setup() -> void:
    if edit_button:
        edit_button.disabled = true
    if menu_button:
        menu_button.disabled = true
    if viewport_menu_button:
        viewport_menu_button.disabled = true

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
    undo_redo_manager = undo_redo

func setup_selection_manager(manager: SelectionManager) -> void:
    if selection_manager and selection_manager.tile_selected.is_connected(_on_tile_selected):
        selection_manager.tile_selected.disconnect(_on_tile_selected)
    selection_manager = manager
    if selection_manager and not selection_manager.tile_selected.is_connected(_on_tile_selected):
        selection_manager.tile_selected.connect(_on_tile_selected)

func setup_library(library: ModuleLibrary) -> void:
    if current_library == library:
        return
    _ensure_wfc_config_initialized()
    current_library = library
    _reset_wfc_session()
    if current_library:
        var cell := current_library.cell_world_size
        if wfc_setup_dialog:
            wfc_setup_dialog.apply_library_defaults(Vector3i.ZERO, cell)
            wfc_last_config = _hydrate_wfc_config(wfc_setup_dialog.get_last_config())
        elif cell != Vector3.ZERO:
            wfc_last_config["cell_size"] = cell
        var configured_cell := _get_configured_cell_size()
        _update_grid_spacing(configured_cell)
        var configured_grid: Vector3i = wfc_last_config.get("grid_size", Vector3i.ZERO)
        _update_grid_bounds(configured_grid, configured_cell)
        _update_wfc_root_offset(configured_grid, configured_cell)
    _update_buttons_state()

func handle_socket_preview_request(tile: Tile, socket: Socket) -> void:
    if tile == null or socket == null:
        return
    _reset_wfc_session()
    _display_tile(tile)
    _show_socket_preview(tile, socket)

func _on_tile_selected(tile: Tile, _previous: Tile) -> void:
    current_tile = tile
    if tile == null:
        _stop_socket_cycle()
        _clear_children(base_tile_root)
        _set_instruction(DEFAULT_INSTRUCTION)
        return
    _reset_wfc_session()
    _stop_socket_cycle()
    _show_tile_preview(tile)

func _show_tile_preview(tile: Tile) -> void:
    preview_mode = PreviewMode.TILE
    _display_tile(tile)
    _set_instruction("Previewing %s" % tile.name)
    _align_camera_default()

func _display_tile(tile: Tile) -> void:
    _clear_children(base_tile_root)
    _clear_children(socket_preview_root)
    if tile == null:
        return
    var instance := _instantiate_tile(tile)
    if instance == null:
        _set_instruction("Tile has no mesh or scene attached.")
        return
    base_tile_root.add_child(instance)
    instance.owner = null
    _focus_camera_on(instance)

func _show_socket_preview(tile: Tile, socket: Socket) -> void:
    if current_library == null:
        _set_instruction("Load a module library to preview sockets.")
        return
    preview_mode = PreviewMode.SOCKET
    socket_cycle_socket = socket
    _clear_children(socket_preview_root)
    socket_cycle_entries.clear()
    socket_cycle_entries.append({"type": "base"})
    var matches := WfcHelper.find_compatible_tiles(socket, current_library.tiles, tile)
    var cell := _get_configured_cell_size()
    for data in matches:
        var compat_tile: Tile = data.get("tile")
        if compat_tile == null:
            continue
        var rotation := data.get("rotation_degrees", 0)
        var inst := _instantiate_tile(compat_tile)
        if inst == null:
            continue
        inst.rotation_degrees.y = rotation
        inst.visible = false
        var offset := WfcHelper.calculate_adjacent_tile_position(tile.size, compat_tile.size, socket.direction, cell, rotation)
        inst.position = offset
        socket_preview_root.add_child(inst)
        inst.owner = null
        socket_cycle_entries.append({
            "type": "match",
            "node": inst,
            "tile": compat_tile,
            "rotation": rotation
        })
    socket_cycle_index = 0
    if socket_cycle_entries.size() <= 1:
        _set_instruction("No compatible sockets found.")
        return
    _set_instruction("Cycling %d compatible tiles" % (socket_cycle_entries.size() - 1))
    _run_socket_cycle()
    _align_camera_to_socket(socket.direction)

func _run_socket_cycle() -> void:
    if socket_cycle_entries.is_empty():
        return
    _socket_cycle_show_current()
    socket_cycle_timer.wait_time = CYCLE_DELAY
    socket_cycle_timer.start()

func _on_socket_cycle_timeout() -> void:
    if socket_cycle_entries.is_empty():
        socket_cycle_timer.stop()
        return
    socket_cycle_index = (socket_cycle_index + 1) % socket_cycle_entries.size()
    _socket_cycle_show_current()

func _socket_cycle_show_current() -> void:
    for entry in socket_cycle_entries:
        var node: Node3D = entry.get("node")
        if node:
            node.visible = false
    var current := socket_cycle_entries[socket_cycle_index]
    var node: Node3D = current.get("node")
    if node:
        node.visible = true

func _stop_socket_cycle() -> void:
    socket_cycle_timer.stop()
    socket_cycle_entries.clear()
    _clear_children(socket_preview_root)
    socket_cycle_socket = null

func _ensure_wfc_config_initialized() -> void:
    if not wfc_last_config.is_empty():
        return
    if wfc_setup_dialog:
        wfc_last_config = _hydrate_wfc_config(wfc_setup_dialog.get_last_config())
    else:
        wfc_last_config = _build_default_wfc_config()

func _build_default_wfc_config() -> Dictionary:
    var solver_config := _create_default_solver_config()
    return {
        "grid_size": Vector3i(5, 3, 5),
        "cell_size": Vector3(2, 2, 2),
        "solver_config": solver_config,
        "solver_settings": _serialize_solver_config(solver_config, "medium")
    }

func _create_default_solver_config() -> WfcSolverConfig:
    var config := WfcSolverConfig.medium_grid()
    config.solve_strategy_id = "entropy"
    return config

func _hydrate_wfc_config(source: Dictionary) -> Dictionary:
    var hydrated := source.duplicate(true)
    var solver_settings: Dictionary = hydrated.get("solver_settings", {})
    var preset_id: String = solver_settings.get("preset_id", "custom")
    var solver_config: WfcSolverConfig
    if hydrated.has("solver_config") and hydrated["solver_config"] is WfcSolverConfig:
        solver_config = _clone_solver_config(hydrated["solver_config"])
    elif not solver_settings.is_empty():
        solver_config = _deserialize_solver_settings(solver_settings)
    else:
        solver_config = _create_default_solver_config()
        preset_id = "medium"
    hydrated["solver_config"] = solver_config
    if solver_settings.is_empty():
        hydrated["solver_settings"] = _serialize_solver_config(solver_config, preset_id)
    else:
        hydrated["solver_settings"] = solver_settings.duplicate(true)
    return hydrated

func _copy_wfc_config(source: Dictionary) -> Dictionary:
    return _hydrate_wfc_config(source)

func _extract_solver_config(config: Dictionary) -> WfcSolverConfig:
    if config.has("solver_config") and config["solver_config"] is WfcSolverConfig:
        return _clone_solver_config(config["solver_config"])
    return _deserialize_solver_settings(config.get("solver_settings", {}))

func _deserialize_solver_settings(data: Dictionary) -> WfcSolverConfig:
    var config := _create_default_solver_config()
    if data.is_empty():
        return config
    config.yield_interval_ms = data.get("yield_interval_ms", config.yield_interval_ms)
    config.propagation_batch_size = data.get("propagation_batch_size", config.propagation_batch_size)
    config.prewarm_cache = data.get("prewarm_cache", config.prewarm_cache)
    config.max_iterations = data.get("max_iterations", config.max_iterations)
    config.progress_report_interval_ms = data.get("progress_report_interval_ms", config.progress_report_interval_ms)
    config.enable_backtracking = data.get("enable_backtracking", config.enable_backtracking)
    config.max_backtrack_depth = data.get("max_backtrack_depth", config.max_backtrack_depth)
    config.backtrack_checkpoint_frequency = data.get("backtrack_checkpoint_frequency", config.backtrack_checkpoint_frequency)
    config.solve_strategy_id = data.get("solve_strategy_id", config.solve_strategy_id)
    config.blueprint_config = _sanitize_blueprint_config(data.get("blueprint_config", config.blueprint_config))
    # Restore region settings from unified config or legacy field
    if data.has("region_config"):
        config.region_config = WfcRegionConfig.from_dict(data["region_config"])
    else:
        # Legacy field migration
        config.region_config.enabled = data.get("enforce_region_boundaries", false)
    return config

func _serialize_solver_config(config: WfcSolverConfig, preset_id: String) -> Dictionary:
    return {
        "preset_id": preset_id,
        "yield_interval_ms": config.yield_interval_ms,
        "propagation_batch_size": config.propagation_batch_size,
        "prewarm_cache": config.prewarm_cache,
        "max_iterations": config.max_iterations,
        "progress_report_interval_ms": config.progress_report_interval_ms,
        "enable_backtracking": config.enable_backtracking,
        "max_backtrack_depth": config.max_backtrack_depth,
        "backtrack_checkpoint_frequency": config.backtrack_checkpoint_frequency,
        "solve_strategy_id": config.solve_strategy_id,
        "blueprint_config": _sanitize_blueprint_config(config.blueprint_config),
        # Region settings (using unified config)
        "region_config": config.region_config.to_dict() if config.region_config else {}
    }

func _clone_solver_config(source: WfcSolverConfig) -> WfcSolverConfig:
    var clone := WfcSolverConfig.new()
    if source == null:
        return clone
    clone.yield_interval_ms = source.yield_interval_ms
    clone.propagation_batch_size = source.propagation_batch_size
    clone.prewarm_cache = source.prewarm_cache
    clone.max_iterations = source.max_iterations
    clone.progress_report_interval_ms = source.progress_report_interval_ms
    clone.enable_backtracking = source.enable_backtracking
    clone.max_backtrack_depth = source.max_backtrack_depth
    clone.backtrack_checkpoint_frequency = source.backtrack_checkpoint_frequency
    clone.solve_strategy_id = source.solve_strategy_id
    clone.blueprint_config = _sanitize_blueprint_config(source.blueprint_config)
    # Clone region config properly
    if source.region_config:
        clone.region_config = source.region_config.duplicate_config()
    return clone

func _sanitize_blueprint_config(data: Dictionary) -> Dictionary:
    var result := DEFAULT_BLUEPRINT_CONFIG.duplicate(true)
    if data == null:
        return result
    if data.has("min_room_size"):
        result["min_room_size"] = max(1, int(data["min_room_size"]))
    if data.has("max_room_size"):
        result["max_room_size"] = max(result["min_room_size"], int(data["max_room_size"]))
    else:
        result["max_room_size"] = max(result["min_room_size"], result["max_room_size"])
    if data.has("max_rooms"):
        result["max_rooms"] = max(1, int(data["max_rooms"]))
    if data.has("margin"):
        result["margin"] = max(0, int(data["margin"]))
    if data.has("floor_height"):
        result["floor_height"] = max(1, int(data["floor_height"]))
    if data.has("num_floors"):
        result["num_floors"] = max(1, int(data["num_floors"]))
    if data.has("doors_per_room"):
        result["doors_per_room"] = int(data["doors_per_room"])
    if data.has("add_roof"):
        result["add_roof"] = bool(data["add_roof"])
    return result

func _on_new_button_pressed() -> void:
    if current_library == null:
        _set_instruction("Load a module library before starting WFC.")
        return
    _ensure_wfc_config_initialized()
    var grid_size: Vector3i = wfc_last_config.get("grid_size", Vector3i(5, 3, 5))
    var cell_size: Vector3 = wfc_last_config.get("cell_size", _get_cell_size_from_library())
    var config: Dictionary = _copy_wfc_config(wfc_last_config)
    config["grid_size"] = grid_size
    config["cell_size"] = cell_size
    wfc_last_config = _copy_wfc_config(config)
    _start_wfc_session(config)

func _on_edit_button_pressed() -> void:
    if current_library == null:
        _set_instruction("Load a module library before editing WFC settings.")
        return
    _ensure_wfc_config_initialized()
    var grid_size: Vector3i = wfc_last_config.get("grid_size", Vector3i(5, 3, 5))
    var cell_size: Vector3 = wfc_last_config.get("cell_size", _get_cell_size_from_library())
    wfc_setup_dialog.open_with_defaults(grid_size, cell_size)

func _on_wfc_setup_confirmed(config: Dictionary) -> void:
    wfc_last_config = _copy_wfc_config(config)
    _reset_wfc_session()
    var cell_size: Vector3 = wfc_last_config.get("cell_size", _get_cell_size_from_library())
    var grid_size: Vector3i = wfc_last_config.get("grid_size", Vector3i.ZERO)
    _update_grid_spacing(cell_size)
    _update_grid_bounds(grid_size, cell_size)
    _update_wfc_root_offset(grid_size, cell_size)
    _set_instruction("Preview settings applied. Press Step or Solve to begin.")
    _update_buttons_state()

func _start_wfc_session(config: Dictionary) -> void:
    _reset_wfc_session()
    var grid_size: Vector3i = config.get("grid_size", Vector3i(4, 3, 4))
    var cell_size: Vector3 = config.get("cell_size", _get_cell_size_from_library())
    wfc_cell_size = cell_size
    wfc_grid = WfcGrid.new(grid_size, current_library.tiles)
    wfc_solver = WfcSolver.new(wfc_grid)
    var solver_config: WfcSolverConfig = _extract_solver_config(config)
    if solver_config:
        var structural_config = config.get("structural_constraints", {})
        solver_config.apply_to_solver(wfc_solver, structural_config)
    wfc_solver.start_interactive(true)
    wfc_session_active = true
    preview_mode = PreviewMode.WFC
    _set_instruction("WFC session ready. Press Step or Solve.")
    _clear_children(base_tile_root)
    _clear_children(socket_preview_root)
    _sync_wfc_visuals()
    _update_grid_spacing(cell_size)
    _update_grid_bounds(grid_size, cell_size)
    _update_wfc_root_offset(grid_size, cell_size)
    _focus_camera_on_grid(grid_size, cell_size)
    _update_buttons_state()

func _reset_wfc_session(clear_visuals: bool = true) -> void:
    _release_wfc_job(true)
    wfc_session_active = false
    wfc_solver = null
    wfc_grid = null
    wfc_waiting_for_choice.clear()
    _clear_decision_highlight(clear_visuals)
    if clear_visuals:
        wfc_cell_nodes.clear()
        _clear_children(wfc_root)
    _set_step_options_visible(false)
    _update_buttons_state()

func _ensure_wfc_session_ready() -> bool:
    if wfc_session_active and wfc_solver != null:
        return true
    if current_library == null:
        _set_instruction("Load a module library before running WFC.")
        return false
    _ensure_wfc_config_initialized()
    var grid_size: Vector3i = wfc_last_config.get("grid_size", Vector3i(5, 3, 5))
    var cell_size: Vector3 = wfc_last_config.get("cell_size", _get_cell_size_from_library())
    var config: Dictionary = _copy_wfc_config(wfc_last_config)
    config["grid_size"] = grid_size
    config["cell_size"] = cell_size
    wfc_last_config = _copy_wfc_config(config)
    _start_wfc_session(config)
    return wfc_session_active and wfc_solver != null


func _on_step_button_pressed() -> void:
    if not _ensure_wfc_session_ready():
        return
    var result := wfc_solver.advance_until_choice()
    _sync_wfc_visuals()
    _handle_solver_result(result)

func _on_solve_button_pressed() -> void:
    if not _ensure_wfc_session_ready():
        return
    _set_step_options_visible(false)
    _start_async_solve()

func _start_async_solve() -> void:
    if wfc_solver == null:
        return
    if _is_job_active():
        return
    var job: WfcSolveJob = wfc_solver.solve_async(false)
    if job == null:
        _finish_session(false, "Unable to create solve job.")
        return
    wfc_solve_job = job
    if not job.progress.is_connected(_on_wfc_job_progress):
        job.progress.connect(_on_wfc_job_progress)
    if not job.completed.is_connected(_on_wfc_job_completed):
        job.completed.connect(_on_wfc_job_completed)
    if not job.cancelled.is_connected(_on_wfc_job_cancelled):
        job.cancelled.connect(_on_wfc_job_cancelled)
    var started := job.start()
    if not started:
        _release_wfc_job()
        _finish_session(false, "Failed to start solve job.")
        return
    _show_job_status_ui(true)
    _update_job_progress_bar(0.0)
    _update_job_status_label("Initializing solve...")
    if job_cancel_button:
        job_cancel_button.disabled = false
    _set_instruction("Solving in background... Click Cancel to abort.")
    _update_buttons_state()

func _on_job_cancel_pressed() -> void:
    _cancel_wfc_job()

func _cancel_wfc_job() -> void:
    if not _is_job_active():
        return
    wfc_solve_job.cancel()
    _update_job_status_label("Cancelling solve...")
    if job_cancel_button:
        job_cancel_button.disabled = true

func _on_wfc_job_progress(data: Dictionary) -> void:
    _wfc_job_progress = data.duplicate(true)
    var percent := clamp(float(data.get("progress", 0.0)), 0.0, 100.0)
    _update_job_progress_bar(percent)
    var collapsed := int(data.get("cells_collapsed", 0))
    var total := max(1, int(data.get("total_cells", 1)))
    var iterations := int(data.get("iterations", 0))
    var elapsed_ms := int(data.get("elapsed_ms", 0))
    var elapsed_seconds := float(elapsed_ms) / 1000.0
    var status := "%.1f%% — %d/%d cells (iter %d, %.1fs)" % [percent, collapsed, total, iterations, elapsed_seconds]
    _update_job_status_label(status)

func _on_wfc_job_completed(success: bool) -> void:
    _update_job_progress_bar(100.0)
    _update_job_status_label("Finalizing...")
    _release_wfc_job()
    _sync_wfc_visuals()
    if success:
        _finish_session(true, "Solve complete.")
    else:
        _finish_session(false, "Solver failed to complete.")

func _on_wfc_job_cancelled() -> void:
    _release_wfc_job()
    _finish_session(false, "Solve cancelled.")

func _release_wfc_job(request_cancel: bool = false) -> void:
    if wfc_solve_job:
        if request_cancel and wfc_solve_job.is_running():
            wfc_solve_job.cancel()
        if wfc_solve_job.progress.is_connected(_on_wfc_job_progress):
            wfc_solve_job.progress.disconnect(_on_wfc_job_progress)
        if wfc_solve_job.completed.is_connected(_on_wfc_job_completed):
            wfc_solve_job.completed.disconnect(_on_wfc_job_completed)
        if wfc_solve_job.cancelled.is_connected(_on_wfc_job_cancelled):
            wfc_solve_job.cancelled.disconnect(_on_wfc_job_cancelled)
        wfc_solve_job = null
    _show_job_status_ui(false)
    _update_buttons_state()

func _is_job_active() -> bool:
    return wfc_solve_job != null and wfc_solve_job.is_running()

func _show_job_status_ui(visible: bool) -> void:
    if job_status_container:
        job_status_container.visible = visible
    if job_cancel_button:
        job_cancel_button.disabled = not visible
    if not visible:
        _update_job_progress_bar(0.0)
        _update_job_status_label("Preparing solve...")

func _update_job_progress_bar(value: float) -> void:
    if job_progress_bar:
        job_progress_bar.value = clamp(value, job_progress_bar.min_value, job_progress_bar.max_value)

func _update_job_status_label(text: String) -> void:
    if job_status_label:
        job_status_label.text = text

func _handle_solver_result(result: Dictionary) -> void:
    var status := String(result.get("status", ""))
    if status == "complete":
        _finish_session(true, "Solve complete.")
    elif status == "error":
        _finish_session(false, result.get("message", "Solver error."))
    elif status == "choice":
        wfc_waiting_for_choice = result.duplicate(true)
        _show_decision_highlight(result.get("cell_position", Vector3i.ZERO))
        _show_step_options(result)
        _set_instruction("Select a tile for cell %s" % str(result.get("cell_position", Vector3i.ZERO)))
        step_button.disabled = true
        solve_button.disabled = true
    else:
        _set_instruction("Continuing WFC...")
        _update_buttons_state()

func _show_step_options(data: Dictionary) -> void:
    _set_step_options_visible(true)
    _clear_step_option_buttons()
    var variants: Array = data.get("variants", [])
    for i in range(variants.size()):
        var variant: Dictionary = variants[i]
        var tile: Tile = variant.get("tile")
        var label := tile.name if tile else "Unknown"
        var rotation := int(variant.get("rotation_degrees", 0))
        var button := Button.new()
        button.text = "%s (%d°)" % [label, rotation]
        button.custom_minimum_size.x = 140
        button.pressed.connect(_on_step_option_pressed.bind(i))
        step_options_container.add_child(button)

func _clear_step_option_buttons() -> void:
    for child in step_options_container.get_children():
        child.queue_free()

func _set_step_options_visible(visible: bool) -> void:
    step_options_container.visible = visible
    if step_options_scroll:
        step_options_scroll.visible = visible
    if not visible:
        wfc_waiting_for_choice.clear()
        _clear_decision_highlight()

func _on_step_option_pressed(index: int) -> void:
    if wfc_solver == null or wfc_waiting_for_choice.is_empty():
        return
    var decision_id := wfc_waiting_for_choice.get("decision_id", 0)
    var result := wfc_solver.commit_choice(decision_id, index)
    _sync_wfc_visuals()
    _set_step_options_visible(false)
    var status := String(result.get("status", "ok"))
    if status == "complete":
        _finish_session(true, "Solve complete.")
    elif status == "error":
        _finish_session(false, result.get("message", "Solver error."))
    else:
        _set_instruction("Choice applied. Press Step to continue.")
        _update_buttons_state()

func _finish_session(success: bool, message: String = "") -> void:
    if success:
        _set_instruction(message if message else "WFC finished successfully.")
    else:
        _set_instruction(message if message else "WFC failed.")
    wfc_session_active = false
    _show_job_status_ui(false)
    _set_step_options_visible(false)
    _update_buttons_state()

func _sync_wfc_visuals() -> void:
    if wfc_grid == null:
        return
    var seen: Dictionary = {}
    for cell in wfc_grid.get_all_cells():
        var key := _cell_key(cell.position)
        if cell.is_collapsed():
            seen[key] = true
            if not wfc_cell_nodes.has(key):
                var variant := cell.get_variant()
                var instance := _instantiate_variant(variant)
                if instance:
                    var tile: Tile = variant.get("tile")
                    var rotation := variant.get("rotation_degrees", 0)
                    var cell_size: Vector3 = _get_active_wfc_cell_size()
                    var base_position := WfcHelper.grid_to_world(cell.position, cell_size)
                    if tile:
                        base_position += WfcHelper.get_rotation_offset_world(tile.size, rotation, cell_size)
                    instance.position = base_position
                    wfc_root.add_child(instance)
                    instance.owner = null
                    wfc_cell_nodes[key] = instance
        else:
            _remove_cell_visual(key)
    for key in wfc_cell_nodes.keys():
        if not seen.has(key):
            _remove_cell_visual(key)

func _remove_cell_visual(key: String) -> void:
    var node: Node3D = wfc_cell_nodes.get(key)
    if node:
        node.queue_free()
    wfc_cell_nodes.erase(key)

func _instantiate_variant(variant: Dictionary) -> Node3D:
    var tile: Tile = variant.get("tile")
    if tile == null:
        return null
    var instance := _instantiate_tile(tile)
    if instance:
        instance.rotation_degrees.y = variant.get("rotation_degrees", 0)
    return instance

func _instantiate_tile(tile: Tile) -> Node3D:
    var root: Node = null
    if tile.scene:
        root = tile.scene.instantiate()
    elif tile.mesh:
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.mesh = tile.mesh
        root = mesh_instance
    else:
        var placeholder := Node3D.new()
        root = placeholder
    return _ensure_node3d(root)

func _ensure_node3d(node: Node) -> Node3D:
    if node is Node3D:
        return node
    var wrapper := Node3D.new()
    if node:
        wrapper.add_child(node)
        node.owner = null
    return wrapper

func _focus_camera_on(target: Node3D) -> void:
    if camera_controller == null or target == null:
        return
    var aabb := _compute_aabb(target)
    var center := aabb.get_center()
    var radius := aabb.size.length() * 0.6
    if radius <= 0.01:
        radius = 2.0
    camera_controller.orbit_target = center
    camera_controller.orbit_distance = radius * 1.4

func _focus_camera_on_grid(grid_size: Vector3i, cell_size: Vector3) -> void:
    if camera_controller == null:
        return
    var world_extent := Vector3(grid_size) * cell_size
    var center := world_extent * 0.5
    var radius := max(world_extent.length() * 0.3, 5.0)
    camera_controller.orbit_target = center
    camera_controller.orbit_distance = radius
    _align_camera_to_direction(Vector3(0.6, 0.6, -0.9))

func _compute_aabb(node: Node3D, parent: Transform3D = Transform3D.IDENTITY) -> AABB:
    var transform := parent * node.transform
    var aabb := AABB(transform.origin, Vector3.ZERO)
    var initialized := false
    if node is MeshInstance3D:
        var mesh: Mesh = node.mesh
        if mesh:
            var mesh_aabb: AABB = node.get_aabb()
            var corners := [
                mesh_aabb.position,
                mesh_aabb.position + Vector3(mesh_aabb.size.x, 0, 0),
                mesh_aabb.position + Vector3(0, mesh_aabb.size.y, 0),
                mesh_aabb.position + Vector3(0, 0, mesh_aabb.size.z),
                mesh_aabb.position + mesh_aabb.size
            ]
            for corner in corners:
                var world_point: Vector3 = transform * corner
                if not initialized:
                    aabb = AABB(world_point, Vector3.ZERO)
                    initialized = true
                else:
                    aabb = aabb.expand(world_point)
    for child in node.get_children():
        if child is Node3D:
            var child_aabb := _compute_aabb(child, transform)
            if child_aabb.size != Vector3.ZERO:
                if not initialized:
                    aabb = child_aabb
                    initialized = true
                else:
                    aabb = aabb.merge(child_aabb)
    if not initialized:
        aabb = AABB(transform.origin - Vector3.ONE * 0.5, Vector3.ONE)
    return aabb

func _align_camera_to_direction(direction: Vector3) -> void:
    if camera_controller == null:
        return
    camera_controller.align_to_direction(direction)

func _align_camera_default() -> void:
    _align_camera_to_direction(DEFAULT_VIEW_DIRECTION)

func _align_camera_to_socket(direction: Vector3i) -> void:
    var view := _socket_direction_to_view(direction)
    _align_camera_to_direction(view)

func _socket_direction_to_view(direction: Vector3i) -> Vector3:
    var view := Vector3(direction)
    if view.length() < 0.1:
        return DEFAULT_VIEW_DIRECTION
    if abs(view.y) < 0.1:
        view.y = 0.35
    else:
        if abs(view.z) < 0.1:
            view.z = -0.45 * sign(view.y if view.y != 0 else 1)
        view.x *= 0.4
    return view

func _clear_children(node: Node) -> void:
    if node == null:
        return
    for child in node.get_children():
        child.queue_free()

func _show_decision_highlight(cell_position: Vector3i) -> void:
    if wfc_root == null:
        return
    var cell_size := _get_active_wfc_cell_size()
    if wfc_decision_highlight == null or not is_instance_valid(wfc_decision_highlight):
        wfc_decision_highlight = MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = cell_size
        wfc_decision_highlight.mesh = mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.9, 0.6, 0.05, 0.35)
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        wfc_decision_highlight.material_override = material
        wfc_decision_highlight.visible = false
        wfc_root.add_child(wfc_decision_highlight)
        wfc_decision_highlight.owner = null
    var box_mesh: BoxMesh = wfc_decision_highlight.mesh
    if box_mesh:
        box_mesh.size = cell_size
    wfc_decision_highlight.position = WfcHelper.grid_to_world(cell_position, cell_size) + cell_size * 0.5
    wfc_decision_highlight.visible = true

func _clear_decision_highlight(free_node: bool = false) -> void:
    if wfc_decision_highlight == null:
        return
    if not is_instance_valid(wfc_decision_highlight):
        wfc_decision_highlight = null
        return
    if free_node:
        wfc_decision_highlight.queue_free()
        wfc_decision_highlight = null
    else:
        wfc_decision_highlight.visible = false

func _set_instruction(text: String) -> void:
    if instructions_label:
        instructions_label.text = text

func _update_buttons_state() -> void:
    var has_library := current_library != null
    var job_running := _is_job_active()
    if new_button:
        new_button.disabled = not has_library or job_running
    if edit_button:
        edit_button.disabled = not has_library or job_running
    var waiting_choice := not wfc_waiting_for_choice.is_empty()
    var can_step := has_library and not waiting_choice and not job_running
    if step_button:
        step_button.disabled = not can_step
    if solve_button:
        solve_button.disabled = not has_library or waiting_choice or job_running

func _get_cell_size_from_library() -> Vector3:
    if current_library and current_library.cell_world_size != Vector3.ZERO:
        return current_library.cell_world_size
    return Vector3(2, 2, 2)

func _get_active_wfc_cell_size() -> Vector3:
    if wfc_cell_size != Vector3.ZERO:
        return wfc_cell_size
    return _get_configured_cell_size()

func _get_configured_cell_size() -> Vector3:
    var configured: Vector3 = wfc_last_config.get("cell_size", Vector3.ZERO)
    if configured != Vector3.ZERO:
        return configured
    return _get_cell_size_from_library()

func _update_grid_spacing(cell_size: Vector3) -> void:
    if grid_node == null:
        return
    var avg := max(0.1, (cell_size.x + cell_size.z) * 0.5)
    grid_node.grid_spacing = avg

func _update_grid_bounds(grid_size: Vector3i, cell_size: Vector3) -> void:
    if grid_node == null:
        return
    var size := Vector3(
        max(0.0, float(max(grid_size.x, 0)) * abs(cell_size.x)),
        max(0.0, float(max(grid_size.y, 0)) * abs(cell_size.y)),
        max(0.0, float(max(grid_size.z, 0)) * abs(cell_size.z))
    )
    grid_node.set_world_bounds(size)

func _update_wfc_root_offset(grid_size: Vector3i, cell_size: Vector3) -> void:
    if wfc_root == null:
        return
    var extent := Vector3(
        max(0.0, float(max(grid_size.x, 0)) * abs(cell_size.x)),
        0.0,
        max(0.0, float(max(grid_size.z, 0)) * abs(cell_size.z))
    )
    wfc_root.position.x = -extent.x * 0.5
    wfc_root.position.z = -extent.z * 0.5

func _cell_key(pos: Vector3i) -> String:
    return "%d_%d_%d" % [pos.x, pos.y, pos.z]

func _pick_weighted_index(variants: Array) -> int:
    var total := 0.0
    for variant in variants:
        total += float(variant.get("weight", 1.0))
    if total <= 0.0:
        return 0
    var random_value := randf() * total
    var cumulative := 0.0
    for i in range(variants.size()):
        cumulative += float(variants[i].get("weight", 1.0))
        if cumulative >= random_value:
            return i
    return variants.size() - 1
