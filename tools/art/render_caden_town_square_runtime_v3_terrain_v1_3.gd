extends "res://tools/art/render_caden_town_square_protected_gate_v1_2.gd"

const TERRAIN_MANIFEST_PATH := "res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.json"
const ARCHITECTURE_MANIFEST_PATH := "res://assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"
const ACTIVE_TERRAIN_TILESET_PATH := "res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.tres"
const ACTIVE_RENDER_TOOL_PATH := "res://tools/art/render_caden_town_square_runtime_v3_terrain_v1_3.gd"


func _render() -> void:
	_output_root = _argument_value("--output-root")
	if _output_root.is_empty() or _output_root.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("An absolute --output-root outside res:// is required.")
		return
	var terrain_manifest := _load_external_json(ProjectSettings.globalize_path(TERRAIN_MANIFEST_PATH))
	var architecture_manifest := _load_external_json(ProjectSettings.globalize_path(ARCHITECTURE_MANIFEST_PATH))
	if terrain_manifest.get("gate_state", "") != "town_square_tonal_terrain_runtime_v1_3_visual_approved":
		_fail("Town Square Terrain Runtime v1.3 is not approved.")
		return
	if architecture_manifest.get("gate_state", "") != "town_square_architecture_runtime_v3_visual_approved":
		_fail("Town Square Architecture Runtime v3 is not approved.")
		return
	var scene := TOWN_SQUARE_SCENE.instantiate()
	for layer_node: Node in scene.get_node("TerrainLayers").find_children("*", "TileMapLayer", true, false):
		if (layer_node as TileMapLayer).tile_set.resource_path != ACTIVE_TERRAIN_TILESET_PATH:
			scene.free()
			_fail("Serialized Town Square does not use Terrain Runtime v1.3.")
			return
	for slot: String in (architecture_manifest.get("generated_buildings", {}) as Dictionary):
		var record: Dictionary = architecture_manifest["generated_buildings"][slot]
		var sprite := scene.get_node(String(record["target_node"]) + "/ExteriorSprite") as Sprite2D
		if sprite.texture == null or sprite.texture.resource_path != "res://" + String(record["path"]):
			scene.free()
			_fail("Serialized Town Square does not use Architecture Runtime v3: %s" % slot)
			return
	scene.free()
	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create active Town Square capture directory: %s" % error_string(directory_result))
		return
	var specs: Array[Dictionary] = [
		_spec("town_square_active_v3_v1_3_full_960x704", false, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Active full Town Square"),
		_spec("town_square_active_v3_v1_3_plaza_640x360", false, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active central plaza"),
		_spec("town_square_active_v3_v1_3_north_640x360", false, false, Vector2(480, 180), Vector2(480, 160), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active Marketplace arrival"),
		_spec("town_square_active_v3_v1_3_west_640x360", false, false, Vector2(320, 352), Vector2(160, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active Wayfarer arrival"),
		_spec("town_square_active_v3_v1_3_south_640x360", false, false, Vector2(480, 524), Vector2(480, 544), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active Commons arrival"),
		_spec("town_square_active_v3_v1_3_east_640x360", false, false, Vector2(640, 352), Vector2(800, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Active Residential arrival"),
		_spec("town_square_active_v3_v1_3_plaza_display_1280x720", false, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x active plaza"),
	]
	var captures: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var image := await _capture(spec)
		if image == null:
			_fail("Active Town Square capture failed: %s" % spec["name"])
			return
		var output_size: Vector2i = spec["output_size"]
		if image.get_size() != output_size:
			image.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := capture_root.path_join("%s.png" % spec["name"])
		var result := image.save_png(output_path)
		if result != OK:
			_fail("Unable to save active Town Square capture: %s" % error_string(result))
			return
		captures.append(_capture_record(spec, output_path))
		print("capture=%s" % output_path)
	var manifest := {
		"schema": "caden-town-square-runtime-v3-terrain-v1.3-render",
		"gate_state": "town_square_runtime_v3_terrain_v1_3_active_verified",
		"scene": SCENE_PATH,
		"scene_sha256": FileAccess.get_sha256(SCENE_PATH),
		"architecture_manifest_sha256": FileAccess.get_sha256(ARCHITECTURE_MANIFEST_PATH),
		"terrain_manifest_sha256": FileAccess.get_sha256(TERRAIN_MANIFEST_PATH),
		"renderer": "Compatibility",
		"render_tool": ACTIVE_RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(ACTIVE_RENDER_TOOL_PATH),
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("town_square_runtime_v3_terrain_v1_3_render_manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_fail("Unable to create active Town Square render manifest.")
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("manifest=%s" % manifest_path)
	quit(0)
