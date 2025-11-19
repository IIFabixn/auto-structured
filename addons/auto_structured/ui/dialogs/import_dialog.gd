@tool
class_name ImportDialog extends ConfirmationDialog

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const TileImporter = preload("res://addons/auto_structured/core/io/tile_importer.gd")
const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")
const BatchControlsScene = preload("res://addons/auto_structured/ui/controls/import_controls/batch_controls.tscn")
const BatchControls = preload("res://addons/auto_structured/ui/controls/import_controls/batch_controls.gd")
const ImportTileDetailSene = preload("res://addons/auto_structured/ui/controls/import_controls/tile_detail.tscn")
const ImportTileDetail = preload("res://addons/auto_structured/ui/controls/import_controls/tile_detail.gd")

signal tiles_imported(tiles: Array[Tile])

@onready var batchControls: BatchControls = %BatchControls

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
    
    if batchControls:
        if batchControls.applyAllButton:
            batchControls.applyAllButton.pressed.connect(_on_apply_to_all)
        if batchControls.applySelectedButton:
            batchControls.applySelectedButton.pressed.connect(_on_apply_to_selected)

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
    
    # Setup batch controls with library reference
    if batchControls:
        batchControls.setup(library)
    else:
        push_error("ImportDialog: batchControls is null!")
    
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
        var detail = ImportTileDetailSene.instantiate() as ImportTileDetail
        if detail:
            tilesListContainer.add_child(detail)
            detail.setup(file_path, _library)
            _tile_details.append(detail)
            
            # Connect checkbox signal to update counts
            if detail.checkedCheckBox:
                detail.checkedCheckBox.toggled.connect(_on_tile_check_changed)
            else:
                push_warning("ImportDialog: Tile detail missing checkedCheckBox")
        else:
            push_error("ImportDialog: Failed to instantiate tile detail for %s" % file_path)
    
    print("ImportDialog: Created %d tile details" % _tile_details.size())

func _update_counts() -> void:
    """Update the tile count and selected count labels."""
    var selected_count = _get_selected_count()
    
    if tilesContLabel:
        var tile_text = "Tile" if _tile_details.size() == 1 else "Tiles"
        tilesContLabel.text = "%s (%d)" % [tile_text, _tile_details.size()]
    
    if batchControls and batchControls.applySelectedButton:
        if selected_count > 0:
            batchControls.applySelectedButton.text = "Apply to Selected (%d)" % selected_count
            batchControls.applySelectedButton.disabled = false
        else:
            batchControls.applySelectedButton.text = "Apply to Selected"
            batchControls.applySelectedButton.disabled = true

func _get_selected_count() -> int:
    """Get the number of selected tiles."""
    var count = 0
    for detail in _tile_details:
        if detail.is_checked():
            count += 1
    return count

## ============================================================================
## Batch Operations
## ============================================================================

func _on_apply_to_all() -> void:
    """Apply batch settings to all tiles."""
    if not batchControls:
        return
    
    var config = batchControls.get_config()
    
    for detail in _tile_details:
        detail.set_config(config)
        detail.reset_override()

func _on_apply_to_selected() -> void:
    """Apply batch settings to selected tiles only."""
    if not batchControls:
        return
    
    var config = batchControls.get_config()
    
    for detail in _tile_details:
        if detail.is_checked():
            detail.set_config(config)
            detail.reset_override()

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
    
    var imported_tiles: Array[Tile] = []
    
    for detail in _tile_details:
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
    options.auto_generate_sockets = false  # We'll apply template instead
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
    
    # Apply template if selected (ID 0 = none, 1+ = template)
    var template_id = config.get("template_id", 0)
    if template_id > 0:
        var template_index = template_id - 1  # Convert ID to array index
        var templates = LibraryPresets.get_socket_templates()
        if template_index >= 0 and template_index < templates.size():
            var template = templates[template_index]
            LibraryPresets.apply_socket_template(tile, template, _library)
    
    # Apply symmetry detection
    if config.get("auto_detect_symmetry", true):
        tile.rotation_symmetry = Tile.RotationSymmetry.AUTO
    else:
        tile.rotation_symmetry = Tile.RotationSymmetry.FULL
    
    return tile
