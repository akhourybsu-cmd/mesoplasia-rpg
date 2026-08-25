extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")
const PATROL_NPC_SCENE := preload("res://scenes/npcs/PatrolNpc.tscn")
const MANIFEST_PATH := "res://assets/characters/caden/npc/variants/caden_npc_variants_runtime_v1_manifest.json"
const VARIANT_IDS := [
	"dwarf_elder_man_01",
	"dwarf_middle_woman_01",
	"elf_older_woman_01",
	"elf_younger_man_01",
	"half_elf_young_nonbinary_01",
	"human_elder_woman_01",
	"human_middle_man_01",
	"human_young_woman_01",
]
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_down", &"idle_left", &"idle_right", &"idle_up",
	&"walk_down", &"walk_left", &"walk_right", &"walk_up",
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_manifest_and_variant_resources():
		return
	if not await _verify_patrol_component():
		return
	if not await _verify_town_square_population():
		return
	print("PASS: eight NPC variant atlases, reusable forward-idle patrol behavior, and three bounded Town Square lanes.")
	quit(0)


func _verify_manifest_and_variant_resources() -> bool:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var manifest: Variant = JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else null
	if not manifest is Dictionary or manifest.get("schema", "") != "caden-npc-variants-runtime-v1":
		return _fail("NPC variant runtime manifest is missing or invalid.")
	var variants := manifest.get("variants", []) as Array
	if variants.size() != VARIANT_IDS.size():
		return _fail("NPC variant manifest does not contain all eight supplied characters.")
	var found_ids: Array[String] = []
	for variant_value: Variant in variants:
		var variant := variant_value as Dictionary
		var variant_id := variant.get("variant_id", "") as String
		found_ids.append(variant_id)
		var runtime := variant.get("runtime", {}) as Dictionary
		var runtime_path := "res://" + (runtime.get("path", "") as String)
		if FileAccess.get_sha256(runtime_path) != runtime.get("sha256", ""):
			return _fail("NPC runtime hash mismatch: %s." % variant_id)
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(runtime_path)) != OK or image.get_size() != Vector2i(160, 224):
			return _fail("NPC runtime atlas failed its 160x224 decode contract: %s." % variant_id)
		for row in 4:
			for column in 4:
				if not image.get_region(Rect2i(column * 40, row * 56, 40, 56)).get_used_rect().has_area():
					return _fail("NPC runtime atlas contains an empty frame: %s." % variant_id)

		var frames_data := variant.get("sprite_frames", {}) as Dictionary
		var frames_path := "res://" + (frames_data.get("path", "") as String)
		if FileAccess.get_sha256(frames_path) != frames_data.get("sha256", ""):
			return _fail("NPC SpriteFrames hash mismatch: %s." % variant_id)
		var frames := load(frames_path) as SpriteFrames
		if not _sprite_frames_match_contract(frames):
			return _fail("NPC SpriteFrames contract failed: %s." % variant_id)
	for expected_id: String in VARIANT_IDS:
		if expected_id not in found_ids:
			return _fail("NPC variant manifest is missing %s." % expected_id)
	return true


func _sprite_frames_match_contract(frames: SpriteFrames) -> bool:
	if frames == null or frames.get_animation_names().size() != REQUIRED_ANIMATIONS.size():
		return false
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if not frames.has_animation(animation_name):
			return false
		var walking := animation_name.begins_with("walk_")
		if frames.get_frame_count(animation_name) != (4 if walking else 1):
			return false
		if frames.get_animation_loop(animation_name) != walking:
			return false
		if not is_equal_approx(frames.get_animation_speed(animation_name), 8.0):
			return false
	return true


func _verify_patrol_component() -> bool:
	var patrol := PATROL_NPC_SCENE.instantiate() as CharacterBody2D
	patrol.set("character_sprite_frames", load("res://assets/characters/caden/npc/variants/half_elf_young_nonbinary_01/caden_npc_half_elf_young_nonbinary_01_sprite_frames_v1.tres"))
	patrol.set("patrol_axis", 0)
	patrol.set("patrol_distance", 64.0)
	patrol.set("move_speed", 32.0)
	patrol.set("pause_duration", 0.05)
	root.add_child(patrol)
	await physics_frame
	var sprite := patrol.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if not patrol.is_in_group(&"ambient_npcs") or patrol.is_in_group(&"npcs"):
		return _fail("PatrolNpc group contract would pollute interactive dialogue population.")
	if not sprite.visible or sprite.animation != &"idle_down" or sprite.is_playing():
		return _fail("PatrolNpc does not begin paused and facing forward.")
	var initial_x := patrol.position.x
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	if patrol.position.x <= initial_x or sprite.animation != &"walk_right" or not sprite.is_playing():
		return _fail("Horizontal PatrolNpc did not transition from forward idle to walk_right movement.")
	patrol.queue_free()
	await process_frame
	return true


func _verify_town_square_population() -> bool:
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	root.add_child(town_square)
	await physics_frame
	var npc_root := town_square.get_node("Actors/NPCs") as Node2D
	if npc_root.get_child_count() != 5 or not npc_root.y_sort_enabled:
		return _fail("Town Square NPC hierarchy does not contain two interactive NPCs plus three y-sorted patrols.")
	var expected_axes := {
		"NorthPlazaWalker": 0,
		"WestPlazaWalker": 1,
		"SouthPlazaWalker": 0,
	}
	var ambient_count := 0
	for node: Node in npc_root.get_children():
		if not node.is_in_group(&"ambient_npcs"):
			continue
		ambient_count += 1
		var patrol := node as CharacterBody2D
		if patrol == null or patrol.get("patrol_axis") != expected_axes.get(String(patrol.name), -1):
			return _fail("Town Square patrol axis changed: %s." % node.name)
		if not bool(patrol.get("face_forward_while_idle")):
			return _fail("Town Square patrol no longer faces forward while paused: %s." % node.name)
		var sprite := patrol.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
		if not sprite.visible or sprite.animation != &"idle_down":
			return _fail("Town Square patrol is not using its prepared forward-facing variant: %s." % node.name)
	if ambient_count != 3:
		return _fail("Town Square should contain exactly three ambient patrols.")
	if town_square.get_tree().get_nodes_in_group(&"npcs").size() != 2:
		return _fail("Ambient patrols changed the Town Square interactive dialogue population.")
	town_square.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
