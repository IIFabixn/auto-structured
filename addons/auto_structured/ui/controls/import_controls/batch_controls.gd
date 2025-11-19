@tool
class_name BatchControls extends VBoxContainer

@onready var xSpinBox : SpinBox = %XSizeSpinBox
@onready var ySpinBox : SpinBox = %YSizeSpinBox
@onready var zSpinBox : SpinBox = %ZSizeSpinBox

@onready var templateOptionButton : OptionButton = %TemplateOptionButton
@onready var addTemplateButton : TextureButton = %AddTemplateButton

@onready var tagsMenuButton : MenuButton = %TagsMenuButton
@onready var addTagButton : TextureButton = %AddTagButton

@onready var autoSymmetryDetectCheckBox : CheckBox = %AutoSymmetryDetectCheckBox
@onready var rotationalVarianceCheckBox : CheckBox = %RotationalVarianceCheckBox
@onready var selfMatchCheckBox : CheckBox = %SelfMatchCheckBox

@onready var applyAllButton : Button = %ApplyAllButton
@onready var applySelectedButton : Button = %ApplySelectedButton

