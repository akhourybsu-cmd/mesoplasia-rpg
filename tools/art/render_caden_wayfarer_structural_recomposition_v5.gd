extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const RENDER_TOOL_PATH := "res://tools/art/render_caden_wayfarer_structural_recomposition_v5.gd"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const FULL_ZONE_SIZE := Vector2i(1024, 640)
const DISPLAY_SIZE := Vector2i(1280, 720)
const NO_PLAYER := Vector2(-10000, -10000)

var _output_root := ""


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _resolve_output_root()
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var capture_root := _output_root.path_join("raw_captures")
	var make_directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if make_directory_result != OK:
		_fail("Unable to create raw capture directory %s: %s" % [capture_root, error_string(make_directory_result)])
		return

	var specs: Array[Dictionary] = [
		_spec(1, "wayfarer_full_zone_after_v5_1024x640", Vector2(512, 320), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full-zone structural recomposition"),
		_spec(2, "wayfarer_primary_gameplay_after_v5_640x360", Vector2(704, 400), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary road, traveler-yard, and rest-grove composition"),
		_spec(3, "wayfarer_inn_precinct_after_v5_640x360", Vector2(320, 260), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Inn precinct, service clusters, and softened road shoulder"),
		_spec(4, "wayfarer_traveler_yard_after_v5_640x360", Vector2(416, 460), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Unified traveler working yard and southern entrance"),
		_spec(5, "wayfarer_rest_grove_after_v5_640x360", Vector2(704, 460), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Sheltered rest grove and connected approach"),
		_spec(6, "wayfarer_open_meadow_after_v5_640x360", Vector2(704, 180), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Open northeast meadow with clustered perimeter frame"),
		_spec(7, "wayfarer_road_transitions_after_v5_640x360", Vector2(704, 320), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Softened road shoulders and preserved transition readability"),
		_spec(8, "wayfarer_05_player_front_after_v5_640x360", Vector2(704, 460), Vector2(880, 578), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player below and in front of 05"),
		_spec(9, "wayfarer_05_player_behind_after_v5_640x360", Vector2(704, 460), Vector2(880, 516), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player above and behind 05"),
		_spec(10, "wayfarer_07_player_front_after_v5_640x360", Vector2(640, 420), Vector2(650, 526), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player below and in front of 07"),
		_spec(11, "wayfarer_07_player_behind_after_v5_640x360", Vector2(640, 420), Vector2(650, 462), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player above and behind 07"),
		_spec(12, "wayfarer_grove_tree_player_front_after_v5_640x360", Vector2(704, 460), Vector2(790, 606), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player below and in front of the west grove tree"),
		_spec(13, "wayfarer_grove_tree_player_behind_after_v5_640x360", Vector2(704, 460), Vector2(790, 548), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Player above and behind the west grove tree"),
		_spec(14, "wayfarer_primary_display_after_v5_1280x720", Vector2(704, 400), NO_PLAYER, GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x primary gameplay view"),
	]
	var entries: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec["camera_center"], spec["player_position"], spec["capture_size"])
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
		entries.append(_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-wayfarer-structural-recomposition-screenshot-manifest-v5",
		"scope": "Wayfarer's Approach structural landscape recomposition only; no additional library candidate.",
		"scene": "res://scenes/world/caden/WayfarersApproach.tscn",
		"renderer": "Compatibility",
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"full_zone_viewport": [FULL_ZONE_SIZE.x, FULL_ZONE_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"determinism": {
			"player_facing": "down",
			"player_animation": "idle_down",
			"player_animation_frame": 0,
			"ui_state": "interaction prompt and dialogue UI hidden",
			"lighting": "unchanged live-scene lighting",
			"animated_scene_sprites": "paused at frame 0",
			"camera_smoothing": "disabled capture camera",
		},
		"reproduction": {
			"godot_arguments": "--path <repository> --rendering-method gl_compatibility --script res://tools/art/render_caden_wayfarer_structural_recomposition_v5.gd -- --output-root <absolute-directory-outside-res>",
			"notes": "All views instantiate the live scene. The 1280x720 frame is a nearest-neighbor resize of its native 640x360 capture state.",
		},
		"captures": entries,
	}
	var manifest_path := _output_root.path_join("wayfarer_structural_recomposition_screenshot_manifest_v5.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create %s." % manifest_path)
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _spec(
	evidence_id: int,
	name: String,
	camera_center: Vector2,
	player_position: Vector2,
	capture_size: Vector2i,
	output_size: Vector2i,
	description: String
) -> Dictionary:
	return {
		"evidence_id": evidence_id,
		"name": name,
		"camera_center": camera_center,
		"player_position": player_position,
		"capture_size": capture_size,
		"output_size": output_size,
		"description": description,
	}


func _manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"evidence_id": spec["evidence_id"],
		"filename": output_path.get_file(),
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": _vector_to_array(spec["camera_center"]),
		"player_position_xy": null if player_position == NO_PLAYER else _vector_to_array(player_position),
		"player_facing": null if player_position == NO_PLAYER else "down",
		"player_animation": null if player_position == NO_PLAYER else "idle_down",
		"player_animation_frame": null if player_position == NO_PLAYER else 0,
		"ui_visible": false,
		"sha256": FileAccess.get_sha256(output_path),
	}


func _vector_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _resolve_output_root() -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--output-root":
			return arguments[index + 1]
	return OS.get_environment("CADEN_WAYFARER_RECOMPOSITION_OUTPUT_ROOT")


func _capture(camera_position: Vector2, player_position: Vector2, capture_size: Vector2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = capture_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)

	var zone := ZONE_SCENE.instantiate()
	viewport.add_child(zone)
	for animated_node: Node in zone.find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite := animated_node as AnimatedSprite2D
		animated_sprite.pause()
		animated_sprite.frame = 0

	var player: CharacterBody2D
	if player_position != NO_PLAYER:
		player = PLAYER_SCENE.instantiate() as CharacterBody2D
		player.position = player_position
		player.z_index = 10
		player.set("facing_direction", Vector2.DOWN)
		viewport.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		var interaction_detector := player.get_node("InteractionDetector") as Area2D
		interaction_detector.process_mode = Node.PROCESS_MODE_DISABLED
		interaction_detector.monitoring = false
		(player.get_node("InteractionPrompt") as CanvasLayer).visible = false
		(player.get_node("DialogueUI") as CanvasLayer).visible = false
		var player_sprite := player.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
		player_sprite.animation = &"idle_down"
		player_sprite.pause()
		player_sprite.frame = 0

	var camera := Camera2D.new()
	camera.position = camera_position
	camera.enabled = true
	viewport.add_child(camera)
	for _frame in range(4):
		await process_frame
	if player != null:
		(player.get_node("InteractionPrompt") as CanvasLayer).visible = false
		(player.get_node("DialogueUI") as CanvasLayer).visible = false
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
