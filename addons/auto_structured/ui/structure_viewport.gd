@tool
class_name StructureViewport extends Control

@onready var module_library_control: ModuleLibraryControl = %ModuleLibraryControl
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

func _ready() -> void:
    module_library_control.tile_selected.connect(_on_module_tile_selected)

func _on_module_tile_selected(tile: Tile) -> void:
    details_panel.display_tile_details(tile)
