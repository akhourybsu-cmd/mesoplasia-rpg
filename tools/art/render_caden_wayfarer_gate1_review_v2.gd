extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const RENDER_TOOL_PATH := "res://tools/art/render_caden_wayfarer_gate1_review_v2.gd"
const CAPTURE_SIZE := Vector2i(640, 360)
const DISPLAY_SIZE := Vector2i(1280, 720)
const NO_PLAYER := Vector2(-10000, -10000)

var _output_root := ""


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _resolve_output_root()
	if _output_root.is_empty():
		_fail("An absolute --output-root outside res:// is required.")
		return
	if _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("Gate 1 review evidence must be written outside res://.")
		return
	var make_directory_result := DirAccess.make_dir_recursive_absolute(_output_root)
	if make_directory_result != OK:
		_fail("Unable to create output directory %s: %s" % [_output_root, error_string(make_directory_result)])
		return
	var capture_root := _output_root.path_join("raw_captures")
	make_directory_result = DirAccess.make_dir_recursive_absolute(capture_root)
	if make_directory_result != OK:
		_fail("Unable to create raw capture directory %s: %s" % [capture_root, error_string(make_directory_result)])
		return

	var specs: Array[Dictionary] = [
		_evidence_spec(1, "caden_wayfarer_rest_area_before_640x360", Vector2(704, 460), false, NO_PLAYER, CAPTURE_SIZE, "Baseline right-side rest area"),
		_evidence_spec(2, "caden_wayfarer_rest_area_after_640x360", Vector2(704, 460), true, NO_PLAYER, CAPTURE_SIZE, "Right-side rest area with 05"),
		_evidence_spec(3, "caden_wayfarer_05_player_front_640x360", Vector2(704, 460), true, Vector2(880, 578), CAPTURE_SIZE, "Player below and in front of 05"),
		_evidence_spec(4, "caden_wayfarer_05_player_behind_640x360", Vector2(704, 460), true, Vector2(880, 516), CAPTURE_SIZE, "Player above and behind 05"),
		_evidence_spec(5, "caden_wayfarer_hitching_area_before_640x360", Vector2(640, 390), false, NO_PLAYER, CAPTURE_SIZE, "Baseline wagon and hitching area"),
		_evidence_spec(6, "caden_wayfarer_hitching_area_after_640x360", Vector2(640, 390), true, NO_PLAYER, CAPTURE_SIZE, "Wagon and hitching area with 07"),
		_evidence_spec(7, "caden_wayfarer_07_player_front_640x360", Vector2(640, 390), true, Vector2(700, 526), CAPTURE_SIZE, "Player below and in front of 07"),
		_evidence_spec(8, "caden_wayfarer_07_player_behind_640x360", Vector2(640, 390), true, Vector2(700, 462), CAPTURE_SIZE, "Player above and behind 07"),
		_evidence_spec(9, "caden_wayfarer_road_readability_after_640x360", Vector2(704, 400), true, NO_PLAYER, CAPTURE_SIZE, "Road-adjacent view with both pilot compositions"),
		_evidence_spec(10, "caden_wayfarer_pilot_display_after_1280x720", Vector2(704, 400), true, NO_PLAYER, DISPLAY_SIZE, "Exact 2x nearest-neighbor display view"),
	]
	var entries: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec["camera_center"], spec["pilot_visible"], spec["player_position"])
		if image == null:
			_fail("Viewport capture failed for %s." % spec["name"])
			return
		var output_size: Vector2i = spec["output_size"]
		if output_size != CAPTURE_SIZE:
			image.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var save_result := image.save_png(output_path)
		if save_result != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(save_result)])
			return
		entries.append(_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-wayfarer-gate-1-screenshot-manifest-v2",
		"scope": "Two-asset Wayfarer pilot only; no other Caden zone or library asset is authorized.",
		"scene": "res://scenes/world/caden/WayfarersApproach.tscn",
		"renderer": "Compatibility",
		"internal_viewport": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
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
			"godot_arguments": "--path <repository> --rendering-method gl_compatibility --script res://tools/art/render_caden_wayfarer_gate1_review_v2.gd -- --output-root <absolute-directory-outside-res>",
			"notes": "Matched before/after frames use identical camera, UI, animation, and lighting state. Baselines instantiate the live scene and hide only SolidScenery/PilotProps.",
		},
		"captures": entries,
	}
	var manifest_path := _output_root.path_join("wayfarer_gate1_screenshot_manifest_v2.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create %s." % manifest_path)
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _evidence_spec(
	evidence_id: int,
	name: String,
	camera_center: Vector2,
	pilot_visible: bool,
	player_position: Vector2,
	output_size: Vector2i,
	description: String
) -> Dictionary:
	return {
		"evidence_id": evidence_id,
		"name": name,
		"camera_center": camera_center,
		"pilot_visible": pilot_visible,
		"player_position": player_position,
		"output_size": output_size,
		"description": description,
	}


func _manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"evidence_id": spec["evidence_id"],
		"filename": output_path.get_file(),
		"description": spec["description"],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": _vector_to_array(spec["camera_center"]),
		"player_position_xy": null if player_position == NO_PLAYER else _vector_to_array(player_position),
		"player_facing": null if player_position == NO_PLAYER else "down",
		"player_animation": null if player_position == NO_PLAYER else "idle_down",
		"player_animation_frame": null if player_position == NO_PLAYER else 0,
		"ui_visible": false,
		"pilot_visible": spec["pilot_visible"],
		"sha256": FileAccess.get_sha256(output_path),
	}


func _vector_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _resolve_output_root() -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--output-root":
			return arguments[index + 1]
	return OS.get_environment("CADEN_WAYFARER_GATE1_OUTPUT_ROOT")


func _capture(camera_position: Vector2, pilot_visible: bool, player_position: Vector2) -> Image:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)

	var zone := ZONE_SCENE.instantiate()
	viewport.add_child(zone)
	var pilot_props := zone.get_node("SolidScenery/PilotProps") as Node2D
	pilot_props.visible = pilot_visible
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
		return null
	var image := texture.get_image()
	viewport.queue_free()
	return image


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
