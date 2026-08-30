extends "res://tools/art/render_caden_residential_terrain_gate_v1_2.gd"

const ACTIVE_TERRAIN_MANIFEST_PATH := "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.json"
const PREVIOUS_TERRAIN_PATH := "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
const ACTIVE_RENDER_TOOL_PATH := "res://tools/art/render_caden_residential_terrain_runtime_v1_2.gd"


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var terrain_manifest := _load_json(ACTIVE_TERRAIN_MANIFEST_PATH)
	if terrain_manifest.get("gate_state", "") != "residential_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
		_fail("Unexpected active Residential terrain gate state.")
		return
	var runtime_path := "res://%s" % terrain_manifest.get("output_path", "")
	if FileAccess.get_sha256(runtime_path) != terrain_manifest.get("output_sha256", ""):
		_fail("Active Residential terrain runtime hash mismatch.")
		return
	var previous_image := Image.load_from_file(ProjectSettings.globalize_path(PREVIOUS_TERRAIN_PATH))
	if previous_image == null or previous_image.get_size() != FULL_ZONE_SIZE:
		_fail("Unable to load the rollback terrain for before captures.")
		return
	_candidate_texture = ImageTexture.create_from_image(previous_image)

	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create %s: %s" % [capture_root, error_string(directory_result)])
		return
	var specs: Array[Dictionary] = [
		_spec("residential_terrain_full_before_v1_2_1152x768", true, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Rollback v1 terrain in transient before instance"),
		_spec("residential_terrain_full_after_v1_2_1152x768", false, Vector2(576, 384), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Active v1.2 terrain from serialized scene"),
		_spec("residential_terrain_north_before_v1_2_640x360", true, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North homes before"),
		_spec("residential_terrain_north_after_v1_2_640x360", false, Vector2(576, 208), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "North homes after"),
		_spec("residential_terrain_south_before_v1_2_640x360", true, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South homes before"),
		_spec("residential_terrain_south_after_v1_2_640x360", false, Vector2(576, 592), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "South homes after"),
		_spec("residential_terrain_primary_before_v1_2_640x360", true, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route and player before"),
		_spec("residential_terrain_primary_after_v1_2_640x360", false, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Primary route and player after"),
		_spec("residential_terrain_west_before_v1_2_640x360", true, Vector2(320, 384), Vector2(128, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "West arrival before"),
		_spec("residential_terrain_west_after_v1_2_640x360", false, Vector2(320, 384), Vector2(128, 384), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "West arrival after"),
		_spec("residential_terrain_commons_before_v1_2_640x360", true, Vector2(576, 588), Vector2(576, 640), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Commons transition before"),
		_spec("residential_terrain_commons_after_v1_2_640x360", false, Vector2(576, 588), Vector2(576, 640), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Commons transition after"),
		_spec("residential_terrain_primary_after_display_v1_2_1280x720", false, Vector2(576, 384), Vector2(576, 384), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x active primary view"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
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
		captures.append(_active_manifest_entry(spec, output_path))
		print("capture=%s" % output_path)

	var active_scene := ZONE_SCENE.instantiate()
	var active_scene_texture := (active_scene.get_node("TerrainRuntime") as Sprite2D).texture
	if active_scene_texture == null or active_scene_texture.resource_path != runtime_path:
		active_scene.free()
		_fail("Serialized Residential scene does not use the approved v1.2 runtime.")
		return
	active_scene.free()
	var manifest := {
		"schema": "caden-residential-terrain-runtime-v1.2-render",
		"gate_state": "residential_terrain_runtime_v1_2_active_pilot_pending_visual_approval",
		"scope": "Active serialized Residential terrain pilot with transient v1 rollback views for matched comparison.",
		"scene": "res://scenes/world/caden/Residential.tscn",
		"scene_sha256": FileAccess.get_sha256("res://scenes/world/caden/Residential.tscn"),
		"active_terrain_path": runtime_path,
		"active_terrain_sha256": terrain_manifest.get("output_sha256", ""),
		"rollback_terrain_path": PREVIOUS_TERRAIN_PATH,
		"rollback_terrain_sha256": FileAccess.get_sha256(PREVIOUS_TERRAIN_PATH),
		"terrain_manifest_sha256": FileAccess.get_sha256(ACTIVE_TERRAIN_MANIFEST_PATH),
		"renderer": "Compatibility",
		"render_tool": ACTIVE_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(ACTIVE_RENDER_TOOL_PATH),
		"zone_dimensions": [FULL_ZONE_SIZE.x, FULL_ZONE_SIZE.y],
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"population": {"dialogue_npcs": 2, "ambient_walkers": 5, "total_visible_npcs": 7},
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("residential_terrain_runtime_render_manifest_v1_2.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create runtime render manifest.")
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _active_manifest_entry(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"state": "before_rollback_override" if spec["candidate"] else "after_active_serialized_scene",
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
		"player_position_xy": null if player_position == NO_PLAYER else [player_position.x, player_position.y],
		"sha256": FileAccess.get_sha256(output_path),
	}
