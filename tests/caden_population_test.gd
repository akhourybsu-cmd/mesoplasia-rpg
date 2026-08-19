extends SceneTree

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")
const ZONE_CASES := [
	{
		"scene": preload("res://scenes/world/caden/WayfarersApproach.tscn"),
		"expected_count": 3,
	},
	{
		"scene": preload("res://scenes/world/caden/Marketplace.tscn"),
		"expected_count": 3,
	},
	{
		"scene": preload("res://scenes/world/caden/TownSquare.tscn"),
		"expected_count": 2,
	},
	{
		"scene": preload("res://scenes/world/caden/Residential.tscn"),
		"expected_count": 2,
	},
	{
		"scene": preload("res://scenes/world/caden/Commons.tscn"),
		"expected_count": 1,
	},
]

var _conversation_paths: Dictionary[String, bool] = {}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not await _test_each_zone_population_and_dialogue():
		return
	if not await _test_population_zone_unload_safety():
		return
	if _conversation_paths.size() != 11:
		return _fail("Expected 11 distinct NPC dialogue resources, found %d." % _conversation_paths.size())

	print("PASS: Caden NPC population, distinct dialogue data, per-zone interaction, and zone-unload safety.")
	quit(0)


func _test_each_zone_population_and_dialogue() -> bool:
	for zone_case: Dictionary in ZONE_CASES:
		var zone_scene := zone_case["scene"] as PackedScene
		var expected_count := zone_case["expected_count"] as int
		var zone := zone_scene.instantiate() as Node2D
		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		root.add_child(zone)
		root.add_child(player)
		await physics_frame

		var npcs := _find_npcs(zone)
		if npcs.size() != expected_count:
			return _fail("Zone %s expected %d NPCs, found %d." % [zone.name, expected_count, npcs.size()])

		for npc in npcs:
			var conversation := npc.get("conversation") as Resource
			if conversation == null:
				return _fail("NPC %s has no dialogue resource." % npc.name)
			var speaker_id := conversation.get("speaker_id") as StringName
			var speaker_name := conversation.get("speaker_name") as String
			var lines := conversation.get("lines") as Array
			if speaker_id == &"" or speaker_name.is_empty():
				return _fail("NPC %s has incomplete speaker data." % npc.name)
			if lines.is_empty() or lines.size() > 3:
				return _fail("NPC %s dialogue must contain one to three lines." % npc.name)
			if conversation.resource_path.is_empty():
				return _fail("NPC %s dialogue is embedded instead of stored separately." % npc.name)
			_conversation_paths[conversation.resource_path] = true

		if not await _verify_dialogue_interaction(player, npcs[0]):
			return false

		player.queue_free()
		zone.queue_free()
		await process_frame

	return true


func _test_population_zone_unload_safety() -> bool:
	var caden := CADEN_SCENE.instantiate() as Node2D
	root.add_child(caden)
	await physics_frame

	var player := caden.get_node("Player") as CharacterBody2D
	var player_instance_id := player.get_instance_id()
	var approach := caden.get("_current_zone") as Node2D
	var old_npc := _find_npcs(approach)[0] as Node2D
	var old_interactable := old_npc.get_node("Interactable") as Area2D
	var old_npc_reference: WeakRef = weakref(old_npc)
	player.position = old_npc.position + Vector2(0, 48)
	await physics_frame
	await physics_frame

	var detector := player.get_node("InteractionDetector") as Area2D
	if detector.call("get_active_interactable") != old_interactable:
		return _fail("Starting-zone NPC was not detected before zone replacement.")

	var marketplace_exit := approach.get_node("Exits/ToMarketplace") as Area2D
	marketplace_exit.emit_signal("transition_requested", &"marketplace", &"from_wayfarers_approach")
	await physics_frame
	await physics_frame
	await physics_frame

	var marketplace := caden.get("_current_zone") as Node2D
	if marketplace.name != "Marketplace":
		return _fail("Population zone-unload test did not reach Marketplace.")
	if player.get_instance_id() != player_instance_id:
		return _fail("Persistent Player was replaced during population zone transition.")
	if old_npc_reference.get_ref() != null:
		return _fail("An NPC from the unloaded zone remained alive.")
	if detector.call("get_active_interactable") != null:
		return _fail("Player retained an interaction target from the unloaded zone.")

	var marketplace_npcs := _find_npcs(marketplace)
	if not await _verify_dialogue_interaction(player, marketplace_npcs[0] as Node2D):
		return false

	caden.queue_free()
	await process_frame
	return true


func _verify_dialogue_interaction(player: CharacterBody2D, npc: Node2D) -> bool:
	player.position = npc.position + Vector2(0, 48)
	await physics_frame
	await physics_frame

	var detector := player.get_node("InteractionDetector") as Area2D
	var dialogue_ui := player.get_node("DialogueUI") as CanvasLayer
	var interactable := npc.get_node("Interactable") as Area2D
	var conversation := npc.get("conversation") as Resource
	var speaker_name := conversation.get("speaker_name") as String
	var lines := conversation.get("lines") as Array
	if detector.call("get_active_interactable") != interactable:
		return _fail("NPC %s did not become the active interactable." % npc.name)

	detector.call("try_interact")
	if not dialogue_ui.call("is_dialogue_active"):
		return _fail("NPC %s did not start dialogue." % npc.name)
	if dialogue_ui.call("get_speaker_name") != speaker_name:
		return _fail("NPC %s displayed the wrong speaker name." % npc.name)
	if dialogue_ui.call("get_current_line_text") != lines[0]:
		return _fail("NPC %s displayed the wrong first line." % npc.name)

	dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	for _line in lines:
		dialogue_ui.call("_unhandled_input", _make_interact_event(true))
		dialogue_ui.call("_unhandled_input", _make_interact_event(false))
	if dialogue_ui.call("is_dialogue_active"):
		return _fail("NPC %s dialogue did not close." % npc.name)
	if player.call("is_control_locked"):
		return _fail("Player controls remained locked after speaking with NPC %s." % npc.name)

	return true


func _find_npcs(zone: Node) -> Array[Node2D]:
	var npcs: Array[Node2D] = []
	for node in zone.find_children("*", "", true, false):
		if node.is_in_group(&"npcs"):
			npcs.append(node as Node2D)
	return npcs


func _make_interact_event(is_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = is_pressed
	return event


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
