extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const EXPECTED_SOURCE_SHA256 := "82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8"
const EXPECTED_TERRAIN_SHA256 := "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
const BUILDING_ROOT := "SolidScenery/Buildings/"
const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"
const BUILDINGS := {
	&"GenericBuildingNorthwest": {
		"position": Vector2(144, 112),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1.png",
		"v1_hash": "f493d5ac99bb9c81e04f940244c6e79fdabad1f2303abea8f3557ae58048418f",
		"v2_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v2.png",
		"v2_hash": "24b29773c878b774b4f370ce812bb13ff5fb71fd1fe0a6f53c629f1c4174d479",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v3.png",
		"runtime_hash": "f0c26b6fee62fc89b93e7c29ee43968f89e8304ad7fb56ab1340b9dfa64f6f6e",
		"texture_size": Vector2i(168, 130),
		"sprite_position": Vector2(0, -11),
	},
	&"GenericBuildingSouthwest": {
		"position": Vector2(144, 560),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1.png",
		"v1_hash": "e8d418c26653085d63f8bb434068908f3368508a33ae467346ce44a13adfb335",
		"v2_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v2.png",
		"v2_hash": "a9b63a7d6ad67bdbe3d99c97bdd9b3c3e6f4ac9014bdd5f0fc2e8734187d1d93",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v3.png",
		"runtime_hash": "968afcb3f1429ebf008dd5c33fcb5cf6b0fb81b2cc354f7786c0c9ef882cfd76",
		"texture_size": Vector2i(180, 126),
		"sprite_position": Vector2(0, -9),
	},
	&"GenericBuildingNortheast": {
		"position": Vector2(832, 208),
		"footprint": Vector2(128, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1.png",
		"v1_hash": "023082b67d5924c542c250c5080f35410a3c5c9b69a5ca5cc9e6534b100b1460",
		"v2_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v2.png",
		"v2_hash": "8505d8435638e305544d6794d464d1c7249b595b2bf0cb279f42a68139c0f0b1",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v3.png",
		"runtime_hash": "5c7310e51d10093e939d0116b57b66fa3c44f446edb95ae983114af47bc92059",
		"texture_size": Vector2i(150, 126),
		"sprite_position": Vector2(0, -10),
	},
	&"GenericBuildingSoutheast": {
		"position": Vector2(816, 560),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1.png",
		"v1_hash": "cd0e3baaf0ad75ca29b94d2651c0ad7af746bf9db5cbdb3e8c07d71bed63d1dd",
		"v2_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v2.png",
		"v2_hash": "00ae942961bfe3cf6abef30804e848f2b8565d2c38c3670c193f2993f8a3e2af",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v3.png",
		"runtime_hash": "e243f0ebba150353983aac91b0d75d727b2fa3d8ff80bfff22a48a2ce4c87343",
		"texture_size": Vector2i(178, 140),
		"sprite_position": Vector2(0, -17),
	},
	&"GenericBuildingSouth": {
		"position": Vector2(352, 624),
		"footprint": Vector2(128, 64),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v1.png",
		"v1_hash": "bcd2289ef3685ac2205664fd90ce617657624be48641a9026b69baef64ec7456",
		"v2_path": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v2.png",
		"v2_hash": "b33ca98d80e099c817fe8cc47894a93184e4aab7fb2a690f37818d41d2f22457",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v3.png",
		"runtime_hash": "63a0a21ec7c7a4d9590e70af69b6db98424b963b2987325e4a95b6291451bbee",
		"texture_size": Vector2i(138, 108),
		"sprite_position": Vector2(0, -17),
	},
}
const ENTRY_POSITIONS := {
	&"from_wayfarers_approach": Vector2(160, 352),
	&"from_residential": Vector2(800, 352),
	&"from_marketplace": Vector2(480, 160),
	&"from_commons": Vector2(480, 544),
}
const EXIT_POSITIONS := {
	&"ToWayfarersApproach": Vector2(64, 352),
	&"ToResidential": Vector2(896, 352),
	&"ToMarketplace": Vector2(480, 64),
	&"ToCommons": Vector2(480, 640),
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_protected_files():
		return
	if not _verify_runtime_textures():
		return
	if not await _verify_town_square():
		return

	print("PASS: Caden Architecture Runtime v3 source-fidelity integration, protected rollback assets, locked layout, and visual-only scene wiring.")
	quit(0)


func _verify_protected_files() -> bool:
	if FileAccess.get_sha256("res://assets/source_art/caden/architecture/caden_architecture_master_v1.png") != EXPECTED_SOURCE_SHA256:
		return _fail("The immutable architecture source-master hash changed.")
	if FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png") != EXPECTED_TERRAIN_SHA256:
		return _fail("The protected Terrain Runtime v1.1 hash changed.")
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		if FileAccess.get_sha256(expected["v1_path"] as String) != expected["v1_hash"]:
			return _fail("Protected Runtime v1 texture changed for %s." % building_name)
		if FileAccess.get_sha256(expected["v2_path"] as String) != expected["v2_hash"]:
			return _fail("Protected Runtime v2 rollback texture changed for %s." % building_name)
	var manifest_file := FileAccess.open(RUNTIME_MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		return _fail("Runtime v3 approval manifest is missing.")
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	if not parsed is Dictionary:
		return _fail("Runtime v3 approval manifest is invalid.")
	var manifest := parsed as Dictionary
	if manifest.get("gate_state", "") != "town_square_architecture_runtime_v3_visual_approved":
		return _fail("Runtime v3 approval state changed.")
	if (manifest.get("terrain_decision", {}) as Dictionary).get("status", "") != "approved_active_tonal_runtime_v1_3":
		return _fail("Town Square protected terrain decision changed.")
	if (manifest.get("generated_buildings", {}) as Dictionary).size() != BUILDINGS.size():
		return _fail("Runtime v3 approval manifest building count changed.")
	return true


func _verify_runtime_textures() -> bool:
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		var path := expected["runtime_path"] as String
		if not FileAccess.file_exists(path):
			return _fail("Missing Runtime v3 texture for %s." % building_name)
		if FileAccess.get_sha256(path) != expected["runtime_hash"]:
			return _fail("Runtime v3 texture hash changed for %s." % building_name)
		var texture := load(path) as Texture2D
		if texture == null:
			return _fail("Runtime v3 texture did not load for %s." % building_name)
		if Vector2i(texture.get_size()) != expected["texture_size"]:
			return _fail("Runtime v3 dimensions changed for %s." % building_name)
		var image := texture.get_image()
		if image == null or image.is_empty():
			return _fail("Runtime v3 image data is unavailable for %s." % building_name)
		if not _has_binary_transparency(image):
			return _fail("Runtime v3 texture lacks clean binary transparency for %s." % building_name)
		if not _has_clear_canvas_edge(image):
			return _fail("Runtime v3 texture touches its canvas edge for %s." % building_name)
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


func _has_clear_canvas_edge(image: Image) -> bool:
	for x in range(image.get_width()):
		if not is_zero_approx(image.get_pixel(x, 0).a) or not is_zero_approx(image.get_pixel(x, image.get_height() - 1).a):
			return false
	for y in range(image.get_height()):
		if not is_zero_approx(image.get_pixel(0, y).a) or not is_zero_approx(image.get_pixel(image.get_width() - 1, y).a):
			return false
	return true


func _verify_town_square() -> bool:
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	root.add_child(town_square)
	await process_frame

	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square camera bounds changed during architecture polish.")
	var footprints: Array[Rect2] = []
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		var building := town_square.get_node(NodePath(BUILDING_ROOT + String(building_name))) as StaticBody2D
		if building == null or building.position != expected["position"]:
			return _fail("Locked center changed for %s." % building_name)
		var collision := building.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D
		if rectangle == null or rectangle.size != expected["footprint"]:
			return _fail("Locked collision changed for %s." % building_name)
		footprints.append(Rect2(building.position - rectangle.size * 0.5, rectangle.size))

		var sprite := building.get_node("ExteriorSprite") as Sprite2D
		if sprite == null or sprite.texture == null or sprite.texture.resource_path != expected["runtime_path"]:
			return _fail("Town Square does not reference Runtime v3 for %s." % building_name)
		if sprite.position != expected["sprite_position"] or sprite.get_script() != null:
			return _fail("Runtime v3 structural pivot or visual-only status changed for %s." % building_name)
		var shadow := building.get_node("ContactShadow") as Polygon2D
		if shadow == null or shadow.get_script() != null:
			return _fail("Contact shadow is missing or gained gameplay logic for %s." % building_name)
		var fallback := building.get_node("DevelopmentFallback") as Node2D
		if fallback.visible or fallback.get_node_or_null("Visual") == null:
			return _fail("Hidden greybox fallback changed for %s." % building_name)
		for descendant in building.find_children("*", "Area2D", true, false):
			return _fail("Architecture added a door or interaction area under %s: %s." % [building_name, descendant.name])
		for descendant in building.find_children("*", "CollisionObject2D", true, false):
			if descendant != building:
				return _fail("Architecture visual added physics under %s." % building_name)

	if not _verify_corridors(town_square, footprints):
		return false
	if town_square.get_node("Actors/NPCs").get_child_count() != 5:
		return _fail("Town Square NPC population does not include the three bounded ambient patrols.")
	town_square.queue_free()
	await process_frame
	return true


func _verify_corridors(town_square: Node2D, footprints: Array[Rect2]) -> bool:
	var entries := town_square.get_node("EntryPoints") as Node2D
	for entry_name: StringName in ENTRY_POSITIONS:
		var marker := entries.get_node(NodePath(entry_name)) as Marker2D
		if marker.position != ENTRY_POSITIONS[entry_name] or _point_is_blocked(marker.position, footprints):
			return _fail("Entry corridor changed or became blocked: %s." % entry_name)
	var exits := town_square.get_node("Exits") as Node2D
	if exits.get_child_count() != 4:
		return _fail("Town Square exit count changed.")
	for exit_name: StringName in EXIT_POSITIONS:
		var zone_exit := exits.get_node(NodePath(exit_name)) as Area2D
		if zone_exit.position != EXIT_POSITIONS[exit_name] or _point_is_blocked(zone_exit.position, footprints):
			return _fail("Exit corridor changed or became blocked: %s." % exit_name)
	return true


func _point_is_blocked(point: Vector2, footprints: Array[Rect2]) -> bool:
	for footprint in footprints:
		if footprint.has_point(point):
			return true
	return false


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
