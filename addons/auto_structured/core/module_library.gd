class_name ModuleLibrary extends Resource

const Tile = preload("res://addons/auto_structured/core/tile.gd")

@export var library_name: String = "My Building Set"
@export var tiles: Array[Tile] = []

func get_tile_by_name(name: String) -> Tile:
    for tile in tiles:
        if tile.name == name:
            return tile
    return null

func get_tiles_with_tag(tag: String) -> Array[Tile]:
    return tiles.filter(func(t): return t.tags.has(tag))
