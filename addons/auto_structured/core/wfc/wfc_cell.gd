@tool
class_name WfcCell extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int), "weight" (float)
var possible_tile_variants: Array[Dictionary] = []
var position: Vector3i
var variant_mask: PackedByteArray = PackedByteArray()

var _mask_enabled: bool = false
var _variant_count: int = 0
var _all_variants: Array[Dictionary] = []

## Cache for Shannon entropy (invalidated when possibilities change)
var _cached_entropy: float = -1.0
var _entropy_valid: bool = false

func _init(pos: Vector3i, all_tile_variants: Array[Dictionary], variant_count: int = -1, enable_mask: bool = false) -> void:
	position = pos
	_all_variants = all_tile_variants
	possible_tile_variants = all_tile_variants.duplicate()
	_entropy_valid = false
	_mask_enabled = enable_mask and (variant_count > 0 or not all_tile_variants.is_empty())
	if _mask_enabled:
		_variant_count = variant_count if variant_count > 0 else all_tile_variants.size()
		_ensure_mask_capacity(_variant_count)
		_sync_mask_from_variants(all_tile_variants)
	else:
		variant_mask = PackedByteArray()
		_variant_count = 0

func is_collapsed() -> bool:
	"""Cell is collapsed when only one variant remains."""
	return possible_tile_variants.size() == 1

func get_entropy() -> float:
	"""Calculate Shannon entropy: -sum(p * log(p)) where p is normalized weight."""
	if is_collapsed():
		return -1.0
	
	if _entropy_valid:
		return _cached_entropy
	
	var variants_for_entropy: Array[Dictionary] = []
	for variant in possible_tile_variants:
		if not _is_fallback_variant(variant):
			variants_for_entropy.append(variant)
	if variants_for_entropy.is_empty():
		variants_for_entropy = possible_tile_variants

	var count = variants_for_entropy.size()
	if count == 0:
		return 0.0
	
	# Calculate total weight
	var total_weight := 0.0
	for variant in variants_for_entropy:
		total_weight += variant.get("weight", 1.0)
	
	# Calculate Shannon entropy
	var entropy := 0.0
	for variant in variants_for_entropy:
		var weight = variant.get("weight", 1.0)
		var probability = weight / total_weight
		if probability > 0.0:
			entropy -= probability * log(probability)
	
	# Add small noise for tie-breaking
	entropy += randf() * 0.0001
	
	_cached_entropy = entropy
	_entropy_valid = true
	return entropy

func collapse() -> bool:
	"""Collapse to a single variant using weighted random selection."""
	if possible_tile_variants.is_empty():
		return false

	if is_collapsed():
		return true

	var primary_variants: Array[Dictionary] = []
	var fallback_variants: Array[Dictionary] = []
	for variant in possible_tile_variants:
		if _is_fallback_variant(variant):
			fallback_variants.append(variant)
		else:
			primary_variants.append(variant)

	var selection_pool: Array[Dictionary] = primary_variants
	if selection_pool.is_empty():
		selection_pool = fallback_variants
	if selection_pool.is_empty():
		return false

	# Weighted random selection based on tile weights
	var total_weight := 0.0
	for variant in selection_pool:
		total_weight += variant.get("weight", 1.0)
	
	var random_value = randf() * total_weight
	var cumulative_weight := 0.0
	var selected_variant: Dictionary
	
	for variant in selection_pool:
		cumulative_weight += variant.get("weight", 1.0)
		if cumulative_weight >= random_value:
			selected_variant = variant
			break
	
	# Fallback to last variant if floating point errors
	if selected_variant.is_empty():
		selected_variant = possible_tile_variants[-1]
	
	# Keep only the selected variant
	possible_tile_variants.clear()
	possible_tile_variants.append(selected_variant)
	_entropy_valid = false
	_sync_mask_from_variants()

	return true

func constrain(valid_variants: Array[Dictionary]) -> bool:
	"""Constrain possibilities to only valid variants. Returns true if changed."""
	if is_collapsed():
		return false

	var original_count := possible_tile_variants.size()
	var new_possible: Array[Dictionary] = []

	for variant in possible_tile_variants:
		if is_variant_in_list(variant, valid_variants):
			new_possible.append(variant)

	possible_tile_variants = new_possible
	var changed := possible_tile_variants.size() < original_count
	if changed:
		_entropy_valid = false
		_sync_mask_from_variants()
	return changed

func is_variant_in_list(variant: Dictionary, list: Array[Dictionary]) -> bool:
	"""Check if a tile+rotation variant exists in the list. Optimized for performance."""
	var target_tile = variant["tile"]
	var target_rotation = variant["rotation_degrees"]
	
	# Direct comparison is faster than dictionary access in tight loops
	for item in list:
		if item["tile"] == target_tile and item["rotation_degrees"] == target_rotation:
			return true
	return false

func has_contradiction() -> bool:
	"""A cell has a contradiction when no variants remain."""
	return possible_tile_variants.is_empty()

func get_tile() -> Tile:
	"""Get the collapsed tile, or null if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0].get("tile", null)
	return null

func get_rotation() -> int:
	"""Get the collapsed rotation, or 0 if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0].get("rotation_degrees", 0)
	return 0

func get_variant() -> Dictionary:
	"""Get the collapsed variant, or empty dict if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0]
	return {}

func restrict_to_boundary_tiles() -> bool:
	"""Remove all non-boundary tile variants. Returns true if changed."""
	if is_collapsed():
		return false
	var original_count := possible_tile_variants.size()
	var filtered: Array[Dictionary] = []
	for variant in possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and tile.boundary_role != Tile.BoundaryRole.NONE:
			filtered.append(variant)
	if filtered.is_empty():
		return false  # Don't remove everything - keep at least some options
	possible_tile_variants = filtered
	_entropy_valid = false
	var changed := possible_tile_variants.size() < original_count
	if changed:
		_sync_mask_from_variants()
	return changed

func restrict_to_non_boundary_tiles() -> bool:
	"""Remove all boundary tile variants. Returns true if changed."""
	if is_collapsed():
		return false
	var original_count := possible_tile_variants.size()
	var filtered: Array[Dictionary] = []
	for variant in possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and tile.boundary_role == Tile.BoundaryRole.NONE:
			filtered.append(variant)
	if filtered.is_empty():
		return false  # Don't remove everything
	possible_tile_variants = filtered
	_entropy_valid = false
	var changed := possible_tile_variants.size() < original_count
	if changed:
		_sync_mask_from_variants()
	return changed

func reset(all_tile_variants: Array[Dictionary]) -> void:
	"""Reset cell to uncollapsed state with all possibilities."""
	_all_variants = all_tile_variants
	possible_tile_variants = all_tile_variants.duplicate()
	_entropy_valid = false
	if _mask_enabled:
		if _variant_count <= 0:
			_variant_count = all_tile_variants.size()
		_ensure_mask_capacity(_variant_count)
		_sync_mask_from_variants(all_tile_variants)

func _is_fallback_variant(variant: Dictionary) -> bool:
	return variant.get("is_internal_fallback", false)

func mask_enabled() -> bool:
	return _mask_enabled

func get_variant_mask() -> PackedByteArray:
	return variant_mask

func rebuild_variant_mask() -> void:
	_sync_mask_from_variants()

func set_variant_mask_from(mask: PackedByteArray) -> void:
	if not _mask_enabled:
		return
	if mask.is_empty():
		_clear_mask()
		possible_tile_variants.clear()
		_entropy_valid = false
		return
	if variant_mask.size() != mask.size():
		_set_mask_raw(mask)
	else:
		for i in range(mask.size()):
			variant_mask[i] = mask[i]
	_rebuild_variants_from_mask()
	_entropy_valid = false

func intersect_with_mask(mask: PackedByteArray) -> bool:
	if not _mask_enabled or mask.is_empty():
		return false
	var changed := false
	var byte_count := min(variant_mask.size(), mask.size())
	for i in range(byte_count):
		var new_val := variant_mask[i] & mask[i]
		if new_val != variant_mask[i]:
			variant_mask[i] = new_val
			changed = true
	# Zero out any remaining bytes beyond mask length
	for j in range(byte_count, variant_mask.size()):
		if variant_mask[j] != 0:
			variant_mask[j] = 0
			changed = true
	if changed:
		_rebuild_variants_from_mask()
		_entropy_valid = false
	return changed

func create_snapshot() -> Dictionary:
	var snapshot := {
		"position": position,
		"variants": possible_tile_variants.duplicate(),
		"entropy_valid": _entropy_valid,
		"cached_entropy": _cached_entropy
	}
	if _mask_enabled:
		snapshot["mask"] = variant_mask.duplicate()
	return snapshot

func restore_snapshot(snapshot: Dictionary) -> void:
	possible_tile_variants = snapshot.get("variants", []).duplicate()
	_entropy_valid = snapshot.get("entropy_valid", false)
	_cached_entropy = snapshot.get("cached_entropy", -1.0)
	if _mask_enabled:
		if snapshot.has("mask"):
			_set_mask_raw(snapshot["mask"])
		else:
			rebuild_variant_mask()

func _ensure_mask_capacity(bit_count: int) -> void:
	if not _mask_enabled:
		return
	var count := max(bit_count, 1)
	var byte_count := int(ceil(count / 8.0))
	if variant_mask.size() != byte_count:
		variant_mask.resize(byte_count)
	_clear_mask()

func _clear_mask() -> void:
	for i in range(variant_mask.size()):
		variant_mask[i] = 0

func _sync_mask_from_variants(source: Array = possible_tile_variants) -> void:
	if not _mask_enabled:
		return
	if variant_mask.is_empty():
		_ensure_mask_capacity(max(_variant_count, 1))
	else:
		_clear_mask()
	for variant in source:
		var variant_id := _extract_variant_id(variant)
		if variant_id < 0:
			continue
		_write_mask_bit(variant_id, true)

func _rebuild_variants_from_mask() -> void:
	if not _mask_enabled:
		return
	possible_tile_variants.clear()
	if variant_mask.is_empty() or _all_variants.is_empty():
		return
	for variant in _all_variants:
		var variant_id := _extract_variant_id(variant)
		if variant_id < 0:
			continue
		if _is_mask_bit_set(variant_id):
			possible_tile_variants.append(variant)

func _extract_variant_id(variant: Dictionary) -> int:
	if variant == null:
		return -1
	return variant.get("variant_id", variant.get("id", -1))

func _write_mask_bit(variant_id: int, enabled: bool) -> void:
	if not _mask_enabled or variant_id < 0:
		return
	var byte_index := variant_id >> 3
	if byte_index < 0 or byte_index >= variant_mask.size():
		return
	var bit_mask := 1 << (variant_id & 7)
	var value := variant_mask[byte_index]
	if enabled:
		value |= bit_mask
	else:
		value &= ~bit_mask
	variant_mask[byte_index] = value

func _is_mask_bit_set(variant_id: int) -> bool:
	if not _mask_enabled or variant_id < 0:
		return false
	var byte_index := variant_id >> 3
	if byte_index < 0 or byte_index >= variant_mask.size():
		return false
	return (variant_mask[byte_index] & (1 << (variant_id & 7))) != 0

func _set_mask_raw(mask: PackedByteArray) -> void:
	variant_mask = mask.duplicate()