extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/development/LocalMultiAvatarSandbox.tscn")
const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")
const LOCAL_CHARACTER_ID: StringName = &"local.character.primary"
const REMOTE_CHARACTER_ID: StringName = &"development.character.remote"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var sandbox := SANDBOX_SCENE.instantiate() as Node2D
	root.add_child(sandbox)
	await process_frame
	await physics_frame
	await process_frame

	if not _verify_registry_and_ownership(sandbox):
		return
	if not await _verify_local_input_and_remote_presentation(sandbox):
		return
	if not await _verify_interaction_and_transition_intents(sandbox):
		return
	if not _verify_explicit_depth_reference(sandbox):
		return
	if not _verify_no_ambiguous_player_lookup():
		return
	sandbox.queue_free()
	await process_frame
	if not await _verify_production_caden_depth_seam():
		return

	print("PASS: Phase B two-avatar sandbox, exclusive local ownership, registry, intents, and depth reference.")
	quit(0)


func _verify_registry_and_ownership(sandbox: Node2D) -> bool:
	var registry := sandbox.call("get_avatar_registry") as Node
	var local_avatar := sandbox.call("get_local_avatar") as CharacterBody2D
	var remote_avatar := sandbox.call("get_remote_avatar") as CharacterBody2D
	if registry.call("get_avatar_count") != 2:
		return _fail("Sandbox registry did not retain exactly two avatars.")
	if registry.call("get_local_avatar") != local_avatar:
		return _fail("Sandbox registry did not resolve the explicit local avatar.")
	if registry.call("get_avatar", REMOTE_CHARACTER_ID) != remote_avatar:
		return _fail("Sandbox registry did not resolve the remote-style avatar by CharacterId.")
	if registry.call("get_registered_character_ids") != [REMOTE_CHARACTER_ID, LOCAL_CHARACTER_ID]:
		return _fail("Sandbox registry CharacterIds are not stable and deterministic.")
	if registry.call("register_avatar", remote_avatar):
		return _fail("Sandbox registry accepted a duplicate CharacterId.")

	if local_avatar.name != &"LocalAvatar" or remote_avatar.name != &"RemoteAvatar":
		return _fail("Sandbox avatars lost their collision-free node names.")
	if local_avatar.call("get_character_id") == remote_avatar.call("get_character_id"):
		return _fail("Sandbox avatars share a CharacterId.")
	if not local_avatar.call("is_locally_controlled") or remote_avatar.call("is_locally_controlled"):
		return _fail("Sandbox avatar roles are not explicit.")

	var local_camera := local_avatar.get_node_or_null("Camera2D") as Camera2D
	if local_camera == null or not local_camera.enabled:
		return _fail("Local avatar does not own the active Camera2D.")
	if remote_avatar.get_node_or_null("Camera2D") != null:
		return _fail("Remote-style avatar retained a Camera2D.")
	if remote_avatar.get_node_or_null("LocalAvatarInput") != null:
		return _fail("Remote-style avatar retained a local input source.")
	if remote_avatar.get_node_or_null("InteractionDetector") != null:
		return _fail("Remote-style avatar retained a local interaction detector.")
	if remote_avatar.get_node_or_null("InteractionPrompt") != null:
		return _fail("Remote-style avatar retained local prompt UI.")
	if remote_avatar.get_node_or_null("DialogueUI") != null:
		return _fail("Remote-style avatar retained local dialogue UI.")

	var cameras := sandbox.find_children("*", "Camera2D", true, false)
	var canvas_layers := sandbox.find_children("*", "CanvasLayer", true, false)
	if cameras.size() != 1:
		return _fail("Sandbox contains %d cameras instead of one." % cameras.size())
	if canvas_layers.size() != 2:
		return _fail("Sandbox contains duplicate avatar UI; expected the local prompt and dialogue only.")
	if sandbox.get_node("Actors").get_child_count() != 2:
		return _fail("Sandbox Actors root contains unexpected avatar nodes.")
	return true


func _verify_local_input_and_remote_presentation(sandbox: Node2D) -> bool:
	var local_avatar := sandbox.call("get_local_avatar") as CharacterBody2D
	var remote_avatar := sandbox.call("get_remote_avatar") as CharacterBody2D
	var local_start := local_avatar.global_position
	var remote_start := remote_avatar.global_position

	Input.action_press(&"move_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"move_right")
	if local_avatar.global_position.x <= local_start.x:
		return _fail("Local avatar did not consume the sandbox movement input.")
	if not remote_avatar.global_position.is_equal_approx(remote_start):
		return _fail("Remote-style avatar moved in response to local input.")

	var remote_position := Vector2(432, 192)
	if not remote_avatar.call(
		"apply_remote_presentation_state",
		remote_position,
		Vector2.LEFT,
		Vector2.LEFT
	):
		return _fail("Remote-style avatar rejected presentation state.")
	if not remote_avatar.global_position.is_equal_approx(remote_position):
		return _fail("Remote-style presentation state did not update position.")
	var remote_sprite := remote_avatar.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if remote_sprite.animation != &"walk_left":
		return _fail("Remote-style presentation did not update its visual state.")
	if local_avatar.call(
		"apply_remote_presentation_state",
		Vector2.ZERO,
		Vector2.LEFT,
		Vector2.LEFT
	):
		return _fail("Local avatar accepted remote presentation authority.")
	return true


func _verify_interaction_and_transition_intents(sandbox: Node2D) -> bool:
	var local_avatar := sandbox.call("get_local_avatar") as CharacterBody2D
	var remote_avatar := sandbox.call("get_remote_avatar") as CharacterBody2D
	var interaction_target := sandbox.call("get_interaction_target") as StaticBody2D
	var detector := local_avatar.get_node("InteractionDetector") as Area2D
	await physics_frame
	await physics_frame
	if detector.call("get_active_interactable") != interaction_target.get_node("Interactable"):
		return _fail("Local avatar did not select the sandbox interaction target.")
	if not detector.call("try_interact") or interaction_target.get("interaction_count") != 1:
		return _fail("Local avatar interaction request did not execute once.")
	if remote_avatar.get_node_or_null("InteractionDetector") != null:
		return _fail("Remote-style avatar can still originate local interaction intent.")

	var transition_probe := sandbox.call("get_transition_probe") as Area2D
	transition_probe.call("_on_body_entered", remote_avatar)
	if sandbox.get("transition_intent_count") != 0:
		return _fail("Remote-style avatar originated a local transition intent.")
	transition_probe.call("_on_body_entered", local_avatar)
	if sandbox.get("transition_intent_count") != 1:
		return _fail("Local avatar transition intent was not observed exactly once.")
	if sandbox.get("last_transition_character_id") != LOCAL_CHARACTER_ID:
		return _fail("Sandbox transition intent carried the wrong CharacterId.")
	if sandbox.get("last_transition_exit_id") != &"development.exit.multi_avatar_sandbox.probe":
		return _fail("Sandbox transition intent carried the wrong ExitId.")
	return true


func _verify_explicit_depth_reference(sandbox: Node2D) -> bool:
	var local_avatar := sandbox.call("get_local_avatar") as CharacterBody2D
	var remote_avatar := sandbox.call("get_remote_avatar") as CharacterBody2D
	var depth_probe := sandbox.call("get_depth_probe") as StaticBody2D
	if depth_probe.call("get_depth_reference") != local_avatar:
		return _fail("Depth-sorted sandbox prop did not bind to the registry's local avatar.")
	if not (sandbox.get_node("Actors") as Node2D).y_sort_enabled:
		return _fail("Sandbox avatar presentation root does not use Y sorting.")
	if not (local_avatar.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D).visible:
		return _fail("Local avatar is not visible in the multi-avatar sandbox.")
	if not (remote_avatar.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D).visible:
		return _fail("Remote-style avatar is not visible in the multi-avatar sandbox.")

	local_avatar.global_position.y = depth_probe.global_position.y + 48.0
	depth_probe.call("_process", 0.0)
	if depth_probe.z_index != depth_probe.get("behind_player_z_index"):
		return _fail("Depth probe did not move behind the explicit local avatar.")
	local_avatar.global_position.y = depth_probe.global_position.y - 48.0
	depth_probe.call("_process", 0.0)
	if depth_probe.z_index != depth_probe.get("in_front_of_player_z_index"):
		return _fail("Depth probe did not move in front of the explicit local avatar.")
	return true


func _verify_no_ambiguous_player_lookup() -> bool:
	for script_path: String in [
		"res://scripts/world/depth_sorted_static_prop.gd",
		"res://scripts/client/players/avatar_registry.gd",
		"res://scripts/development/local_multi_avatar_sandbox.gd",
	]:
		var source := FileAccess.get_file_as_string(script_path)
		if source.contains("get_first_node_in_group"):
			return _fail("Phase B script retains an ambiguous first-player lookup: %s" % script_path)
	return true


func _verify_production_caden_depth_seam() -> bool:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame
	var player := caden.get_node("Player") as CharacterBody2D
	var player_count := 0
	for node: Node in caden.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"player"):
			player_count += 1
	if player_count != 1:
		return _fail("Phase B changed production Caden's single-Player composition.")

	var current_zone := caden.get("_current_zone") as Node2D
	var bound_depth_prop_count := 0
	for node: Node in current_zone.find_children("*", "StaticBody2D", true, false):
		if not node.has_method("get_depth_reference"):
			continue
		bound_depth_prop_count += 1
		if node.call("get_depth_reference") != player:
			return _fail("Caden depth prop is not explicitly bound to its persistent Player.")
	if bound_depth_prop_count == 0:
		return _fail("Caden starting zone exposed no explicit depth-reference seams.")
	caden.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	Input.action_release(&"move_right")
	push_error(message)
	quit(1)
	return false
