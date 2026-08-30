extends "res://tools/art/render_caden_commons_terrain_gate_v1_2.gd"

const RUNTIME_ACTIVE_TERRAIN_PATH := "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png"
const RUNTIME_ACTIVE_MANIFEST_PATH := "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.json"
const RUNTIME_ROLLBACK_TERRAIN_PATH := "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png"
const RUNTIME_RENDER_TOOL_PATH := "res://tools/art/render_caden_commons_terrain_runtime_v1_2.gd"


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var terrain_manifest := _load_external_json(ProjectSettings.globalize_path(RUNTIME_ACTIVE_MANIFEST_PATH))
	if terrain_manifest.get("gate_state", "") != "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
		_fail("Unexpected active Commons terrain gate state.")
		return
	if FileAccess.get_sha256(RUNTIME_ACTIVE_TERRAIN_PATH) != terrain_manifest.get("output_sha256", ""):
		_fail("Active Commons terrain runtime hash mismatch.")
		return
	var rollback_image := Image.load_from_file(ProjectSettings.globalize_path(RUNTIME_ROLLBACK_TERRAIN_PATH))
	if rollback_image == null or rollback_image.get_size() != FULL_ZONE_SIZE:
		_fail("Unable to load the Commons rollback terrain.")
		return
	_candidate_texture = ImageTexture.create_from_image(rollback_image)

	var active_scene := ZONE_SCENE.instantiate()
	var active_texture := (active_scene.get_node("TerrainRuntime") as Sprite2D).texture
	if active_texture == null or active_texture.resource_path != RUNTIME_ACTIVE_TERRAIN_PATH:
		active_scene.free()
		_fail("Serialized Commons scene does not use the approved v1.2 pilot runtime.")
		return
	active_scene.free()

	var capture_root := _output_root.path_join("raw_captures")
	var make_directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if make_directory_result != OK:
		_fail("Unable to create %s: %s" % [capture_root, error_string(make_directory_result)])
		return
	var specs: Array[Dictionary] = [
		_comparison_spec("commons_terrain_full_before_v1_2_1024x704", true, Vector2(512, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Rollback v1 terrain in transient before instance"),
		_comparison_spec("commons_terrain_full_after_v1_2_1024x704", false, Vector2(512, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Active v1.2 terrain from serialized scene"),
		_comparison_spec("commons_terrain_west_before_v1_2_640x360", true, Vector2(320, 352), Vector2(128, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Town Square arrival before"),
		_comparison_spec("commons_terrain_west_after_v1_2_640x360", false, Vector2(320, 352), Vector2(128, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Town Square arrival after"),
		_comparison_spec("commons_terrain_north_before_v1_2_640x360", true, Vector2(512, 256), Vector2(512, 128), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Residential arrival before"),
		_comparison_spec("commons_terrain_north_after_v1_2_640x360", false, Vector2(512, 256), Vector2(512, 128), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Residential arrival after"),
		_comparison_spec("commons_terrain_junction_before_v1_2_640x360", true, Vector2(512, 352), Vector2(512, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route junction and Player before"),
		_comparison_spec("commons_terrain_junction_after_v1_2_640x360", false, Vector2(512, 352), Vector2(512, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route junction and Player after"),
		_comparison_spec("commons_terrain_quiet_green_before_v1_2_640x360", true, Vector2(704, 352), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Quiet Green and rest pocket before"),
		_comparison_spec("commons_terrain_quiet_green_after_v1_2_640x360", false, Vector2(704, 352), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Quiet Green and rest pocket after"),
		_comparison_spec("commons_terrain_south_before_v1_2_640x360", true, Vector2(512, 524), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Southern planted boundary before"),
		_comparison_spec("commons_terrain_south_after_v1_2_640x360", false, Vector2(512, 524), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Southern planted boundary after"),
		_comparison_spec("commons_terrain_junction_after_display_v1_2_1280x720", false, Vector2(512, 352), Vector2(512, 352), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x active junction view"),
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
		captures.append(_runtime_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var manifest := {
		"schema": "caden-commons-terrain-runtime-v1.2-render",
		"gate_state": "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval",
		"scope": "Active serialized Commons terrain pilot with transient v1 rollback views for matched comparison.",
		"scene": "res://scenes/world/caden/Commons.tscn",
		"scene_sha256": FileAccess.get_sha256("res://scenes/world/caden/Commons.tscn"),
		"active_terrain_path": RUNTIME_ACTIVE_TERRAIN_PATH,
		"active_terrain_sha256": terrain_manifest.get("output_sha256", ""),
		"rollback_terrain_path": RUNTIME_ROLLBACK_TERRAIN_PATH,
		"rollback_terrain_sha256": FileAccess.get_sha256(RUNTIME_ROLLBACK_TERRAIN_PATH),
		"terrain_manifest_sha256": FileAccess.get_sha256(RUNTIME_ACTIVE_MANIFEST_PATH),
		"renderer": "Compatibility",
		"render_tool": RUNTIME_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RUNTIME_RENDER_TOOL_PATH),
		"zone_dimensions": [FULL_ZONE_SIZE.x, FULL_ZONE_SIZE.y],
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"population": {"dialogue_npcs": 1, "ambient_walkers": 2, "total_visible_npcs": 3},
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("commons_terrain_runtime_render_manifest_v1_2.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create active Commons terrain render manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _runtime_manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"state": "before_rollback_override" if spec["candidate"] else "after_active_serialized_scene",
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": _vector_to_array(spec["camera_center"]),
		"player_position_xy": null if player_position == NO_PLAYER else _vector_to_array(player_position),
		"sha256": FileAccess.get_sha256(output_path),
	}
