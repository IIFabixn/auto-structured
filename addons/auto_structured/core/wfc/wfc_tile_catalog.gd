@tool
class_name WfcTileCatalog extends Resource

const Tile = preload("res://addons/auto_structured/core/tile.gd")

class VariantRecord:
	var id: int = -1
	var tile: Tile = null
	var rotation_degrees: int = 0
	var is_internal_fallback: bool = false
	var weight: float = 1.0

	func _init(record_id: int, tile_ref: Tile, rotation: int, fallback: bool, variant_weight: float) -> void:
		id = record_id
		tile = tile_ref
		rotation_degrees = rotation
		is_internal_fallback = fallback
		weight = variant_weight

var source_library_name: String = ""
var cell_world_size: Vector3 = Vector3.ONE
var internal_fallback_tile: Tile = null
var variant_records: Array[VariantRecord] = []
var direction_vectors: Array[Vector3i] = []
var compatibility_masks: Array = []  ## direction_index -> Array[PackedByteArray]

func get_variant_count() -> int:
	return variant_records.size()

func get_variant_record(index: int) -> VariantRecord:
	if index < 0 or index >= variant_records.size():
		return null
	return variant_records[index]

func get_solver_variant_dicts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(variant_records.size())
	for i in range(variant_records.size()):
		var record: VariantRecord = variant_records[i]
		result[i] = {
			"tile": record.tile,
			"rotation_degrees": record.rotation_degrees,
			"weight": record.weight,
			"is_internal_fallback": record.is_internal_fallback,
			"variant_id": record.id
		}
	return result

func get_direction_count() -> int:
	return direction_vectors.size()

func get_direction(index: int) -> Vector3i:
	if index < 0 or index >= direction_vectors.size():
		return Vector3i.ZERO
	return direction_vectors[index]

func get_variant_mask(direction_index: int, variant_id: int) -> PackedByteArray:
	if direction_index < 0 or direction_index >= compatibility_masks.size():
		return PackedByteArray()
	var masks_for_dir: Array = compatibility_masks[direction_index]
	if variant_id < 0 or variant_id >= masks_for_dir.size():
		return PackedByteArray()
	return masks_for_dir[variant_id]

static func mask_has_variant(mask: PackedByteArray, variant_id: int) -> bool:
	if mask.is_empty():
		return false
	var byte_index := variant_id >> 3
	if byte_index < 0 or byte_index >= mask.size():
		return false
	var bit_index := variant_id & 7
	return (mask[byte_index] & (1 << bit_index)) != 0

static func clear_mask(mask: PackedByteArray) -> void:
	for i in range(mask.size()):
		mask[i] = 0

static func mask_or_in_place(destination: PackedByteArray, source: PackedByteArray) -> void:
	var count := min(destination.size(), source.size())
	for i in range(count):
		destination[i] = destination[i] | source[i]

static func mask_and_in_place(destination: PackedByteArray, source: PackedByteArray) -> void:
	var count := min(destination.size(), source.size())
	for i in range(count):
		destination[i] = destination[i] & source[i]

static func mask_count_bits(mask: PackedByteArray) -> int:
	var total := 0
	for byte in mask:
		total += _bit_count(byte)
	return total

static func set_mask_variant(mask: PackedByteArray, variant_id: int, enabled: bool) -> void:
	if mask.is_empty():
		return
	var byte_index := variant_id >> 3
	if byte_index < 0 or byte_index >= mask.size():
		return
	var bit_index := variant_id & 7
	var value := mask[byte_index]
	if enabled:
		value |= 1 << bit_index
	else:
		value &= ~(1 << bit_index)
	mask[byte_index] = value

static func create_empty_mask(bit_count: int) -> PackedByteArray:
	var byte_count := int(ceil(bit_count / 8.0))
	var mask := PackedByteArray()
	mask.resize(max(byte_count, 1))
	for i in range(mask.size()):
		mask[i] = 0
	return mask

static func _bit_count(value: int) -> int:
	var x := value & 0xFF
	x = x - ((x >> 1) & 0x55)
	x = (x & 0x33) + ((x >> 2) & 0x33)
	return (((x + (x >> 4)) & 0x0F) * 0x01) & 0x1F
