@tool
class_name AutoStructuredSettings

const USE_BITSET_PATH := "auto_structured/wfc/use_bitset_catalog"
const EDITOR_USE_BITSET_PATH := "auto_structured/wfc_setup/use_bitset_catalog"
const USE_DIFF_BACKTRACKING_PATH := "auto_structured/wfc/use_diff_backtracking"
const EDITOR_USE_DIFF_BACKTRACKING_PATH := "auto_structured/wfc_setup/use_diff_backtracking"

static func ensure_defaults() -> void:
	_ensure_bool_setting(
		USE_BITSET_PATH,
		false,
		"Enable the new bitset-backed WFC tile catalog and compatibility masks. Experimental."
	)
	_ensure_bool_setting(
		USE_DIFF_BACKTRACKING_PATH,
		true,
		"Use diff-based solver backtracking instead of legacy full snapshots."
	)
	if Engine.is_editor_hint():
		_ensure_editor_bool_setting(
			EDITOR_USE_BITSET_PATH,
			false,
			"Toggle the experimental bitset-backed WFC path (per editor)."
		)
		_ensure_editor_bool_setting(
			EDITOR_USE_DIFF_BACKTRACKING_PATH,
			true,
			"Toggle diff-based WFC backtracking (per editor)."
		)
		sync_editor_preference_to_project()

static func get_use_bitset_catalog() -> bool:
	if ProjectSettings.has_setting(USE_BITSET_PATH):
		return ProjectSettings.get_setting(USE_BITSET_PATH)
	return false

static func get_use_diff_backtracking() -> bool:
	if ProjectSettings.has_setting(USE_DIFF_BACKTRACKING_PATH):
		return ProjectSettings.get_setting(USE_DIFF_BACKTRACKING_PATH)
	return true

static func set_use_diff_backtracking(enabled: bool) -> void:
	ProjectSettings.set_setting(USE_DIFF_BACKTRACKING_PATH, enabled)
	ProjectSettings.save()

static func set_use_bitset_catalog(enabled: bool) -> void:
	ProjectSettings.set_setting(USE_BITSET_PATH, enabled)
	ProjectSettings.save()

static func sync_editor_preference_to_project() -> void:
	if not Engine.is_editor_hint():
		return
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	if editor_settings.has_setting(EDITOR_USE_BITSET_PATH):
		ProjectSettings.set_setting(USE_BITSET_PATH, editor_settings.get_setting(EDITOR_USE_BITSET_PATH))
	if editor_settings.has_setting(EDITOR_USE_DIFF_BACKTRACKING_PATH):
		ProjectSettings.set_setting(USE_DIFF_BACKTRACKING_PATH, editor_settings.get_setting(EDITOR_USE_DIFF_BACKTRACKING_PATH))

static func _ensure_bool_setting(path: String, default_value: bool, description: String) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({
		"name": path,
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": description
	})

static func _ensure_editor_bool_setting(path: String, default_value: bool, description: String) -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	if not editor_settings.has_setting(path):
		editor_settings.set_setting(path, default_value)
	editor_settings.add_property_info({
		"name": path,
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": description
	})

static func _get_editor_settings() -> EditorSettings:
	var editor_interface := Engine.get_singleton("EditorInterface")
	if editor_interface == null:
		return null
	return editor_interface.get_editor_settings()
