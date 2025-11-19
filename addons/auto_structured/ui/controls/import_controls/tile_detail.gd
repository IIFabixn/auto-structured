@tool
class_name ImportTileDetail
extends VBoxContainer

@onready var checkedCheckBox : CheckBox = %CheckedCheckBox
@onready var nameLabel : Label = %NameLabel
@onready var overrideCheckButton : Button = %OverrideCheckButton

@onready var detailsContainer : VBoxContainer = %DetailsContainer

@onready var xSizeSpinBox : SpinBox = %XSizeSpinBox
@onready var ySizeSpinBox : SpinBox = %YSizeSpinBox
@onready var zSizeSpinBox : SpinBox = %ZSizeSpinBox

@onready var templateOptionButton : OptionButton = %TemplateOptionButton
@onready var addTemplateButton : TextureButton = %AddTemplateButton

@onready var tagsMenuButton : MenuButton = %TagsMenuButton
@onready var addTagButton : TextureButton = %AddTagButton

@onready var upSocketMenuButton : MenuButton = %UpSocketMenuButton
@onready var downSocketMenuButton : MenuButton = %DownSocketMenuButton
@onready var leftSocketMenuButton : MenuButton = %LeftSocketMenuButton
@onready var rightSocketMenuButton : MenuButton = %RightSocketMenuButton
@onready var frontSocketMenuButton : MenuButton = %FrontSocketMenuButton
@onready var backSocketMenuButton : MenuButton = %BackSocketMenuButton

@onready var autoSymmetryDetectionCheckBox : CheckBox = %AutoSymmetryDetectionCheckBox
@onready var rotationalVarianceCheckBox : CheckBox = %RotationalVarianceCheckBox
@onready var selfMatchCheckBox : CheckBox = %SelfMatchCheckBox