extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PREP_TOOL_PATH := "res://tools/art/prepare_caden_town_square_protected_gate_v1_2.py"
const RENDER_TOOL_PATH := "res://tools/art/render_caden_town_square_protected_gate_v1_2.gd"
const SCENE_PATH := "res://scenes/world/caden/TownSquare.tscn"
const ACTIVE_TILESET_PATH := "res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres"
const GAMEPLAY_SIZE := Vector2i(640, 360)
const FULL_ZONE_SIZE := Vector2i(960, 704)
const DISPLAY_SIZE := Vector2i(1280, 720)
const NO_PLAYER := Vector2(-100000.0, -100000.0)

var _output_root := ""
var _prep_root := ""
var _prep_manifest: Dictionary
var _terrain_texture: Texture2D
var _building_textures: Dictionary = {}


func _initialize() -> void:
	_render.call_deferred()


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
	var prep_manifest_path := _prep_root.path_join("metadata/town_square_protected_preparation_manifest_v1_2.json")
	_prep_manifest = _load_external_json(prep_manifest_path)
	if _prep_manifest.get("gate_state", "") != "inactive_town_square_terrain_architecture_comparison":
		_fail("Unexpected Town Square preparation gate state.")
		return
	if _prep_manifest.get("generator_sha256", "") != FileAccess.get_sha256(PREP_TOOL_PATH):
		_fail("Town Square preparation tool changed after candidate generation.")
		return
	if _prep_manifest.get("scene_sha256", "") != FileAccess.get_sha256(SCENE_PATH):
		_fail("Town Square scene changed after candidate generation.")
		return
	var terrain_record: Dictionary = _prep_manifest.get("terrain_candidate", {})
	var terrain_path := _prep_root.path_join(terrain_record.get("path", ""))
	if FileAccess.get_sha256(terrain_path) != terrain_record.get("sha256", ""):
		_fail("Town Square terrain candidate hash mismatch.")
		return
	var terrain_image := Image.load_from_file(terrain_path)
	if terrain_image == null or terrain_image.get_size() != Vector2i(256, 256):
		_fail("Town Square terrain candidate dimensions are invalid.")
		return
	_terrain_texture = ImageTexture.create_from_image(terrain_image)
	for record: Dictionary in _prep_manifest.get("building_candidates", []):
		var candidate_path := _prep_root.path_join(record.get("runtime_path", ""))
		if FileAccess.get_sha256(candidate_path) != record.get("runtime_sha256", ""):
			_fail("Town Square building candidate hash mismatch: %s" % record.get("source_id", "unknown"))
			return
		var image := Image.load_from_file(candidate_path)
		if image == null or image.get_size() != Vector2i(record["runtime_dimensions"][0], record["runtime_dimensions"][1]):
			_fail("Town Square building candidate dimensions are invalid: %s" % record.get("source_id", "unknown"))
			return
		_building_textures[record.get("slot", "")] = ImageTexture.create_from_image(image)

	var active_scene := TOWN_SQUARE_SCENE.instantiate()
	for layer_node: Node in active_scene.get_node("TerrainLayers").find_children("*", "TileMapLayer", true, false):
		var layer := layer_node as TileMapLayer
		if layer.tile_set == null or layer.tile_set.resource_path != ACTIVE_TILESET_PATH:
			active_scene.free()
			_fail("Serialized Town Square terrain no longer uses Runtime v1.1.")
			return
	active_scene.free()

	var capture_root := _output_root.path_join("raw_captures")
	var directory_result := DirAccess.make_dir_recursive_absolute(capture_root)
	if directory_result != OK:
		_fail("Unable to create capture directory: %s" % error_string(directory_result))
		return
	var specs: Array[Dictionary] = [
		_spec("town_square_full_current_v1_2_960x704", false, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full current protected scene"),
		_spec("town_square_full_terrain_v1_2_960x704", true, false, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full transient terrain-only candidate"),
		_spec("town_square_full_architecture_v1_2_960x704", false, true, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full transient architecture-only candidate"),
		_spec("town_square_full_combined_v1_2_960x704", true, true, Vector2(480, 352), NO_PLAYER, FULL_ZONE_SIZE, FULL_ZONE_SIZE, "Full transient combined candidate"),
		_spec("town_square_plaza_current_v1_2_640x360", false, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current plaza and Player"),
		_spec("town_square_plaza_terrain_v1_2_640x360", true, false, Vector2(480, 352), Vector2(480, 352), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Terrain-only plaza and Player"),
		_spec("town_square_northwest_current_v1_2_640x360", false, false, Vector2(224, 180), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current northwest civic frontage"),
		_spec("town_square_northwest_architecture_v1_2_640x360", false, true, Vector2(224, 180), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Candidate northwest civic frontage"),
		_spec("town_square_south_current_v1_2_640x360", false, false, Vector2(480, 524), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current south edge architecture"),
		_spec("town_square_south_architecture_v1_2_640x360", false, true, Vector2(480, 524), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Candidate south edge architecture"),
		_spec("town_square_doorway_current_v1_2_640x360", false, false, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current doorway scale and overlap"),
		_spec("town_square_doorway_architecture_v1_2_640x360", false, true, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Architecture-only candidate doorway scale and overlap"),
		_spec("town_square_doorway_combined_v1_2_640x360", true, true, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Combined candidate doorway scale and overlap"),
		_spec("town_square_east_current_v1_2_640x360", false, false, Vector2(736, 352), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Current east corridor"),
		_spec("town_square_east_combined_v1_2_640x360", true, true, Vector2(736, 352), NO_PLAYER, GAMEPLAY_SIZE, GAMEPLAY_SIZE, "Combined candidate east corridor"),
		_spec("town_square_doorway_architecture_display_v1_2_1280x720", false, true, Vector2(224, 180), Vector2(144, 190), GAMEPLAY_SIZE, DISPLAY_SIZE, "Exact nearest-neighbor 2x architecture-only doorway view"),
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
		"schema": "caden-town-square-protected-gate-v1.2-render",
		"gate_state": "inactive_town_square_terrain_architecture_comparison",
		"scope": "Transient Town Square terrain-only, architecture-only, and combined comparisons; active scene and resources unchanged.",
		"scene": SCENE_PATH,
		"scene_sha256": FileAccess.get_sha256(SCENE_PATH),
		"active_tileset": ACTIVE_TILESET_PATH,
		"preparation_manifest_sha256": FileAccess.get_sha256(prep_manifest_path),
		"active_reference_changed": false,
		"renderer": "Compatibility",
		"render_tool": RENDER_TOOL_PATH.trim_prefix("res://"),
		"render_tool_sha256": FileAccess.get_sha256(RENDER_TOOL_PATH),
		"internal_viewport": [GAMEPLAY_SIZE.x, GAMEPLAY_SIZE.y],
		"display_viewport": [DISPLAY_SIZE.x, DISPLAY_SIZE.y],
		"captures": captures,
	}
	var manifest_path := _output_root.path_join("town_square_protected_render_manifest_v1_2.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to create Town Square render manifest.")
		return
	manifest_file.store_string(JSON.stringify(render_manifest, "  ") + "\n")
	manifest_file.close()
	print("manifest=%s" % manifest_path)
	quit(0)


func _spec(name: String, terrain: bool, architecture: bool, camera_center: Vector2, player_position: Vector2, capture_size: Vector2i, output_size: Vector2i, description: String) -> Dictionary:
	return {"name": name, "terrain": terrain, "architecture": architecture, "camera_center": camera_center, "player_position": player_position, "capture_size": capture_size, "output_size": output_size, "description": description}


func _capture(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = spec["capture_size"]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	root.add_child(viewport)
	var zone := TOWN_SQUARE_SCENE.instantiate()
	if spec["terrain"]:
		_apply_terrain_candidate(zone)
	if spec["architecture"]:
		_apply_architecture_candidates(zone)
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


func _apply_terrain_candidate(zone: Node) -> void:
	var base_layer := zone.get_node("TerrainLayers/BaseTerrainTiles") as TileMapLayer
	var candidate_tileset := base_layer.tile_set.duplicate(true) as TileSet
	var atlas_source := candidate_tileset.get_source(0) as TileSetAtlasSource
	atlas_source.texture = _terrain_texture
	for layer_node: Node in zone.get_node("TerrainLayers").find_children("*", "TileMapLayer", true, false):
		(layer_node as TileMapLayer).tile_set = candidate_tileset


func _apply_architecture_candidates(zone: Node) -> void:
	for record: Dictionary in _prep_manifest.get("building_candidates", []):
		var body := zone.get_node(record["target_node"]) as StaticBody2D
		var sprite := body.get_node("ExteriorSprite") as Sprite2D
		var runtime_dimensions: Array = record["runtime_dimensions"]
		var pivot: Array = record["pivot_xy"]
		var collision: Array = record["collision_footprint"]
		sprite.texture = _building_textures[record["slot"]]
		sprite.position = Vector2(0, float(collision[1]) / 2.0 - float(pivot[1]) + float(runtime_dimensions[1]) / 2.0)


func _capture_record(spec: Dictionary, output_path: String) -> Dictionary:
	var player_position: Vector2 = spec["player_position"]
	var capture_size: Vector2i = spec["capture_size"]
	var output_size: Vector2i = spec["output_size"]
	return {
		"filename": output_path.get_file(),
		"state": "terrain_%s_architecture_%s" % ["candidate" if spec["terrain"] else "current", "candidate" if spec["architecture"] else "current"],
		"description": spec["description"],
		"capture_dimensions": [capture_size.x, capture_size.y],
		"output_dimensions": [output_size.x, output_size.y],
		"camera_center_xy": [spec["camera_center"].x, spec["camera_center"].y],
		"player_position_xy": null if player_position == NO_PLAYER else [player_position.x, player_position.y],
		"sha256": FileAccess.get_sha256(output_path),
	}


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == name:
			return arguments[index + 1]
	return ""


func _load_external_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
