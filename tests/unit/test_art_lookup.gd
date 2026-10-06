extends GutTest
## ArtLookup: explicit art wins, a file named after the id is found by convention, and
## no art at all gives null. Uses a throwaway folder in user:// instead of the real assets/.

const TEST_ROOT := "user://art_lookup_test/"
const EXT: PackedStringArray = ["tres"]

var _saved_root: String


func before_each() -> void:
	_saved_root = ArtLookup.root
	ArtLookup.root = TEST_ROOT
	ArtLookup.clear_cache()
	DirAccess.make_dir_recursive_absolute(TEST_ROOT + "icons/items")


func after_each() -> void:
	ArtLookup.root = _saved_root
	ArtLookup.clear_cache()
	var dir := DirAccess.open(TEST_ROOT + "icons/items")
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)


func _texture(size: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(size, size, false, Image.FORMAT_RGBA8))


func _save_icon(id: String, size: int) -> void:
	assert_eq(ResourceSaver.save(_texture(size), "%sicons/items/%s.tres" % [TEST_ROOT, id]), OK)


func test_no_art_gives_null() -> void:
	assert_null(ArtLookup.find(null, "icons/items/ghost", EXT))


func test_empty_stem_gives_null() -> void:
	assert_null(ArtLookup.find(null, "", EXT))


func test_explicit_art_wins_over_a_file() -> void:
	_save_icon("both", 64)
	var explicit := _texture(128)
	assert_eq(ArtLookup.find(explicit, "icons/items/both", EXT), explicit)


func test_file_named_after_the_id_is_found() -> void:
	_save_icon("found_me", 64)
	var found := ArtLookup.find(null, "icons/items/found_me", EXT) as Texture2D
	assert_not_null(found)
	assert_eq(found.get_width(), 64)


func test_extensions_are_tried_in_order() -> void:
	_save_icon("ordered", 64)
	var found := ArtLookup.find(null, "icons/items/ordered", PackedStringArray(["png", "tres"]))
	assert_not_null(found, "png is missing, tres is next")


func test_misses_are_cached_until_cleared() -> void:
	assert_null(ArtLookup.find(null, "icons/items/late", EXT))
	_save_icon("late", 64)
	assert_null(ArtLookup.find(null, "icons/items/late", EXT), "the miss is remembered")
	ArtLookup.clear_cache()
	assert_not_null(ArtLookup.find(null, "icons/items/late", EXT))


func test_item_icon_prefers_the_explicit_field() -> void:
	var item := ItemData.new()
	item.id = &"has_icon"
	item.icon = _texture(128)
	assert_eq(ArtLookup.item_icon(item), item.icon)


func test_item_without_art_has_no_icon() -> void:
	var item := ItemData.new()
	item.id = &"plain"
	assert_null(ArtLookup.item_icon(item))


func test_sfx_does_nothing_without_a_stream() -> void:
	var holder: Node3D = add_child_autofree(Node3D.new())
	Sfx.play_3d(holder, null, Vector3.ZERO)
	assert_eq(holder.get_child_count(), 0)


func test_sfx_plays_a_stream_on_the_sfx_bus() -> void:
	var holder: Node3D = add_child_autofree(Node3D.new())
	Sfx.play_3d(holder, AudioStreamWAV.new(), Vector3(1, 0, 2))
	assert_eq(holder.get_child_count(), 1)
	var player := holder.get_child(0) as AudioStreamPlayer3D
	assert_not_null(player)
	if player != null:
		assert_eq(player.bus, &"SFX", "default_bus_layout.tres defines the SFX bus")
		assert_eq(player.global_position, Vector3(1, 0, 2))
