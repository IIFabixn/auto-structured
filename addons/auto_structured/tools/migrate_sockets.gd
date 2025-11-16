@tool
extends EditorScript

## Migration script to convert socket_id and compatible_sockets to SocketType resources
## Run this once to migrate existing assets to the new socket type system

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

func _run() -> void:
	print("=== Socket Migration Script Started ===")
	
	# Load the main module library
	var library_path := "res://module_library.tres"
	if not FileAccess.file_exists(library_path):
		print("ERROR: Module library not found at: ", library_path)
		print("Please adjust the library_path variable in this script.")
		return
	
	var library: ModuleLibrary = ResourceLoader.load(library_path)
	if library == null:
		print("ERROR: Failed to load module library")
		return
	
	print("Loaded library: ", library.library_name)
	print("Total tiles: ", library.tiles.size())
	
	# Step 1: Collect all unique socket IDs from tiles
	var types_by_id := {}
	var socket_compatibilities := {}  # Track which IDs are compatible with each other
	
	print("\n--- Step 1: Collecting socket IDs ---")
	for tile in library.tiles:
		for socket in tile.sockets:
			# Check if socket has old-style data
			var sid := ""
			if socket.has("socket_id"):
				sid = socket.get("socket_id")
			
			if sid == "" or sid == "none":
				continue
			
			if not types_by_id.has(sid):
				print("  Found socket ID: ", sid)
				var t := SocketType.new()
				t.type_id = sid
				types_by_id[sid] = t
			
			# Collect compatibility information
			if socket.has("compatible_sockets"):
				var compat_list = socket.get("compatible_sockets")
				if not socket_compatibilities.has(sid):
					socket_compatibilities[sid] = {}
				for compat_id in compat_list:
					socket_compatibilities[sid][compat_id] = true
	
	# Step 2: Create "none" socket type if needed
	print("\n--- Step 2: Creating default socket types ---")
	if not types_by_id.has("none"):
		print("  Creating 'none' socket type")
		var none_type := SocketType.new()
		none_type.type_id = "none"
		none_type.add_compatible_type("none")
		types_by_id["none"] = none_type
	
	# Step 3: Apply compatibility information to SocketTypes
	print("\n--- Step 3: Setting up compatibility ---")
	for sid in socket_compatibilities:
		var type: SocketType = types_by_id.get(sid)
		if type == null:
			continue
		for compat_id in socket_compatibilities[sid]:
			print("  ", sid, " -> ", compat_id)
			type.add_compatible_type(compat_id)
	
	# Step 4: Register all socket types in the library
	print("\n--- Step 4: Registering socket types in library ---")
	library.socket_types.clear()
	for sid in types_by_id:
		var type: SocketType = types_by_id[sid]
		print("  Registering: ", type.type_id)
		library.register_socket_type(type)
	
	# Step 5: Assign socket types to all sockets
	print("\n--- Step 5: Assigning socket types to sockets ---")
	var socket_count := 0
	for tile in library.tiles:
		for socket in tile.sockets:
			var sid := ""
			if socket.has("socket_id"):
				sid = socket.get("socket_id")
			
			if sid == "":
				sid = "none"
			
			var type: SocketType = types_by_id.get(sid)
			if type == null:
				type = types_by_id.get("none")
			
			socket.socket_type = type
			socket_count += 1
			
			# Clear old properties (if they exist as actual properties)
			# Note: If these are @export properties, they will remain in the .tres file
			# but won't be used by the new code
			if socket.has("socket_id"):
				socket.set("socket_id", "")
			if socket.has("compatible_sockets"):
				var empty_array: Array[String] = []
				socket.set("compatible_sockets", empty_array)
	
	print("  Assigned socket types to ", socket_count, " sockets")
	
	# Step 6: Save the updated library
	print("\n--- Step 6: Saving library ---")
	var save_result := ResourceSaver.save(library, library_path)
	if save_result == OK:
		print("✓ Library saved successfully to: ", library_path)
	else:
		print("✗ ERROR: Failed to save library. Error code: ", save_result)
		return
	
	# Step 7: Validation
	print("\n--- Step 7: Validation ---")
	var validation := library.validate_library()
	if validation["valid"]:
		print("✓ Library validation passed!")
	else:
		print("✗ Library has issues:")
		for issue in validation["issues"]:
			print("  - ", issue)
	
	print("\n=== Migration Complete ===")
	print("Summary:")
	print("  - Socket types created: ", types_by_id.size())
	print("  - Tiles processed: ", library.tiles.size())
	print("  - Sockets migrated: ", socket_count)
	print("\nNext steps:")
	print("  1. Review the migrated library in the editor")
	print("  2. Test WFC generation to ensure compatibility works")
	print("  3. Update any custom tools or UI that reference socket_id")
