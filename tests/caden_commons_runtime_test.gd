extends SceneTree

const COMMONS_SCENE := preload("res://scenes/world/caden/Commons.tscn")
const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/commons/commons_runtime_manifest_v1.json"
const TERRAIN_MANIFEST_PATH := "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.json"
const EXPECTED_SELECTED := {
	"01": {"node": "Greenery/TreeCluster02", "position": Vector2(800, 224), "sprite": "SelectedSprite", "pivot": Vector2(-47, -104)},
	"04": {"node": "Greenery/TreeCluster01", "position": Vector2(192, 160), "sprite": "SelectedSprite", "pivot": Vector2(-49, -78)},
	"09": {"node": "CommonsComposition/WildflowerMeadow", "position": Vector2(704, 352), "sprite": "Visual", "pivot": Vector2(-52, -67)},
	"11": {"node": "Greenery/RockCluster", "position": Vector2(288, 544), "sprite": "SelectedSprite", "pivot": Vector2(-55, -70)},
	"14": {"node": "CommonsComposition/BoundaryUndergrowth", "position": Vector2(896, 624), "sprite": "Visual", "pivot": Vector2(-52, -84)},
	"20": {"node": "CommonsComposition/QuietRestPocket", "position": Vector2(640, 480), "sprite": "Visual", "pivot": Vector2(-49, -87)},
}
const EXPECTED_WALKERS := {
	"MeadowStroller": {"position": Vector2(640, 256), "distance": 64.0},
	"WestGreenStroller": {"position": Vector2(352, 464), "distance": 96.0},
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var runtime_manifest := _load_json(RUNTIME_MANIFEST_PATH)
	var terrain_manifest := _load_json(TERRAIN_MANIFEST_PATH)
	if runtime_manifest.is_empty() or terrain_manifest.is_empty():
		return
	if runtime_manifest.get("catalog_rows_verified", 0) != 222 or runtime_manifest.get("gate_state", "") != "commons_runtime_v1_pending_in_engine_visual_approval":
		_fail("Commons manifest verification or gate state changed.")
		return
	if runtime_manifest.get("source_package_location_policy", "").find("outside res://") == -1:
		_fail("Commons source-package staging policy is missing.")
		return
	var rights := runtime_manifest.get("provenance_and_licensing", {}) as Dictionary
	if rights.get("rights_status", "") != "project_internal_rights_unverified":
		_fail("Unexpected Commons rights status.")
		return

	var records := runtime_manifest.get("assets", {}) as Dictionary
	var selected_ids := records.keys()
	selected_ids.sort()
	if selected_ids != ["01", "04", "09", "11", "14", "20"]:
		_fail("Commons selected-asset set changed: %s" % [selected_ids])
		return
	for asset_id: String in selected_ids:
		var record := records[asset_id] as Dictionary
		if record.get("approval_state", "") != "approved_for_commons_runtime_v1_integration":
			_fail("Commons asset %s lacks approval metadata." % asset_id)
			return
		if not is_equal_approx(float(record.get("normalization_factor", 0.0)), 0.1875) or not is_equal_approx(float(record.get("import_scale", 0.0)), 1.0):
			_fail("Commons asset %s has an invalid normalization/import contract." % asset_id)
			return
		var runtime_path := "res://%s" % record.get("runtime_path", "")
		if not FileAccess.file_exists(runtime_path) or FileAccess.get_sha256(runtime_path) != record.get("runtime_sha256", ""):
			_fail("Commons asset %s runtime hash mismatch." % asset_id)
			return
		var texture := load(runtime_path) as Texture2D
		var dimensions := record.get("runtime_dimensions", []) as Array
		if texture == null or texture.get_size() != Vector2(float(dimensions[0]), float(dimensions[1])):
			_fail("Commons asset %s dimensions do not match the catalog." % asset_id)
			return
		var audit := record.get("post_cleanup_audit", {}) as Dictionary
		for key in ["partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "bright_boundary_halo_candidates", "detached_components_at_or_below_2_pixels"]:
			if audit.get(key, -1) != 0:
				_fail("Commons asset %s failed cleanup audit %s." % [asset_id, key])
				return

	var terrain_path := "res://%s" % terrain_manifest.get("output_path", "")
	if FileAccess.get_sha256(terrain_path) != terrain_manifest.get("output_sha256", ""):
		_fail("Commons terrain hash mismatch.")
		return
	var terrain_texture := load(terrain_path) as Texture2D
	if terrain_texture == null or terrain_texture.get_size() != Vector2(1024, 704):
		_fail("Commons terrain did not load at 1024x704.")
		return

	var commons := COMMONS_SCENE.instantiate() as Node2D
	root.add_child(commons)
	await process_frame
	if commons.get("camera_bounds") != Rect2i(0, 0, 1024, 704):
		_fail("Commons camera bounds changed.")
		return
	var terrain_sprite := commons.get_node("TerrainRuntime") as Sprite2D
	if terrain_sprite.texture == null or terrain_sprite.texture.resource_path != terrain_path or terrain_sprite.centered:
		_fail("Commons terrain sprite contract is invalid.")
		return
	for legacy_path in ["Ground", "WestPath", "NorthPath", "QuietGreen"]:
		if (commons.get_node(legacy_path) as CanvasItem).visible:
			_fail("Commons legacy placeholder surface remains visible: %s" % legacy_path)
			return

	for asset_id: String in EXPECTED_SELECTED:
		var expected := EXPECTED_SELECTED[asset_id] as Dictionary
		var node := commons.get_node(expected["node"]) as Node2D
		var sprite := node.get_node(expected["sprite"]) as Sprite2D
		var record := records[asset_id] as Dictionary
		if node.position != expected["position"] or sprite.position != expected["pivot"] or sprite.scale != Vector2.ONE:
			_fail("Commons asset %s lost its approved placement or pivot." % asset_id)
			return
		if sprite.texture == null or sprite.texture.resource_path != "res://%s" % record["runtime_path"]:
			_fail("Commons asset %s does not use its cleaned runtime texture." % asset_id)
			return
	if commons.get_node("CommonsComposition/WildflowerMeadow").find_children("*", "CollisionShape2D", true, false).size() != 0:
		_fail("Commons wildflower meadow must remain walkable.")
		return
	var rest_pocket := commons.get_node("CommonsComposition/QuietRestPocket")
	if rest_pocket.find_children("*", "CollisionShape2D", true, false).size() != 2:
		_fail("Commons rest pocket must retain separate bench and rock collisions.")
		return

	var protected_routes := [Rect2(0, 288, 576, 128), Rect2(448, 0, 128, 416)]
	for solid_root in [commons.get_node("Greenery"), commons.get_node("CommonsComposition/PerimeterTrees")]:
		for solid: Node in solid_root.get_children():
			if solid is StaticBody2D:
				for route: Rect2 in protected_routes:
					if route.has_point((solid as StaticBody2D).position):
						_fail("Commons solid scenery entered a protected route: %s" % solid.get_path())
						return
	for solid_name in ["BoundaryUndergrowth", "QuietRestPocket"]:
		var solid := commons.get_node("CommonsComposition/%s" % solid_name) as StaticBody2D
		for route: Rect2 in protected_routes:
			if route.has_point(solid.position):
				_fail("Commons selected solid entered a protected route: %s" % solid_name)
				return
	var perimeter_trees := commons.get_node("CommonsComposition/PerimeterTrees")
	if perimeter_trees.get_child_count() != 16:
		_fail("Commons perimeter tree count changed.")
		return
	for tree: StaticBody2D in perimeter_trees.get_children():
		if not tree.has_method("update_depth_for_player"):
			_fail("Commons perimeter tree lacks player-relative depth: %s" % tree.get_path())
			return
		var shape := (tree.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if shape == null or shape.size != Vector2(24, 18):
			_fail("Commons perimeter tree lacks trunk-only collision: %s" % tree.get_path())
			return
	if commons.get_node("CommonsComposition/BoundaryPlanting").get_child_count() != 17:
		_fail("Commons layered boundary planting count changed.")
		return

	var local := commons.get_node("CommonsLocal")
	if local.position != Vector2(704, 400) or local.get("conversation") == null or not local.get("character_visual_enabled") or local.get("character_sprite_frames") == null:
		_fail("Commons interactive resident lost position, dialogue, or approved art.")
		return
	var walkers := commons.get_node("AmbientWalkers")
	if walkers.get_child_count() != 2:
		_fail("Commons must retain two ambient walkers plus its dialogue resident.")
		return
	for walker_name: String in EXPECTED_WALKERS:
		var expected := EXPECTED_WALKERS[walker_name] as Dictionary
		var walker := walkers.get_node(walker_name) as CharacterBody2D
		if walker.position != expected["position"] or walker.get("patrol_distance") != expected["distance"] or walker.get("character_sprite_frames") == null:
			_fail("Commons ambient walker lost its bounded route: %s" % walker_name)
			return

	if (commons.get_node("EntryPoints/from_town_square") as Marker2D).position != Vector2(128, 352) or (commons.get_node("EntryPoints/from_residential") as Marker2D).position != Vector2(512, 128):
		_fail("Commons entry markers changed.")
		return
	var town_exit := commons.get_node("Exits/ToTownSquare") as Area2D
	var residential_exit := commons.get_node("Exits/ToResidential") as Area2D
	if town_exit.position != Vector2(64, 352) or town_exit.get("destination_zone") != &"town_square" or town_exit.get("destination_entry") != &"from_commons":
		_fail("Commons Town Square transition changed.")
		return
	if residential_exit.position != Vector2(512, 64) or residential_exit.get("destination_zone") != &"residential" or residential_exit.get("destination_entry") != &"from_commons":
		_fail("Commons Residential transition changed.")
		return
	if (commons.get_node("ZoneLabel") as CanvasItem).visible:
		_fail("Commons developer label remains visible.")
		return

	print("PASS: Commons terrain, six selected assets, open routes, layered edge, precise collision, sorting, three residents, and transitions.")
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
