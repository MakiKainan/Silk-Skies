class_name ArtLookup
extends RefCounted
## Finds the real art for a piece of content. An explicit field set in the Inspector always
## wins; otherwise a file named after the content id in the matching assets/ folder is used
## (drop `assets/icons/items/pulse_laser.png` and the Pulse Laser has an icon). Null means
## "no art yet": callers then build their placeholder.
##
## Results are cached, misses included, so per-shot lookups cost a dictionary read.

const ROOT_PREFIX := "res://assets/"
const TEXTURE_EXT: PackedStringArray = ["png", "webp", "svg", "jpg"]
const SCENE_EXT: PackedStringArray = ["tscn", "scn", "glb", "gltf"]
const AUDIO_EXT: PackedStringArray = ["ogg", "wav", "mp3"]

## Where convention lookups start. Tests point this somewhere else.
static var root: String = ROOT_PREFIX
static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## [param explicit] if set, else the first existing `<root><stem>.<ext>`, else null.
static func find(explicit: Resource, stem: String, extensions: PackedStringArray) -> Resource:
	if explicit != null:
		return explicit
	if stem == "":
		return null
	var key := root + stem
	if _cache.has(key):
		return _cache[key]
	var found: Resource = null
	for ext in extensions:
		var path := "%s.%s" % [key, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_cache[key] = found
	return found


static func item_icon(item: ItemData) -> Texture2D:
	return find(item.icon, "icons/items/%s" % item.id, TEXTURE_EXT) as Texture2D


static func hull_icon(hull: HullData) -> Texture2D:
	return find(hull.icon, "icons/hulls/%s" % hull.id, TEXTURE_EXT) as Texture2D


static func barrel_scene(weapon: WeaponData) -> PackedScene:
	return find(weapon.barrel_scene, "models/weapons/%s_barrel" % weapon.id, SCENE_EXT) as PackedScene


static func fire_sound(weapon: WeaponData) -> AudioStream:
	return find(weapon.fire_sound, "audio/sfx/%s_fire" % weapon.id, AUDIO_EXT) as AudioStream


static func projectile_scene(projectile: ProjectileData) -> PackedScene:
	return find(projectile.visual_scene, "models/projectiles/%s" % projectile.id, SCENE_EXT) as PackedScene


static func impact_scene(projectile: ProjectileData) -> PackedScene:
	return find(projectile.impact_scene, "vfx/scenes/%s_impact" % projectile.id, SCENE_EXT) as PackedScene


static func impact_sound(projectile: ProjectileData) -> AudioStream:
	return find(projectile.impact_sound, "audio/sfx/%s_impact" % projectile.id, AUDIO_EXT) as AudioStream
