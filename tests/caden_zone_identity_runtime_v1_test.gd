extends SceneTree

const SOURCE_MANIFEST_PATH := "res://assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_runtime_v1.json"
const DECISION_MANIFEST_PATH := "res://assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_blueprint_v3.json"
const MARKETPLACE_SCENE_PATH := "res://scenes/world/caden/Marketplace.tscn"
const TOWN_SQUARE_SCENE_PATH := "res://scenes/world/caden/TownSquare.tscn"
const WAYFARER_SCENE_PATH := "res://scenes/world/caden/WayfarersApproach.tscn"
const EXPECTED_SOURCE_MANIFEST_SHA256 := "e0d7b615a82f7c6224d56edfc97e568ee511819dd452e381d742f63f673d2e99"
const EXPECTED_PHASE_A_WAYFARER_SHA256 := "21f007dd38922bf78ebe088aa233a3e2ac21bc5b9c1c31c651727dd92e52a140"
const ACTIVE_SPECS := {
	"CAD-YARD-35": {
		"scene": "res://scenes/world/caden/Residential.tscn",
		"node": "ZoneIdentityV1/DomesticUtilityYard",
		"position": Vector2(320, 704),
		"sprite_position": Vector2(-61, -106),
		"collisions": {
			"StorageCollision": {"position": Vector2(-18, -12), "size": Vector2(46, 24)},
			"FenceReturnCollision": {"position": Vector2(34, -8), "size": Vector2(24, 12)},
		},
	},
	"CAD-LAND-33": {
		"scene": "res://scenes/world/caden/Commons.tscn",
		"node": "ZoneIdentityV1/NaturalBoundaryMass",
		"position": Vector2(160, 576),
		"sprite_position": Vector2(-70, -113),
		"collisions": {
			"CoreCollision": {"position": Vector2(2, -9), "size": Vector2(38, 18)},
		},
	},
	"CAD-COMP-13": {
		"scene": "res://scenes/world/caden/TownSquare.tscn",
		"node": "BlueprintV3CivicGarden/CivicGardenEdge",
		"position": Vector2(700, 288),
		"sprite_position": Vector2(-56, -103),
		"collisions": {
			"LowWallCollision": {"position": Vector2(-4, -18), "size": Vector2(62, 12)},
			"LanternPostCollision": {"position": Vector2(36, -22), "size": Vector2(10, 14)},
		},
	},
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var source_manifest := _load_json(SOURCE_MANIFEST_PATH)
	var decision_manifest := _load_json(DECISION_MANIFEST_PATH)
	if source_manifest.is_empty() or decision_manifest.is_empty():
		return
	if FileAccess.get_sha256(SOURCE_MANIFEST_PATH) != EXPECTED_SOURCE_MANIFEST_SHA256:
		return _fail("The reviewed Zone Identity source manifest changed.")
	if decision_manifest.get("gate_state") != "blueprint_v3_user_approved_integration":
		return _fail("Blueprint v3 decision gate changed.")
	if decision_manifest.get("source_runtime_manifest_sha256") != EXPECTED_SOURCE_MANIFEST_SHA256:
		return _fail("Blueprint v3 no longer identifies its reviewed source manifest.")
	if decision_manifest.get("wayfarer_decision") != "retain_v5_unchanged_to_preserve_open_rustic_identity":
		return _fail("Wayfarer retention decision changed.")
	if decision_manifest.get("town_square_decision") != "activate_versioned_overlay_by_explicit_user_approval":
		return _fail("Town Square approval decision changed.")

	var records: Dictionary = source_manifest.get("runtime_assets", {})
	var decisions: Dictionary = decision_manifest.get("decisions", {})
	for source_id: String in ACTIVE_SPECS:
		if not records.has(source_id) or not decisions.has(source_id):
			return _fail("Missing active decision record: %s." % source_id)
		if (decisions[source_id] as Dictionary).get("state") != "active_blueprint_v3":
			return _fail("Active decision changed: %s." % source_id)
		if not _verify_runtime_asset(source_id, records[source_id]):
			return
		if not await _verify_zone_integration(source_id, ACTIVE_SPECS[source_id], records[source_id]):
			return

	var market_decision := decisions.get("CAD-COMP-10", {}) as Dictionary
	if market_decision.get("state") != "rejected_not_referenced":
		return _fail("Unsafe Marketplace comparison was not rejected.")
	var marketplace_text := FileAccess.get_file_as_string(MARKETPLACE_SCENE_PATH)
	if "ZoneIdentityV1" in marketplace_text or "cad_comp_v2_r01_c02_runtime_v1" in marketplace_text:
		return _fail("Rejected Marketplace comparison remains referenced by the active scene.")

	var town_decision := decisions.get("CAD-COMP-13", {}) as Dictionary
	if town_decision.get("state") != "active_blueprint_v3" or town_decision.get("approval") != "explicit_user_approval_2026-08-30":
		return _fail("Town Square civic garden is not recorded as explicitly approved and active.")
	var town_square_text := FileAccess.get_file_as_string(TOWN_SQUARE_SCENE_PATH)
	if town_square_text.count("TownSquareBlueprintV3Overlay.tscn") != 1 or town_square_text.count("BlueprintV3CivicGarden") != 1:
		return _fail("Town Square must reference exactly one approved civic-garden assembly.")
	if not _verify_town_square_approved_clearances():
		return

	if FileAccess.get_sha256(WAYFARER_SCENE_PATH) != EXPECTED_PHASE_A_WAYFARER_SHA256:
		return _fail("Wayfarer's Approach v5 presentation plus Phase A identity annotations changed.")
	var wayfarer_text := FileAccess.get_file_as_string(WAYFARER_SCENE_PATH)
	if "ZoneIdentityV1" in wayfarer_text or "zone_identity/runtime_v1" in wayfarer_text:
		return _fail("Wayfarer received an unauthorized Zone Identity asset.")
	if wayfarer_text.count("interactable_id =") != 3 or wayfarer_text.count("exit_id =") != 2:
		return _fail("Wayfarer no longer carries the approved Phase A stable request IDs.")

	print("PASS: Blueprint v3 preserves the approved identities and Wayfarer v5 presentation while retaining Phase A request IDs.")
	quit(0)


func _verify_town_square_approved_clearances() -> bool:
	var scene := load(TOWN_SQUARE_SCENE_PATH) as PackedScene
	var town_square := scene.instantiate() as Node2D if scene != null else null
	if town_square == null:
		return _fail("Town Square did not instantiate for approved-clearance validation.")
	root.add_child(town_square)
	var assembly := town_square.get_node_or_null("BlueprintV3CivicGarden") as Node2D
	var prop := town_square.get_node_or_null("BlueprintV3CivicGarden/CivicGardenEdge") as StaticBody2D
	if assembly == null or assembly.get_child_count() != 1 or prop == null:
		return _fail("Town Square approved assembly must contain exactly one civic garden.")
	var protected_clearances := [
		Rect2(-16, 256, 160, 192),
		Rect2(816, 256, 160, 192),
		Rect2(384, -16, 192, 160),
		Rect2(384, 560, 192, 160),
		Rect2(352, 224, 256, 256),
	]
	for collision_node: Node in prop.find_children("*", "CollisionShape2D", false, false):
		var collision := collision_node as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		if shape == null:
			return _fail("Town Square civic-garden collision is not rectangular.")
		var bounds := Rect2(collision.global_position - shape.size * 0.5, shape.size)
		for protected: Rect2 in protected_clearances:
			if bounds.intersects(protected):
				return _fail("Town Square civic-garden collision entered a trigger safety ring or the reserved civic center.")
	town_square.queue_free()
	return true


func _verify_runtime_asset(source_id: String, record: Dictionary) -> bool:
	var path := "res://" + str(record.get("runtime_path", ""))
	if FileAccess.get_sha256(path) != record.get("runtime_sha256", ""):
		return _fail("Runtime asset identity mismatch: %s." % source_id)
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return _fail("Runtime asset did not decode: %s." % source_id)
	var audit: Dictionary = record.get("pixel_audit", {})
	if image.get_size() != Vector2i(audit.get("dimensions", [0, 0])[0], audit.get("dimensions", [0, 0])[1]):
		return _fail("Runtime dimensions changed: %s." % source_id)
	if audit.get("partial_alpha_pixels", -1) != 0 or audit.get("transparent_rgb_pixels", -1) != 0 or audit.get("canvas_edge_pixels", -1) != 0 or audit.get("boundary_contamination_pixels", -1) != 0:
		return _fail("Runtime cleanup audit no longer passes: %s." % source_id)
	if not is_equal_approx(float(record.get("import_scale", 0.0)), 1.0):
		return _fail("Runtime import scale changed: %s." % source_id)
	return true


func _verify_zone_integration(source_id: String, spec: Dictionary, record: Dictionary) -> bool:
	var scene := load(spec["scene"]) as PackedScene
	if scene == null:
		return _fail("Zone scene did not load: %s." % spec["scene"])
	var zone := scene.instantiate() as Node2D
	root.add_child(zone)
	await process_frame
	var prop := zone.get_node_or_null(spec["node"]) as StaticBody2D
	if prop == null or prop.position != spec["position"] or not prop.has_method("update_depth_for_player"):
		return _fail("%s placement or depth behavior changed." % source_id)
	if not _verify_composition(source_id, prop, spec, record):
		return false
	zone.queue_free()
	await process_frame
	return true


func _verify_composition(source_id: String, prop: StaticBody2D, spec: Dictionary, record: Dictionary) -> bool:
	var sprite := prop.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.centered or sprite.position != spec["sprite_position"] or sprite.scale != Vector2.ONE:
		return _fail("%s bottom-center sprite pivot or scale changed." % source_id)
	if sprite.texture == null or sprite.texture.resource_path != "res://" + str(record["runtime_path"]):
		return _fail("%s texture reference changed." % source_id)
	var expected_collisions: Dictionary = spec["collisions"]
	var actual_collisions := prop.find_children("*", "CollisionShape2D", false, false)
	if actual_collisions.size() != expected_collisions.size():
		return _fail("%s collision count changed." % source_id)
	for collision_name: String in expected_collisions:
		var collision := prop.get_node_or_null(collision_name) as CollisionShape2D
		var collision_spec: Dictionary = expected_collisions[collision_name]
		var shape := collision.shape as RectangleShape2D if collision != null else null
		if collision == null or collision.position != collision_spec["position"] or shape == null or shape.size != collision_spec["size"]:
			return _fail("%s structural collision changed: %s." % [source_id, collision_name])
	return true


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Unable to open %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Invalid JSON object: %s." % path)
		return {}
	return parsed as Dictionary


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
