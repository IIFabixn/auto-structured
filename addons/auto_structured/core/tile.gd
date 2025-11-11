@tool
class_name Tile extends Resource

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

@export var name: String = ""
@export var mesh: Mesh = null
@export var scene: PackedScene = null
@export var tags: Array[String] = []
@export var requirements: Array[Requirement] = []
@export var sockets: Array[Socket] = []

func get_sockets_in_direction(direction: Vector3i) -> Array[Socket]:
    """
    Get all sockets on this tile that face the specified direction.

    Args:
        direction: The direction to filter sockets by

    Returns:
        An array of Socket instances facing the given direction
    """
    var result: Array[Socket] = []
    for socket in sockets:
        if socket.direction == direction:
            result.append(socket)
    return result

func add_tag(tag: String) -> void:
    """
    Add a tag to this tile if it doesn't already exist.

    Args:
        tag: The tag string to add
    """
    if tag in tags:
        return
    var tags_copy: Array[String] = []
    tags_copy.assign(tags)
    tags_copy.append(tag)
    tags = tags_copy

func remove_tag(tag: String) -> void:
    """
    Remove a tag from this tile if it exists.
    Args:
        tag: The tag string to remove
    """
    if tag not in tags:
        return
    var tags_copy: Array[String] = []
    tags_copy.assign(tags)
    tags_copy.erase(tag)
    tags = tags_copy

func add_socket(socket: Socket) -> void:
    """
    Add a socket to this tile.
    Args:
        socket: The Socket instance to add
    """
    var sockets_copy: Array[Socket] = []
    sockets_copy.assign(sockets)
    sockets_copy.append(socket)
    sockets = sockets_copy

func remove_socket(socket: Socket) -> void:
    """
    Remove a socket from this tile.
    Args:
        socket: The Socket instance to remove
    """
    if socket not in sockets:
        return
    var sockets_copy: Array[Socket] = []
    sockets_copy.assign(sockets)
    sockets_copy.erase(socket)
    sockets = sockets_copy
