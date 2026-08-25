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
		"texture": "res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1.png",
		"texture_size": Vector2i(192, 160),
	},
	&"GenericBuildingSouthwest": {
		"position": Vector2(144, 560),
		"footprint": Vector2(160, 96),
		"texture": "res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1.png",
		"texture_size": Vector2i(192, 160),
	},
	&"GenericBuildingNortheast": {
		"position": Vector2(832, 208),
		"footprint": Vector2(128, 96),
		"texture": "res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1.png",
		"texture_size": Vector2i(160, 160),
	},
	&"GenericBuildingSoutheast": {
		"position": Vector2(816, 560),
		"footprint": Vector2(160, 96),
		"texture": "res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1.png",
		"texture_size": Vector2i(192, 160),
	},
	&"GenericBuildingSouth": {
		"position": Vector2(352, 624),
		"footprint": Vector2(128, 64),
		"texture": "res://assets/environments/caden/architecture/town_square/town_square_building_south_v1.png",
		"texture_size": Vector2i(160, 128),
	},
}
const ENTRY_POSITIONS := {
	&"from_wayfarers_approach": Vector2(160, 352),
	&"from_residential": Vector2(800, 352),
	&"from_marketplace": Vector2(480, 160),
	&"from_commons": Vector2(480, 544),
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

	print("PASS: Caden architecture runtime assets, locked footprints, clear approaches, and visual-only integration.")
	quit(0)


func _verify_protected_files() -> bool:
	if FileAccess.get_sha256("res://assets/source_art/caden/architecture/caden_architecture_master_v1.png") != EXPECTED_SOURCE_SHA256:
		return _fail("The immutable Caden architecture source-master hash changed.")
	if FileAccess.get_sha256("res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png") != EXPECTED_TERRAIN_SHA256:
		return _fail("The protected Terrain Runtime v1.1 atlas hash changed.")
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)
	return true


func _verify_runtime_textures() -> bool:
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		var path := expected["texture"] as String
		if not FileAccess.file_exists(path):
			return _fail("Missing runtime texture for %s." % building_name)
		if path.contains("source_art"):
			return _fail("Runtime texture path for %s points into source_art." % building_name)

		var texture := load(path) as Texture2D
		if texture == null:
			return _fail("Runtime texture for %s did not load." % building_name)
		var expected_size := expected["texture_size"] as Vector2i
		if Vector2i(texture.get_size()) != expected_size:
			return _fail("Runtime texture for %s has the wrong dimensions." % building_name)
		if expected_size.x % 32 != 0 or expected_size.y % 32 != 0:
			return _fail("Runtime canvas for %s is not divisible by 32." % building_name)

		var image := texture.get_image()
		if image == null or image.is_empty():
			return _fail("Runtime image for %s could not be read." % building_name)
		if not _has_clean_transparency(image):
			return _fail("Runtime image for %s lacks clean binary transparency." % building_name)
	return true


func _has_clean_transparency(image: Image) -> bool:
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

	var footprint_rects: Array[Rect2] = []
	for building_name: StringName in BUILDINGS:
		var expected: Dictionary = BUILDINGS[building_name]
		var building := town_square.get_node(NodePath(BUILDING_ROOT + String(building_name))) as StaticBody2D
		if building == null:
			return _fail("Town Square is missing %s." % building_name)
		if building.position != expected["position"]:
			return _fail("Locked center for %s changed." % building_name)

		var collision := building.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D
		if rectangle == null or rectangle.size != expected["footprint"]:
			return _fail("Locked collision footprint for %s changed." % building_name)
		footprint_rects.append(Rect2(building.position - rectangle.size * 0.5, rectangle.size))

		var fallback := building.get_node("DevelopmentFallback") as Node2D
		if fallback.visible or fallback.get_node_or_null("Visual") == null:
			return _fail("Brown development fallback for %s is not preserved and hidden." % building_name)
		var label_name := String(building_name).trim_prefix("Generic") + "Label"
		var development_label := town_square.get_node(NodePath("DevelopmentLabels/" + label_name)) as Label
		if development_label.visible:
			return _fail("Development label for %s still covers the runtime exterior." % building_name)

		var sprite := building.get_node("ExteriorSprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			return _fail("%s is missing its runtime exterior sprite." % building_name)
		# Runtime v1 remains independently validated above when a later version
		# becomes the scene's active visual; v1 stays available for rollback.
		if sprite.texture.resource_path.contains("source_art"):
			return _fail("%s references a source master directly." % building_name)
		if sprite.position != Vector2(0, -16):
			return _fail("%s no longer uses the documented integer anchor." % building_name)

		var shadow := building.get_node("ContactShadow") as Polygon2D
		if shadow == null:
			return _fail("%s is missing its visual contact shadow." % building_name)
		for descendant in building.find_children("*", "CollisionObject2D", true, false):
			if descendant != building:
				return _fail("Architecture visual for %s added a physics collision object." % building_name)
		for descendant in building.find_children("*", "Area2D", true, false):
			return _fail("Architecture visual for %s added a door or interaction area: %s." % [building_name, descendant.name])

	if not _verify_entry_clearance(town_square, footprint_rects):
		return false
	if not _verify_npc_approaches(town_square, footprint_rects):
		return false
	if town_square.get_node("Exits").get_child_count() != 4:
		return _fail("Town Square zone-exit count changed during architecture integration.")

	town_square.queue_free()
	await process_frame
	return true


func _verify_entry_clearance(town_square: Node2D, footprints: Array[Rect2]) -> bool:
	var entries := town_square.get_node("EntryPoints") as Node2D
	for entry_name: StringName in ENTRY_POSITIONS:
		var marker := entries.get_node(NodePath(entry_name)) as Marker2D
		if marker.position != ENTRY_POSITIONS[entry_name]:
			return _fail("Town Square entry %s moved." % entry_name)
		for footprint in footprints:
			if footprint.has_point(marker.position):
				return _fail("Town Square entry %s is blocked by a building footprint." % entry_name)
	return true


func _verify_npc_approaches(town_square: Node2D, footprints: Array[Rect2]) -> bool:
	var npc_root := town_square.get_node("Actors/NPCs") as Node2D
	if npc_root.get_child_count() != 5:
		return _fail("Town Square NPC count changed during architecture integration.")
	var interactive_count := 0
	for npc in npc_root.get_children():
		if not npc.is_in_group(&"npcs"):
			continue
		interactive_count += 1
		var interactable := npc.get_node_or_null("Interactable") as Area2D
		if interactable == null:
			return _fail("NPC %s lost its interaction area." % npc.name)
		var clear_approaches := 0
		for offset in [Vector2(0, -48), Vector2(48, 0), Vector2(0, 48), Vector2(-48, 0)]:
			var approach_point: Vector2 = npc.position + offset
			var blocked := false
			for footprint in footprints:
				if footprint.has_point(approach_point):
					blocked = true
					break
			if not blocked:
				clear_approaches += 1
		if clear_approaches < 2:
			return _fail("NPC %s no longer has sufficient clear interaction approaches." % npc.name)
	if interactive_count != 2:
		return _fail("Town Square interactive NPC count changed during architecture integration.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
