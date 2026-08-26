extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const OUTPUT_ROOT := "res://docs/art/previews/wayfarers_approach/pilot_v1"
const CAPTURE_SIZE := Vector2i(640, 360)
const NO_PLAYER := Vector2(-10000, -10000)


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var specs := [
		{"name": "grass_before_640x360", "camera": Vector2(704, 460), "pilot": false, "player": NO_PLAYER},
		{"name": "grass_after_640x360", "camera": Vector2(704, 460), "pilot": true, "player": NO_PLAYER},
		{"name": "road_before_640x360", "camera": Vector2(640, 390), "pilot": false, "player": NO_PLAYER},
		{"name": "road_after_640x360", "camera": Vector2(640, 390), "pilot": true, "player": NO_PLAYER},
		{"name": "bench_player_behind_640x360", "camera": Vector2(704, 460), "pilot": true, "player": Vector2(880, 516)},
		{"name": "bench_player_front_640x360", "camera": Vector2(704, 460), "pilot": true, "player": Vector2(880, 578)},
		{"name": "rail_player_behind_640x360", "camera": Vector2(640, 390), "pilot": true, "player": Vector2(700, 462)},
		{"name": "rail_player_front_640x360", "camera": Vector2(640, 390), "pilot": true, "player": Vector2(700, 526)},
	]
	for spec: Dictionary in specs:
		var image := await _capture(spec["camera"], spec["pilot"], spec["player"])
		if image == null:
			_fail("Viewport capture failed for %s." % spec["name"])
			return
		var output_path := "%s/%s.png" % [OUTPUT_ROOT, spec["name"]]
		var result := image.save_png(ProjectSettings.globalize_path(output_path))
		if result != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(result)])
			return
		print("capture=%s" % output_path)
	quit(0)


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

	var player: CharacterBody2D
	if player_position != NO_PLAYER:
		player = PLAYER_SCENE.instantiate() as CharacterBody2D
		player.position = player_position
		player.z_index = 10
		(player.get_node("Camera2D") as Camera2D).enabled = false
		viewport.add_child(player)

	var camera := Camera2D.new()
	camera.position = camera_position
	camera.enabled = true
	viewport.add_child(camera)
	await process_frame
	await process_frame
	await process_frame
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
