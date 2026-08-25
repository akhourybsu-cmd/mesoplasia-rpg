extends SceneTree

const ZONE_SCENE := preload("res://scenes/world/caden/WayfarersApproach.tscn")
const FULL_ZONE_OUTPUT := "res://docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_full_zone.png"
const GAMEPLAY_OUTPUT := "res://docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_gameplay_640x360.png"
const DISPLAY_OUTPUT := "res://docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_display_1280x720.png"


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FULL_ZONE_OUTPUT.get_base_dir()))
	var full_zone := await _capture(Vector2i(1024, 640), Vector2.ZERO, false)
	if full_zone == null:
		_fail("The active rendering driver did not provide a viewport texture.")
		return
	var result := full_zone.save_png(ProjectSettings.globalize_path(FULL_ZONE_OUTPUT))
	if result != OK:
		_fail("Unable to save full-zone preview: %s" % error_string(result))
		return

	var gameplay := await _capture(Vector2i(640, 360), Vector2(512, 320), true)
	if gameplay == null:
		_fail("The active rendering driver did not provide the gameplay viewport texture.")
		return
	result = gameplay.save_png(ProjectSettings.globalize_path(GAMEPLAY_OUTPUT))
	if result != OK:
		_fail("Unable to save gameplay preview: %s" % error_string(result))
		return
	var display := gameplay.duplicate()
	display.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	result = display.save_png(ProjectSettings.globalize_path(DISPLAY_OUTPUT))
	if result != OK:
		_fail("Unable to save 2x display preview: %s" % error_string(result))
		return
	print("full_zone=%s" % FULL_ZONE_OUTPUT)
	print("gameplay=%s" % GAMEPLAY_OUTPUT)
	print("display=%s" % DISPLAY_OUTPUT)
	quit(0)


func _capture(size: Vector2i, camera_position: Vector2, use_camera: bool) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	viewport.add_child(ZONE_SCENE.instantiate())
	if use_camera:
		var camera := Camera2D.new()
		camera.position = camera_position
		camera.enabled = true
		viewport.add_child(camera)
	await process_frame
	await process_frame
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
