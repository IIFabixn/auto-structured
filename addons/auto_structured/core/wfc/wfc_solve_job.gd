@tool
class_name WfcSolveJob extends RefCounted

signal progress(data: Dictionary)
signal completed(success: bool)
signal cancelled

var solver
var _thread: Thread = null
var _status: String = "idle"
var _result: bool = false
var _running: bool = false
var _should_cancel: bool = false
var _finalized: bool = false
var _prev_progress_callback: Callable = Callable()

func _init(wfc_solver) -> void:
    solver = wfc_solver

func start() -> bool:
    if solver == null:
        push_error("WfcSolveJob: Cannot start without a solver instance")
        return false
    if _running:
        push_warning("WfcSolveJob: Already running")
        return false
    _prev_progress_callback = solver.progress_callback
    solver.progress_callback = Callable(self, "_handle_progress")
    solver.clear_cancel_request()
    _should_cancel = false
    _finalized = false
    _thread = Thread.new()
    var err = _thread.start(Callable(self, "_thread_main"))
    if err != OK:
        push_error("WfcSolveJob: Failed to start solver thread (%s)" % err)
        solver.progress_callback = _prev_progress_callback
        _prev_progress_callback = Callable()
        _thread = null
        return false
    _running = true
    _status = "running"
    return true

func cancel() -> void:
    if not _running:
        return
    _should_cancel = true
    solver.request_cancel()

func wait_to_finish() -> bool:
    if _thread:
        var value = _thread.wait_to_finish()
        _thread = null
        _finalize_from_result(value)
    return _result

func get_status() -> String:
    return _status

func is_running() -> bool:
    return _running

func _thread_main() -> bool:
    var success = solver.solve()
    call_deferred("_on_thread_join_ready")
    return success

func _on_thread_join_ready() -> void:
    if _thread == null:
        return
    var value = _thread.wait_to_finish()
    _thread = null
    _finalize_from_result(value)

func _finalize_from_result(value: bool) -> void:
    if _finalized:
        return
    _finalized = true
    _running = false
    _result = value
    solver.progress_callback = _prev_progress_callback
    _prev_progress_callback = Callable()
    var cancelled: bool = _should_cancel or solver.was_solve_cancelled()
    solver.clear_cancel_request()
    if cancelled:
        _status = "cancelled"
        emit_signal("cancelled")
    else:
        _status = "completed" if value else "failed"
        emit_signal("completed", value)

func _handle_progress(data: Dictionary) -> void:
    call_deferred("_emit_progress", data)
    if _prev_progress_callback.is_valid():
        call_deferred("_relay_previous_progress", data)

func _emit_progress(data: Dictionary) -> void:
    emit_signal("progress", data)

func _relay_previous_progress(data: Dictionary) -> void:
    if _prev_progress_callback.is_valid():
        _prev_progress_callback.call(data)
