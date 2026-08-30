extends SceneTree

const TERRAIN_TILESET := preload("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.tres")
const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")

const EXPECTED_SOURCE_SHA256 := "36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c"
const EXPECTED_V1_SHA256 := "0e0b6e5bad4c3a64acd427171212ba16ed2a75e10f0006df22d6445100fa0279"
const EXPECTED_V1_1_SHA256 := "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
const EXPECTED_V1_3_SHA256 := "aa290ab82c5f79b90b491d9f67c88d181f320a2078ca97c161d8925cec46b86d"
const EXPECTED_ENTRY_POSITIONS := {
	&"from_wayfarers_approach": Vector2(160, 352),
	&"from_residential": Vector2(800, 352),
	&"from_marketplace": Vector2(480, 160),
	&"from_commons": Vector2(480, 544),
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_protected_hashes():
		return
	if not _verify_tileset():
		return
	if not await _verify_town_square():
		return

	print("PASS: Caden Terrain Runtime v1.3 tonal atlas, protected v1.1 rollback, distributions, and preserved Town Square layout.")
	quit(0)


func _verify_protected_hashes() -> bool:
	var source_hash := FileAccess.get_sha256("res://assets/source_art/caden/terrain/caden_terrain_master_v1.png")
	if source_hash != EXPECTED_SOURCE_SHA256:
		return _fail("The immutable Caden terrain source-master hash changed.")

	var v1_hash := FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1.png")
	if v1_hash != EXPECTED_V1_SHA256:
		return _fail("The protected Terrain Runtime v1 atlas hash changed.")
	if FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png") != EXPECTED_V1_1_SHA256:
		return _fail("The protected Terrain Runtime v1.1 rollback atlas hash changed.")
	if FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.png") != EXPECTED_V1_3_SHA256:
		return _fail("The approved Terrain Runtime v1.3 tonal atlas hash changed.")

	return true


func _verify_tileset() -> bool:
	if TERRAIN_TILESET.tile_size != Vector2i(32, 32):
		return _fail("Terrain Runtime v1.3 does not use 32x32 tiles.")
	if TERRAIN_TILESET.get_physics_layers_count() != 0:
		return _fail("Decorative Terrain Runtime v1.3 unexpectedly defines collision.")
	if not TERRAIN_TILESET.has_source(0):
		return _fail("Terrain Runtime v1.3 is missing atlas source 0.")

	var atlas_source := TERRAIN_TILESET.get_source(0) as TileSetAtlasSource
	if atlas_source == null:
		return _fail("Terrain Runtime v1.3 source 0 is not an atlas source.")
	if atlas_source.texture_region_size != Vector2i(32, 32):
		return _fail("Terrain Runtime v1.3 atlas regions are not 32x32.")
	if atlas_source.texture == null or atlas_source.texture.get_size() != Vector2(256, 256):
		return _fail("Terrain Runtime v1.3 atlas is not 256x256.")

	var tile_count := 0
	for y in range(8):
		for x in range(8):
			if y == 7 and x >= 2:
				continue
			if not atlas_source.has_tile(Vector2i(x, y)):
				return _fail("Missing documented v1.1 tile at %s." % Vector2i(x, y))
			tile_count += 1
	if tile_count != 58:
		return _fail("Expected 58 documented v1.3 tiles, found %d." % tile_count)

	return true


func _verify_town_square() -> bool:
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	root.add_child(town_square)
	await process_frame

	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square camera bounds changed during v1.3 integration.")

	var terrain_layers := town_square.get_node("TerrainLayers") as Node2D
	for layer_name in [&"BaseTerrainTiles", &"RoadTiles", &"PlazaTiles", &"TerrainTransitions"]:
		var layer := terrain_layers.get_node(NodePath(layer_name)) as TileMapLayer
		if layer == null:
			return _fail("Missing Town Square terrain layer %s." % layer_name)
		if layer.position != Vector2.ZERO:
			return _fail("Terrain layer %s has a non-integral placement." % layer_name)
		if layer.tile_set == null or layer.tile_set.resource_path != TERRAIN_TILESET.resource_path:
			return _fail("Terrain layer %s does not reference Runtime v1.3." % layer_name)

	if not _verify_grass_distribution(terrain_layers.get_node("BaseTerrainTiles") as TileMapLayer):
		return false
	if not _verify_road_distribution(terrain_layers.get_node("RoadTiles") as TileMapLayer):
		return false
	if not _verify_plaza_distribution(terrain_layers.get_node("PlazaTiles") as TileMapLayer):
		return false
	if (terrain_layers.get_node("TerrainTransitions") as TileMapLayer).get_used_cells().size() != 16:
		return _fail("Town Square no longer has 16 directional transition cells.")

	var entry_points := town_square.get_node("EntryPoints") as Node2D
	for entry_name: StringName in EXPECTED_ENTRY_POSITIONS:
		var marker := entry_points.get_node(NodePath(entry_name)) as Marker2D
		if marker.position != EXPECTED_ENTRY_POSITIONS[entry_name]:
			return _fail("Town Square entry %s moved during v1.3 integration." % entry_name)

	if town_square.get_node("Exits").get_child_count() != 4:
		return _fail("Town Square zone-exit count changed.")
	if town_square.get_node("Boundaries").get_child_count() != 4:
		return _fail("Town Square technical-boundary count changed.")

	town_square.queue_free()
	await process_frame
	return true


func _verify_grass_distribution(layer: TileMapLayer) -> bool:
	var counts := _atlas_coordinate_counts(layer)
	var total := layer.get_used_cells().size()
	if total != 660:
		return _fail("Base terrain no longer covers the 30x22 Town Square grid.")

	var base_ratio := float(int(counts.get(Vector2i(0, 0), 0))) / total
	var variant_count := 0
	for x in range(1, 6):
		variant_count += int(counts.get(Vector2i(x, 0), 0))
	var variant_ratio := float(variant_count) / total
	var worn_count := int(counts.get(Vector2i(6, 0), 0)) + int(counts.get(Vector2i(7, 0), 0))
	var worn_ratio := float(worn_count) / total

	if base_ratio < 0.70 or base_ratio > 0.80:
		return _fail("Primary grass usage is outside the documented 70-80%% range.")
	if variant_ratio < 0.15 or variant_ratio > 0.25:
		return _fail("Subtle grass variation is outside the documented 15-25%% range.")
	if worn_ratio > 0.10:
		return _fail("Worn grass exceeds the documented maximum.")
	return true


func _verify_road_distribution(layer: TileMapLayer) -> bool:
	var counts := _atlas_coordinate_counts(layer)
	var fill_count := int(counts.get(Vector2i(0, 1), 0))
	var variant_count := 0
	var distinct_variants := 0
	for x in range(1, 5):
		var count := int(counts.get(Vector2i(x, 1), 0))
		variant_count += count
		if count > 0:
			distinct_variants += 1
	var worn_count := int(counts.get(Vector2i(5, 1), 0)) + int(counts.get(Vector2i(6, 1), 0))
	var total_fill := fill_count + variant_count + worn_count
	if total_fill == 0 or distinct_variants < 3:
		return _fail("Road fill does not use enough coherent variants.")
	if float(worn_count) / total_fill > 0.12:
		return _fail("Worn road variants are overused.")
	return true


func _verify_plaza_distribution(layer: TileMapLayer) -> bool:
	var counts := _atlas_coordinate_counts(layer)
	var distinct_variants := 0
	for coordinate in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5)]:
		if int(counts.get(coordinate, 0)) > 0:
			distinct_variants += 1
	var macro_count := 0
	for coordinate in [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]:
		macro_count += int(counts.get(coordinate, 0))
	if distinct_variants < 4:
		return _fail("Plaza fill does not use enough subtle variants.")
	if macro_count == 0 or float(macro_count) / layer.get_used_cells().size() > 0.10:
		return _fail("Plaza macro variation is absent or overused.")
	return true


func _atlas_coordinate_counts(layer: TileMapLayer) -> Dictionary:
	var counts := {}
	for cell in layer.get_used_cells():
		var coordinate := layer.get_cell_atlas_coords(cell)
		counts[coordinate] = counts.get(coordinate, 0) + 1
	return counts


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
