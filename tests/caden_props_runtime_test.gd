extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const EXPECTED_PROTECTED_HASHES := {
	"res://assets/source_art/caden/props/caden_props_master_v1.png": "1bec25a3cb6928014a893cbbd9e04d3b4d4cd9105171df45318037098446ae53",
	"res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1_1.png": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1_1.png": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1_1.png": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
	"res://assets/environments/caden/architecture/town_square/town_square_building_south_v1_1.png": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
	"res://assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.png": "9a9cf0889528763c2cdbdbe4b7d5fb755c5df9247529f9dcf2e5e5864190f045",
	"res://assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png": "4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828",
	"res://assets/environments/caden/nature/trees/caden_tree_medium_02_v1.png": "c062eca53c29d4f734716e2708c48acb35bfe86cafbfb71c453a667096f735d9",
	"res://assets/environments/caden/nature/trees/caden_tree_small_01_v1.png": "099d85522798fa45f68b20e9b23afab2f171936c7279b0f96795d808d78bce78",
	"res://assets/environments/caden/nature/trees/caden_tree_small_02_v1.png": "907f22a378b064941e7bf92aba877dd1ac9eb08e31f3b2c29c494d16954d9d1e",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_01_v1.png": "71d4f3883c0cb48ba20b05dea8288fc877b4031aeda2fe4a137141317e6b9c56",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_02_v1.png": "b7aa6706bd868e828e7c1843535b484eefe2b7416a172cf454c19d85ccb60fe5",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_03_v1.png": "d488ebf7a5e5a1b0e198e098c977047d7337c285df376ae75966255a5249cc28",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_01_v1.png": "1b6f822eeb9344af4964b798596d8397d3bbb46c0df8b094ca1de4176d4e3d51",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_02_v1.png": "9f0d898a81bce8dbb726e2d132b50ad0fef987cbce8f4aa46af8184d1ba3ed4c",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_03_v1.png": "6f18c869d556e9d37128a8cc78a2dfcd6348fe078c9293189ff89d575f6d5113",
	"res://assets/environments/caden/nature/rocks/caden_rock_small_01_v1.png": "1314c6e6e33e4e32588980a7d74821f7ca0f8d27002801926ed45f1c861f4887",
	"res://assets/environments/caden/nature/rocks/caden_rock_small_02_v1.png": "db8d584dcb72613b99e58dfa0d3ec7c034bb3d9ac8735bc22c6df06252b8beb6",
	"res://assets/environments/caden/nature/rocks/caden_rock_cluster_01_v1.png": "1918ff6469b3684e84aba4c5ea6d7437d87894f280c84b5cf2fab0d629927660",
}
const RUNTIME_TEXTURES := {
	"res://assets/environments/caden/props/seating/caden_bench_01_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/props/seating/caden_bench_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png": Vector2i(32, 96),
	"res://assets/environments/caden/props/lighting/caden_ground_lantern_01_v1.png": Vector2i(32, 64),
	"res://assets/environments/caden/props/fences/caden_fence_straight_01_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/props/fences/caden_fence_corner_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/fences/caden_fence_gate_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/fences/caden_fence_end_01_v1.png": Vector2i(32, 64),
	"res://assets/environments/caden/props/planters/caden_planter_box_01_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/props/planters/caden_planter_box_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_barrel_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_barrel_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_crate_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_crate_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_sack_cluster_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/storage/caden_storage_cluster_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/travel/caden_luggage_bundle_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/travel/caden_luggage_bundle_02_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/travel/caden_travel_pack_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/props/signage/caden_signpost_blank_01_v1.png": Vector2i(64, 64),
}
const EXPECTED_CATEGORY_COUNTS := {
	"Seating": 2,
	"Lighting": 3,
	"Fences": 4,
	"Planters": 2,
	"Storage": 3,
	"Travel": 2,
}
const EXPECTED_COLLIDERS := {
	"Seating/BenchWest": Vector2(52, 10),
	"Seating/BenchEast": Vector2(64, 10),
	"Lighting/LanternNorth": Vector2(12, 10),
	"Lighting/LanternSouth": Vector2(12, 10),
}
const PROTECTED_CLEARANCES := [
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
const PRINCIPAL_ROUTES := [
	Rect2(0, 288, 224, 128),
	Rect2(736, 288, 224, 128),
	Rect2(416, 0, 128, 160),
	Rect2(416, 544, 128, 160),
]
const SOLID_FOOTPRINTS := [
	Rect2(64, 64, 160, 96),
	Rect2(64, 512, 160, 96),
	Rect2(768, 160, 128, 96),
	Rect2(736, 512, 160, 96),
	Rect2(288, 592, 128, 64),
	Rect2(256, 224, 96, 96),
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_protected_files():
		return
	if not _verify_runtime_textures():
		return
	if not await _verify_town_square():
		return
	print("PASS: Caden Neutral Props Runtime v1 assets, hierarchy, collisions, clearances, and visual-only integration.")
	quit(0)


func _verify_protected_files() -> bool:
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)
	for path: String in EXPECTED_PROTECTED_HASHES:
		if FileAccess.get_sha256(path) != EXPECTED_PROTECTED_HASHES[path]:
			return _fail("Protected input changed: %s" % path)
	return true


func _verify_runtime_textures() -> bool:
	for path: String in RUNTIME_TEXTURES:
		if not FileAccess.file_exists(path):
			return _fail("Missing neutral-prop runtime texture: %s" % path)
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != RUNTIME_TEXTURES[path]:
			return _fail("Neutral-prop texture failed to load at its documented size: %s" % path)
		var image := texture.get_image()
		if image == null or image.is_empty() or not _has_binary_transparency(image):
			return _fail("Neutral-prop texture lacks clean binary transparency: %s" % path)
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
	var props := town_square.get_node_or_null("EnvironmentalProps/Props") as Node2D
	if props == null:
		return _fail("Town Square is missing its Props hierarchy.")
	for category_name: String in EXPECTED_CATEGORY_COUNTS:
		var category := props.get_node_or_null(category_name)
		if category == null or category.get_child_count() != EXPECTED_CATEGORY_COUNTS[category_name]:
			return _fail("Props category count changed: %s" % category_name)
	if not _verify_visual_only_tree(props):
		return false
	if not _verify_placement_bases(props):
		return false
	if not _verify_colliders(props):
		return false
	if not _verify_locked_scene_state(town_square, props):
		return false
	town_square.queue_free()
	await process_frame
	return true


func _verify_visual_only_tree(props: Node2D) -> bool:
	var collision_objects := props.find_children("*", "CollisionObject2D", true, false)
	if collision_objects.size() != EXPECTED_COLLIDERS.size():
		return _fail("Neutral props must contain exactly four collision objects.")
	for object: Node in collision_objects:
		if not object is StaticBody2D:
			return _fail("Neutral props introduced a non-static collision object: %s" % object.name)
	if not props.find_children("*", "Area2D", true, false).is_empty():
		return _fail("Neutral props introduced an interaction or trigger area.")
	for sprite_node: Node in props.find_children("*", "Sprite2D", true, false):
		var sprite := sprite_node as Sprite2D
		if sprite.texture == null or sprite.get_script() != null:
			return _fail("A neutral prop sprite lacks a texture or gained gameplay logic: %s" % sprite.name)
		if "source_art" in sprite.texture.resource_path:
			return _fail("A neutral prop directly references the source master: %s" % sprite.name)
	for node: Node in _descendants(props):
		if node.get_script() != null:
			return _fail("Neutral-props hierarchy gained a script: %s" % node.name)
	return true


func _verify_placement_bases(props: Node2D) -> bool:
	for prop: Node2D in _placed_props(props):
		if prop.position != prop.position.round():
			return _fail("A neutral prop uses fractional placement: %s" % prop.name)
		for protected: Rect2 in PROTECTED_CLEARANCES:
			if protected.has_point(prop.position):
				return _fail("A neutral prop base enters a protected clearance: %s" % prop.name)
		for route: Rect2 in PRINCIPAL_ROUTES:
			if route.has_point(prop.position):
				return _fail("A neutral prop base enters a principal route: %s" % prop.name)
	return true


func _verify_colliders(props: Node2D) -> bool:
	var collision_rects: Array[Rect2] = []
	for path: String in EXPECTED_COLLIDERS:
		var body := props.get_node_or_null(path) as StaticBody2D
		if body == null:
			return _fail("Missing approved static prop collider: %s" % path)
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D if collision != null else null
		if rectangle == null or rectangle.size != EXPECTED_COLLIDERS[path]:
			return _fail("Approved prop collision size changed: %s" % path)
		if collision.position != Vector2(0, -5):
			return _fail("Approved prop collision anchor changed: %s" % path)
		var collision_rect := Rect2(body.position + collision.position - rectangle.size * 0.5, rectangle.size)
		collision_rects.append(collision_rect)
		for protected: Rect2 in PROTECTED_CLEARANCES:
			if collision_rect.intersects(protected):
				return _fail("Prop collider enters a protected clearance: %s" % path)
		for route: Rect2 in PRINCIPAL_ROUTES:
			if collision_rect.intersects(route):
				return _fail("Prop collider narrows a principal route: %s" % path)
		if _minimum_distance_to_solids(collision_rect) < 64.0:
			return _fail("Prop collider is less than 64 pixels from locked solid geometry: %s" % path)
	for index in range(collision_rects.size()):
		for other_index in range(index + 1, collision_rects.size()):
			if _distance_between_rectangles(collision_rects[index], collision_rects[other_index]) < 64.0:
				return _fail("Approved prop colliders create a gap narrower than 64 pixels.")
	return true


func _minimum_distance_to_solids(rectangle: Rect2) -> float:
	var minimum := INF
	for solid: Rect2 in SOLID_FOOTPRINTS:
		minimum = minf(minimum, _distance_between_rectangles(rectangle, solid))
	return minimum


func _distance_between_rectangles(first: Rect2, second: Rect2) -> float:
	var dx := maxf(maxf(second.position.x - first.end.x, first.position.x - second.end.x), 0.0)
	var dy := maxf(maxf(second.position.y - first.end.y, first.position.y - second.end.y), 0.0)
	return Vector2(dx, dy).length()


func _verify_locked_scene_state(town_square: Node2D, props: Node2D) -> bool:
	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square camera bounds changed during prop integration.")
	if town_square.get_node("Exits").get_child_count() != 4:
		return _fail("Town Square exit count changed during prop integration.")
	if town_square.get_node("Actors/NPCs").get_child_count() != 2:
		return _fail("Town Square NPC population changed during prop integration.")
	var closure := town_square.get_node("SolidScenery/TerrebonneClosure") as Node2D
	if not _verify_static_rectangle(closure.get_node("HorizontalBarrier") as StaticBody2D, Vector2(768, 112), Vector2(320, 32)):
		return _fail("The Terrebonne horizontal closure changed.")
	if not _verify_static_rectangle(closure.get_node("VerticalBarrier") as StaticBody2D, Vector2(624, 80), Vector2(32, 96)):
		return _fail("The Terrebonne vertical closure changed.")
	var terrebonne_route := PackedVector2Array([Vector2(576, 192), Vector2(704, 192), Vector2(864, 32), Vector2(736, 32)])
	for prop: Node2D in _placed_props(props):
		if Geometry2D.is_point_in_polygon(prop.position, terrebonne_route):
			return _fail("A neutral prop enters the Terrebonne branch: %s" % prop.name)
	return true


func _verify_static_rectangle(body: StaticBody2D, expected_position: Vector2, expected_size: Vector2) -> bool:
	if body == null or body.position != expected_position:
		return false
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	return rectangle != null and rectangle.size == expected_size


func _descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in parent.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _placed_props(props: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for category: Node in props.get_children():
		for child: Node in category.get_children():
			if child is Node2D:
				result.append(child as Node2D)
	return result


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
