@tool
class_name Tile extends Resource

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

@export var name: String = ""
@export var mesh: Mesh = null
@export var scene: PackedScene = null
@export var size: Vector3 = Vector3.ONE  ## Size of the tile in grid units (default 1x1x1)
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

func ensure_all_sockets() -> void:
    """
    Ensure this tile has exactly 6 sockets (one for each cardinal direction).
    Creates missing sockets with socket_id = 'none'.
    """
    var directions = [
        Vector3i.UP,      # (0, 1, 0)
        Vector3i.DOWN,    # (0, -1, 0)
        Vector3i.RIGHT,   # (1, 0, 0)
        Vector3i.LEFT,    # (-1, 0, 0)
        Vector3i.FORWARD, # (0, 0, -1)
        Vector3i.BACK     # (0, 0, 1)
    ]
    
    for direction in directions:
        var existing = get_sockets_in_direction(direction)
        if existing.is_empty():
            # Create a 'none' socket for this direction
            var new_socket = Socket.new()
            new_socket.direction = direction
            new_socket.socket_id = "none"
            add_socket(new_socket)

func get_socket_by_direction(direction: Vector3i) -> Socket:
    """
    Get the socket for a specific direction.
    
    Args:
        direction: The direction to get the socket for
    
    Returns:
        The Socket instance for that direction, or null if not found
    """
    var sockets_in_dir = get_sockets_in_direction(direction)
    if not sockets_in_dir.is_empty():
        return sockets_in_dir[0]
    return null
