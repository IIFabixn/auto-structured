@tool
class_name DetailsPanel extends Control

const SocketItemScene = preload("res://addons/auto_structured/ui/controls/socket_item.tscn")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

@onready var sockets_container = %SocketsContainer
@onready var new_socket_id_edit = %NewSocketIDEdit
@onready var add_socket_button = %AddSocketButton
@onready var name_label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/NameLabel

func _ready() -> void:
    add_socket_button.pressed.connect(_on_add_socket_button_pressed)

func _on_add_socket_button_pressed() -> void:
    var socket_id = new_socket_id_edit.text.strip_edges()
    if socket_id == "":
        return
    add_socket_item(socket_id)
    new_socket_id_edit.text = ""

func clear_sockets() -> void:
    for child in sockets_container.get_children():
        child.queue_free()

func add_socket_item(id: String) -> void:
    var socket_item = SocketItemScene.instantiate()
    sockets_container.add_child(socket_item)
    var socket = Socket.new()
    socket.socket_id = id
    socket_item.socket = socket

func close_details() -> void:
    hide()

func display_tile_details(tile: Tile) -> void:
    show()
    clear_sockets()
    name_label.text = "Tile: %s" % tile.name
    for socket in tile.sockets:
        add_socket_item(socket.socket_id)
