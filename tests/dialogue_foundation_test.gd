extends SceneTree

const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")

const EXPECTED_LINES := [
	"I was lucky to find a place to rest.",
	"Rooms are filling quickly with travelers bound for the festival.",
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame

	var player := caden.get_node("Player") as CharacterBody2D
	var approach := caden.get("_current_zone") as Node2D
	var traveler := approach.get_node("Actors/NPCs/RestingTraveler") as StaticBody2D
	var old_traveler_reference: WeakRef = weakref(traveler)
	var detector := player.get_node("InteractionDetector") as Area2D
	var interaction_prompt := player.get_node("InteractionPrompt") as CanvasLayer
	var dialogue_ui := player.get_node("DialogueUI") as CanvasLayer

	player.position = traveler.position + Vector2(0, -56)
	await physics_frame
	await physics_frame

	if detector.call("get_active_interactable") != traveler.get_node("Interactable"):
		return _fail("Temporary traveler did not become the active interactable.")
	if not interaction_prompt.visible:
		return _fail("Normal interaction prompt was not visible before dialogue.")

	var opening_press := _make_interact_event(true)
	detector.call("_unhandled_input", opening_press)
	if not dialogue_ui.call("is_dialogue_active"):
		return _fail("Dialogue did not open from traveler interaction.")
	if dialogue_ui.call("get_speaker_name") != "Traveler":
		return _fail("Dialogue speaker name was not displayed correctly.")
	if dialogue_ui.call("get_current_line_text") != EXPECTED_LINES[0]:
		return _fail("Dialogue did not display the first line correctly.")
	if not player.call("is_control_locked"):
		return _fail("Player controls were not locked when dialogue opened.")
	if detector.call("get_active_interactable") != null or interaction_prompt.visible:
		return _fail("Interaction target or prompt remained active during dialogue.")

	var position_before_dialogue := player.position
	var facing_before_dialogue: Vector2 = player.get("facing_direction")
	Input.action_press(&"move_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"move_right")
	if not player.position.is_equal_approx(position_before_dialogue):
		return _fail("Player moved while dialogue was active.")
	if player.get("facing_direction") != facing_before_dialogue:
		return _fail("Player facing changed while dialogue was active.")

	dialogue_ui.call("_unhandled_input", opening_press)
	if dialogue_ui.call("get_current_line_index") != 0:
		return _fail("Opening interaction press skipped the first dialogue line.")

	var blocked_exit := approach.get_node("Exits/ToMarketplace") as Area2D
	_emit_transition_request(blocked_exit, player)
	await physics_frame
	await physics_frame
	if caden.get("_current_zone") != approach:
		return _fail("Caden changed zones while dialogue was active.")

	dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	dialogue_ui.call("_unhandled_input", _make_interact_event(true))
	if dialogue_ui.call("get_current_line_text") != EXPECTED_LINES[1]:
		return _fail("Dialogue did not advance to line two.")

	dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	dialogue_ui.call("_unhandled_input", _make_interact_event(true))
	await physics_frame
	if dialogue_ui.call("is_dialogue_active"):
		return _fail("Dialogue did not close after the final line.")
	if player.call("is_control_locked"):
		return _fail("Player controls were not restored after dialogue closed.")
	if detector.call("get_active_interactable") == null or not interaction_prompt.visible:
		return _fail("Normal interaction did not resume after dialogue closed.")

	_emit_transition_request(blocked_exit, player)
	await physics_frame
	await physics_frame
	await physics_frame
	var marketplace := caden.get("_current_zone") as Node2D
	if marketplace.name != "Marketplace":
		return _fail("Zone transition did not resume after dialogue closed.")
	if old_traveler_reference.get_ref() != null:
		return _fail("Traveler from the unloaded zone remained alive.")

	var return_exit := marketplace.get_node("Exits/ToWayfarersApproach") as Area2D
	_emit_transition_request(return_exit, player)
	await physics_frame
	await physics_frame
	await physics_frame
	var reloaded_approach := caden.get("_current_zone") as Node2D
	var reloaded_traveler := reloaded_approach.get_node("Actors/NPCs/RestingTraveler") as StaticBody2D
	player.position = reloaded_traveler.position + Vector2(0, -56)
	await physics_frame
	await physics_frame
	detector.call("_unhandled_input", _make_interact_event(true))
	if not dialogue_ui.call("is_dialogue_active"):
		return _fail("Dialogue did not work after changing Caden zones.")
	if dialogue_ui.call("get_current_line_text") != EXPECTED_LINES[0]:
		return _fail("Reloaded traveler dialogue did not restart at line one.")

	print("PASS: Dialogue sequence, input gate, control lock, interaction integration, and zone compatibility.")
	quit(0)


func _make_interact_event(is_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = is_pressed
	return event


func _emit_transition_request(zone_exit: Area2D, player: CharacterBody2D) -> void:
	zone_exit.emit_signal(
		"transition_requested",
		player.call("get_character_id") as StringName,
		zone_exit.get("exit_id") as StringName,
		zone_exit.get("destination_zone") as StringName,
		zone_exit.get("destination_entry") as StringName
	)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
