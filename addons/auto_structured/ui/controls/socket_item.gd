@tool
class_name SocketItem extends FoldableContainer

signal socket_changed(new_socket: Socket)
signal socket_deleted(socket: Socket)

const Socket = preload("res://addons/auto_structured/core/socket.gd")


@export var socket: Socket:
    set(value):
        socket = value
        if name_edit and socket:
            name_edit.text = socket.socket_id
        if socket:
            socket_changed.emit(socket)
    get:
        return socket

var name_edit: LineEdit
var direction_option: OptionButton
var popup_menu: PopupMenu

func _ready() -> void:
    name_edit = get_node_or_null("VBoxContainer/NameEdit")
    direction_option = get_node_or_null("VBoxContainer/DirectionContainer/DirectionOption")
    popup_menu = get_node_or_null("PopupMenu")
    if popup_menu:
        popup_menu.id_pressed.connect(_on_delete_selected)

    update_title()
    if socket and name_edit:
        name_edit.text = socket.socket_id

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            var mouse_pos = get_viewport().get_mouse_position()
            popup_menu.popup(Rect2(mouse_pos, Vector2.ZERO))


func update_title() -> void:
    if not socket:
        return

    title = "Socket: %s" % get_direction_name(socket.direction)
    if name_edit:
        name_edit.text = socket.socket_id

func get_direction_name(direction: Vector3i) -> String:
    var direction_names = {
        Vector3i(1, 0, 0): "Right",
        Vector3i(-1, 0, 0): "Left",
        Vector3i(0, 1, 0): "Up",
        Vector3i(0, -1, 0): "Down",
        Vector3i(0, 0, 1): "Forward",
        Vector3i(0, 0, -1): "Back"
    }

    return direction_names.get(direction, "Unknown")

func set_direction(value: int) -> void:
    if not socket:
        return

    match value:
        0:
            pass
        1:
            socket.direction = Vector3i(1, 0, 0)  # Right
        2:
            socket.direction = Vector3i(-1, 0, 0)  # Left
        3:
            socket.direction = Vector3i(0, 1, 0)  # Up
        4:
            socket.direction = Vector3i(0, -1, 0)  # Down
        5:
            socket.direction = Vector3i(0, 0, 1)  # Forward
        6:
            socket.direction = Vector3i(0, 0, -1)  # Back
    update_title()

func _on_delete_selected(id: int) -> void:
    if id == 0:
        socket_deleted.emit(socket)
        queue_free()