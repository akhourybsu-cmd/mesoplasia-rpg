extends "res://tools/art/render_caden_marketplace_runtime_v1.gd"

const PREP_TOOL_PATH := "res://tools/art/prepare_caden_marketplace_terrain_gate_v1_2.py"
const ACTIVE_TERRAIN_PATH := "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png"
const ACTIVE_TERRAIN_MANIFEST_PATH := "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.json"
const TERRAIN_GATE_RENDER_TOOL_PATH := "res://tools/art/render_caden_marketplace_terrain_gate_v1_2.gd"

var _candidate_texture: Texture2D


func _render() -> void:
	_output_root = _argument_value("--output-root")
	var prep_root := _argument_value("--prep-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	if prep_root.is_empty() or prep_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --prep-root outside res:// is required.")
		return
	var prep_manifest_path := prep_root.path_join("metadata/marketplace_terrain_preparation_manifest_v1_2.json")
	var prep_manifest := _load_external_json(prep_manifest_path)
	if prep_manifest.get("gate_state", "") != "inactive_marketplace_terrain_comparison_pending_visual_approval":
		_fail("Unexpected Marketplace terrain preparation gate state.")
		return
	if prep_manifest.get("generator_sha256", "") != FileAccess.get_sha256(PREP_TOOL_PATH):
		_fail("Marketplace terrain preparation tool changed after candidate generation.")
		return
	var candidate_record: Dictionary = prep_manifest.get("candidate", {})
	var candidate_path := prep_root.path_join(candidate_record.get("runtime_path", ""))
	if FileAccess.get_sha256(candidate_path) != candidate_record.get("runtime_sha256", ""):
		_fail("Marketplace terrain candidate hash mismatch.")
		return
	var candidate_image := Image.load_from_file(candidate_path)
	if candidate_image == null or candidate_image.get_size() != FULL_ZONE_SIZE:
		_fail("Marketplace terrain candidate dimensions are invalid.")
		return
	_candidate_texture = ImageTexture.create_from_image(candidate_image)

	var active_manifest := _load_external_json(ProjectSettings.globalize_path(ACTIVE_TERRAIN_MANIFEST_PATH))
	if FileAccess.get_sha256(ACTIVE_TERRAIN_PATH) != active_manifest.get("output_sha256", ""):
		_fail("Active Marketplace terrain identity mismatch.")
		return
	var active_scene := ZONE_SCENE.instantiate()
	var active_scene_texture := (active_scene.get_node("TerrainRuntime") as Sprite2D).texture
	if active_scene_texture == null or active_scene_texture.resource_path != ACTIVE_TERRAIN_PATH:
		active_scene.free()
		_fail("Serialized Marketplace scene does not retain Terrain Runtime v1.")
		return
	active_scene.free()

	var capture_root := _output_root.path_join("raw_captures")
	var make_directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if make_directory_result != OK:
		_fail("Unable to create %s: %s" % [capture_root, error_string(make_directory_result)])
		return
	var specs: Array[Dictionary] = [
		_comparison_spec("marketplace_terrain_full_current_v1_2_896x640", false, Vector2(448, 320), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full approved Marketplace runtime"),
		_comparison_spec("marketplace_terrain_full_candidate_v1_2_896x640", true, Vector2(448, 320), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full inactive terrain candidate"),
		_comparison_spec("marketplace_terrain_primary_current_v1_2_640x360", false, Vector2(448, 320), Vector2(448, 320), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary aisle and player current"),
		_comparison_spec("marketplace_terrain_primary_candidate_v1_2_640x360", true, Vector2(448, 320), Vector2(448, 320), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary aisle and player candidate"),
		_comparison_spec("marketplace_terrain_north_current_v1_2_640x360", false, Vector2(448, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North vendor districts current"),
		_comparison_spec("marketplace_terrain_north_candidate_v1_2_640x360", true, Vector2(448, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North vendor districts candidate"),
		_comparison_spec("marketplace_terrain_south_current_v1_2_640x360", false, Vector2(448, 448), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South vendor districts current"),
		_comparison_spec("marketplace_terrain_south_candidate_v1_2_640x360", true, Vector2(448, 448), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South vendor districts candidate"),
		_comparison_spec("marketplace_terrain_west_current_v1_2_640x360", false, Vector2(320, 320), Vector2(128, 320), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Wayfarer arrival current"),
		_comparison_spec("marketplace_terrain_west_candidate_v1_2_640x360", true, Vector2(320, 320), Vector2(128, 320), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Wayfarer arrival candidate"),
		_comparison_spec("marketplace_terrain_town_square_current_v1_2_640x360", false, Vector2(448, 460), Vector2(448, 512), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Town Square transition current"),
		_comparison_spec("marketplace_terrain_town_square_candidate_v1_2_640x360", true, Vector2(448, 460), Vector2(448, 512), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Town Square transition candidate"),
		_comparison_spec("marketplace_terrain_primary_candidate_display_v1_2_1280x720", true, Vector2(448, 320), Vector2(448, 320), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x candidate primary view"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture_comparison(spec)
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
		captures.append(_comparison_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-marketplace-terrain-gate-v1.2-render",
		"gate_state": "inactive_marketplace_terrain_comparison_pending_visual_approval",
		"scope": "Transient Marketplace terrain comparison only; active scene and resources remain unchanged.",
		"scene": "res://scenes/world/caden/Marketplace.tscn",
		"scene_sha256": FileAccess.get_sha256("res://scenes/world/caden/Marketplace.tscn"),
		"active_terrain_path": ACTIVE_TERRAIN_PATH,
		"active_terrain_sha256": active_manifest.get("output_sha256", ""),
		"candidate_terrain_path": candidate_path,
		"candidate_terrain_sha256": candidate_record.get("runtime_sha256", ""),
		"preparation_manifest_sha256": FileAccess.get_sha256(prep_manifest_path),
		"active_reference_changed": false,
		"renderer": "Compatibility",
		"render_tool": TERRAIN_GATE_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(TERRAIN_GATE_RENDER_TOOL_PATH),
		"zone_dimensions": [FULL_ZONE_SIZE.x, FULL_ZONE_SIZE.y],
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"population": {"dialogue_npcs": 3, "ambient_walkers": 4, "total_visible_npcs": 7},
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("marketplace_terrain_render_manifest_v1_2.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create Marketplace terrain render manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _comparison_spec(
	name: String,
	candidate: bool,
	camera_center: Vector2,
	player_position: Vector2,
	capture_size: Vector2i,
	output_size: Vector2i,
	description: String
) -> Dictionary:
	return {
		"name": name,
		"candidate": candidate,
		"camera_center": camera_center,
		"player_position": player_position,
		"capture_size": capture_size,
		"output_size": output_size,
		"description": description,
	}


func _comparison_manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"state": "candidate_transient_override" if spec["candidate"] else "current_active_serialized_scene",
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": _vector_to_array(spec["camera_center"]),
		"player_position_xy": null if player_position == NO_PLAYER else _vector_to_array(player_position),
		"sha256": FileAccess.get_sha256(output_path),
	}


func _capture_comparison(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = spec["capture_size"]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)

	var zone := ZONE_SCENE.instantiate()
	if spec["candidate"]:
		(zone.get_node("TerrainRuntime") as Sprite2D).texture = _candidate_texture
	viewport.add_child(zone)
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
		var sprite := player.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
		sprite.animation = &"idle_down"
		sprite.pause()
		sprite.frame = 0

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


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == name:
			return arguments[index + 1]
	return ""


func _load_external_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}
