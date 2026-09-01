extends SceneTree

const ZoneRegistry := preload("res://scripts/world/caden_zone_registry.gd")
const HubService := preload("res://scripts/server/hub/caden_hub_service.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var registry := ZoneRegistry.new()
	if not _verify_registry(registry):
		return
	var hub := HubService.new()
	if not hub.configure(registry):
		_fail("Authoritative Caden hub rejected the five-zone registry.")
		return
	if not _verify_avatar_movement_transfer_interaction_and_reconnect(registry, hub):
		return
	if not _verify_server_patrol_state(hub):
		return
	print("PASS: Phase D five-zone authoritative hub, movement, transfer, interaction, patrol, and reconnect domain.")
	quit(0)


func _verify_registry(registry: RefCounted) -> bool:
	if not registry.call("is_valid"):
		return _fail("Caden zone registry is invalid.")
	if (registry.call("get_zone_ids") as Array).size() != 5:
		return _fail("Caden zone registry does not expose exactly five zones.")
	var exit_count := 0
	var interactable_count := 0
	var patrol_count := 0
	for zone_id: String in registry.call("get_zone_ids"):
		var scene := registry.call("get_zone_scene", zone_id) as PackedScene
		if scene == null or not (registry.call("get_camera_bounds", zone_id) as Rect2i).has_area():
			return _fail("Registered Caden zone has no scene or bounds: %s" % zone_id)
		var zone := scene.instantiate() as Node2D
		for node: Node in zone.find_children("*", "Area2D", true, false):
			if node.get_script() != null and node.get_script().resource_path.ends_with("zone_exit.gd"):
				exit_count += 1
			elif node.has_method("get_interactable_id"):
				interactable_count += 1
		zone.free()
		patrol_count += (registry.call("get_patrol_definitions", zone_id) as Array).size()
		if (registry.call("get_collision_rectangles", zone_id) as Array).is_empty():
			return _fail("Registered Caden zone exposes no server collision rectangles: %s" % zone_id)
	if exit_count != 12 or interactable_count != 11 or patrol_count != 14:
		return _fail(
			"Registry count mismatch: %d exits, %d interactables, %d patrol NPCs." % [
				exit_count, interactable_count, patrol_count
			]
		)
	return true


func _verify_avatar_movement_transfer_interaction_and_reconnect(
	registry: RefCounted,
	hub: RefCounted
) -> bool:
	var alice := _identity("development.account.1", "development.character.1", "development.session.1", "development.avatar_runtime.1", "Alice")
	var bob := _identity("development.account.2", "development.character.2", "development.session.2", "development.avatar_runtime.2", "Bob")
	if not (hub.call("attach_avatar", alice, 0) as Dictionary).accepted:
		return _fail("Hub did not attach Alice.")
	if not (hub.call("attach_avatar", bob, 0) as Dictionary).accepted:
		return _fail("Hub did not attach Bob.")
	if (hub.call("get_snapshot_for", alice.character_id) as Dictionary).avatars.size() != 2:
		return _fail("Same-zone full snapshot did not contain both attached avatars.")

	var diagonal := hub.call(
		"submit_movement_input", alice.character_id, 1, Vector2(1, 1), 1
	) as Dictionary
	if diagonal.accepted or diagonal.reason_code != "INVALID_MOVEMENT":
		return _fail("Server accepted diagonal/non-cardinal movement input.")
	var before := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if not (hub.call(
		"submit_movement_input", alice.character_id, 2, Vector2.RIGHT, 2
	) as Dictionary).accepted:
		return _fail("Server rejected valid cardinal movement input.")
	hub.call("tick", 0.05, 20)
	var after := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if (after.position as Vector2).is_equal_approx(before.position):
		return _fail("Server-authoritative movement did not advance the avatar.")
	if (hub.call(
		"submit_movement_input", alice.character_id, 2, Vector2.LEFT, 21
	) as Dictionary).reason_code != "STALE_SEQUENCE":
		return _fail("Server did not reject stale movement input.")

	var route := registry.call(
		"get_exit_route",
		"wayfarers_approach",
		"caden.exit.wayfarers_approach.to_town_square"
	) as Dictionary
	if route.is_empty():
		return _fail("Wayfarer's Approach transition route is absent from the registry.")
	var forged_transfer := hub.call(
		"request_zone_transition", alice.character_id, "caden.exit.marketplace.to_town_square"
	) as Dictionary
	if forged_transfer.accepted or forged_transfer.reason_code != "INVALID_EXIT":
		return _fail("Server accepted an exit ID from another zone.")
	var distant_transfer := hub.call(
		"request_zone_transition",
		alice.character_id,
		"caden.exit.wayfarers_approach.to_town_square"
	) as Dictionary
	if distant_transfer.accepted or distant_transfer.reason_code != "OUT_OF_RANGE":
		return _fail("Server accepted a valid exit ID while the avatar was out of range.")
	hub.call(
		"set_avatar_position_for_test",
		alice.character_id,
		"wayfarers_approach",
		(route.activation_rect as Rect2).get_center()
	)
	var transfer := hub.call(
		"request_zone_transition",
		alice.character_id,
		"caden.exit.wayfarers_approach.to_town_square"
	) as Dictionary
	if not transfer.accepted or transfer.zone_id != "town_square":
		return _fail("Validated server transition did not move Alice to Town Square.")
	if (hub.call("get_avatar_state", bob.character_id) as Dictionary).zone_id != "wayfarers_approach":
		return _fail("Alice's transition changed Bob's authoritative zone.")
	if (hub.call("get_snapshot_for", alice.character_id) as Dictionary).avatars.size() != 1:
		return _fail("Town Square snapshot leaked the avatar in another zone.")
	if (hub.call("get_snapshot_for", bob.character_id) as Dictionary).avatars.size() != 1:
		return _fail("Wayfarer's snapshot leaked the transferred avatar.")

	var interaction := registry.call(
		"get_interactable", "town_square", "caden.interactable.town_square.square_local"
	) as Dictionary
	var interaction_position := (interaction.activation_rect as Rect2).get_center()
	hub.call("set_avatar_position_for_test", alice.character_id, "town_square", interaction_position)
	hub.call("set_avatar_position_for_test", bob.character_id, "town_square", interaction_position)
	if not (hub.call(
		"request_interaction", alice.character_id, "caden.interactable.town_square.square_local"
	) as Dictionary).accepted:
		return _fail("Alice's valid concurrent interaction was rejected.")
	if not (hub.call(
		"request_interaction", bob.character_id, "caden.interactable.town_square.square_local"
	) as Dictionary).accepted:
		return _fail("Bob's valid concurrent interaction was rejected.")
	if (hub.call(
		"request_interaction", alice.character_id, "caden.interactable.marketplace.market_shopper"
	) as Dictionary).accepted:
		return _fail("Server accepted an interactable from the wrong zone.")

	hub.call(
		"set_avatar_position_for_test",
		alice.character_id,
		"town_square",
		registry.call("get_entry_position", "town_square", "from_wayfarers_approach") as Vector2
	)
	var safe_state := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if not hub.call("detach_avatar", alice.character_id):
		return _fail("Hub did not detach Alice for reconnect.")
	var replacement := _identity(
		alice.account_id,
		alice.character_id,
		"development.session.20",
		"development.avatar_runtime.20",
		"Alice"
	)
	var reconnect := hub.call("attach_avatar", replacement, 500) as Dictionary
	var reconnected_state := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if not reconnect.accepted or not reconnect.reconnected:
		return _fail("Hub did not recognize Alice's replacement peer as a reconnect.")
	if reconnected_state.zone_id != safe_state.zone_id or not (reconnected_state.position as Vector2).is_equal_approx(safe_state.position):
		return _fail("Safe reconnect did not retain the server-owned Caden location.")
	if reconnected_state.session_id == safe_state.session_id:
		return _fail("Safe reconnect retained the transient session ID.")
	var reconnect_position := reconnected_state.position as Vector2
	var reconnect_movement := hub.call(
		"submit_movement_input", alice.character_id, 1, Vector2.RIGHT, 501
	) as Dictionary
	hub.call("tick", 0.05, 510)
	var moved_reconnect_state := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if (
		not reconnect_movement.accepted
		or (moved_reconnect_state.position as Vector2).is_equal_approx(reconnect_position)
	):
		return _fail("Replacement session could not restart movement input sequencing at one.")
	var blocked_position := (
		(registry.call("get_collision_rectangles", "town_square") as Array)[0] as Rect2
	).get_center()
	hub.call("set_avatar_position_for_test", alice.character_id, "town_square", blocked_position)
	hub.call("detach_avatar", alice.character_id)
	var sanitized_reconnect := hub.call(
		"attach_avatar",
		_identity(
			alice.account_id,
			alice.character_id,
			"development.session.21",
			"development.avatar_runtime.21",
			"Alice"
		),
		600
	) as Dictionary
	var sanitized_state := hub.call("get_avatar_state", alice.character_id) as Dictionary
	if (
		not sanitized_reconnect.accepted
		or sanitized_state.zone_id != ZoneRegistry.STARTING_ZONE
		or not (sanitized_state.position as Vector2).is_equal_approx(
			registry.call(
				"get_entry_position", ZoneRegistry.STARTING_ZONE, ZoneRegistry.STARTING_ENTRY
			) as Vector2
		)
	):
		return _fail("Reconnect did not replace an unsafe retained location with the safe start.")
	return true


func _verify_server_patrol_state(hub: RefCounted) -> bool:
	var npc_id := "caden.npc.town_square.north_plaza_walker"
	var before := hub.call("get_npc_state", "town_square", npc_id) as Dictionary
	for index in 30:
		hub.call("tick", 0.1, 1000 + index * 100)
	var after := hub.call("get_npc_state", "town_square", npc_id) as Dictionary
	if before.is_empty() or after.is_empty():
		return _fail("Server patrol state is missing for an authored Town Square NPC.")
	if (before.position as Vector2).is_equal_approx(after.position):
		return _fail("Server-owned Town Square patrol state did not advance.")
	var snapshot := hub.call("get_snapshot_for", "development.character.2") as Dictionary
	if snapshot.npcs.is_empty():
		return _fail("Hub snapshot contains no server-owned patrol projections.")
	return true


func _identity(
	account_id: String,
	character_id: String,
	session_id: String,
	avatar_runtime_id: String,
	display_label: String
) -> Dictionary:
	return {
		"account_id": account_id,
		"character_id": character_id,
		"session_id": session_id,
		"avatar_runtime_id": avatar_runtime_id,
		"display_label": display_label,
	}


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
