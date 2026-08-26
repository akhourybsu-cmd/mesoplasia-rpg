extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ROAD_TILESET := preload("res://assets/tilesets/caden/terrain/wayfarers_approach_road_runtime_v1.tres")
const MANIFEST_PATH := "res://assets/environments/caden/wayfarers_approach/wayfarers_approach_runtime_manifest_v1.json"
const PILOT_MANIFEST_PATH := "res://assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json"

var _zone: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_zone = ZONE_SCENE.instantiate()
	root.add_child(_zone)
	await physics_frame

	if _zone.get("camera_bounds") != Rect2i(0, 0, 1024, 640):
		return _fail("Wayfarer's Approach camera bounds changed.")
	if not _check_position("EntryPoints/arrival", Vector2(128, 320)):
		return
	if not _check_position("EntryPoints/from_town_square", Vector2(864, 320)):
		return
	if not _check_position("EntryPoints/from_marketplace", Vector2(512, 128)):
		return
	if not _check_position("Exits/ToTownSquare", Vector2(960, 320)):
		return
	if not _check_position("Exits/ToMarketplace", Vector2(512, 64)):
		return
	if not _check_position("Actors/NPCs/RestingTraveler", Vector2(128, 448)):
		return
	if not _check_position("Actors/NPCs/ContinuingTraveler", Vector2(768, 448)):
		return
	if not _check_position("Actors/NPCs/RoadsideLocal", Vector2(416, 352)):
		return
	if not _check_position("SolidScenery/PilotProps/HitchingRailBarrels", Vector2(680, 500)):
		return
	if not _check_position("SolidScenery/PilotProps/BenchLuggageLantern", Vector2(860, 556)):
		return

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var player_shape := player.get_node("CollisionShape2D").shape as RectangleShape2D
	if player_shape.size != Vector2(24, 24):
		return _fail("The preserved Player collision is not 24x24.")
	player.free()
	if ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1) != 0:
		return _fail("Nearest-neighbor texture filtering is not active.")
	if ROAD_TILESET.get_source_count() < 36:
		return _fail("The road TileSet does not contain the complete reusable road family.")
	var ground := _zone.get_node_or_null("TerrainLayers/BaseGrass/VariedGrass") as TileMapLayer
	if ground == null or ground.tile_set == null or ground.get_used_cells().size() != 640:
		return _fail("The shared 32x20 varied-grass ground layer is missing or incomplete.")
	var grass_variants: Dictionary = {}
	for cell in ground.get_used_cells():
		grass_variants[ground.get_cell_atlas_coords(cell)] = true
	if grass_variants.size() < 8:
		return _fail("The base grass does not use the complete shared eight-variant mix.")
	var resting_frames: SpriteFrames = _zone.get_node("Actors/NPCs/RestingTraveler").get("character_sprite_frames")
	var continuing_frames: SpriteFrames = _zone.get_node("Actors/NPCs/ContinuingTraveler").get("character_sprite_frames")
	var local_frames: SpriteFrames = _zone.get_node("Actors/NPCs/RoadsideLocal").get("character_sprite_frames")
	if resting_frames == continuing_frames or resting_frames == local_frames or continuing_frames == local_frames:
		return _fail("The preserved Wayfarer's Approach characters do not have distinct shared Caden visuals.")

	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		return _fail("Wayfarer's Approach asset manifest is missing.")
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	if not manifest is Dictionary or (manifest["assets"] as Dictionary).size() < 75:
		return _fail("Wayfarer's Approach asset manifest is incomplete.")
	for asset_record: Dictionary in (manifest["assets"] as Dictionary).values():
		var runtime_path: String = asset_record["runtime_path"]
		var import_file := FileAccess.open(runtime_path + ".import", FileAccess.READ)
		if import_file == null:
			return _fail("Missing Godot import settings for %s." % runtime_path)
		var import_settings := import_file.get_as_text()
		if not import_settings.contains("compress/mode=0") or not import_settings.contains("mipmaps/generate=false"):
			return _fail("Non-lossless or mipmapped import settings found for %s." % runtime_path)
	var pilot_manifest_file := FileAccess.open(PILOT_MANIFEST_PATH, FileAccess.READ)
	if pilot_manifest_file == null:
		return _fail("Wayfarer pilot asset manifest is missing.")
	var pilot_manifest = JSON.parse_string(pilot_manifest_file.get_as_text())
	if not pilot_manifest is Dictionary:
		return _fail("Wayfarer pilot asset manifest is invalid.")
	var pilot_assets := pilot_manifest["assets"] as Dictionary
	if pilot_assets.size() != 2:
		return _fail("The Wayfarer pilot must contain exactly two selected assets.")
	for pilot_record: Dictionary in pilot_assets.values():
		if pilot_record["selection_status"] != "pilot_selected":
			return _fail("A Wayfarer pilot manifest record is not selected for the pilot.")
		if not is_equal_approx(pilot_record["scale"] as float, 0.1875):
			return _fail("A Wayfarer pilot asset was not normalized at 0.1875.")
		if not is_equal_approx(pilot_record["import_scale"] as float, 1.0):
			return _fail("A Wayfarer pilot asset is not configured for runtime scale 1.0.")
		var pilot_runtime_path: String = "res://" + (pilot_record["runtime_path"] as String)
		if FileAccess.get_sha256(pilot_runtime_path) != pilot_record["runtime_sha256"]:
			return _fail("Wayfarer pilot runtime hash mismatch for %s." % pilot_runtime_path)
		var pilot_import_file := FileAccess.open(pilot_runtime_path + ".import", FileAccess.READ)
		if pilot_import_file == null:
			return _fail("Missing Godot import settings for %s." % pilot_runtime_path)
		var pilot_import_settings := pilot_import_file.get_as_text()
		if not pilot_import_settings.contains("compress/mode=0") or not pilot_import_settings.contains("mipmaps/generate=false"):
			return _fail("Non-lossless or mipmapped pilot import settings found for %s." % pilot_runtime_path)
	var zone_text := FileAccess.get_file_as_string("res://scenes/world/caden/WayfarersApproach.tscn")
	if zone_text.contains("source_art") or zone_text.contains("full_zone_concept"):
		return _fail("The runtime zone directly references source or concept artwork.")

	for collider_path in [
		"SolidScenery/InnExterior/CollisionShape2D",
		"SolidScenery/TravelerRestArea/CoveredWagonWest/CollisionShape2D",
		"SolidScenery/TravelerRestArea/CoveredWagonEast/CollisionShape2D",
		"SolidScenery/TravelerRestArea/SupplyCart/CollisionShape2D",
		"SolidScenery/TravelerRestArea/YardFences/WagonGate/CollisionShape2D",
		"SolidScenery/InteriorTrees/NorthLawnTree/CollisionShape2D",
	]:
		var collider := _zone.get_node_or_null(collider_path) as CollisionShape2D
		if collider == null or collider.disabled or collider.shape == null:
			return _fail("Missing active obstacle collision at %s." % collider_path)
	for pilot_collider_path in [
		"SolidScenery/PilotProps/BenchLuggageLantern/LanternPostCollision",
		"SolidScenery/PilotProps/BenchLuggageLantern/BenchCollision",
		"SolidScenery/PilotProps/BenchLuggageLantern/LuggageCollision",
		"SolidScenery/PilotProps/HitchingRailBarrels/BarrelsCollision",
		"SolidScenery/PilotProps/HitchingRailBarrels/HitchingRailCollision",
	]:
		var pilot_collider := _zone.get_node_or_null(pilot_collider_path) as CollisionShape2D
		if pilot_collider == null or pilot_collider.disabled or not pilot_collider.shape is RectangleShape2D:
			return _fail("Missing object-specific pilot collision at %s." % pilot_collider_path)
	var bench_prop := _zone.get_node("SolidScenery/PilotProps/BenchLuggageLantern") as DepthSortedStaticProp
	var rail_prop := _zone.get_node("SolidScenery/PilotProps/HitchingRailBarrels") as DepthSortedStaticProp
	if bench_prop.scale != Vector2.ONE or rail_prop.scale != Vector2.ONE:
		return _fail("Wayfarer pilot assets must be imported and placed at scale 1.0.")
	bench_prop.update_depth_for_player(bench_prop.global_position.y - 1.0)
	if bench_prop.z_index != 11:
		return _fail("Bench pilot does not sort in front of a player standing behind it.")
	bench_prop.update_depth_for_player(bench_prop.global_position.y + 1.0)
	if bench_prop.z_index != 9:
		return _fail("Bench pilot does not sort behind a player standing in front of it.")
	rail_prop.update_depth_for_player(rail_prop.global_position.y - 1.0)
	if rail_prop.z_index != 11:
		return _fail("Hitching-rail pilot does not sort in front of a player standing behind it.")
	rail_prop.update_depth_for_player(rail_prop.global_position.y + 1.0)
	if rail_prop.z_index != 9:
		return _fail("Hitching-rail pilot does not sort behind a player standing in front of it.")

	var route_points: Array[Vector2] = []
	for x in range(64, 961, 64):
		route_points.append(Vector2(x, 320))
	for y in range(64, 241, 32):
		route_points.append(Vector2(512, y))
	for point in [Vector2(660, 416), Vector2(700, 416), Vector2(820, 416), Vector2(900, 416), Vector2(940, 416)]:
		route_points.append(point)
	for point in route_points:
		if not _footprint_is_clear(point):
			return _fail("The 24x24 player footprint is obstructed on a primary route at %s." % point)
	for point in [Vector2(880, 510), Vector2(680, 450)]:
		if not _footprint_is_clear(point):
			return _fail("A pilot prop blocks the upper visual composite instead of only its structural footprint at %s." % point)
	for point in [Vector2(853, 550), Vector2(651, 493), Vector2(700, 495)]:
		if _footprint_is_clear(point):
			return _fail("A pilot structural footprint is missing collision at %s." % point)
	for point in [Vector2(16, 200), Vector2(1008, 200), Vector2(200, 16), Vector2(200, 624)]:
		if _footprint_is_clear(point):
			return _fail("The player footprint can cross a preserved gameplay boundary at %s." % point)

	print("PASS: Wayfarer's Approach runtime assets, limited two-prop pilot, depth sorting, object collisions, preserved contracts, and primary travel lanes.")
	quit(0)


func _check_position(path: NodePath, expected: Vector2) -> bool:
	var node := _zone.get_node_or_null(path) as Node2D
	if node == null or not node.position.is_equal_approx(expected):
		_fail("Expected %s at %s." % [path, expected])
		return false
	return true


func _footprint_is_clear(point: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return _zone.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
