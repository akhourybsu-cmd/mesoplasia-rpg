extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")

const EXPECTED_PROJECT_SHA256 := "b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0"
const EXPECTED_PROTECTED_HASHES := {
	"res://assets/source_art/caden/accents/caden_edenite_festival_master_v1.png": "95a1860a8cc172ae7fbb65a8256450c018f7cef277595c33af80211feff5fc16",
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
	"res://assets/environments/caden/props/seating/caden_bench_01_v1.png": "49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79",
	"res://assets/environments/caden/props/seating/caden_bench_02_v1.png": "b5363f4e1616c517864e717f3f88b5596a8f9bb516d6e8f82d0f77885bd075df",
	"res://assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png": "705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59",
	"res://assets/environments/caden/props/lighting/caden_ground_lantern_01_v1.png": "4fcdf7d84a73a6026cd4cd38e72d5a6e482df9a621693682a3e6abc01df2908c",
	"res://assets/environments/caden/props/fences/caden_fence_straight_01_v1.png": "3f2c330f73edcea4cbf438eff7a9da3cff83a800df304bca3105578ac96065bf",
	"res://assets/environments/caden/props/fences/caden_fence_corner_01_v1.png": "1e5594b37e9340155861839c4124215ba13a162dbadd73e1966261a8f548c637",
	"res://assets/environments/caden/props/fences/caden_fence_gate_01_v1.png": "876bbd3f59c18e969294248a9ddea6dabffe5466cf85f1119811074ccf77a35c",
	"res://assets/environments/caden/props/fences/caden_fence_end_01_v1.png": "2e4f396a9241f0d86916fb49f8a31493e0166270c35fa4ded91877b7585919ef",
	"res://assets/environments/caden/props/planters/caden_planter_box_01_v1.png": "27bd2c5c79206ae766d8b36b21431e0d9bf6e67db5a6da22d1e55d681a7d3782",
	"res://assets/environments/caden/props/planters/caden_planter_box_02_v1.png": "c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8",
	"res://assets/environments/caden/props/storage/caden_barrel_01_v1.png": "6ba3230d218aa0659c3fe2d22d4f74afb5c6019f461155434b3b0bcfdd8c1e55",
	"res://assets/environments/caden/props/storage/caden_barrel_02_v1.png": "0cc377a6f04baa9995da2cfd097c000883b1f9146e80ce4fc76291cb95297c3d",
	"res://assets/environments/caden/props/storage/caden_crate_01_v1.png": "927fe189ec720bbf0eb1575fdbcb21dace7e27f27b3329d04e40cf13bd45a9fb",
	"res://assets/environments/caden/props/storage/caden_crate_02_v1.png": "be608df14dfd73ed49b4e1e98f683e45567ee640faec5b8a1ea57d0b7307b6a3",
	"res://assets/environments/caden/props/storage/caden_sack_cluster_01_v1.png": "df6d76760b092a75753f8ea10889416e6a14452948e1184b586283679f8bad95",
	"res://assets/environments/caden/props/storage/caden_storage_cluster_01_v1.png": "825732a76e08e1bacdd635ad42ba9227e0c205cd90a15521caea5db905d668c0",
	"res://assets/environments/caden/props/travel/caden_luggage_bundle_01_v1.png": "147b1345512ac5faf2a1754e2e19109a83b460a3b9cee5bb5810fd55994367d1",
	"res://assets/environments/caden/props/travel/caden_luggage_bundle_02_v1.png": "d6973d5921940315aa03dee3e01460b0b3f1a90538eaab091fd5c5d592e507b4",
	"res://assets/environments/caden/props/travel/caden_travel_pack_01_v1.png": "8d74fb7dc0f439bfb113b7bd2715f672e311273e90468f0a4cb3f3dd099a9caf",
	"res://assets/environments/caden/props/signage/caden_signpost_blank_01_v1.png": "c9761623de0099b3b84dd9909298f713d38546f31ab548a175c6ac5b75d64ede",
}
const RUNTIME_TEXTURES := {
	"res://assets/environments/caden/accents/edenite/caden_edenite_lantern_01_v1.png": Vector2i(64, 96),
	"res://assets/environments/caden/accents/edenite/caden_edenite_stone_fixture_01_v1.png": Vector2i(64, 96),
	"res://assets/environments/caden/accents/edenite/caden_edenite_small_fixture_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/accents/festival/caden_festival_drape_01_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/accents/festival/caden_festival_drape_02_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_01_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_02_v1.png": Vector2i(96, 64),
	"res://assets/environments/caden/accents/festival/caden_festival_ribbon_drop_01_v1.png": Vector2i(32, 64),
	"res://assets/environments/caden/accents/closure/caden_closure_gate_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/accents/closure/caden_closure_rope_01_v1.png": Vector2i(64, 64),
	"res://assets/environments/caden/accents/closure/caden_closure_timbers_01_v1.png": Vector2i(64, 64),
}
const BINARY_TEXTURES := [
	"res://assets/environments/caden/accents/festival/caden_festival_drape_01_v1.png",
	"res://assets/environments/caden/accents/festival/caden_festival_drape_02_v1.png",
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_01_v1.png",
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_02_v1.png",
	"res://assets/environments/caden/accents/festival/caden_festival_ribbon_drop_01_v1.png",
	"res://assets/environments/caden/accents/closure/caden_closure_gate_01_v1.png",
	"res://assets/environments/caden/accents/closure/caden_closure_rope_01_v1.png",
	"res://assets/environments/caden/accents/closure/caden_closure_timbers_01_v1.png",
]
const PROTECTED_CLEARANCES := [
	Rect2(0, 256, 144, 192),
	Rect2(816, 256, 144, 192),
	Rect2(384, 0, 192, 192),
	Rect2(384, 512, 192, 192),
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
const RESERVED_SPACE := Rect2(256, 224, 96, 96)
const LOCKED_SOLIDS := [
	Rect2(64, 64, 160, 96),
	Rect2(64, 512, 160, 96),
	Rect2(768, 160, 128, 96),
	Rect2(736, 512, 160, 96),
	Rect2(288, 592, 128, 64),
	RESERVED_SPACE,
	Rect2(608, 96, 320, 32),
	Rect2(608, 32, 32, 96),
]
const EXISTING_PROP_COLLIDERS := [
	Rect2(134, 230, 52, 10),
	Rect2(752, 430, 64, 10),
	Rect2(362, 134, 12, 10),
	Rect2(570, 486, 12, 10),
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
	print("PASS: Caden Edenite/Festival Runtime v1 assets, restrained density, fencing, clearances, collision, and visual-only integration.")
	quit(0)


func _verify_protected_files() -> bool:
	if FileAccess.get_sha256("res://project.godot") != EXPECTED_PROJECT_SHA256:
		return _fail("project.godot changed during the Edenite/Festival pass.")
	for path: String in EXPECTED_PROTECTED_HASHES:
		if not FileAccess.file_exists(path):
			return _fail("Missing protected input: %s" % path)
		if FileAccess.get_sha256(path) != EXPECTED_PROTECTED_HASHES[path]:
			return _fail("Protected input changed: %s" % path)
	return true


func _verify_runtime_textures() -> bool:
	for path: String in RUNTIME_TEXTURES:
		if not FileAccess.file_exists(path):
			return _fail("Missing accent runtime texture: %s" % path)
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != RUNTIME_TEXTURES[path]:
			return _fail("Accent texture failed to load at its documented size: %s" % path)
		var image := texture.get_image()
		if image == null or image.is_empty() or not _has_transparent_and_visible_pixels(image):
			return _fail("Accent texture lacks expected transparency: %s" % path)
		if path in BINARY_TEXTURES and not _has_binary_alpha(image):
			return _fail("Festival or closure texture retained unintended partial alpha: %s" % path)
		if "/edenite/" in path and not _has_partial_alpha(image):
			return _fail("Edenite texture lost its contained glow alpha: %s" % path)
	return true


func _has_transparent_and_visible_pixels(image: Image) -> bool:
	var saw_transparent := false
	var saw_visible := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			saw_transparent = saw_transparent or is_zero_approx(alpha)
			saw_visible = saw_visible or alpha > 0.0
	return saw_transparent and saw_visible


func _has_binary_alpha(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if not is_zero_approx(alpha) and not is_equal_approx(alpha, 1.0):
				return false
	return true


func _has_partial_alpha(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0 and alpha < 1.0:
				return true
	return false


func _verify_town_square() -> bool:
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	root.add_child(town_square)
	await process_frame
	var accents := town_square.get_node_or_null("FestivalAndEdenite") as Node2D
	if accents == null:
		return _fail("Town Square is missing the FestivalAndEdenite hierarchy.")
	if not _verify_hierarchy_and_visual_only(accents):
		return false
	if not _verify_fencing(town_square, accents):
		return false
	if not _verify_density(accents):
		return false
	if not _verify_clearances(accents):
		return false
	if not _verify_collision(town_square, accents):
		return false
	if not _verify_locked_scene_state(town_square, accents):
		return false
	town_square.queue_free()
	await process_frame
	return true


func _verify_hierarchy_and_visual_only(accents: Node2D) -> bool:
	var expected_counts := {
		"PerimeterFencing/PlainFences": 6,
		"FestivalFabric/FenceOverlays": 3,
		"FestivalFabric/LanternDecor": 1,
		"EdeniteFixtures": 3,
		"TerrebonneClosure": 4,
	}
	for path: String in expected_counts:
		var branch := accents.get_node_or_null(path)
		if branch == null or branch.get_child_count() != expected_counts[path]:
			return _fail("Accent hierarchy count changed: %s" % path)
	for node: Node in _descendants(accents):
		if node.get_script() != null:
			return _fail("Pass 5 introduced gameplay logic: %s" % node.name)
		if node is Area2D:
			return _fail("Pass 5 introduced an interaction or trigger area: %s" % node.name)
		if node is Light2D or node is LightOccluder2D:
			return _fail("Pass 5 introduced dynamic lighting: %s" % node.name)
		if node is GPUParticles2D or node is CPUParticles2D or node is AnimationPlayer:
			return _fail("Pass 5 introduced animation or particles: %s" % node.name)
		if node is Sprite2D:
			var sprite := node as Sprite2D
			if sprite.texture == null:
				return _fail("Pass 5 contains an untextured sprite: %s" % sprite.name)
			if "source_art" in sprite.texture.resource_path:
				return _fail("A Pass 5 sprite directly references source art: %s" % sprite.name)
	return true


func _verify_fencing(town_square: Node2D, accents: Node2D) -> bool:
	var prior_fences := town_square.get_node("EnvironmentalProps/Props/Fences")
	var new_fences := accents.get_node("PerimeterFencing/PlainFences")
	var decorated := accents.get_node("FestivalFabric/FenceOverlays").get_child_count()
	var total_plain := prior_fences.get_child_count() + new_fences.get_child_count()
	if total_plain != 10:
		return _fail("The selective perimeter should contain 10 neutral fence segments.")
	if decorated != 3 or total_plain < decorated:
		return _fail("Plain perimeter fencing must outnumber decorated segments.")
	var ratio := float(decorated) / float(total_plain)
	if ratio < 0.25 or ratio > 0.40:
		return _fail("Decorated fence coverage left the approved 25–40 percent range.")
	return true


func _verify_density(accents: Node2D) -> bool:
	var fixtures := accents.get_node("EdeniteFixtures")
	if fixtures.get_child_count() < 3 or fixtures.get_child_count() > 5:
		return _fail("Total visible Edenite placement left the approved range.")
	var points: Array[Vector2] = []
	for fixture: Node in fixtures.get_children():
		points.append((fixture as Node2D).global_position)
	var maximum_visible := 0
	for left in range(0, 321):
		for top in range(0, 345):
			var view := Rect2(left, top, 640, 360)
			var count := 0
			for point: Vector2 in points:
				if view.has_point(point):
					count += 1
			maximum_visible = maxi(maximum_visible, count)
	if maximum_visible > 2:
		return _fail("More than two Edenite fixtures can appear in one 640×360 view.")
	return true


func _verify_clearances(accents: Node2D) -> bool:
	for sprite: Sprite2D in _pass5_sprites(accents):
		if sprite.global_position != sprite.global_position.round():
			return _fail("Pass 5 uses fractional placement: %s" % sprite.name)
		if RESERVED_SPACE.intersects(_sprite_canvas_bounds(sprite)):
			return _fail("A Pass 5 asset enters the reserved community space: %s" % sprite.name)
		for protected: Rect2 in PROTECTED_CLEARANCES:
			if protected.has_point(sprite.global_position):
				return _fail("A Pass 5 asset base enters a protected clearance: %s" % sprite.name)
		for route: Rect2 in PRINCIPAL_ROUTES:
			if route.has_point(sprite.global_position):
				return _fail("A Pass 5 asset base enters a principal route: %s" % sprite.name)
	return true


func _verify_collision(town_square: Node2D, accents: Node2D) -> bool:
	var collision_objects := accents.find_children("*", "CollisionObject2D", true, false)
	if collision_objects.size() != 1:
		return _fail("Pass 5 should add exactly one scene-local collision object.")
	var body := accents.get_node_or_null("EdeniteFixtures/LanternEastPlazaEdge") as StaticBody2D
	if body == null or collision_objects[0] != body:
		return _fail("The approved east Edenite lantern collider is missing.")
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	if rectangle == null or rectangle.size != Vector2(14, 10) or collision.position != Vector2(0, -5):
		return _fail("The east Edenite lantern collision shape changed.")
	var collider := Rect2(body.position + collision.position - rectangle.size * 0.5, rectangle.size)
	for protected: Rect2 in PROTECTED_CLEARANCES:
		if collider.intersects(protected):
			return _fail("The Edenite collider enters a protected clearance.")
	for route: Rect2 in PRINCIPAL_ROUTES:
		if collider.intersects(route):
			return _fail("The Edenite collider narrows a principal route.")
	for solid: Rect2 in LOCKED_SOLIDS:
		if _distance_between_rectangles(collider, solid) < 64.0:
			return _fail("The Edenite collider creates a sub-64-pixel gap to locked geometry.")
	for prop_collider: Rect2 in EXISTING_PROP_COLLIDERS:
		if _distance_between_rectangles(collider, prop_collider) < 64.0:
			return _fail("The Edenite collider creates a sub-64-pixel gap to an existing prop.")
	return true


func _verify_locked_scene_state(town_square: Node2D, accents: Node2D) -> bool:
	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square camera bounds changed during Pass 5.")
	if town_square.get_node("Exits").get_child_count() != 4:
		return _fail("Town Square exit count changed during Pass 5.")
	if town_square.get_node("Actors/NPCs").get_child_count() != 2:
		return _fail("Town Square NPC population changed during Pass 5.")
	var locked_closure := town_square.get_node("SolidScenery/TerrebonneClosure") as Node2D
	if not _verify_static_rectangle(locked_closure.get_node("HorizontalBarrier") as StaticBody2D, Vector2(768, 112), Vector2(320, 32)):
		return _fail("The horizontal Terrebonne closure changed.")
	if not _verify_static_rectangle(locked_closure.get_node("VerticalBarrier") as StaticBody2D, Vector2(624, 80), Vector2(32, 96)):
		return _fail("The vertical Terrebonne closure changed.")
	if (locked_closure.get_node("HorizontalBarrier/Visual") as CanvasItem).visible:
		return _fail("The horizontal closure greybox remains visible through the prepared art.")
	if (locked_closure.get_node("VerticalBarrier/Visual") as CanvasItem).visible:
		return _fail("The vertical closure greybox remains visible through the prepared art.")
	var closure_region := Rect2(608, 96, 320, 32)
	for closure_asset: Node in accents.get_node("TerrebonneClosure").get_children():
		if not closure_region.has_point((closure_asset as Node2D).global_position):
			return _fail("Closure art no longer aligns with the existing blocked region: %s" % closure_asset.name)
	return true


func _sprite_canvas_bounds(sprite: Sprite2D) -> Rect2:
	var size := sprite.texture.get_size() * sprite.global_scale.abs()
	var center := sprite.global_position + sprite.offset * sprite.global_scale.abs()
	return Rect2(center - size * 0.5, size)


func _distance_between_rectangles(first: Rect2, second: Rect2) -> float:
	var dx := maxf(maxf(second.position.x - first.end.x, first.position.x - second.end.x), 0.0)
	var dy := maxf(maxf(second.position.y - first.end.y, first.position.y - second.end.y), 0.0)
	return Vector2(dx, dy).length()


func _verify_static_rectangle(body: StaticBody2D, expected_position: Vector2, expected_size: Vector2) -> bool:
	if body == null or body.position != expected_position:
		return false
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	return rectangle != null and rectangle.size == expected_size


func _pass5_sprites(parent: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for node: Node in _descendants(parent):
		if node is Sprite2D:
			result.append(node as Sprite2D)
	return result


func _descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in parent.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
