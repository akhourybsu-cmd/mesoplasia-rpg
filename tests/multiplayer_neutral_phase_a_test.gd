extends SceneTree

const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TEST_OBJECT_SCENE := preload("res://scenes/development/InteractionTestObject.tscn")
const CHARACTER_IDENTITY := preload("res://scripts/core/character_identity.gd")
const ZONE_SCENES: Array[PackedScene] = [
	preload("res://scenes/world/caden/WayfarersApproach.tscn"),
	preload("res://scenes/world/caden/Marketplace.tscn"),
	preload("res://scenes/world/caden/TownSquare.tscn"),
	preload("res://scenes/world/caden/Residential.tscn"),
	preload("res://scenes/world/caden/Commons.tscn"),
]

var _interaction_character_id: StringName
var _interaction_target_id: StringName
var _interaction_target: Area2D
var _transition_character_id: StringName
var _transition_exit_id: StringName
var _transition_destination_zone: StringName
var _transition_destination_entry: StringName


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_input_and_identity_contracts():
		return
	if not await _verify_stable_authored_ids():
		return
	if not await _verify_local_role_and_qualified_requests():
		return

	print("PASS: Phase A stable identity, local presentation, input seam, and qualified requests.")
	quit(0)


func _verify_input_and_identity_contracts() -> bool:
	if not CHARACTER_IDENTITY.is_valid(CHARACTER_IDENTITY.LOCAL_PRIMARY):
		return _fail("The Phase A local CharacterId is invalid.")
	if CHARACTER_IDENTITY.is_valid(&"Player") or CHARACTER_IDENTITY.is_valid(&"/root/Caden/Player"):
		return _fail("CharacterId validation accepted a node name or node path.")

	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var movement_source := FileAccess.get_file_as_string(
		"res://scripts/players/avatar_movement_adapter.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/client/players/local_avatar_input.gd"
	)
	if player_source.contains("Input.") or movement_source.contains("Input."):
		return _fail("Player or movement simulation still reads global Input directly.")
	if not input_source.contains("Input.get_vector"):
		return _fail("The local input source no longer owns movement input sampling.")
	return true


func _verify_stable_authored_ids() -> bool:
	var known_ids: Dictionary[StringName, bool] = {}
	var interactable_count := 0
	var exit_count := 0
	for zone_scene: PackedScene in ZONE_SCENES:
		var zone := zone_scene.instantiate() as Node2D
		root.add_child(zone)
		await process_frame
		for node: Node in zone.find_children("*", "Area2D", true, false):
			var stable_id: StringName
			if node.is_in_group(&"interactables"):
				stable_id = node.call("get_interactable_id") as StringName
				interactable_count += 1
			elif node.is_in_group(&"zone_exits"):
				stable_id = node.get("exit_id") as StringName
				exit_count += 1
			else:
				continue

			if stable_id == &"":
				return _fail("A Caden interactable or exit has no stable ID: %s" % node.get_path())
			if known_ids.has(stable_id):
				return _fail("Stable authored ID is duplicated: %s" % stable_id)
			known_ids[stable_id] = true
		zone.queue_free()
		await process_frame

	if interactable_count != 11:
		return _fail("Expected 11 stable Caden interactable IDs, found %d." % interactable_count)
	if exit_count != 12:
		return _fail("Expected 12 stable Caden exit IDs, found %d." % exit_count)
	return true


func _verify_local_role_and_qualified_requests() -> bool:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame
	var player := caden.get_node("Player") as CharacterBody2D
	if player.call("get_character_id") != CHARACTER_IDENTITY.LOCAL_PRIMARY:
		return _fail("Caden Player does not retain the stable local CharacterId.")
	if not player.call("is_locally_controlled"):
		return _fail("Caden Player is not explicitly configured as the local avatar.")

	var remote_avatar := PLAYER_SCENE.instantiate() as CharacterBody2D
	remote_avatar.set("character_id", &"development.character.remote")
	remote_avatar.set("is_local_avatar", false)
	remote_avatar.position = Vector2(2048, 2048)
	root.add_child(remote_avatar)
	await physics_frame
	if remote_avatar.call("get_character_id") == player.call("get_character_id"):
		return _fail("Two configured avatars retained the same CharacterId.")
	if remote_avatar.get_node_or_null("Camera2D") != null:
		return _fail("A remote-style avatar retained a local camera.")
	if remote_avatar.is_physics_processing():
		return _fail("A remote-style avatar retained the local movement process.")
	if remote_avatar.get_node_or_null("InteractionDetector") != null:
		return _fail("A remote-style avatar retained local interaction input.")
	if remote_avatar.get_node_or_null("DialogueUI") != null:
		return _fail("A remote-style avatar retained local dialogue UI.")

	var enabled_camera_count := 0
	for avatar: Node in get_nodes_in_group(&"player"):
		var camera := avatar.get_node_or_null("Camera2D") as Camera2D
		if camera != null and camera.enabled:
			enabled_camera_count += 1
	if enabled_camera_count != 1:
		return _fail("Expected exactly one enabled avatar camera, found %d." % enabled_camera_count)

	var test_object := TEST_OBJECT_SCENE.instantiate() as StaticBody2D
	test_object.global_position = player.global_position + Vector2(0, 56)
	root.add_child(test_object)
	await physics_frame
	await physics_frame
	var detector := player.get_node("InteractionDetector") as Area2D
	detector.connect("interaction_requested", _capture_interaction_request)
	if not detector.call("try_interact"):
		return _fail("The local interaction adapter rejected a valid request.")
	if _interaction_character_id != player.call("get_character_id"):
		return _fail("Interaction request did not carry the local CharacterId.")
	if _interaction_target_id != &"development.interactable.test_object":
		return _fail("Interaction request did not carry the stable interactable ID.")
	if _interaction_target != test_object.get_node("Interactable"):
		return _fail("Local interaction request selected the wrong presentation target.")
	if test_object.get("interaction_count") != 1:
		return _fail("Qualified interaction did not preserve local behavior.")

	var approach := caden.get("_current_zone") as Node2D
	var zone_exit := approach.get_node("Exits/ToTownSquare") as Area2D
	zone_exit.connect("transition_requested", _capture_transition_request)
	var forged_request_accepted: bool = caden.call(
		"request_zone_transition",
		&"development.character.forged",
		zone_exit.get("exit_id") as StringName,
		zone_exit.get("destination_zone") as StringName,
		zone_exit.get("destination_entry") as StringName
	)
	if forged_request_accepted or caden.get("_current_zone") != approach:
		return _fail("Caden accepted a transition for the wrong CharacterId.")

	zone_exit.call("_on_body_entered", player)
	if _transition_character_id != player.call("get_character_id"):
		return _fail("Transition request did not carry the local CharacterId.")
	if _transition_exit_id != &"caden.exit.wayfarers_approach.to_town_square":
		return _fail("Transition request did not carry its stable ExitId.")
	if _transition_destination_zone != &"town_square" or _transition_destination_entry != &"from_wayfarers_approach":
		return _fail("Transition request changed its destination contract.")
	await physics_frame
	await physics_frame
	await physics_frame
	if (caden.get("_current_zone") as Node2D).name != &"TownSquare":
		return _fail("Qualified transition did not preserve local Caden travel.")

	test_object.queue_free()
	remote_avatar.queue_free()
	caden.queue_free()
	await process_frame
	return true


func _capture_interaction_request(
	character_id: StringName,
	interactable_id: StringName,
	interactable: Area2D
) -> void:
	_interaction_character_id = character_id
	_interaction_target_id = interactable_id
	_interaction_target = interactable


func _capture_transition_request(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
) -> void:
	_transition_character_id = character_id
	_transition_exit_id = exit_id
	_transition_destination_zone = destination_zone
	_transition_destination_entry = destination_entry


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
