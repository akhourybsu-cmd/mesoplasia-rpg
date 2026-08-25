extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const EXPECTED_SOURCE_SHA256 := "82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8"
const EXPECTED_TERRAIN_SHA256 := "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
const BUILDING_ROOT := "SolidScenery/Buildings/"
const BUILDINGS := {
	&"GenericBuildingNorthwest": {
		"position": Vector2(144, 112),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1.png",
		"v1_hash": "f493d5ac99bb9c81e04f940244c6e79fdabad1f2303abea8f3557ae58048418f",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v2.png",
		"runtime_hash": "24b29773c878b774b4f370ce812bb13ff5fb71fd1fe0a6f53c629f1c4174d479",
		"texture_size": Vector2i(192, 160),
		"join_bounds": Rect2i(20, 65, 152, 6),
	},
	&"GenericBuildingSouthwest": {
		"position": Vector2(144, 560),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1.png",
		"v1_hash": "e8d418c26653085d63f8bb434068908f3368508a33ae467346ce44a13adfb335",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v2.png",
		"runtime_hash": "a9b63a7d6ad67bdbe3d99c97bdd9b3c3e6f4ac9014bdd5f0fc2e8734187d1d93",
		"texture_size": Vector2i(192, 160),
		"join_bounds": Rect2i(20, 65, 152, 4),
	},
	&"GenericBuildingNortheast": {
		"position": Vector2(832, 208),
		"footprint": Vector2(128, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1.png",
		"v1_hash": "023082b67d5924c542c250c5080f35410a3c5c9b69a5ca5cc9e6534b100b1460",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v2.png",
		"runtime_hash": "8505d8435638e305544d6794d464d1c7249b595b2bf0cb279f42a68139c0f0b1",
		"texture_size": Vector2i(160, 160),
		"join_bounds": Rect2i(20, 65, 120, 6),
	},
	&"GenericBuildingSoutheast": {
		"position": Vector2(816, 560),
		"footprint": Vector2(160, 96),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1.png",
		"v1_hash": "cd0e3baaf0ad75ca29b94d2651c0ad7af746bf9db5cbdb3e8c07d71bed63d1dd",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v2.png",
		"runtime_hash": "00ae942961bfe3cf6abef30804e848f2b8565d2c38c3670c193f2993f8a3e2af",
		"texture_size": Vector2i(192, 160),
		"join_bounds": Rect2i(20, 65, 152, 6),
	},
	&"GenericBuildingSouth": {
		"position": Vector2(352, 624),
		"footprint": Vector2(128, 64),
		"v1_path": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v1.png",
		"v1_hash": "bcd2289ef3685ac2205664fd90ce617657624be48641a9026b69baef64ec7456",
		"runtime_path": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v2.png",
		"runtime_hash": "b33ca98d80e099c817fe8cc47894a93184e4aab7fb2a690f37818d41d2f22457",
		"texture_size": Vector2i(160, 128),
		"join_bounds": Rect2i(20, 55, 120, 4),
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

	print("PASS: Caden Architecture Runtime v2 continuous roofs, protected prior assets, locked layout, and visual-only integration.")
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
	return true


func _verify_runtime_textures() -> bool:
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		var path := expected["runtime_path"] as String
		if not FileAccess.file_exists(path):
			return _fail("Missing Runtime v2 texture for %s." % building_name)
		if FileAccess.get_sha256(path) != expected["runtime_hash"]:
			return _fail("Runtime v2 texture hash changed for %s." % building_name)
		var texture := load(path) as Texture2D
		if texture == null:
			return _fail("Runtime v2 texture did not load for %s." % building_name)
		if Vector2i(texture.get_size()) != expected["texture_size"]:
			return _fail("Runtime v2 dimensions changed for %s." % building_name)
		var image := texture.get_image()
		if image == null or image.is_empty():
			return _fail("Runtime v2 image data is unavailable for %s." % building_name)
		if not _has_binary_transparency(image):
			return _fail("Runtime v2 texture lacks clean binary transparency for %s." % building_name)
		if not _join_is_opaque(image, expected["join_bounds"] as Rect2i):
			return _fail("Runtime v2 has a transparent roof/façade gap for %s." % building_name)
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


func _join_is_opaque(image: Image, bounds: Rect2i) -> bool:
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if not is_equal_approx(image.get_pixel(x, y).a, 1.0):
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
			return _fail("Town Square does not reference Runtime v2 for %s." % building_name)
		if sprite.position != Vector2(0, -16) or sprite.get_script() != null:
			return _fail("Runtime v2 sprite anchor or visual-only status changed for %s." % building_name)
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
