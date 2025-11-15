extends RefCounted

const ModuleLibraryPanel := preload("res://addons/auto_structured/ui/panels/module_library_panel.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")

const TMP_DIR := "res://addons/auto_structured/tests/tmp"

func run_all() -> Dictionary:
    var results := {
        "total": 0,
        "failures": []
    }
    _run_test(
        results,
        "Deleting library removes the resource file and updates selection",
        _test_delete_library_updates_state
    )
    _run_test(
        results,
        "Deleting last library shows the placeholder",
        _test_delete_last_library_placeholder
    )
    _run_test(
        results,
        "Saving library recreates missing resource file",
        _test_recreate_missing_library_file
    )
    _run_test(
        results,
        "Relocating library updates resource path",
        _test_relocate_library_updates_path
    )
    _run_test(
        results,
        "Deleting selected tile emits null selection",
        _test_delete_selected_tile_emits_null_selection
    )
    return results

func _run_test(results: Dictionary, name: String, fn: Callable) -> void:
    results["total"] += 1
    var outcome := fn.call()
    if outcome == null:
        print("  ✔ ", name)
    else:
        print("  ✘ ", name, " -> ", outcome)
        results["failures"].append("%s: %s" % [name, outcome])

func _test_delete_library_updates_state() -> Variant:
    _ensure_tmp_dir()
    var panel := _make_panel()
    var lib_a_path := TMP_DIR.path_join("delete_test_a.tres")
    var lib_b_path := TMP_DIR.path_join("delete_test_b.tres")
    var error: Variant = null
    var lib_a := _create_library_resource(lib_a_path, "DeleteTestA")
    var lib_b := _create_library_resource(lib_b_path, "DeleteTestB")
    if lib_a == null or lib_b == null:
        error = "Failed to create test libraries"
    else:
        var libs: Array[ModuleLibrary] = []
        libs.append(lib_a)
        libs.append(lib_b)
        panel.libraries = libs
        panel.current_library = lib_a
        panel.library_option.clear()
        panel.library_option.add_item(lib_a.library_name, 0)
        panel.library_option.add_item(lib_b.library_name, 1)
        panel.library_option.select(0)
        panel._delete_library()
        if FileAccess.file_exists(lib_a_path):
            error = "Library file %s was not deleted" % lib_a_path
        elif panel.libraries.size() != 1:
            error = "Expected exactly one library after deletion"
        elif panel.libraries[0] != lib_b:
            error = "Unexpected library remained after deletion"
        elif panel.current_library != lib_b:
            error = "Current library did not update to remaining library"
        elif panel.library_option.get_item_count() != 1:
            error = "OptionButton did not refresh items"
        elif panel.library_option.selected != 0:
            error = "Remaining library was not selected"
        elif panel.library_option.disabled:
            error = "OptionButton should remain enabled"

    _remove_library_file(lib_a_path)
    _remove_library_file(lib_b_path)
    _cleanup_panel(panel)
    return error

func _test_delete_last_library_placeholder() -> Variant:
    _ensure_tmp_dir()
    var panel := _make_panel()
    var lib_path := TMP_DIR.path_join("delete_test_single.tres")
    var error: Variant = null
    var lib := _create_library_resource(lib_path, "DeleteTestSingle")
    if lib == null:
        error = "Failed to create test library"
    else:
        var libs: Array[ModuleLibrary] = []
        libs.append(lib)
        panel.libraries = libs
        panel.current_library = lib
        panel.library_option.clear()
        panel.library_option.add_item(lib.library_name, 0)
        panel.library_option.select(0)
        panel._delete_library()
        if FileAccess.file_exists(lib_path):
            error = "Library file %s was not deleted" % lib_path
        elif not panel._is_showing_no_library_placeholder():
            var count := panel.library_option.get_item_count()
            var item_id := panel.library_option.get_item_id(0) if count > 0 else null
            var text := panel.library_option.get_item_text(0) if count > 0 else ""
            error = "Placeholder entry not displayed after deleting last library (count=%d, id=%s, text='%s')" % [count, str(item_id), text]
        elif panel.current_library != null:
            error = "Current library should be null when none remain"
        elif not panel.libraries.is_empty():
            error = "Libraries array should be empty"
        elif panel.library_option.get_item_count() != 1:
            error = "OptionButton should only show placeholder"
        elif panel.library_option.selected != 0:
            error = "Placeholder should remain selected"

    _remove_library_file(lib_path)
    _cleanup_panel(panel)
    return error

func _test_recreate_missing_library_file() -> Variant:
    _ensure_tmp_dir()
    var panel := _make_panel()
    var lib_path := TMP_DIR.path_join("missing_file.tres")
    var error: Variant = null
    var lib := _create_library_resource(lib_path, "MissingFile")
    if lib == null:
        error = "Failed to create test library"
    else:
        var libs: Array[ModuleLibrary] = []
        libs.append(lib)
        panel.libraries = libs
        panel.current_library = lib
        panel.library_option.clear()
        panel.library_option.add_item(lib.library_name, 0)
        panel.library_option.select(0)
        var absolute := ProjectSettings.globalize_path(lib_path)
        var remove_err := DirAccess.remove_absolute(absolute)
        if remove_err != OK:
            push_error("Failed to delete test library file: %d" % remove_err)
        panel._save_library()
        if not FileAccess.file_exists(lib_path):
            error = "Library file was not recreated after saving"

    _remove_library_file(lib_path)
    _cleanup_panel(panel)
    return error

func _test_relocate_library_updates_path() -> Variant:
    _ensure_tmp_dir()
    var panel := _make_panel()
    var lib_path := TMP_DIR.path_join("relocate_original.tres")
    var error: Variant = null
    var lib := _create_library_resource(lib_path, "RelocateOriginal")
    var new_dir := TMP_DIR.path_join("relocated")
    var new_path := new_dir.path_join("relocate_new.tres")
    if lib == null:
        error = "Failed to create test library"
    else:
        var libs: Array[ModuleLibrary] = []
        libs.append(lib)
        panel.libraries = libs
        panel.current_library = lib
        panel.library_option.clear()
        panel.library_option.add_item(lib.library_name, 0)
        panel.library_option.select(0)
        panel._apply_library_save_location(new_path)
        if panel.current_library.resource_path != new_path:
            error = "Library resource_path was not updated"
        elif not FileAccess.file_exists(new_path):
            error = "Relocated library file does not exist"
        elif FileAccess.file_exists(lib_path):
            error = "Old library file still exists after relocation"

    _remove_library_file(lib_path)
    _remove_library_file(new_dir.path_join("relocate_new.tres"))
    _cleanup_panel(panel)
    return error

func _test_delete_selected_tile_emits_null_selection() -> Variant:
    _ensure_tmp_dir()
    var panel := _make_panel()
    var lib_path := TMP_DIR.path_join("delete_selected_tile.tres")
    var error: Variant = null
    var lib := _create_library_resource(lib_path, "DeleteSelection")
    if lib == null:
        error = "Failed to create test library"
    else:
        var tile := Tile.new()
        tile.name = "DeleteMe"
        tile.ensure_all_sockets()
        lib.tiles = [tile]
        panel.libraries = [lib]
        panel.current_library = lib
        panel.library_option.clear()
        panel.library_option.add_item(lib.library_name, 0)
        panel.library_option.select(0)
        panel.selected_tile = tile
        var emitted_tiles: Array = []
        panel.tile_selected.connect(func(tile_arg): emitted_tiles.append(tile_arg))
        panel._delete_selected_tile()
        if lib.tiles.has(tile):
            error = "Tile still present after deletion"
        elif panel.selected_tile != null:
            error = "Selected tile not cleared after deletion"
        elif emitted_tiles.is_empty():
            error = "tile_selected signal not emitted"
        elif emitted_tiles[0] != null:
            error = "Expected null selection after deletion"

    _remove_library_file(lib_path)
    _cleanup_panel(panel)
    return error

func _ensure_tmp_dir() -> void:
    var absolute := ProjectSettings.globalize_path(TMP_DIR)
    var err := DirAccess.make_dir_recursive_absolute(absolute)
    if err != OK and err != ERR_ALREADY_EXISTS:
        push_error("Failed to prepare test directory: %d" % err)

func _make_panel() -> ModuleLibraryPanel:
    var panel := ModuleLibraryPanel.new()
    var option_button := OptionButton.new()
    option_button.get_popup()  # Ensure popup is initialized even when not in a scene tree
    var menu_button := MenuButton.new()
    menu_button.get_popup()
    var tile_list := ItemList.new()
    var search_edit := LineEdit.new()
    panel.library_option = option_button
    panel.library_menu_button = menu_button
    panel.tile_list = tile_list
    panel.search_edit = search_edit
    panel.set_meta("_test_nodes", [option_button, menu_button, tile_list, search_edit])
    return panel

func _create_library_resource(path: String, name: String) -> ModuleLibrary:
    var lib := ModuleLibrary.new()
    lib.library_name = name
    lib.ensure_defaults()
    var err := ResourceSaver.save(lib, path)
    if err != OK:
        push_error("Failed to save test library '%s': %d" % [path, err])
        return null
    return ResourceLoader.load(path) as ModuleLibrary

func _remove_library_file(path: String) -> void:
    var absolute := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(absolute)

func _cleanup_panel(panel: ModuleLibraryPanel) -> void:
    if panel == null:
        return
    if panel.has_meta("_test_nodes"):
        var nodes: Array = panel.get_meta("_test_nodes")
        for node in nodes:
            if node and node is Node:
                (node as Node).free()
    panel.set_meta("_test_nodes", null)
    panel.free()