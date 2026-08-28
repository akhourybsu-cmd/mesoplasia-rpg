extends SceneTree

const RESIDENTIAL_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/residential/residential_runtime_manifest_v1.json"
const TERRAIN_MANIFEST_PATH := "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.json"
const EXPECTED_HOMES := {
	"Cabin01": Vector2(160, 128), "Cabin02": Vector2(384, 160), "Cabin03": Vector2(608, 128),
	"Cabin04": Vector2(800, 176), "Cabin05": Vector2(1024, 128), "Cabin06": Vector2(160, 592),
	"Cabin07": Vector2(400, 624), "Cabin08": Vector2(752, 608), "Cabin09": Vector2(992, 576),
	"Cabin10": Vector2(1024, 256),
}
const EXPECTED_FENCES := {"Fence01": Vector2(160, 240), "Fence02": Vector2(784, 272), "Fence03": Vector2(240, 512)}
const EXPECTED_SET_PIECES := {
	"FencedFlowerYard": {"position": Vector2(608, 288), "sprite": Vector2(-57, -69), "asset": "01"},
	"WoodpileBarrelFence": {"position": Vector2(80, 688), "sprite": Vector2(-57, -59), "asset": "04"},
	"LaundryLine": {"position": Vector2(400, 536), "sprite": Vector2(-46, -63), "asset": "05"},
	"SmallGardenPatch": {"position": Vector2(752, 536), "sprite": Vector2(-50, -75), "asset": "06"},
	"DoorstepFlowerCluster": {"position": Vector2(384, 256), "sprite": Vector2(-49, -67), "asset": "08"},
	"RainBarrelsCrates": {"position": Vector2(1080, 688), "sprite": Vector2(-47, -82), "asset": "09"},
	"SteppingStoneFlowers": {"position": Vector2(800, 288), "sprite": Vector2(-45, -78), "asset": "11"},
}
const EXPECTED_WALKERS := {
	"NorthwestNeighbor": {"position": Vector2(336, 272), "distance": 64.0},
	"NortheastNeighbor": {"position": Vector2(704, 272), "distance": 64.0},
	"SouthwestNeighbor": {"position": Vector2(368, 480), "distance": 64.0},
	"SoutheastNeighbor": {"position": Vector2(816, 480), "distance": 64.0},
	"MainLaneNeighbor": {"position": Vector2(576, 384), "distance": 96.0},
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var runtime_manifest := _load_json(RUNTIME_MANIFEST_PATH)
	var terrain_manifest := _load_json(TERRAIN_MANIFEST_PATH)
	if runtime_manifest.is_empty() or terrain_manifest.is_empty():
		return
	if runtime_manifest.get("catalog_rows_verified", 0) != 222:
		_fail("Residential manifest did not verify all 222 catalog rows.")
		return
	if runtime_manifest.get("gate_state", "") != "residential_runtime_v1_visual_approved":
		_fail("Unexpected Residential runtime gate state.")
		return
	if runtime_manifest.get("source_package_location_policy", "").find("outside res://") == -1:
		_fail("Residential source package staging policy is missing.")
		return
	var rights := runtime_manifest.get("provenance_and_licensing", {}) as Dictionary
	if rights.get("rights_status", "") != "project_internal_rights_unverified":
		_fail("Unexpected Residential rights status.")
		return

	var records := runtime_manifest.get("assets", {}) as Dictionary
	var selected_ids := records.keys()
	selected_ids.sort()
	if selected_ids != ["01", "04", "05", "06", "08", "09", "11"]:
		_fail("Residential selected-asset set changed: %s" % [selected_ids])
		return
	for asset_id: String in selected_ids:
		var record := records[asset_id] as Dictionary
		if record.get("approval_state", "") != "approved_for_residential_runtime_v1_integration":
			_fail("Asset %s lacks Residential approval metadata." % asset_id)
			return
		if not is_equal_approx(float(record.get("normalization_factor", 0.0)), 0.1875) or not is_equal_approx(float(record.get("import_scale", 0.0)), 1.0):
			_fail("Asset %s has an invalid normalization/import scale contract." % asset_id)
			return
		var runtime_path := "res://%s" % record.get("runtime_path", "")
		if not FileAccess.file_exists(runtime_path) or FileAccess.get_sha256(runtime_path) != record.get("runtime_sha256", ""):
			_fail("Asset %s runtime hash mismatch." % asset_id)
			return
		var texture := load(runtime_path) as Texture2D
		var dimensions := record.get("runtime_dimensions", []) as Array
		if texture == null or texture.get_size() != Vector2(float(dimensions[0]), float(dimensions[1])):
			_fail("Asset %s texture dimensions do not match the catalog." % asset_id)
			return
		var audit := record.get("post_cleanup_audit", {}) as Dictionary
		for key in ["partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "bright_boundary_halo_candidates", "detached_components_at_or_below_2_pixels"]:
			if audit.get(key, -1) != 0:
				_fail("Asset %s failed cleanup audit %s." % [asset_id, key])
				return

	var terrain_path := "res://%s" % terrain_manifest.get("output_path", "")
	if FileAccess.get_sha256(terrain_path) != terrain_manifest.get("output_sha256", ""):
		_fail("Residential terrain hash mismatch.")
		return
	var terrain_texture := load(terrain_path) as Texture2D
	if terrain_texture == null or terrain_texture.get_size() != Vector2(1152, 768):
		_fail("Residential terrain did not load at 1152x768.")
		return

	var residential := RESIDENTIAL_SCENE.instantiate() as Node2D
	root.add_child(residential)
	await process_frame
	if residential.get("camera_bounds") != Rect2i(0, 0, 1152, 768):
		_fail("Residential camera bounds changed.")
		return
	var terrain_sprite := residential.get_node("TerrainRuntime") as Sprite2D
	if terrain_sprite.texture == null or terrain_sprite.texture.resource_path != terrain_path or terrain_sprite.centered:
		_fail("Residential terrain sprite contract is invalid.")
		return
	for legacy_path in ["Ground", "WestPath", "CommonsPath", "NorthLane", "NortheastLane", "SouthwestLane", "SoutheastLane"]:
		if (residential.get_node(legacy_path) as CanvasItem).visible:
			_fail("Legacy placeholder surface remains visible: %s" % legacy_path)
			return

	var homes := residential.get_node("Homes")
	if homes.get_child_count() != 10:
		_fail("Residential must retain ten authoritative home bodies.")
		return
	for home_name: String in EXPECTED_HOMES:
		var home := homes.get_node(home_name) as StaticBody2D
		if home.position != EXPECTED_HOMES[home_name]:
			_fail("%s moved from its authoritative center." % home_name)
			return
		var shape := (home.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		var sprite := home.get_node("ExteriorSprite") as Sprite2D
		if shape == null or shape.size != Vector2(128, 96) or sprite.texture == null or sprite.scale != Vector2.ONE or sprite.position != Vector2(0, -16):
			_fail("%s lost its aligned building/collision contract." % home_name)
			return
		if (home.get_node("Visual") as CanvasItem).visible:
			_fail("%s legacy placeholder remains visible." % home_name)
			return

	var fences := residential.get_node("YardFences")
	if fences.get_child_count() != 3:
		_fail("Residential must retain three authoritative yard-fence bodies.")
		return
	for fence_name: String in EXPECTED_FENCES:
		var fence := fences.get_node(fence_name) as StaticBody2D
		var shape := (fence.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if fence.position != EXPECTED_FENCES[fence_name] or shape == null or shape.size != Vector2(192, 24):
			_fail("%s moved or changed collision." % fence_name)
			return
		for sprite_name in ["FenceWest", "FenceEast"]:
			if (fence.get_node(sprite_name) as Sprite2D).texture == null:
				_fail("%s lacks aligned fence art." % fence_name)
				return

	var set_pieces := residential.get_node("DomesticSetPieces")
	if set_pieces.get_child_count() != 7:
		_fail("Residential selected set-piece count changed.")
		return
	for piece_name: String in EXPECTED_SET_PIECES:
		var expected := EXPECTED_SET_PIECES[piece_name] as Dictionary
		var piece := set_pieces.get_node(piece_name) as Node2D
		var sprite := piece.get_node("Visual") as Sprite2D
		var record := records[expected["asset"]] as Dictionary
		if piece.position != expected["position"] or sprite.position != expected["sprite"] or sprite.scale != Vector2.ONE:
			_fail("%s lost its approved placement or pivot." % piece_name)
			return
		if sprite.texture == null or sprite.texture.resource_path != "res://%s" % record["runtime_path"]:
			_fail("%s does not use its selected runtime asset." % piece_name)
			return
		if piece_name != "SteppingStoneFlowers" and not piece.has_method("update_depth_for_player"):
			_fail("%s lacks player-relative depth sorting." % piece_name)
			return
	if set_pieces.get_node("LaundryLine").get_child_count() != 3 or set_pieces.get_node("DoorstepFlowerCluster").get_child_count() != 3:
		_fail("Passable composite set pieces do not retain two object-specific collisions.")
		return
	if set_pieces.get_node("SteppingStoneFlowers").find_children("*", "CollisionShape2D", true, false).size() != 0:
		_fail("Walkable stepping stones unexpectedly gained collision.")
		return

	var trees := residential.get_node("ResidentialLandscaping/PerimeterTrees")
	if trees.get_child_count() != 12:
		_fail("Residential perimeter tree count changed.")
		return
	var protected_routes := [Rect2(0, 320, 1152, 128), Rect2(512, 448, 128, 320)]
	for tree: StaticBody2D in trees.get_children():
		if not tree.has_method("update_depth_for_player"):
			_fail("Perimeter tree lacks player-relative depth: %s" % tree.get_path())
			return
		for route: Rect2 in protected_routes:
			if route.has_point(tree.position):
				_fail("Perimeter tree entered a protected road: %s" % tree.get_path())
				return
	if residential.get_node("ResidentialLandscaping/LowPlanting").get_child_count() != 16 or residential.get_node("ResidentialLandscaping/LaneLighting").get_child_count() != 4:
		_fail("Residential landscaping density contract changed.")
		return

	for npc_name in ["HomeResident", "PathResident"]:
		var npc := residential.get_node(npc_name)
		if not npc.get("character_visual_enabled") or npc.get("character_sprite_frames") == null or npc.get("conversation") == null:
			_fail("%s lost its approved art or dialogue." % npc_name)
			return
	var walkers := residential.get_node("AmbientWalkers")
	if walkers.get_child_count() != 5:
		_fail("Residential ambient population must remain five walkers plus two dialogue NPCs.")
		return
	for walker_name: String in EXPECTED_WALKERS:
		var expected := EXPECTED_WALKERS[walker_name] as Dictionary
		var walker := walkers.get_node(walker_name) as CharacterBody2D
		if walker.position != expected["position"] or walker.get("character_sprite_frames") == null or walker.get("patrol_distance") != expected["distance"]:
			_fail("Residential ambient walker lost its bounded route: %s" % walker_name)
			return

	if (residential.get_node("EntryPoints/from_town_square") as Marker2D).position != Vector2(128, 384) or (residential.get_node("EntryPoints/from_commons") as Marker2D).position != Vector2(576, 640):
		_fail("Residential entry markers changed.")
		return
	var town_exit := residential.get_node("Exits/ToTownSquare") as Area2D
	var commons_exit := residential.get_node("Exits/ToCommons") as Area2D
	if town_exit.position != Vector2(64, 384) or town_exit.get("destination_zone") != &"town_square" or town_exit.get("destination_entry") != &"from_residential":
		_fail("Residential Town Square transition changed.")
		return
	if commons_exit.position != Vector2(576, 704) or commons_exit.get("destination_zone") != &"commons" or commons_exit.get("destination_entry") != &"from_residential":
		_fail("Residential Commons transition changed.")
		return
	if (residential.get_node("ZoneLabel") as CanvasItem).visible:
		_fail("Residential developer label remains visible.")
		return

	print("PASS: Residential homes, yards, selected art, seven residents, landscaping, collision, routes, sorting, and transitions.")
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Unable to open %s." % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Invalid JSON object: %s." % path)
		return {}
	return parsed as Dictionary


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
