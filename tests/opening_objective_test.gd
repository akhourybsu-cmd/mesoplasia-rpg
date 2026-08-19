extends SceneTree

const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")

var _caden: Node2D
var _player: CharacterBody2D
var _tracker: Node
var _objective_ui: CanvasLayer


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_caden = CADEN_SCENE.instantiate() as Node2D
	root.add_child(_caden)
	await physics_frame
	await process_frame

	_player = _caden.get_node("Player") as CharacterBody2D
	_tracker = _caden.get_node("ObjectiveTracker")
	_objective_ui = _caden.get_node("ObjectiveUI") as CanvasLayer

	if not _check_progress(0, "Visit the Marketplace", false):
		return
	if _tracker.call("get_objective_title") != "Get Your Bearings":
		return _fail("Development objective started with the wrong title.")
	if not _objective_ui.visible:
		return _fail("Objective UI was not visible after the objective started.")

	if not await _verify_dialogue_while_objective_active():
		return

	# Visiting Town Square before Marketplace must not skip the first step.
	if not await _travel("Exits/ToTownSquare", &"TownSquare"):
		return
	if not _check_progress(0, "Visit the Marketplace", false):
		return
	if not await _travel("Exits/ToWayfarersApproach", &"WayfarersApproach"):
		return

	if not await _travel("Exits/ToMarketplace", &"Marketplace"):
		return
	if not _check_progress(1, "Visit the Town Square", false):
		return

	# Re-entering Marketplace while waiting for Town Square is a harmless duplicate.
	if not await _travel("Exits/ToWayfarersApproach", &"WayfarersApproach"):
		return
	if not await _travel("Exits/ToMarketplace", &"Marketplace"):
		return
	if not _check_progress(1, "Visit the Town Square", false):
		return

	if not await _travel("Exits/ToTownSquare", &"TownSquare"):
		return
	if not _check_progress(2, "Visit the Commons", false):
		return

	# Residential is not the selected optional-area step and must not advance it.
	if not await _travel("Exits/ToResidential", &"Residential"):
		return
	if not _check_progress(2, "Visit the Commons", false):
		return
	if not await _travel("Exits/ToCommons", &"Commons"):
		return
	if not _check_progress(3, "Return to Wayfarer's Approach", false):
		return

	# Re-entering Commons after its step is complete must not affect the final step.
	if not await _travel("Exits/ToResidential", &"Residential"):
		return
	if not await _travel("Exits/ToCommons", &"Commons"):
		return
	if not _check_progress(3, "Return to Wayfarer's Approach", false):
		return

	if not await _travel("Exits/ToTownSquare", &"TownSquare"):
		return
	if not await _travel("Exits/ToWayfarersApproach", &"WayfarersApproach"):
		return
	if not _check_progress(4, "", true):
		return
	var completion_label := _objective_ui.get_node("ObjectivePanel/Content/CurrentStep") as Label
	if completion_label.text != "Objective Complete":
		return _fail("Objective UI did not show the completion message.")
	var completion_timer := _objective_ui.get_node("CompletionTimer") as Timer
	if completion_timer.is_stopped():
		return _fail("Objective completion message was not scheduled to hide.")

	# Further zone visits after completion must leave progress stable.
	if not await _travel("Exits/ToTownSquare", &"TownSquare"):
		return
	if not _check_progress(4, "", true):
		return

	print("PASS: Opening objective order, unrelated and duplicate visits, UI updates, completion, and dialogue compatibility.")
	quit(0)


func _verify_dialogue_while_objective_active() -> bool:
	var approach := _caden.get("_current_zone") as Node2D
	var traveler := approach.get_node("RestingTraveler") as StaticBody2D
	var detector := _player.get_node("InteractionDetector") as Area2D
	var dialogue_ui := _player.get_node("DialogueUI") as CanvasLayer
	_player.position = traveler.position + Vector2(0, -56)
	await physics_frame
	await physics_frame

	if detector.call("get_active_interactable") != traveler.get_node("Interactable"):
		return _fail("NPC interaction was unavailable while the objective was active.")
	detector.call("try_interact")
	if not dialogue_ui.call("is_dialogue_active"):
		return _fail("NPC dialogue did not open while the objective was active.")
	if not _check_progress(0, "Visit the Marketplace", false):
		return false

	dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	dialogue_ui.call("_unhandled_input", _make_interact_event(true))
	dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	dialogue_ui.call("_unhandled_input", _make_interact_event(true))
	await physics_frame
	if dialogue_ui.call("is_dialogue_active") or _player.call("is_control_locked"):
		return _fail("Dialogue did not close and restore control while the objective was active.")

	return true


func _travel(exit_path: NodePath, expected_zone_name: StringName) -> bool:
	var current_zone := _caden.get("_current_zone") as Node2D
	var zone_exit := current_zone.get_node(exit_path) as Area2D
	zone_exit.emit_signal(
		"transition_requested",
		zone_exit.get("destination_zone") as StringName,
		zone_exit.get("destination_entry") as StringName
	)
	await physics_frame
	await physics_frame
	await physics_frame

	var destination_zone := _caden.get("_current_zone") as Node2D
	if destination_zone.name != expected_zone_name:
		return _fail("Expected zone %s, got %s." % [expected_zone_name, destination_zone.name])
	return true


func _check_progress(expected_index: int, expected_step: String, expected_complete: bool) -> bool:
	if _tracker.call("get_current_step_index") != expected_index:
		return _fail("Expected objective step index %d, got %d." % [
			expected_index,
			_tracker.call("get_current_step_index"),
		])
	if _tracker.call("get_current_step_text") != expected_step:
		return _fail("Expected objective step '%s', got '%s'." % [
			expected_step,
			_tracker.call("get_current_step_text"),
		])
	if _tracker.call("is_complete") != expected_complete:
		return _fail("Objective completion state was incorrect at step %d." % expected_index)

	var step_label := _objective_ui.get_node("ObjectivePanel/Content/CurrentStep") as Label
	var expected_ui_text := "Objective Complete" if expected_complete else expected_step
	if step_label.text != expected_ui_text:
		return _fail("Objective UI did not match runtime progress.")
	return true


func _make_interact_event(is_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = is_pressed
	return event


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
