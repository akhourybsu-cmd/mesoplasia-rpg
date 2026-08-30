extends "res://tools/art/render_caden_town_square_protected_gate_v1_2.gd"

const TONAL_PREP_TOOL_PATH := "res://tools/art/prepare_caden_town_square_tonal_terrain_gate_v1_3.py"
const TONAL_RENDER_TOOL_PATH := "res://tools/art/render_caden_town_square_tonal_terrain_gate_v1_3.gd"
const RUNTIME_V3_MANIFEST_PATH := "res://assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"


func _render() -> void:
	_output_root = _argument_value("--output-root")
	_prep_root = _argument_value("--prep-root")
	var project_root := ProjectSettings.globalize_path("res://")
	if _output_root.is_empty() or _output_root.begins_with(project_root):
		_fail("An absolute --output-root outside res:// is required.")
		return
	if _prep_root.is_empty() or _prep_root.begins_with(project_root):
		_fail("An absolute --prep-root outside res:// is required.")
		return
	var prep_manifest_path := _prep_root.path_join("metadata/town_square_tonal_terrain_preparation_v1_3.json")
	var prep_manifest := _load_external_json(prep_manifest_path)
	if prep_manifest.get("gate_state", "") != "inactive_town_square_tonal_terrain_comparison":
		_fail("Unexpected Town Square tonal terrain gate state.")
		return
	if prep_manifest.get("generator_sha256", "") != FileAccess.get_sha256(TONAL_PREP_TOOL_PATH):
		_fail("Tonal terrain preparation tool changed after candidate generation.")
		return
	if prep_manifest.get("scene_sha256", "") != FileAccess.get_sha256(SCENE_PATH):
		_fail("Town Square changed after tonal terrain preparation.")
		return
	var runtime_v3 := _load_external_json(ProjectSettings.globalize_path(RUNTIME_V3_MANIFEST_PATH))
	if runtime_v3.get("gate_state", "") != "town_square_architecture_runtime_v3_visual_approved":
		_fail("Town Square Runtime v3 architecture is not active and approved.")
		return
	var candidate_path := _prep_root.path_join(prep_manifest.get("candidate_path", ""))
	if FileAccess.get_sha256(candidate_path) != prep_manifest.get("candidate_sha256", ""):
		_fail("Tonal terrain candidate hash mismatch.")
		return
	var candidate_image := Image.load_from_file(candidate_path)
	if candidate_image == null or candidate_image.get_size() != Vector2i(256, 256):
		_fail("Tonal terrain candidate dimensions are invalid.")
		return
	_terrain_texture = ImageTexture.create_from_image(candidate_image)
	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create tonal terrain capture directory: %s" % error_string(directory_result))
		return
	var specs: Array[Dictionary] = [
		_spec("town_square_tonal_full_current_v1_3_960x704", false, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full active Runtime v3 with terrain v1.1"),
		_spec("town_square_tonal_full_candidate_v1_3_960x704", true, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full transient tonal terrain candidate"),
		_spec("town_square_tonal_plaza_current_v1_3_640x360", false, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current plaza and Player"),
		_spec("town_square_tonal_plaza_candidate_v1_3_640x360", true, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Tonal plaza and Player"),
		_spec("town_square_tonal_north_current_v1_3_640x360", false, false, Vector2(480, 180), Vector2(480, 160), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current Marketplace arrival"),
		_spec("town_square_tonal_north_candidate_v1_3_640x360", true, false, Vector2(480, 180), Vector2(480, 160), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Tonal Marketplace arrival"),
		_spec("town_square_tonal_west_current_v1_3_640x360", false, false, Vector2(320, 352), Vector2(160, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current Wayfarer arrival"),
		_spec("town_square_tonal_west_candidate_v1_3_640x360", true, false, Vector2(320, 352), Vector2(160, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Tonal Wayfarer arrival"),
		_spec("town_square_tonal_south_current_v1_3_640x360", false, false, Vector2(480, 524), Vector2(480, 544), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current Commons arrival"),
		_spec("town_square_tonal_south_candidate_v1_3_640x360", true, false, Vector2(480, 524), Vector2(480, 544), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Tonal Commons arrival"),
		_spec("town_square_tonal_east_current_v1_3_640x360", false, false, Vector2(640, 352), Vector2(800, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current Residential arrival"),
		_spec("town_square_tonal_east_candidate_v1_3_640x360", true, false, Vector2(640, 352), Vector2(800, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Tonal Residential arrival"),
		_spec("town_square_tonal_plaza_candidate_display_v1_3_1280x720", true, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x tonal plaza"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Tonal terrain capture failed: %s" % spec["name"])
			return
		var output_size: Vector2i = spec["output_size"]
		if image.get_size() != output_size:
			image.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var result := image.save_png(output_path)
		if result != OK:
			_fail("Unable to save tonal terrain capture: %s" % error_string(result))
			return
		captures.append(_capture_record(spec, output_path))
		print("capture=%s" % output_path)
	var manifest := {
		"schema": "caden-town-square-tonal-terrain-gate-v1.3-render",
		"gate_state": "inactive_town_square_tonal_terrain_comparison",
		"scope": "Transient topology-identical tonal terrain comparison with active Runtime v3 architecture.",
		"scene": SCENE_PATH,
		"scene_sha256": FileAccess.get_sha256(SCENE_PATH),
		"preparation_manifest_sha256": FileAccess.get_sha256(prep_manifest_path),
		"candidate_sha256": prep_manifest.get("candidate_sha256", ""),
		"active_tileset": ACTIVE_TILESET_PATH,
		"active_reference_changed": false,
		"renderer": "Compatibility",
		"render_tool": TONAL_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(TONAL_RENDER_TOOL_PATH),
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("town_square_tonal_terrain_render_manifest_v1_3.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_fail("Unable to create tonal terrain render manifest.")
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("manifest=%s" % manifest_path)
	quit(0)
