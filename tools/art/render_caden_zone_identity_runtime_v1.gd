extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const RESIDENTIAL_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const COMMONS_SCENE := preload("res://scenes/world/caden/Commons.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SOURCE_MANIFEST_PATH := "res://assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_runtime_v1.json"
const DECISION_MANIFEST_PATH := "res://assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_blueprint_v3.json"
const RENDER_TOOL_PATH := "res://tools/art/render_caden_zone_identity_runtime_v1.gd"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const DISPLAY_SIZE := Vector2i(1280, 720)
const NO_PLAYER := Vector2(-9999, -9999)

var _output_root := ""


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var source_manifest := _load_json(SOURCE_MANIFEST_PATH)
	var decision_manifest := _load_json(DECISION_MANIFEST_PATH)
	if source_manifest.get("gate_state", "") != "limited_four_asset_in_engine_comparison":
		_fail("Unexpected Zone Identity source-manifest state.")
		return
	if decision_manifest.get("gate_state", "") != "blueprint_v3_user_approved_integration":
		_fail("Blueprint v3 has not reached its user-approved integration state.")
		return
	if not _verify_runtime_assets(source_manifest.get("runtime_assets", {}), decision_manifest.get("decisions", {})):
		return
	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create capture directory: %s" % error_string(directory_result))
		return

	var specs: Array[Dictionary] = []
	specs.append_array(_zone_specs(
		"town_square", "Town Square", TOWN_SQUARE_SCENE, "res://scenes/world/caden/TownSquare.tscn",
		"BlueprintV3CivicGarden", "BlueprintV3CivicGarden/CivicGardenEdge", Vector2i(960, 704),
		Vector2(480, 352), Vector2(700, 288), Vector2(680, 270), Vector2(680, 312),
		[Rect2(-16, 256, 160, 192), Rect2(816, 256, 160, 192), Rect2(384, -16, 192, 160), Rect2(384, 560, 192, 160), Rect2(352, 224, 256, 256)]))
	specs.append_array(_zone_specs(
		"residential", "Residential", RESIDENTIAL_SCENE, "res://scenes/world/caden/Residential.tscn",
		"ZoneIdentityV1", "ZoneIdentityV1/DomesticUtilityYard", Vector2i(1152, 768),
		Vector2(576, 384), Vector2(320, 608), Vector2(320, 680), Vector2(320, 736),
		[Rect2(256, 448, 64, 224), Rect2(480, 624, 192, 160)]))
	specs.append_array(_zone_specs(
		"commons", "Commons", COMMONS_SCENE, "res://scenes/world/caden/Commons.tscn",
		"ZoneIdentityV1", "ZoneIdentityV1/NaturalBoundaryMass", Vector2i(1024, 704),
		Vector2(512, 352), Vector2(320, 524), Vector2(170, 548), Vector2(170, 608),
		[Rect2(-16, 256, 160, 192), Rect2(416, -16, 192, 160), Rect2(0, 304, 560, 96), Rect2(464, 0, 96, 400)]))
	specs.append(_spec(
		"town_square_identity_after_display_v1_1280x720", "Town Square", TOWN_SQUARE_SCENE,
		"res://scenes/world/caden/TownSquare.tscn", "BlueprintV3CivicGarden", "BlueprintV3CivicGarden/CivicGardenEdge",
		true, false, [], Vector2(700, 288), NO_PLAYER, GAMEPLAY_SIZE, DISPLAY_SIZE,
		"Exact nearest-neighbor 2x approved Town Square identity view"))

	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Viewport capture failed for %s." % spec["name"])
			return
		var output_size: Vector2i = spec["output_size"]
		if image.get_size() != output_size:
			image.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var save_result := image.save_png(output_path)
		if save_result != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(save_result)])
			return
		captures.append(_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-zone-identity-blueprint-v3-proof",
		"gate_state": "approved_active_three_asset_depth_collision_and_clearance_proof",
		"scope": "Matched before/after, player depth-order, collision, and protected-clearance evidence for the three active Zone Identity compositions.",
		"active_source_ids": ["CAD-COMP-13", "CAD-YARD-35", "CAD-LAND-33"],
		"rejected_source_ids": ["CAD-COMP-10"],
		"source_manifest": SOURCE_MANIFEST_PATH.trim_prefix("res://"),
		"source_manifest_sha256": FileAccess.get_sha256(SOURCE_MANIFEST_PATH),
		"decision_manifest": DECISION_MANIFEST_PATH.trim_prefix("res://"),
		"decision_manifest_sha256": FileAccess.get_sha256(DECISION_MANIFEST_PATH),
		"renderer": "Compatibility",
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"internal_gameplay_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"overlay_legend": {"protected_clearance": "translucent_blue", "identity_collision": "translucent_red"},
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("caden_zone_identity_blueprint_v3_proof.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create proof manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _zone_specs(slug: String, zone_name: String, scene: PackedScene, scene_path: String,
		identity_root_path: String, identity_path: String, full_size: Vector2i, full_camera: Vector2,
		focus_camera: Vector2, player_behind: Vector2, player_front: Vector2,
		protected_clearances: Array) -> Array[Dictionary]:
	return [
		_spec("%s_identity_full_before_v1_%dx%d" % [slug, full_size.x, full_size.y], zone_name, scene, scene_path,
			identity_root_path, identity_path, false, false, [], full_camera, NO_PLAYER, full_size, full_size, "%s full-zone context with identity hidden" % zone_name),
		_spec("%s_identity_full_after_v1_%dx%d" % [slug, full_size.x, full_size.y], zone_name, scene, scene_path,
			identity_root_path, identity_path, true, false, [], full_camera, NO_PLAYER, full_size, full_size, "%s approved active full-zone context" % zone_name),
		_spec("%s_identity_focus_before_v1_640x360" % slug, zone_name, scene, scene_path,
			identity_root_path, identity_path, false, false, [], focus_camera, NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "%s focused view with identity hidden" % zone_name),
		_spec("%s_identity_focus_after_v1_640x360" % slug, zone_name, scene, scene_path,
			identity_root_path, identity_path, true, false, [], focus_camera, NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "%s approved active focused view" % zone_name),
		_spec("%s_identity_player_behind_v1_640x360" % slug, zone_name, scene, scene_path,
			identity_root_path, identity_path, true, false, [], focus_camera, player_behind, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "%s player behind the identity composition" % zone_name),
		_spec("%s_identity_player_front_v1_640x360" % slug, zone_name, scene, scene_path,
			identity_root_path, identity_path, true, false, [], focus_camera, player_front, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "%s player in front of the identity composition" % zone_name),
		_spec("%s_identity_collision_clearance_v1_640x360" % slug, zone_name, scene, scene_path,
			identity_root_path, identity_path, true, true, protected_clearances, focus_camera, NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "%s identity collision and protected-clearance overlay" % zone_name),
	]


func _spec(name: String, zone_name: String, scene: PackedScene, scene_path: String, identity_root_path: String,
		identity_path: String, identity_visible: bool, collision_overlay: bool, protected_clearances: Array,
		camera_center: Vector2, player_position: Vector2, capture_size: Vector2i, output_size: Vector2i,
		description: String) -> Dictionary:
	return {
		"name": name,
		"zone_name": zone_name,
		"scene": scene,
		"scene_path": scene_path,
		"identity_root_path": identity_root_path,
		"identity_path": identity_path,
		"identity_visible": identity_visible,
		"collision_overlay": collision_overlay,
		"protected_clearances": protected_clearances,
		"camera_center": camera_center,
		"player_position": player_position,
		"capture_size": capture_size,
		"output_size": output_size,
		"description": description,
	}


func _capture(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = spec["capture_size"]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	var zone := (spec["scene"] as PackedScene).instantiate()
	viewport.add_child(zone)
	var identity_root := zone.get_node_or_null(spec["identity_root_path"]) as CanvasItem
	var identity_prop := zone.get_node_or_null(spec["identity_path"]) as StaticBody2D
	if identity_root == null or identity_prop == null:
		viewport.queue_free()
		await process_frame
		return null
	identity_root.visible = spec["identity_visible"]
	for body_node: Node in zone.find_children("*", "CharacterBody2D", true, false):
		body_node.set_physics_process(false)
	for animated_node: Node in zone.find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite := animated_node as AnimatedSprite2D
		animated_sprite.pause()
		animated_sprite.frame = 0
	var player_position: Vector2 = spec["player_position"]
	if player_position != NO_PLAYER:
		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		player.position = player_position
		player.z_index = 10
		player.set("facing_direction", Vector2.DOWN)
		viewport.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		var detector := player.get_node("InteractionDetector") as Area2D
		detector.process_mode = Node.PROCESS_MODE_DISABLED
		detector.monitoring = false
		(player.get_node("InteractionPrompt") as CanvasLayer).visible = false
		(player.get_node("DialogueUI") as CanvasLayer).visible = false
		var player_sprite := player.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
		player_sprite.animation = &"idle_down"
		player_sprite.pause()
		player_sprite.frame = 0
		for solid_node: Node in zone.find_children("*", "StaticBody2D", true, false):
			if solid_node.has_method("update_depth_for_player"):
				solid_node.call("update_depth_for_player", player_position.y)
	if spec["collision_overlay"]:
		_add_collision_overlay(zone, identity_prop, spec["protected_clearances"])
	var camera := Camera2D.new()
	camera.position = spec["camera_center"]
	camera.enabled = true
	viewport.add_child(camera)
	for _frame in range(4):
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		viewport.queue_free()
		await process_frame
		return null
	var image := texture.get_image()
	viewport.queue_free()
	await process_frame
	return image


func _add_collision_overlay(zone: Node, identity_prop: StaticBody2D, protected_clearances: Array) -> void:
	var overlay := Node2D.new()
	overlay.name = "BlueprintV3CollisionProof"
	overlay.z_index = 100
	zone.add_child(overlay)
	for clearance: Rect2 in protected_clearances:
		var polygon := Polygon2D.new()
		polygon.polygon = PackedVector2Array([clearance.position, Vector2(clearance.end.x, clearance.position.y), clearance.end, Vector2(clearance.position.x, clearance.end.y)])
		polygon.color = Color(0.1, 0.55, 1.0, 0.28)
		overlay.add_child(polygon)
	for collision_node: Node in identity_prop.find_children("*", "CollisionShape2D", false, false):
		var collision := collision_node as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		if shape == null:
			continue
		var bounds := Rect2(collision.global_position - shape.size * 0.5, shape.size)
		var polygon := Polygon2D.new()
		polygon.polygon = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
		polygon.color = Color(1.0, 0.18, 0.12, 0.72)
		overlay.add_child(polygon)


func _manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"zone": spec["zone_name"],
		"state": "approved_active" if spec["identity_visible"] else "transient_identity_hidden",
		"description": spec["description"],
		"scene": spec["scene_path"],
		"scene_sha256": FileAccess.get_sha256(spec["scene_path"]),
		"identity_node": spec["identity_path"],
		"collision_overlay": spec["collision_overlay"],
		"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
		"player_position_xy": null if player_position == NO_PLAYER else [player_position.x, player_position.y],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"sha256": FileAccess.get_sha256(output_path),
	}


func _verify_runtime_assets(records: Variant, decisions: Variant) -> bool:
	if not records is Dictionary or records.size() != 4 or not decisions is Dictionary:
		return _fail_bool("Zone Identity manifests have an unexpected candidate set.")
	for source_id: Variant in records:
		var record: Dictionary = records[source_id]
		var runtime_path := "res://%s" % record.get("runtime_path", "")
		if FileAccess.get_sha256(runtime_path) != record.get("runtime_sha256", ""):
			return _fail_bool("Runtime identity mismatch for %s." % source_id)
	var expected_states := {
		"CAD-COMP-10": "rejected_not_referenced",
		"CAD-COMP-13": "active_blueprint_v3",
		"CAD-YARD-35": "active_blueprint_v3",
		"CAD-LAND-33": "active_blueprint_v3",
	}
	for source_id: String in expected_states:
		if not decisions.has(source_id) or (decisions[source_id] as Dictionary).get("state") != expected_states[source_id]:
			return _fail_bool("Blueprint v3 decision mismatch for %s." % source_id)
	return true


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == name:
			return arguments[index + 1]
	return ""


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
