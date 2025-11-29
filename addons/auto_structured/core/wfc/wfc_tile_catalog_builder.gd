@tool
class_name WfcTileCatalogBuilder

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcTileCatalog = preload("res://addons/auto_structured/core/wfc/wfc_tile_catalog.gd")
const WfcInternalFallbackFactory = preload("res://addons/auto_structured/core/wfc/wfc_internal_fallback_factory.gd")

static func build(library: ModuleLibrary, include_fallback: bool = true) -> WfcTileCatalog:
	if library == null:
		push_error("Cannot build WFC tile catalog without a ModuleLibrary")
		return null

	var catalog := WfcTileCatalog.new()
	catalog.source_library_name = library.library_name
	catalog.cell_world_size = library.cell_world_size

	var solver_tiles: Array[Tile] = library.tiles.duplicate()
	var fallback_tile: Tile = null
	if include_fallback:
		fallback_tile = WfcInternalFallbackFactory.create_fallback_tile()
		solver_tiles.append(fallback_tile)

	catalog.internal_fallback_tile = fallback_tile

	var variant_records: Array[WfcTileCatalog.VariantRecord] = []
	var variant_id := 0

	for tile in solver_tiles:
		if tile == null:
			continue
		var rotations: Array[int] = tile.get_unique_rotations()
		for rotation in rotations:
			var weight := tile.weight if tile.weight > 0.0 else 1.0
			var is_fallback := fallback_tile != null and tile == fallback_tile
			var record := WfcTileCatalog.VariantRecord.new(variant_id, tile, rotation, is_fallback, weight)
			variant_records.append(record)
			variant_id += 1

	catalog.variant_records = variant_records
	catalog.direction_vectors = WfcHelper.get_cardinal_directions()
	catalog.compatibility_masks = _build_compatibility_masks(catalog)

	return catalog

static func _build_compatibility_masks(catalog: WfcTileCatalog) -> Array:
	var directions := catalog.direction_vectors
	var variant_count := catalog.get_variant_count()

	var masks: Array = []
	masks.resize(directions.size())

	for dir_index in range(directions.size()):
		var per_variant_masks: Array = []
		per_variant_masks.resize(variant_count)
		for variant_id in range(variant_count):
			per_variant_masks[variant_id] = WfcTileCatalog.create_empty_mask(variant_count)
		masks[dir_index] = per_variant_masks

	var rotation_basis_cache: Dictionary = {}
	for src_id in range(variant_count):
		var src_record := catalog.get_variant_record(src_id)
		for dir_index in range(directions.size()):
			var direction := directions[dir_index]
			var mask: PackedByteArray = masks[dir_index][src_id]
			for neighbor_id in range(variant_count):
				var neighbor_record := catalog.get_variant_record(neighbor_id)
				var compatible := _are_variants_compatible(src_record, neighbor_record, direction, rotation_basis_cache)
				WfcTileCatalog.set_mask_variant(mask, neighbor_id, compatible)

	return masks

static func _are_variants_compatible(source_record: WfcTileCatalog.VariantRecord, neighbor_record: WfcTileCatalog.VariantRecord, direction: Vector3i, basis_cache: Dictionary) -> bool:
	if source_record == null or neighbor_record == null:
		return false
	if source_record.tile == null or neighbor_record.tile == null:
		return false

	if source_record.is_internal_fallback or neighbor_record.is_internal_fallback:
		return true

	var source_basis := _get_basis(source_record.rotation_degrees, basis_cache)
	var source_local_dir := WfcHelper.rotate_direction(direction, source_basis.inverse())
	var source_sockets := source_record.tile.get_sockets_in_direction(source_local_dir)
	if source_sockets.is_empty():
		return false

	var neighbor_basis := _get_basis(neighbor_record.rotation_degrees, basis_cache)
	var neighbor_local_dir := WfcHelper.rotate_direction(-direction, neighbor_basis.inverse())
	var neighbor_sockets := neighbor_record.tile.get_sockets_in_direction(neighbor_local_dir)
	if neighbor_sockets.is_empty():
		return false

	for source_socket in source_sockets:
		for neighbor_socket in neighbor_sockets:
			if source_socket.is_compatible_with(neighbor_socket) and neighbor_socket.is_compatible_with(source_socket):
				return true

	return false

static func _get_basis(rotation_degrees: int, cache: Dictionary) -> Basis:
	if cache.has(rotation_degrees):
		return cache[rotation_degrees]
	var basis := WfcHelper.rotation_y_to_basis(rotation_degrees)
	cache[rotation_degrees] = basis
	return basis
