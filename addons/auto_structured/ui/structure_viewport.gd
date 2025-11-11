@tool
class_name StructureViewport extends Control

@onready var module_library_control: ModuleLibraryControl = %ModuleLibraryControl
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

func _ready() -> void:
    module_library_control.tile_selected.connect(_on_module_tile_selected)
    details_panel.closed.connect(_on_details_panel_closed)
    details_panel.tile_modified.connect(_on_tile_modified)


func _on_module_tile_selected(tile: Tile) -> void:
    details_panel.display_tile_details(tile)
    viewport_panel.display_tile_preview(tile)


func _on_details_panel_closed() -> void:
    viewport_panel.clear_structure()
    module_library_control.unselect_tile()


func _on_tile_modified(_tile: Tile) -> void:
    module_library_control.save_current_library()
