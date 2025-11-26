@tool
class_name ImportDialog extends ConfirmationDialog

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const TileImporter = preload("res://addons/auto_structured/core/io/tile_importer.gd")
const ImportTileDetailScene = preload("res://addons/auto_structured/ui/controls/import_controls/tile_detail.tscn")
const ImportTileDetail = preload("res://addons/auto_structured/ui/controls/import_controls/tile_detail.gd")

signal tiles_imported(tiles: Array[Tile])

@onready var tilesContLabel: Label = %TilesContLabel
@onready var selectAllButton: Button = %SelectAllButton
@onready var deselectAllButton: Button = %DeselectAllButton

@onready var tilesListContainer: VBoxContainer = %TilesListContainer

var _tile_details: Array[ImportTileDetail] = []
var _library: ModuleLibrary = null
var _file_paths: PackedStringArray = []

func _ready() -> void:
    """Initialize the dialog."""
    confirmed.connect(_on_confirmed)
    
    if selectAllButton:
        selectAllButton.pressed.connect(_on_select_all)
    
    if deselectAllButton:
        deselectAllButton.pressed.connect(_on_deselect_all)

## ============================================================================
## Public API
## ============================================================================

func setup(file_paths: PackedStringArray, library: ModuleLibrary) -> void:
    """Setup the import dialog with files to import."""
    print("ImportDialog.setup() called with %d files" % file_paths.size())
    _file_paths = file_paths
    _library = library
    
    if library:
        print("ImportDialog: Library is: %s" % library.library_name)
    else:
        push_error("ImportDialog: Library is null!")
    # Wait for the dialog to be ready if it isn't yet
    if not is_node_ready():
        await ready
    
    _populate_tile_list()
    _update_counts()

## ============================================================================
## Tile List Management
## ============================================================================

func _populate_tile_list() -> void:
    """Create ImportTileDetail controls for each file."""
    # Clear existing
    for detail in _tile_details:
        detail.queue_free()
    _tile_details.clear()
    
    if not tilesListContainer:
        push_error("ImportDialog: tilesListContainer is null")
        return
    
    print("ImportDialog: Populating %d files" % _file_paths.size())
    
    # Create detail for each file
    for file_path in _file_paths:
        print("ImportDialog: Creating detail for: %s" % file_path)
        var detail = ImportTileDetailScene.instantiate() as ImportTileDetail
        if detail:
            tilesListContainer.add_child(detail)
            detail.setup(file_path, _library)
            _tile_details.append(detail)
            if detail.has_signal("selection_changed"):
                detail.selection_changed.connect(_on_tile_check_changed)
        else:
            push_error("ImportDialog: Failed to instantiate tile detail for %s" % file_path)
    
    print("ImportDialog: Created %d tile details" % _tile_details.size())

func _update_counts() -> void:
    """Update the tile count and selected count labels."""
    var selected_count = _get_selected_count()
    
    if tilesContLabel:
        var tile_text = "Tile" if _tile_details.size() == 1 else "Tiles"
        tilesContLabel.text = "%s (%d)" % [tile_text, _tile_details.size()]

    var ok_button := get_ok_button()
    if ok_button:
        ok_button.disabled = selected_count == 0

func _get_selected_count() -> int:
    """Get the number of selected tiles."""
    var count = 0
    for detail in _tile_details:
        if detail.is_checked():
            count += 1
    return count

func _on_select_all() -> void:
    """Select all tiles."""
    for detail in _tile_details:
        detail.set_checked(true)
    _update_counts()

func _on_deselect_all() -> void:
    """Deselect all tiles."""
    for detail in _tile_details:
        detail.set_checked(false)
    _update_counts()

func _on_tile_check_changed(_toggled: bool) -> void:
    """Handle tile checkbox change."""
    _update_counts()

## ============================================================================
## Import Execution
## ============================================================================

func _on_confirmed() -> void:
    """Handle import confirmation."""
    if not _library:
        push_error("No library provided for import")
        return
    
    if _get_selected_count() == 0:
        push_warning("No tiles selected for import")
        return
    
    var imported_tiles: Array[Tile] = []
    
    for detail in _tile_details:
        if not detail.is_checked():
            continue
        var config = detail.get_config()
        var tile = _import_tile_from_config(config)
        
        if tile:
            imported_tiles.append(tile)
    
    if imported_tiles.size() > 0:
        tiles_imported.emit(imported_tiles)
        print("Imported %d tiles" % imported_tiles.size())

func _import_tile_from_config(config: Dictionary) -> Tile:
    """Import a single tile from configuration."""
    var file_path = config.get("file_path", "")
    if file_path.is_empty():
        return null
    
    # Create import options
    var options = TileImporter.ImportOptions.new()
    options.auto_generate_sockets = false  # We'll ensure GUID sockets after import
    options.name_from_filename = false  # Use custom name
    options.add_filename_as_tag = false  # Use custom tags
    
    # Import the tile
    var tile = TileImporter.import_file(file_path, _library, options)
    if not tile:
        push_error("Failed to import: %s" % file_path)
        return null
    
    # Apply configuration
    tile.name = config.get("tile_name", file_path.get_file().get_basename())
    tile.size = config.get("size", Vector3i.ONE)
    
    # Apply tags
    var tags = config.get("tags", [])
    for tag in tags:
        tile.add_tag(tag)
    
    # Ensure tile has default sockets using GUID flow
    tile.ensure_all_sockets(_library)
    tile.rotation_symmetry = config.get("rotation_symmetry", Tile.RotationSymmetry.AUTO)
    
    return tile
