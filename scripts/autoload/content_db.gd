extends Node
## Autoload. Indexes every authored resource under res://data/ by its unique `id` and
## validates the lot at startup (loudly, in debug builds).

const DATA_ROOT := "res://data"

## Problems found by the last reload(). Empty means the content is clean.
var validation_errors := PackedStringArray()

var _by_id: Dictionary = {}  # StringName -> Resource


func _ready() -> void:
	reload()


func reload() -> void:
	_by_id.clear()
	var resources := ContentLoader.load_all(DATA_ROOT)
	validation_errors = ContentValidator.validate(resources)
	for res in resources:
		var id: Variant = res.get(&"id")
		if id != null and StringName(id) != &"" and not _by_id.has(StringName(id)):
			_by_id[StringName(id)] = res
	if OS.is_debug_build():
		for message in validation_errors:
			push_error("[ContentDB] %s" % message)


func get_by_id(id: StringName) -> Resource:
	return _by_id.get(id)


func get_hull(id: StringName) -> HullData:
	return get_by_id(id) as HullData


## Every item definition (weapons, techmods, fighter bays, crew), sorted by category then id.
func items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for res: Resource in _by_id.values():
		if res is ItemData:
			out.append(res)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.slot_type() != b.slot_type():
			return a.slot_type() < b.slot_type()
		return String(a.id) < String(b.id))
	return out


## Every enemy, sorted by id.
func enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for res: Resource in _by_id.values():
		if res is EnemyData:
			out.append(res)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return String(a.id) < String(b.id))
	return out


## All weapons, sorted by id.
func weapons() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for res: Resource in _by_id.values():
		if res is WeaponData:
			out.append(res)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return String(a.id) < String(b.id))
	return out


## All hulls, sorted by id so indexes are stable between runs.
func hulls() -> Array[HullData]:
	var out: Array[HullData] = []
	for res: Resource in _by_id.values():
		if res is HullData:
			out.append(res)
	out.sort_custom(func(a: HullData, b: HullData) -> bool: return String(a.id) < String(b.id))
	return out
