@tool
class_name StrategyPresetStore
extends RefCounted

const PRESET_FILE_PATH := "user://auto_structured_strategy_presets.cfg"

func list_presets(strategy_key: String) -> Array[String]:
	var config := ConfigFile.new()
	var err := config.load(PRESET_FILE_PATH)
	if err != OK:
		return []
	if not config.has_section(strategy_key):
		return []
	var keys := config.get_section_keys(strategy_key)
	keys.sort()
	var names: Array[String] = []
	for key in keys:
		names.append(key)
	return names

func save_preset(strategy_key: String, preset_name: String, data: Dictionary) -> void:
	if preset_name.is_empty():
		push_warning("Cannot save preset with empty name")
		return
	var config := ConfigFile.new()
	var err := config.load(PRESET_FILE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND and err != ERR_DOES_NOT_EXIST:
		push_warning("StrategyPresetStore: Unable to load preset file (%s)" % error_string(err))
	# Ensure existing entries preserved
	if err != OK:
		config = ConfigFile.new()
	config.set_value(strategy_key, preset_name, data)
	err = config.save(PRESET_FILE_PATH)
	if err != OK:
		push_warning("StrategyPresetStore: Unable to save preset (%s)" % error_string(err))

func load_preset(strategy_key: String, preset_name: String) -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(PRESET_FILE_PATH)
	if err != OK:
		return {}
	return config.get_value(strategy_key, preset_name, {})

func remove_preset(strategy_key: String, preset_name: String) -> void:
	var config := ConfigFile.new()
	var err := config.load(PRESET_FILE_PATH)
	if err != OK:
		return
	if not config.has_section_key(strategy_key, preset_name):
		return
	config.erase_section_key(strategy_key, preset_name)
	err = config.save(PRESET_FILE_PATH)
	if err != OK:
		push_warning("StrategyPresetStore: Unable to remove preset (%s)" % error_string(err))
