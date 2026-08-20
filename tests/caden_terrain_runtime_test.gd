extends SceneTree

const TERRAIN_TILESET := preload("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1.tres")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_tileset():
		return

	print("PASS: Preserved Caden Terrain Runtime v1 atlas and TileSet resource.")
	quit(0)


func _verify_tileset() -> bool:
	if TERRAIN_TILESET.tile_size != Vector2i(32, 32):
		return _fail("Terrain TileSet does not use 32x32 tiles.")
	if TERRAIN_TILESET.get_physics_layers_count() != 0:
		return _fail("Decorative terrain unexpectedly defines gameplay collision.")
	if not TERRAIN_TILESET.has_source(0):
		return _fail("Terrain TileSet is missing atlas source 0.")

	var atlas_source := TERRAIN_TILESET.get_source(0) as TileSetAtlasSource
	if atlas_source == null:
		return _fail("Terrain source 0 is not a TileSetAtlasSource.")
	if atlas_source.texture_region_size != Vector2i(32, 32):
		return _fail("Terrain atlas regions are not 32x32.")
	if atlas_source.texture == null or atlas_source.texture.get_size() != Vector2(256, 192):
		return _fail("Terrain atlas texture is not 256x192.")

	var tile_count := 0
	for y in range(6):
		for x in range(8):
			if Vector2i(x, y) == Vector2i(7, 0):
				continue
			if not atlas_source.has_tile(Vector2i(x, y)):
				return _fail("Missing documented atlas tile at %s." % Vector2i(x, y))
			tile_count += 1
	if tile_count != 47:
		return _fail("Expected 47 documented terrain tiles, found %d." % tile_count)

	return true
func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
