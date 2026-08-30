extends SceneTree

const STATIONARY_NPC_SCENE := preload("res://scenes/npcs/StationaryNpc.tscn")
const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const ORIGINAL_SOURCE_PATH := "res://assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png"
const ORIGINAL_SOURCE_SHA256 := "8b284d0864199b1329ac7e448bd2712e2e414aec97e446de35da8cc70c7387cd"
const REPAIRED_SOURCE_PATH := "res://assets/source_art/caden/characters/npc/caden_npc_base_master_v2.png"
const REPAIRED_SOURCE_SHA256 := "ab7e2f000f4f26ccb1a127e588da8e633259cf14f02416f396312d07cb5b9938"
const AUDIT_PATH := "res://docs/art/previews/caden_npc_base_runtime_v1/caden_npc_source_audit_v1.json"
const RUNTIME_PATH := "res://assets/characters/caden/npc/caden_npc_base_runtime_v1.png"
const RUNTIME_SHA256 := "3cba56af2257f09f6c6e7f8ba0789e93a90d0e69f18ac271421ccb1f8354840c"
const SPRITE_FRAMES_PATH := "res://assets/characters/caden/npc/caden_npc_base_sprite_frames_v1.tres"
const SQUARE_LOCAL_DIALOGUE_PATH := "res://data/dialogue/caden/square_local_resident.tres"
const VISITOR_SPRITE_FRAMES_PATH := "res://assets/characters/caden/npc/variants/human_young_woman_01/caden_npc_human_young_woman_01_sprite_frames_v1.tres"
const VISITOR_DIALOGUE_PATH := "res://data/dialogue/caden/square_passing_visitor.tres"
const SOURCE_SIZE := Vector2i(1060, 1484)
const SOURCE_CELL_SIZE := Vector2i(265, 371)
const RUNTIME_SIZE := Vector2i(160, 224)
const RUNTIME_CELL_SIZE := Vector2i(40, 56)
const ZONE_SCENES := [
	preload("res://scenes/world/caden/WayfarersApproach.tscn"),
	preload("res://scenes/world/caden/Marketplace.tscn"),
	preload("res://scenes/world/caden/TownSquare.tscn"),
	preload("res://scenes/world/caden/Residential.tscn"),
	preload("res://scenes/world/caden/Commons.tscn"),
]
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_down",
	&"idle_left",
	&"idle_right",
	&"idle_up",
	&"walk_down",
	&"walk_left",
	&"walk_right",
	&"walk_up",
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_sources_and_audit():
		return
	if not _verify_runtime_sheet():
		return
	if not _verify_sprite_frames():
		return
	if not await _verify_stationary_npc_defaults():
		return
	if not await _verify_configured_interactive_visuals():
		return
	if not await _verify_zone_unload_and_restore():
		return
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)

	print("PASS: NPC base contract, optional StationaryNpc visuals, configured interactive variants, collision, interaction, dialogue, and zone reload behavior.")
	quit(0)


func _verify_sources_and_audit() -> bool:
	if FileAccess.get_sha256(ORIGINAL_SOURCE_PATH) != ORIGINAL_SOURCE_SHA256:
		return _fail("The immutable NPC v1 source is missing or changed.")
	if FileAccess.get_sha256(REPAIRED_SOURCE_PATH) != REPAIRED_SOURCE_SHA256:
		return _fail("The audited NPC v2 repair is missing or changed.")
	var original_source := Image.new()
	if original_source.load(ProjectSettings.globalize_path(ORIGINAL_SOURCE_PATH)) != OK:
		return _fail("The immutable NPC v1 source did not decode.")
	if original_source.get_size() != SOURCE_SIZE:
		return _fail("The immutable NPC v1 source dimensions changed.")
	if SOURCE_SIZE.x % 4 != 0 or SOURCE_SIZE.y % 4 != 0 or SOURCE_SIZE / 4 != SOURCE_CELL_SIZE:
		return _fail("The NPC source no longer divides into a 4x4 grid of 265x371 cells.")
	var audit_file := FileAccess.open(AUDIT_PATH, FileAccess.READ)
	var audit: Variant = JSON.parse_string(audit_file.get_as_text()) if audit_file != null else null
	if not audit is Dictionary:
		return _fail("The NPC source audit is missing or invalid.")
	var grid: Dictionary = audit.get("grid", {})
	var gate: Dictionary = audit.get("quality_gate", {})
	if grid.get("columns", 0) != 4 or grid.get("rows", 0) != 4 or grid.get("nonempty_frames", 0) != 16:
		return _fail("The source audit no longer records exactly 16 nonempty frames.")
	if not gate.get("passed", false) or not (audit.get("boundary_contacts", []) as Array).is_empty():
		return _fail("The repaired NPC source no longer passes the boundary gate.")
	return true


func _verify_runtime_sheet() -> bool:
	if FileAccess.get_sha256(RUNTIME_PATH) != RUNTIME_SHA256:
		return _fail("The selected NPC runtime PNG is missing or changed.")
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(RUNTIME_PATH)) != OK:
		return _fail("The NPC runtime PNG did not decode.")
	if image.get_size() != RUNTIME_SIZE or image.get_format() != Image.FORMAT_RGBA8:
		return _fail("The NPC runtime must remain RGBA 160x224.")

	var has_transparent_pixel := false
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha == 0.0:
				has_transparent_pixel = true
			elif alpha != 1.0:
				return _fail("The NPC runtime contains non-binary alpha.")
	if not has_transparent_pixel:
		return _fail("The NPC runtime has no transparent background.")

	for row in 4:
		for column in 4:
			var frame := image.get_region(Rect2i(column * 40, row * 56, 40, 56))
			var bounds := frame.get_used_rect()
			var frame_id := "r%dc%d" % [row + 1, column + 1]
			if not bounds.has_area():
				return _fail("Runtime frame %s is empty." % frame_id)
			if bounds.position.x <= 0 or bounds.end.x >= RUNTIME_CELL_SIZE.x:
				return _fail("Runtime frame %s touches a horizontal cell boundary." % frame_id)
			if bounds.position.y <= 0 or bounds.end.y != RUNTIME_CELL_SIZE.y:
				return _fail("Runtime frame %s lost headroom or its row-55 feet contact." % frame_id)
			if bounds.size.x < 19 or bounds.size.x > 27 or bounds.size.y < 50 or bounds.size.y > 53:
				return _fail("Runtime frame %s falls outside documented consistency ranges." % frame_id)
	return true


func _verify_sprite_frames() -> bool:
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null or frames.get_animation_names().size() != REQUIRED_ANIMATIONS.size():
		return _fail("The NPC SpriteFrames resource is missing or has an unexpected animation count.")
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if not frames.has_animation(animation_name):
			return _fail("The NPC SpriteFrames resource is missing %s." % animation_name)
		var walking := animation_name.begins_with("walk_")
		if frames.get_frame_count(animation_name) != (4 if walking else 1):
			return _fail("Animation %s has the wrong frame count." % animation_name)
		if frames.get_animation_loop(animation_name) != walking:
			return _fail("Animation %s has the wrong loop setting." % animation_name)
		if not is_equal_approx(frames.get_animation_speed(animation_name), 8.0):
			return _fail("Animation %s is not configured at 8 fps." % animation_name)
	return true


func _verify_stationary_npc_defaults() -> bool:
	var npc := STATIONARY_NPC_SCENE.instantiate() as StaticBody2D
	root.add_child(npc)
	await process_frame
	var body_shape := (npc.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var interaction_shape := (npc.get_node("Interactable/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var placeholder := npc.get_node("PlaceholderVisual") as Polygon2D
	var marker := npc.get_node("FacingMarker") as Polygon2D
	var sprite := npc.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if body_shape == null or body_shape.size != Vector2(20, 20):
		return _fail("StationaryNpc collision is no longer 20x20.")
	if interaction_shape == null or not is_equal_approx(interaction_shape.radius, 32.0):
		return _fail("StationaryNpc interaction radius is no longer 32 pixels.")
	if bool(npc.get("character_visual_enabled")) or npc.get("character_sprite_frames") != null:
		return _fail("StationaryNpc runtime art is no longer opt-in.")
	if not placeholder.visible or not marker.visible or sprite.visible:
		return _fail("An unconfigured StationaryNpc no longer displays its development placeholder.")
	var script_text := FileAccess.get_file_as_string("res://scripts/npcs/stationary_npc.gd")
	if "_process(" in script_text or "NavigationAgent" in script_text or "move_and_slide" in script_text:
		return _fail("StationaryNpc gained movement, pathfinding, or an unnecessary process loop.")
	npc.queue_free()
	await process_frame
	return true


func _verify_configured_interactive_visuals() -> bool:
	var configured_count := 0
	var town_square_configured_count := 0
	for zone_scene: PackedScene in ZONE_SCENES:
		var zone := zone_scene.instantiate() as Node2D
		root.add_child(zone)
		await process_frame
		for node: Node in zone.find_children("*", "", true, false):
			if not node.is_in_group(&"npcs"):
				continue
			var npc := node as StaticBody2D
			var enabled := bool(npc.get("character_visual_enabled"))
			var frames := npc.get("character_sprite_frames") as SpriteFrames
			var placeholder := npc.get_node("PlaceholderVisual") as Polygon2D
			var marker := npc.get_node("FacingMarker") as Polygon2D
			var sprite := npc.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
			if enabled or frames != null:
				configured_count += 1
				if (npc.get_node("VisualRoot") as Node2D).position != Vector2(0, 10) or sprite.position != Vector2(0, -28):
					return _fail("A configured interactive NPC no longer uses the documented integer feet offset.")
				if not sprite.visible or placeholder.visible or marker.visible or sprite.is_playing():
					return _fail("A configured interactive NPC does not hide its placeholder and remain idle.")
				if zone.name != "TownSquare":
					continue
				town_square_configured_count += 1
				var conversation := npc.get("conversation") as Resource
				if npc.name == "SquareLocal":
					if frames == null or frames.resource_path != SPRITE_FRAMES_PATH:
						return _fail("SquareLocal does not use the approved base SpriteFrames resource.")
					if npc.position != Vector2(288, 448) or npc.z_index != 10 or npc.get("facing_direction") != Vector2.RIGHT:
						return _fail("SquareLocal position or facing direction changed.")
					if conversation == null or conversation.resource_path != SQUARE_LOCAL_DIALOGUE_PATH or sprite.animation != &"idle_right":
						return _fail("SquareLocal dialogue or idle-right visual changed.")
					npc.set("facing_direction", Vector2.UP)
					if sprite.animation != &"idle_up" or sprite.is_playing():
						return _fail("SquareLocal did not update to a static idle_up after a runtime facing change.")
					npc.set("facing_direction", Vector2.RIGHT)
				elif npc.name == "PassingVisitor":
					if frames == null or frames.resource_path != VISITOR_SPRITE_FRAMES_PATH:
						return _fail("PassingVisitor does not use its prepared variant SpriteFrames resource.")
					if npc.position != Vector2(352, 448) or npc.z_index != 10 or npc.get("facing_direction") != Vector2.LEFT:
						return _fail("PassingVisitor position or facing direction changed.")
					if conversation == null or conversation.resource_path != VISITOR_DIALOGUE_PATH or sprite.animation != &"idle_left":
						return _fail("PassingVisitor dialogue or idle-left visual changed.")
				else:
					return _fail("Unexpected configured interactive NPC: %s." % npc.name)
			else:
				if not placeholder.visible or not marker.visible or sprite.visible:
					return _fail("An unassigned Caden NPC placeholder changed visibility.")
		zone.queue_free()
		await process_frame
	if configured_count != 11:
		return _fail("Expected exactly 11 configured interactive Caden NPCs, found %d." % configured_count)
	if town_square_configured_count != 2:
		return _fail("Expected exactly two configured Town Square NPCs, found %d." % town_square_configured_count)
	return true


func _verify_zone_unload_and_restore() -> bool:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame
	caden.call("_on_transition_requested", &"town_square", &"from_wayfarers_approach")
	await _wait_for_transition()
	var town_square := caden.get("_current_zone") as Node2D
	var square_local := town_square.get_node("Actors/NPCs/SquareLocal") as StaticBody2D
	var old_square_local: WeakRef = weakref(square_local)
	var old_interactable: WeakRef = weakref(square_local.get_node("Interactable"))

	caden.call("_on_transition_requested", &"residential", &"from_town_square")
	await _wait_for_transition()
	if old_square_local.get_ref() != null or old_interactable.get_ref() != null:
		return _fail("SquareLocal or its interaction area survived Town Square unloading.")

	caden.call("_on_transition_requested", &"town_square", &"from_residential")
	await _wait_for_transition()
	var reloaded_square := (caden.get("_current_zone") as Node2D).get_node("Actors/NPCs/SquareLocal") as StaticBody2D
	var reloaded_sprite := reloaded_square.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	var reloaded_interactable := reloaded_square.get_node("Interactable") as Area2D
	if not reloaded_sprite.visible or reloaded_sprite.animation != &"idle_right":
		return _fail("SquareLocal visual did not restore after returning to Town Square.")
	if reloaded_interactable.get("prompt_text") != "Talk":
		return _fail("SquareLocal interaction prompt changed after zone reload.")
	if not reloaded_interactable.is_connected("interacted", Callable(reloaded_square, "_on_interacted")):
		return _fail("SquareLocal interaction signal was not restored after zone reload.")
	caden.queue_free()
	await process_frame
	return true


func _wait_for_transition() -> void:
	await physics_frame
	await physics_frame
	await physics_frame


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
