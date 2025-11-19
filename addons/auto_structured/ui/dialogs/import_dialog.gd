@tool
class_name ImportDialog extends ConfirmationDialog

const BatchControls = preload("res://addons/auto_structured/ui/controls/import_controls/batch_controls.gd")
const TileDetails = preload("res://addons/auto_structured/ui/controls/import_controls/tile_detail.gd")

@onready var batchControls: BatchControls = %BatchControls

@onready var tilesContLabel: Label = %TilesContLabel
@onready var selectAllButton: Button = %SelectAllButton
@onready var deselectAllButton: Button = %DeselectAllButton

@onready var tilesListContainer: VBoxContainer = %TilesListContainer
