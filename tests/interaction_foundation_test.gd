extends SceneTree

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TEST_OBJECT_SCENE := preload("res://scenes/development/InteractionTestObject.tscn")
const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not await _test_detection_selection_and_activation():
		return
	if not await _test_zone_unload_clears_active_target():
		return

	print("PASS: Interaction detection, activation, prompt clearing, and zone-unload safety.")
	quit(0)


func _test_detection_selection_and_activation() -> bool:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var front_object := TEST_OBJECT_SCENE.instantiate() as StaticBody2D
	var nearer_behind_object := TEST_OBJECT_SCENE.instantiate() as StaticBody2D
	root.add_child(player)
	root.add_child(front_object)
	root.add_child(nearer_behind_object)

	player.position = Vector2(200, 200)
	front_object.position = Vector2(200, 260)
	nearer_behind_object.position = Vector2(200, 155)
	await physics_frame
	await physics_frame

	var detector := player.get_node("InteractionDetector") as Area2D
	var prompt := player.get_node("InteractionPrompt") as CanvasLayer
	var expected_front := front_object.get_node("Interactable") as Area2D
	if detector.call("get_active_interactable") != expected_front:
		return _fail("Detector did not prefer the interactable in front of the Player.")
	if not prompt.visible:
		return _fail("Interaction prompt was not shown for an active interactable.")

	var input_event := InputEventAction.new()
	input_event.action = &"interact"
	input_event.pressed = true
	detector.call("_unhandled_input", input_event)
	if front_object.get("interaction_count") != 1:
		return _fail("The named interact action did not activate the selected interactable.")
	if nearer_behind_object.get("interaction_count") != 0:
		return _fail("More than one interactable activated from a single input.")

	front_object.position = Vector2(500, 500)
	await physics_frame
	await physics_frame
	var expected_behind := nearer_behind_object.get_node("Interactable") as Area2D
	if detector.call("get_active_interactable") != expected_behind:
		return _fail("Detector did not fall back to the remaining nearby interactable.")

	nearer_behind_object.position = Vector2(500, 400)
	await physics_frame
	await physics_frame
	if detector.call("get_active_interactable") != null:
		return _fail("Detector retained an interactable after leaving its interaction area.")
	if prompt.visible:
		return _fail("Interaction prompt remained visible without an active interactable.")

	player.queue_free()
	front_object.queue_free()
	nearer_behind_object.queue_free()
	await process_frame
	return true


func _test_zone_unload_clears_active_target() -> bool:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame

	var player := caden.get_node("Player") as CharacterBody2D
	var approach := caden.get("_current_zone") as Node2D
	var to_town_square := approach.get_node("Exits/ToTownSquare") as Area2D
	player.global_position = to_town_square.global_position
	await physics_frame
	await physics_frame
	await physics_frame

	var town_square := caden.get("_current_zone") as Node2D
	var square_local := town_square.get_node("Actors/NPCs/SquareLocal") as StaticBody2D
	var old_interactable := square_local.get_node("Interactable") as Area2D
	var old_interactable_reference: WeakRef = weakref(old_interactable)
	player.position = square_local.position + Vector2(0, 56)
	await physics_frame
	await physics_frame

	var detector := player.get_node("InteractionDetector") as Area2D
	if detector.call("get_active_interactable") != old_interactable:
		return _fail("Town Square NPC was not detected before zone unload.")

	var to_residential := town_square.get_node("Exits/ToResidential") as Area2D
	to_residential.emit_signal(
		"transition_requested",
		player.call("get_character_id") as StringName,
		to_residential.get("exit_id") as StringName,
		&"residential",
		&"from_town_square"
	)
	await physics_frame
	await physics_frame
	await physics_frame

	if detector.call("get_active_interactable") != null:
		return _fail("Player retained an active interactable from the unloaded zone.")
	if old_interactable_reference.get_ref() != null:
		return _fail("Unloaded zone interactable remained alive unexpectedly.")

	caden.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
