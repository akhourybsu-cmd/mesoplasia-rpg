extends "res://tools/art/render_caden_town_square_protected_gate_v1_2.gd"

const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"
const RUNTIME_RENDER_TOOL_PATH := "res://tools/art/render_caden_town_square_architecture_runtime_v3.gd"


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var runtime_manifest := _load_external_json(ProjectSettings.globalize_path(RUNTIME_MANIFEST_PATH))
	if runtime_manifest.get("gate_state", "") != "town_square_architecture_runtime_v3_visual_approved":
		_fail("Unexpected Town Square Runtime v3 approval state.")
		return
	if (runtime_manifest.get("terrain_decision", {}) as Dictionary).get("status", "") != "retained_unchanged":
		_fail("Town Square terrain is not recorded as retained.")
		return
	var scene := TOWN_SQUARE_SCENE.instantiate()
	for slot: String in (runtime_manifest.get("generated_buildings", {}) as Dictionary):
		var record: Dictionary = runtime_manifest["generated_buildings"][slot]
		var texture_path := "res://" + String(record["path"])
		if FileAccess.get_sha256(texture_path) != record["sha256"]:
			scene.free()
			_fail("Runtime v3 texture identity mismatch: %s" % slot)
			return
		var sprite := scene.get_node(String(record["target_node"]) + "/ExteriorSprite") as Sprite2D
		var offset: Array = record["sprite_offset_xy"]
		if sprite.texture == null or sprite.texture.resource_path != texture_path or sprite.position != Vector2(offset[0], offset[1]):
			scene.free()
			_fail("Serialized Runtime v3 scene wiring mismatch: %s" % slot)
			return
	for layer_node: Node in scene.get_node("TerrainLayers").find_children("*", "TileMapLayer", true, false):
		if (layer_node as TileMapLayer).tile_set.resource_path != ACTIVE_TILESET_PATH:
			scene.free()
			_fail("Town Square terrain changed during Runtime v3 activation.")
			return
	scene.free()

	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create capture directory: %s" % error_string(directory_result))
		return
	var specs: Array[Dictionary] = [
		_spec("town_square_runtime_v3_full_960x704", false, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Active serialized Runtime v3 full scene"),
		_spec("town_square_runtime_v3_northwest_640x360", false, false, Vector2(224, 180), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active serialized northwest frontage"),
		_spec("town_square_runtime_v3_south_640x360", false, false, Vector2(480, 524), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active serialized south edge"),
		_spec("town_square_runtime_v3_doorway_640x360", false, false, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active serialized doorway overlap"),
		_spec("town_square_runtime_v3_east_640x360", false, false, Vector2(736, 352), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active serialized east corridor"),
		_spec("town_square_runtime_v3_doorway_display_1280x720", false, false, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x active doorway view"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Viewport capture failed: %s" % spec["name"])
			return
		var output_size: Vector2i = spec["output_size"]
		if image.get_size() != output_size:
			image.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var save_result := image.save_png(output_path)
		if save_result != OK:
			_fail("Unable to save capture: %s" % error_string(save_result))
			return
		captures.append(_capture_record(spec, output_path))
		print("capture=%s" % output_path)
	var render_manifest := {
		"schema": "caden-town-square-architecture-runtime-v3-render",
		"gate_state": "town_square_architecture_runtime_v3_visual_approved",
		"scope": "Active serialized Runtime v3 architecture with retained Terrain Runtime v1.1.",
		"scene": SCENE_PATH,
		"scene_sha256": FileAccess.get_sha256(SCENE_PATH),
		"runtime_manifest": RUNTIME_MANIFEST_PATH,
		"runtime_manifest_sha256": FileAccess.get_sha256(RUNTIME_MANIFEST_PATH),
		"active_tileset": ACTIVE_TILESET_PATH,
		"renderer": "Compatibility",
		"render_tool": RUNTIME_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RUNTIME_RENDER_TOOL_PATH),
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("town_square_architecture_runtime_v3_render_manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create Runtime v3 render manifest.")
		return
	manifest_file.store_string(JSON.stringify(render_manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)
