extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const OUTPUT_PATH := "res://docs/art/previews/caden_town_square_runtime_v2_gameplay_preview.png"
const CAPTURE_SIZE := Vector2i(960, 704)


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	viewport.add_child(TOWN_SQUARE_SCENE.instantiate())
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if result != OK:
		push_error("Unable to save Town Square runtime preview: %s" % error_string(result))
		quit(1)
		return
	print("rendered=%s" % OUTPUT_PATH)
	quit(0)
