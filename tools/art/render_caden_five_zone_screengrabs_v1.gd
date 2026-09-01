extends SceneTree

const WAYFARER_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const MARKETPLACE_SCENE := preload("res://scenes/world/caden/Marketplace.tscn")
const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const RESIDENTIAL_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const COMMONS_SCENE := preload("res://scenes/world/caden/Commons.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const RENDER_TOOL_PATH := "res://tools/art/render_caden_five_zone_screengrabs_v1.gd"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const NO_PLAYER := Vector2(-9999, -9999)

var _output_root := ""


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var capture_root := _output_root.path_join("captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create screengrab directory: %s" % error_string(directory_result))
		return

	var specs: Array[Dictionary] = []
	specs.append_array(_zone_specs(
		1, "wayfarers_approach", "Wayfarer's Approach", WAYFARER_SCENE,
		"res://scenes/world/caden/WayfarersApproach.tscn", Vector2i(1024, 640), Vector2(512, 320),
		Vector2(512, 320), Vector2(512, 320), "primary crossroads",
		Vector2(704, 460), Vector2(720, 500), "traveler rest and pilot area"))
	specs.append_array(_zone_specs(
		2, "marketplace", "Marketplace", MARKETPLACE_SCENE,
		"res://scenes/world/caden/Marketplace.tscn", Vector2i(896, 640), Vector2(448, 320),
		Vector2(448, 320), Vector2(448, 320), "central market circulation",
		Vector2(448, 460), Vector2(448, 512), "formal south market threshold"))
	specs.append_array(_zone_specs(
		3, "town_square", "Town Square", TOWN_SQUARE_SCENE,
		"res://scenes/world/caden/TownSquare.tscn", Vector2i(960, 704), Vector2(480, 352),
		Vector2(480, 352), Vector2(480, 352), "reserved civic plaza",
		Vector2(640, 288), Vector2(680, 312), "northeast civic garden edge"))
	specs.append_array(_zone_specs(
		4, "residential", "Residential", RESIDENTIAL_SCENE,
		"res://scenes/world/caden/Residential.tscn", Vector2i(1152, 768), Vector2(576, 384),
		Vector2(576, 384), Vector2(576, 384), "central neighborhood routes",
		Vector2(320, 560), Vector2(300, 616), "southwest domestic utility yard"))
	specs.append_array(_zone_specs(
		5, "commons", "Commons", COMMONS_SCENE,
		"res://scenes/world/caden/Commons.tscn", Vector2i(1024, 704), Vector2(512, 352),
		Vector2(512, 352), Vector2(512, 352), "Quiet Green and maintained paths",
		Vector2(320, 524), Vector2(170, 608), "southwest natural boundary"))

	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Viewport capture failed for %s." % spec["name"])
			return
		var output_path := capture_root.path_join("%02d_%s.png" % [spec["evidence_id"], spec["name"]])
		var save_result := image.save_png(output_path)
		if save_result != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(save_result)])
			return
		captures.append(_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-five-zone-screengrabs-v1",
		"gate_state": "current_serialized_five_zone_visual_record",
		"scope": "Full-zone and representative gameplay-scale captures of all five current Caden zones.",
		"renderer": "Compatibility",
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"gameplay_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("caden_five_zone_screengrab_manifest_v1.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_fail("Unable to create screengrab manifest.")
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _zone_specs(zone_index: int, slug: String, zone_name: String, scene: PackedScene, scene_path: String, full_size: Vector2i, full_camera: Vector2, primary_camera: Vector2, primary_player: Vector2, primary_description: String, feature_camera: Vector2, feature_player: Vector2, feature_description: String) -> Array[Dictionary]:
	var start_id := (zone_index - 1) * 3 + 1
	return [
		_spec(start_id, "%s_full_zone_%dx%d" % [slug, full_size.x, full_size.y], zone_name, scene, scene_path, full_camera, NO_PLAYER, full_size, "Full current %s overview" % zone_name),
		_spec(start_id + 1, "%s_primary_640x360" % slug, zone_name, scene, scene_path, primary_camera, primary_player, GAMEPLAY_SIZE, "%s: %s" % [zone_name, primary_description]),
		_spec(start_id + 2, "%s_feature_640x360" % slug, zone_name, scene, scene_path, feature_camera, feature_player, GAMEPLAY_SIZE, "%s: %s" % [zone_name, feature_description]),
	]


func _spec(evidence_id: int, name: String, zone_name: String, scene: PackedScene, scene_path: String, camera_center: Vector2, player_position: Vector2, capture_size: Vector2i, description: String) -> Dictionary:
	return {
		"evidence_id": evidence_id,
		"name": name,
		"zone_name": zone_name,
		"scene": scene,
		"scene_path": scene_path,
		"camera_center": camera_center,
		"player_position": player_position,
		"capture_size": capture_size,
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


func _manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	return {
		"evidence_id": spec["evidence_id"],
		"filename": output_path.get_file(),
		"zone": spec["zone_name"],
		"description": spec["description"],
		"scene": spec["scene_path"],
		"scene_sha256": FileAccess.get_sha256(spec["scene_path"]),
		"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
		"player_position_xy": null if player_position == NO_PLAYER else [player_position.x, player_position.y],
		"dimensions": [capture_size.x, capture_size.y],
		"sha256": FileAccess.get_sha256(output_path),
	}


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == name:
			return arguments[index + 1]
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
