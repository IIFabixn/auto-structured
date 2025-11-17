@tool
class_name DetailsPanel extends Control
## Panel for displaying and editing tile properties.
##
## Provides a clean API for showing tile details with proper state initialization.
## Use show_tile(tile, library) to display a tile's properties.

signal closed
signal tile_modified(tile: Tile)
signal socket_preview_requested(socket: Socket)
signal socket_editor_requested(tile: Tile, start_mode: int)

const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const TagItemControl = preload("res://addons/auto_structured/ui/controls/tag_item_control.gd")

@onready var close_button: TextureButton = %CloseButton

@onready var name_label: Label = %NameLabel
@onready var preview_image: TextureRect = %TileImage

@onready var tab_container: TabContainer = %DetailsTabContainer
@onready var general_tab: Control = %DetailsTabContainer/Generel
@onready var sockets_tab: Control = %DetailsTabContainer/Sockets

@onready var x_size_spinbox: SpinBox = %XSizeSpinBox
@onready var y_size_spinbox: SpinBox = %YSizeSpinBox
@onready var z_size_spinbox: SpinBox = %ZSizeSpinBox

@onready var tags_list: VBoxContainer = %TagsContainer
@onready var add_tag_button: TextureButton = %AddTagButton