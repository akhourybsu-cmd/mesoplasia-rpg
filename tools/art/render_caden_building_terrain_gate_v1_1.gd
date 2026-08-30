extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SCENE_PATH := "res://scenes/world/caden/Residential.tscn"
const RENDER_TOOL_PATH := "res://tools/art/render_caden_building_terrain_gate_v1_1.gd"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const FULL_ZONE_SIZE := Vector2i(1152, 768)
const NO_PLAYER := Vector2(-10000, -10000)
const STRUCTURAL_CONTACT_Y := 48

var _package_root := ""
var _preparation: Dictionary = {}


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_package_root = _resolve_package_root()
	if _package_root.is_empty() or _package_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --package-root outside res:// is required.")
		return
	var preparation_path := _package_root.path_join("metadata/preparation_manifest_v1_1.json")
	_preparation = _load_json(preparation_path)
	if _preparation.is_empty() or int(_preparation.get("candidate_count", 0)) != 10:
		_fail("The prepared ten-candidate manifest is missing or invalid.")
		return
	var output_root := _package_root.path_join("residential_comparison")
	var capture_root := output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create comparison output: %s" % error_string(directory_result))
		return

	var specs: Array[Dictionary] = [
		_spec("residential_full_zone_current_v1_1_1152x768", false, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE),
		_spec("residential_full_zone_candidate_v1_1_1152x768", true, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE),
		_spec("residential_north_current_v1_1_640x360", false, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE),
		_spec("residential_north_candidate_v1_1_640x360", true, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE),
		_spec("residential_south_current_v1_1_640x360", false, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE),
		_spec("residential_south_candidate_v1_1_640x360", true, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE),
		_spec("residential_entrance_current_v1_1_640x360", false, Vector2(384, 176), Vector2(384, 224), GAMEPLAY_SIZE),
		_spec("residential_entrance_candidate_v1_1_640x360", true, Vector2(384, 176), Vector2(384, 224), GAMEPLAY_SIZE),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Capture failed: %s" % spec["name"])
			return
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var save_result := image.save_png(output_path)
		if save_result != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(save_result)])
			return
		captures.append({
			"filename": output_path.get_file(),
			"dimensions": [image.get_width(), image.get_height()],
			"state": "inactive_candidate" if spec["candidate"] else "current_runtime",
			"camera_center_xy": _vector_array(spec["camera_center"]),
			"player_position_xy": null if spec["player_position"] == NO_PLAYER else _vector_array(spec["player_position"]),
			"sha256": FileAccess.get_sha256(output_path),
		})
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-building-terrain-residential-comparison-v1.1",
		"gate_state": "inactive_comparison_pending_visual_approval",
		"scene": SCENE_PATH,
		"scene_sha256": FileAccess.get_sha256(SCENE_PATH),
		"render_tool": RENDER_TOOL_PATH,
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"renderer": "Compatibility",
		"candidate_count": 10,
		"live_scene_serialized_changes": [],
		"replacement_method": "Textures are loaded from the external gate and assigned only to transient scene instances in this renderer.",
		"preserved_contracts": [
			"ten existing Cabin StaticBody2D centers",
			"ten existing 128x96 Cabin collision shapes",
			"all roads, fences, yard pieces, vegetation, NPCs, entries, exits, and camera bounds",
		],
		"captures": captures,
	}
	var manifest_path := output_root.path_join("residential_comparison_manifest_v1_1.json")
	var handle := FileAccess.open(manifest_path, FileAccess.WRITE)
	if handle == null:
		_fail("Unable to create comparison manifest.")
		return
	handle.store_string(JSON.stringify(manifest, "  ") + "\n")
	handle.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _spec(name: String, candidate: bool, camera_center: Vector2, player_position: Vector2, size: Vector2i) -> Dictionary:
	return {
		"name": name,
		"candidate": candidate,
		"camera_center": camera_center,
		"player_position": player_position,
		"size": size,
	}


func _capture(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = spec["size"]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	var zone := ZONE_SCENE.instantiate()
	viewport.add_child(zone)
	if spec["candidate"] and not _apply_candidates(zone):
		viewport.queue_free()
		await process_frame
		return null
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


func _apply_candidates(zone: Node) -> bool:
	var assignments: Array = _preparation.get("residential_assignments", [])
	if assignments.size() != 10:
		push_error("Expected ten Residential assignments.")
		return false
	for assignment_value: Variant in assignments:
		var assignment: Dictionary = assignment_value
		var node_name := String(assignment.get("target_node", ""))
		var relative_path := String(assignment.get("runtime_preview_path", ""))
		var absolute_path := _package_root.path_join(relative_path)
		var image := Image.load_from_file(absolute_path)
		if image == null or image.is_empty():
			push_error("Unable to load external candidate: %s" % absolute_path)
			return false
		var texture := ImageTexture.create_from_image(image)
		var sprite := zone.get_node_or_null("Homes/%s/ExteriorSprite" % node_name) as Sprite2D
		if sprite == null:
			push_error("Missing Residential sprite for %s" % node_name)
			return false
		var pivot_value: Array = assignment.get("pivot_xy", [])
		if pivot_value.size() != 2:
			push_error("Missing pivot for %s" % node_name)
			return false
		var pivot := Vector2i(int(pivot_value[0]), int(pivot_value[1]))
		sprite.texture = texture
		sprite.position = Vector2(
			image.get_width() / 2 - pivot.x,
			STRUCTURAL_CONTACT_Y - pivot.y + image.get_height() / 2,
		)
		if sprite.position != sprite.position.round():
			push_error("Candidate placement is fractional for %s: %s" % [node_name, sprite.position])
			return false
	return true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {}
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	return parsed if parsed is Dictionary else {}


func _resolve_package_root() -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--package-root":
			return arguments[index + 1]
	return OS.get_environment("CADEN_BUILDING_TERRAIN_GATE_ROOT")


func _vector_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
