extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const BUILDING_MANIFEST_PATH := "res://assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json"
const RENDER_TOOL_PATH := "res://tools/art/render_caden_residential_terrain_gate_v1_2.gd"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const FULL_ZONE_SIZE := Vector2i(1152, 768)
const DISPLAY_SIZE := Vector2i(1280, 720)
const NO_PLAYER := Vector2(-10000, -10000)

var _output_root := ""
var _prep_root := ""
var _candidate_texture: ImageTexture
var _candidate_manifest: Dictionary


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _argument_value("--output-root")
	_prep_root = _argument_value("--prep-root")
	var project_root := ProjectSettings.globalize_path("res://")
	if _output_root.is_empty() or _prep_root.is_empty():
		_fail("Absolute --output-root and --prep-root arguments are required.")
		return
	if _output_root.begins_with(project_root) or _prep_root.begins_with(project_root):
		_fail("Terrain preparation and render output must remain outside res://.")
		return
	var manifest_path := _prep_root.path_join("metadata/residential_terrain_preparation_manifest_v1_2.json")
	_candidate_manifest = _load_json(manifest_path)
	if _candidate_manifest.is_empty() or _candidate_manifest.get("gate_state", "") != "inactive_residential_terrain_comparison_pending_visual_approval":
		_fail("Unexpected terrain preparation gate state.")
		return
	var candidate_record := _candidate_manifest.get("candidate", {}) as Dictionary
	var candidate_path := _prep_root.path_join(candidate_record.get("runtime_path", ""))
	if not FileAccess.file_exists(candidate_path) or FileAccess.get_sha256(candidate_path) != candidate_record.get("runtime_sha256", ""):
		_fail("Terrain candidate hash mismatch.")
		return
	var candidate_image := Image.load_from_file(candidate_path)
	if candidate_image == null or candidate_image.get_size() != FULL_ZONE_SIZE:
		_fail("Terrain candidate must be exactly 1152x768.")
		return
	_candidate_texture = ImageTexture.create_from_image(candidate_image)
	if _candidate_texture == null:
		_fail("Unable to create the transient candidate ImageTexture.")
		return

	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create %s: %s" % [capture_root, error_string(directory_result)])
		return
	var specs: Array[Dictionary] = [
		_spec("residential_terrain_full_current_v1_2_1152x768", false, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Approved Residential buildings on current terrain"),
		_spec("residential_terrain_full_candidate_v1_2_1152x768", true, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Approved Residential buildings on inactive terrain candidate"),
		_spec("residential_terrain_north_current_v1_2_640x360", false, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North homes on current terrain"),
		_spec("residential_terrain_north_candidate_v1_2_640x360", true, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North homes on inactive terrain candidate"),
		_spec("residential_terrain_south_current_v1_2_640x360", false, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South homes on current terrain"),
		_spec("residential_terrain_south_candidate_v1_2_640x360", true, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South homes on inactive terrain candidate"),
		_spec("residential_terrain_primary_current_v1_2_640x360", false, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route and player on current terrain"),
		_spec("residential_terrain_primary_candidate_v1_2_640x360", true, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route and player on inactive terrain candidate"),
		_spec("residential_terrain_west_current_v1_2_640x360", false, Vector2(320, 384), Vector2(128, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "West arrival on current terrain"),
		_spec("residential_terrain_west_candidate_v1_2_640x360", true, Vector2(320, 384), Vector2(128, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "West arrival on inactive terrain candidate"),
		_spec("residential_terrain_commons_current_v1_2_640x360", false, Vector2(576, 588), Vector2(576, 640), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Commons transition on current terrain"),
		_spec("residential_terrain_commons_candidate_v1_2_640x360", true, Vector2(576, 588), Vector2(576, 640), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Commons transition on inactive terrain candidate"),
		_spec("residential_terrain_primary_candidate_display_v1_2_1280x720", true, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x candidate primary view"),
	]
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

	var building_manifest := _load_json(BUILDING_MANIFEST_PATH)
	if building_manifest.get("gate_state", "") != "residential_building_pilot_v1_1_visual_approved":
		_fail("Residential building pilot is not in its approved state.")
		return
	var manifest := {
		"schema": "caden-residential-terrain-gate-v1.2-render",
		"gate_state": "inactive_residential_terrain_comparison_pending_visual_approval",
		"scope": "Matched current/candidate views from transient live-scene instances; no scene or resource reference serialized.",
		"scene": "res://scenes/world/caden/Residential.tscn",
		"scene_sha256": FileAccess.get_sha256("res://scenes/world/caden/Residential.tscn"),
		"active_terrain_path": "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png",
		"active_terrain_sha256": FileAccess.get_sha256("res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"),
		"candidate_preparation_manifest_sha256": FileAccess.get_sha256(_prep_root.path_join("metadata/residential_terrain_preparation_manifest_v1_2.json")),
		"building_manifest_sha256": FileAccess.get_sha256(BUILDING_MANIFEST_PATH),
		"building_gate_state": building_manifest.get("gate_state", ""),
		"renderer": "Compatibility",
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"zone_dimensions": [FULL_ZONE_SIZE.x, FULL_ZONE_SIZE.y],
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"population": {"dialogue_npcs": 2, "ambient_walkers": 5, "total_visible_npcs": 7},
		"active_reference_changed": false,
		"captures": captures,
	}
	var output_manifest_path := _output_root.path_join("residential_terrain_render_manifest_v1_2.json")
	var manifest_file := FileAccess.open(output_manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create render manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % output_manifest_path)
	quit(0)


func _spec(name: String, candidate: bool, camera_center: Vector2, player_position: Vector2, capture_size: Vector2i, output_size: Vector2i, description: String) -> Dictionary:
	return {"name": name, "candidate": candidate, "camera_center": camera_center, "player_position": player_position, "capture_size": capture_size, "output_size": output_size, "description": description}


func _manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"candidate": spec["candidate"],
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
		"player_position_xy": null if player_position == NO_PLAYER else [player_position.x, player_position.y],
		"sha256": FileAccess.get_sha256(output_path),
	}


func _capture(spec: Dictionary) -> Image:
	var capture_size: Vector2i = spec["capture_size"]
	var viewport := SubViewport.new()
	viewport.size = capture_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	var zone := ZONE_SCENE.instantiate()
	viewport.add_child(zone)
	if spec["candidate"]:
		(zone.get_node("TerrainRuntime") as Sprite2D).texture = _candidate_texture
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
		for set_piece: Node in zone.get_node("DomesticSetPieces").get_children():
			if set_piece.has_method("update_depth_for_player"):
				set_piece.call("update_depth_for_player", player_position.y)

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


func _argument_value(flag: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == flag:
			return arguments[index + 1]
	return ""


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
