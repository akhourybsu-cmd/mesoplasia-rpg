extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const EXPECTED_SOURCE_SHA256 := "611eb43cc137a63b477d982371e88d6d6d07997878a12bde8202ef26cfe93650"
const EXPECTED_TERRAIN_SHA256 := "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
const EXPECTED_ARCHITECTURE_HASHES := {
	"res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1_1.png": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1_1.png": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1_1.png": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
	"res://assets/environments/caden/architecture/town_square/town_square_building_south_v1_1.png": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
}
const RUNTIME_TEXTURES := {
	"res://assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png": Vector2i(64, 96),
	"res://assets/environments/caden/nature/trees/caden_tree_medium_02_v1.png": Vector2i(64, 96),
	"res://assets/environments/caden/nature/trees/caden_tree_small_01_v1.png": Vector2i(32, 64),
	"res://assets/environments/caden/nature/trees/caden_tree_small_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_01_v1.png": Vector2i(64, 32),
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_02_v1.png": Vector2i(64, 32),
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_03_v1.png": Vector2i(64, 32),
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_01_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_02_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_03_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/rocks/caden_rock_small_01_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/rocks/caden_rock_small_02_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/rocks/caden_rock_cluster_01_v1.png": Vector2i(32, 32),
	"res://assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.png": Vector2i(96, 96),
}
const BLOCKING_BASES := [
	Vector2(32, 240), Vector2(928, 528), Vector2(32, 512), Vector2(928, 208),
	Vector2(32, 656), Vector2(928, 96), Vector2(80, 160), Vector2(768, 256),
	Vector2(208, 160), Vector2(880, 608), Vector2(80, 608), Vector2(896, 255),
	Vector2(928, 640),
]
const PROTECTED_RECTS := [
	Rect2(0, 256, 144, 192),
	Rect2(816, 256, 144, 192),
	Rect2(384, 0, 192, 192),
	Rect2(384, 512, 192, 192),
	Rect2(256, 224, 96, 96),
	Rect2(96, 160, 96, 64),
	Rect2(96, 608, 96, 64),
	Rect2(784, 256, 96, 64),
	Rect2(768, 608, 96, 64),
	Rect2(304, 656, 96, 48),
	Rect2(240, 400, 96, 96),
	Rect2(624, 208, 96, 96),
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_protected_files():
		return
	if not _verify_runtime_assets():
		return
	if not await _verify_town_square():
		return
	print("PASS: Caden Nature Runtime v1 assets, hierarchy, clearances, and visual-only integration.")
	quit(0)


func _verify_protected_files() -> bool:
	if FileAccess.get_sha256("res://assets/source_art/caden/nature/caden_nature_master_v1.png") != EXPECTED_SOURCE_SHA256:
		return _fail("The immutable Nature source-master hash changed.")
	if FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png") != EXPECTED_TERRAIN_SHA256:
		return _fail("The protected Terrain Runtime v1.1 hash changed.")
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)
	for path: String in EXPECTED_ARCHITECTURE_HASHES:
		if FileAccess.get_sha256(path) != EXPECTED_ARCHITECTURE_HASHES[path]:
			return _fail("Protected Architecture Runtime v1.1 changed: %s" % path)
	return true


func _verify_runtime_assets() -> bool:
	for path: String in RUNTIME_TEXTURES:
		if not FileAccess.file_exists(path):
			return _fail("Missing Nature runtime texture: %s" % path)
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != RUNTIME_TEXTURES[path]:
			return _fail("Nature runtime texture failed to load at its documented size: %s" % path)
		var image := texture.get_image()
		if image == null or image.is_empty() or not _has_binary_transparency(image):
			return _fail("Nature runtime texture lacks clean binary transparency: %s" % path)
	var atlas_path := "res://assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.tres"
	var tile_set := load(atlas_path) as TileSet
	if tile_set == null or tile_set.tile_size != Vector2i(32, 32) or tile_set.get_source_count() != 1:
		return _fail("Nature ground TileSet failed to load with one 32x32 source.")
	var source := tile_set.get_source(tile_set.get_source_id(0)) as TileSetAtlasSource
	if source == null or source.texture_region_size != Vector2i(32, 32) or source.get_tiles_count() != 9:
		return _fail("Nature ground atlas does not expose nine exact 32x32 cells.")
	return true


func _has_binary_transparency(image: Image) -> bool:
	var saw_transparent := false
	var saw_opaque := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if is_zero_approx(alpha):
				saw_transparent = true
			elif is_equal_approx(alpha, 1.0):
				saw_opaque = true
			else:
				return false
	return saw_transparent and saw_opaque


func _verify_town_square() -> bool:
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	root.add_child(town_square)
	await process_frame
	var nature := town_square.get_node_or_null("Nature") as Node2D
	if nature == null:
		return _fail("Town Square is missing its Nature hierarchy.")
	for child_name: String in ["GroundOverlays", "LowVegetation", "Trees", "Rocks"]:
		if nature.get_node_or_null(child_name) == null:
			return _fail("Nature hierarchy is missing %s." % child_name)
	if nature.get_node("GroundOverlays").get_child_count() != 14:
		return _fail("Ground-overlay placement count changed.")
	if nature.get_node("LowVegetation").get_child_count() != 9:
		return _fail("Low-vegetation placement count changed.")
	if nature.get_node("Trees").get_child_count() != 6 or nature.get_node("Rocks").get_child_count() != 3:
		return _fail("Tree or rock placement count changed.")
	if not nature.find_children("*", "CollisionObject2D", true, false).is_empty():
		return _fail("Nature introduced a physics body or area.")
	if not nature.find_children("*", "CollisionShape2D", true, false).is_empty():
		return _fail("Nature introduced a collision shape.")
	var all_sprites := nature.find_children("*", "Sprite2D", true, false)
	for node: Node in all_sprites:
		var sprite := node as Sprite2D
		if sprite.get_script() != null or sprite.texture == null:
			return _fail("Nature sprites must remain visual-only with valid textures.")
		if "source_art" in sprite.texture.resource_path:
			return _fail("A runtime Nature sprite directly references the source master.")
		if not _point_preserves_clearances(sprite.position):
			return _fail("Nature base enters a protected clearance: %s at %s" % [sprite.name, sprite.position])
	for point: Vector2 in BLOCKING_BASES:
		if not _blocking_base_is_supported(point):
			return _fail("Blocking-looking Nature base is outside existing blocked geometry: %s" % point)
	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square bounds changed during Nature integration.")
	if town_square.get_node("Exits").get_child_count() != 4 or town_square.get_node("Actors/NPCs").get_child_count() != 2:
		return _fail("Town Square exits or NPC population changed.")
	town_square.queue_free()
	await process_frame
	return true


func _point_preserves_clearances(point: Vector2) -> bool:
	for rectangle: Rect2 in PROTECTED_RECTS:
		if rectangle.has_point(point):
			return false
	var terrebonne_route := PackedVector2Array([Vector2(576, 192), Vector2(704, 192), Vector2(864, 32), Vector2(736, 32)])
	return not Geometry2D.is_point_in_polygon(point, terrebonne_route)


func _blocking_base_is_supported(point: Vector2) -> bool:
	if point.x <= 32.0 or point.x >= 928.0 or point.y <= 32.0 or point.y >= 672.0:
		return true
	for footprint: Rect2 in [
		Rect2(64, 64, 160, 96), Rect2(64, 512, 160, 96), Rect2(768, 160, 128, 96),
		Rect2(736, 512, 160, 96), Rect2(288, 592, 128, 64),
	]:
		if footprint.grow(0.5).has_point(point):
			return true
	return false


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
