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
