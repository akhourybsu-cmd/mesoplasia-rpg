extends SceneTree

const MARKETPLACE_SCENE := preload("res://scenes/world/caden/Marketplace.tscn")
const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json"
const TERRAIN_MANIFEST_PATH := "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.json"
const EXPECTED_STALLS := {
	"Stall01": {"position": Vector2(208, 184), "asset": "01", "shape": Vector2(56, 16), "sprite_position": Vector2(-54, -61)},
	"Stall02": {"position": Vector2(336, 184), "asset": "07", "shape": Vector2(64, 24), "sprite_position": Vector2(-60, -90)},
	"Stall03": {"position": Vector2(560, 184), "asset": "03", "shape": Vector2(48, 16), "sprite_position": Vector2(-46, -54)},
	"Stall04": {"position": Vector2(688, 184), "asset": "04", "shape": Vector2(56, 16), "sprite_position": Vector2(-47, -59)},
	"Stall05": {"position": Vector2(208, 488), "asset": "07", "shape": Vector2(64, 24), "sprite_position": Vector2(-61, -90)},
	"Stall06": {"position": Vector2(336, 488), "asset": "06", "shape": Vector2(56, 16), "sprite_position": Vector2(-53, -72)},
	"Stall07": {"position": Vector2(560, 488), "asset": "13", "shape": Vector2(56, 16), "sprite_position": Vector2(-48, -74)},
	"Stall08": {"position": Vector2(688, 488), "asset": "14", "shape": Vector2(56, 16), "sprite_position": Vector2(-50, -57)},
}
const EXPECTED_ENTRIES := {
	"from_wayfarers_approach": Vector2(128, 320),
	"from_town_square": Vector2(448, 512),
}
const EXPECTED_EXITS := {
	"ToWayfarersApproach": {"position": Vector2(64, 320), "zone": &"wayfarers_approach", "entry": &"from_marketplace"},
	"ToTownSquare": {"position": Vector2(448, 576), "zone": &"town_square", "entry": &"from_marketplace"},
}
const EXPECTED_WALKERS := {
	"NorthwestShopper": Vector2(272, 240),
	"NortheastShopper": Vector2(624, 240),
	"SouthwestShopper": Vector2(272, 416),
	"SoutheastShopper": Vector2(624, 416),
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var runtime_manifest := _load_json(RUNTIME_MANIFEST_PATH)
	if runtime_manifest.is_empty():
		return
	var terrain_manifest := _load_json(TERRAIN_MANIFEST_PATH)
	if terrain_manifest.is_empty():
		return
	if runtime_manifest.get("catalog_rows_verified", 0) != 222:
		_fail("Marketplace runtime manifest did not verify all 222 catalog rows.")
		return
	if runtime_manifest.get("gate_state", "") != "marketplace_runtime_v1_visual_approved":
		_fail("Unexpected Marketplace runtime gate state.")
		return
	if runtime_manifest.get("source_package_location_policy", "").find("outside res://") == -1:
		_fail("Marketplace source package staging policy is missing.")
		return
	var rights := runtime_manifest.get("provenance_and_licensing", {}) as Dictionary
	if rights.get("rights_status", "") != "project_internal_rights_unverified":
		_fail("Unexpected Marketplace rights status.")
		return

	var records := runtime_manifest.get("assets", {}) as Dictionary
	var selected_ids := records.keys()
	selected_ids.sort()
	if selected_ids != ["01", "03", "04", "06", "07", "13", "14"]:
		_fail("Marketplace selected-asset set changed: %s" % [selected_ids])
		return
	for asset_id: String in selected_ids:
		var record := records[asset_id] as Dictionary
		if record.get("approval_state", "") != "approved_for_marketplace_runtime_v1_integration":
			_fail("Asset %s lacks Marketplace approval metadata." % asset_id)
			return
		if not is_equal_approx(float(record.get("normalization_factor", 0.0)), 0.1875):
			_fail("Asset %s has an unexpected normalization factor." % asset_id)
			return
		if not is_equal_approx(float(record.get("import_scale", 0.0)), 1.0):
			_fail("Asset %s is not intended for scale 1.0 import." % asset_id)
			return
		var runtime_path := "res://%s" % record.get("runtime_path", "")
		if not FileAccess.file_exists(runtime_path) or FileAccess.get_sha256(runtime_path) != record.get("runtime_sha256", ""):
			_fail("Asset %s runtime hash mismatch." % asset_id)
			return
		var texture := load(runtime_path) as Texture2D
		var dimensions := record.get("runtime_dimensions", []) as Array
		if texture == null or texture.get_size() != Vector2(float(dimensions[0]), float(dimensions[1])):
			_fail("Asset %s texture failed to load at catalog dimensions." % asset_id)
			return
		var audit := record.get("post_cleanup_audit", {}) as Dictionary
		for key in ["partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "bright_boundary_halo_candidates", "detached_components_at_or_below_2_pixels"]:
			if audit.get(key, -1) != 0:
				_fail("Asset %s failed cleanup audit %s." % [asset_id, key])
				return

	var terrain_path := "res://%s" % terrain_manifest.get("output_path", "")
	if FileAccess.get_sha256(terrain_path) != terrain_manifest.get("output_sha256", ""):
		_fail("Marketplace terrain hash mismatch.")
		return
	var terrain_texture := load(terrain_path) as Texture2D
	if terrain_texture == null or terrain_texture.get_size() != Vector2(896, 640):
		_fail("Marketplace terrain did not load at 896x640.")
		return

	var marketplace := MARKETPLACE_SCENE.instantiate() as Node2D
	root.add_child(marketplace)
	await process_frame
	if marketplace.get("camera_bounds") != Rect2i(0, 0, 896, 640):
		_fail("Marketplace camera bounds changed.")
		return
	var terrain_sprite := marketplace.get_node("TerrainRuntime") as Sprite2D
	if terrain_sprite.texture == null or terrain_sprite.texture.resource_path != terrain_path or terrain_sprite.centered:
		_fail("Marketplace terrain sprite contract is invalid.")
		return
	for legacy_path in ["Ground", "MarketGround", "WestLane", "CentralLane", "CrossLane"]:
		if (marketplace.get_node(legacy_path) as CanvasItem).visible:
			_fail("Legacy placeholder surface remains visible: %s" % legacy_path)
			return

	var stalls := marketplace.get_node("Stalls")
	for stall_name: String in EXPECTED_STALLS:
		var expected := EXPECTED_STALLS[stall_name] as Dictionary
		var stall := stalls.get_node(stall_name) as StaticBody2D
		if stall.position != expected["position"]:
			_fail("%s moved from its approved bay." % stall_name)
			return
		if not stall.has_method("update_depth_for_player"):
			_fail("%s lacks player-relative depth sorting." % stall_name)
			return
		var sprite := stall.get_node("Visual") as Sprite2D
		if sprite.position != expected["sprite_position"] or sprite.scale != Vector2.ONE:
			_fail("%s pivot or runtime scale is invalid." % stall_name)
			return
		var shape := (stall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if shape == null or shape.size != expected["shape"]:
			_fail("%s does not use its object-specific collision footprint." % stall_name)
			return
		stall.call("update_depth_for_player", stall.global_position.y + 32.0)
		if stall.z_index != 9:
			_fail("%s did not render behind a player below it." % stall_name)
			return
		stall.call("update_depth_for_player", stall.global_position.y - 32.0)
		if stall.z_index != 11:
			_fail("%s did not render in front of a player above it." % stall_name)
			return

	for corridor in [Rect2(0, 256, 288, 128), Rect2(96, 288, 704, 64), Rect2(384, 64, 128, 576)]:
		for solid_path in ["Stalls", "EnvironmentalComposition/SolidFrame", "EnvironmentalComposition/Planters", "EnvironmentalComposition/Lighting"]:
			for child: Node in marketplace.get_node(solid_path).get_children():
				if child is StaticBody2D and corridor.has_point((child as StaticBody2D).position):
					_fail("Solid scenery entered a protected route: %s" % child.get_path())
					return

	var solid_frame := marketplace.get_node("EnvironmentalComposition/SolidFrame")
	if solid_frame.get_child_count() != 16:
		_fail("Marketplace perimeter tree mass count changed.")
		return
	var paved_market_bounds := Rect2(96, 64, 704, 512)
	for tree: StaticBody2D in solid_frame.get_children():
		if paved_market_bounds.has_point(tree.position):
			_fail("Marketplace tree ground contact entered paving: %s" % tree.get_path())
			return
	var fencing := marketplace.get_node("EnvironmentalComposition/PerimeterFencing")
	if fencing.get_child_count() != 22:
		_fail("Marketplace perimeter fence segment count changed.")
		return
	for fence: StaticBody2D in fencing.get_children():
		var fence_shape := (fence.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if fence_shape == null or fence_shape.size.y != 10.0:
			_fail("Marketplace fence lacks its narrow structural collision: %s" % fence.get_path())
			return
		if Rect2(0, 256, 128, 128).has_point(fence.position) or Rect2(384, 576, 128, 64).has_point(fence.position):
			_fail("Marketplace fence entered an authorized travel opening: %s" % fence.get_path())
			return
	if marketplace.get_node("EnvironmentalComposition/Planters").get_child_count() != 4:
		_fail("Marketplace district planter count changed.")
		return
	if marketplace.get_node("EnvironmentalComposition/Lighting").get_child_count() != 4:
		_fail("Marketplace lane-lighting count changed.")
		return

	for npc_name in ["StallAttendant", "MarketShopper", "SupplyTraveler"]:
		var npc := marketplace.get_node(npc_name)
		if not npc.get("character_visual_enabled"):
			_fail("%s did not retain an approved character visual." % npc_name)
			return
		if npc.get("conversation") == null:
			_fail("%s dialogue resource was lost." % npc_name)
			return
	var walkers := marketplace.get_node("AmbientWalkers")
	for walker_name: String in EXPECTED_WALKERS:
		var walker := walkers.get_node(walker_name) as CharacterBody2D
		if walker.position != EXPECTED_WALKERS[walker_name]:
			_fail("Marketplace ambient walker moved from its approved aisle: %s" % walker_name)
			return
		if walker.get("character_sprite_frames") == null or walker.get("patrol_distance") != 64.0:
			_fail("Marketplace ambient walker lacks its bounded visual patrol contract: %s" % walker_name)
			return

	for entry_name: String in EXPECTED_ENTRIES:
		if (marketplace.get_node("EntryPoints/%s" % entry_name) as Marker2D).position != EXPECTED_ENTRIES[entry_name]:
			_fail("Marketplace entry changed: %s" % entry_name)
			return
	for exit_name: String in EXPECTED_EXITS:
		var expected_exit := EXPECTED_EXITS[exit_name] as Dictionary
		var zone_exit := marketplace.get_node("Exits/%s" % exit_name) as Area2D
		if zone_exit.position != expected_exit["position"] or zone_exit.get("destination_zone") != expected_exit["zone"] or zone_exit.get("destination_entry") != expected_exit["entry"]:
			_fail("Marketplace exit changed: %s" % exit_name)
			return
	if (marketplace.get_node("ZoneLabel") as CanvasItem).visible:
		_fail("Marketplace developer label remains visible.")
		return

	print("PASS: Marketplace terrain, selective assets, planted edge, fencing, ambient walkers, collision, sorting, routes, and transitions.")
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
