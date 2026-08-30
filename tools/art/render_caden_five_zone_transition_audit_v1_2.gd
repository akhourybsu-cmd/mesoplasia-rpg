extends SceneTree

const WAYFARER_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const MARKETPLACE_SCENE := preload("res://scenes/world/caden/Marketplace.tscn")
const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const RESIDENTIAL_SCENE := preload("res://scenes/world/caden/Residential.tscn")
const COMMONS_SCENE := preload("res://scenes/world/caden/Commons.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const RENDER_TOOL_PATH := "res://tools/art/render_caden_five_zone_transition_audit_v1_2.gd"
const CAPTURE_SIZE := Vector2i(640, 360)

var _output_root := ""


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create transition capture directory: %s" % error_string(directory_result))
		return
	var specs: Array[Dictionary] = [
		_spec(1, "wayfarer_from_marketplace", WAYFARER_SCENE, "res://scenes/world/caden/WayfarersApproach.tscn", Vector2(512, 180), Vector2(512, 128), "Wayfarer arrival from Marketplace"),
		_spec(2, "marketplace_from_wayfarer", MARKETPLACE_SCENE, "res://scenes/world/caden/Marketplace.tscn", Vector2(320, 320), Vector2(128, 320), "Marketplace arrival from Wayfarer"),
		_spec(3, "wayfarer_from_town_square", WAYFARER_SCENE, "res://scenes/world/caden/WayfarersApproach.tscn", Vector2(704, 320), Vector2(864, 320), "Wayfarer arrival from Town Square"),
		_spec(4, "town_square_from_wayfarer", TOWN_SQUARE_SCENE, "res://scenes/world/caden/TownSquare.tscn", Vector2(320, 352), Vector2(160, 352), "Town Square arrival from Wayfarer"),
		_spec(5, "town_square_from_marketplace", TOWN_SQUARE_SCENE, "res://scenes/world/caden/TownSquare.tscn", Vector2(480, 180), Vector2(480, 160), "Town Square arrival from Marketplace"),
		_spec(6, "marketplace_from_town_square", MARKETPLACE_SCENE, "res://scenes/world/caden/Marketplace.tscn", Vector2(448, 460), Vector2(448, 512), "Marketplace arrival from Town Square"),
		_spec(7, "town_square_from_residential", TOWN_SQUARE_SCENE, "res://scenes/world/caden/TownSquare.tscn", Vector2(640, 352), Vector2(800, 352), "Town Square arrival from Residential"),
		_spec(8, "residential_from_town_square", RESIDENTIAL_SCENE, "res://scenes/world/caden/Residential.tscn", Vector2(320, 384), Vector2(128, 384), "Residential arrival from Town Square"),
		_spec(9, "town_square_from_commons", TOWN_SQUARE_SCENE, "res://scenes/world/caden/TownSquare.tscn", Vector2(480, 524), Vector2(480, 544), "Town Square arrival from Commons"),
		_spec(10, "commons_from_town_square", COMMONS_SCENE, "res://scenes/world/caden/Commons.tscn", Vector2(320, 352), Vector2(128, 352), "Commons arrival from Town Square"),
		_spec(11, "residential_from_commons", RESIDENTIAL_SCENE, "res://scenes/world/caden/Residential.tscn", Vector2(576, 588), Vector2(576, 640), "Residential arrival from Commons"),
		_spec(12, "commons_from_residential", COMMONS_SCENE, "res://scenes/world/caden/Commons.tscn", Vector2(512, 180), Vector2(512, 128), "Commons arrival from Residential"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Transition capture failed: %s" % spec["name"])
			return
		var output_path := capture_root.path_join("%02d_%s_640x360.png" % [spec["evidence_id"], spec["name"]])
		var result := image.save_png(output_path)
		if result != OK:
			_fail("Unable to save transition capture: %s" % error_string(result))
			return
		captures.append({
			"evidence_id": spec["evidence_id"],
			"filename": output_path.get_file(),
			"description": spec["description"],
			"scene": spec["scene_path"],
			"scene_sha256": FileAccess.get_sha256(spec["scene_path"]),
			"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
			"entry_position_xy": [spec["player_position"].x, spec["player_position"].y],
			"dimensions": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
			"sha256": FileAccess.get_sha256(output_path),
		})
		print("capture=%s" % output_path)
	var manifest := {
		"schema": "caden-five-zone-transition-audit-v1.2-render",
		"gate_state": "five_zone_transition_visual_audit",
		"scope": "Both arrival sides of all six live bidirectional Caden connections.",
		"renderer": "Compatibility",
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"capture_dimensions": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"connection_pairs": [
			[1, 2, "Wayfarer - Marketplace"],
			[3, 4, "Wayfarer - Town Square"],
			[5, 6, "Town Square - Marketplace"],
			[7, 8, "Town Square - Residential"],
			[9, 10, "Town Square - Commons"],
			[11, 12, "Residential - Commons"],
		],
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("caden_five_zone_transition_render_manifest_v1_2.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_fail("Unable to create transition render manifest.")
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _spec(evidence_id: int, name: String, scene: PackedScene, scene_path: String, camera_center: Vector2, player_position: Vector2, description: String) -> Dictionary:
	return {"evidence_id": evidence_id, "name": name, "scene": scene, "scene_path": scene_path, "camera_center": camera_center, "player_position": player_position, "description": description}


func _capture(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
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


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == name:
			return arguments[index + 1]
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
