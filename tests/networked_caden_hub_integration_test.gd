extends SceneTree

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")
const PresenterScene := preload("res://scenes/network/NetworkedCadenPresenter.tscn")
const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const ZoneRegistry := preload("res://scripts/world/caden_zone_registry.gd")

const ACCESS_CODE := "phase-d-test-access"
const WAIT_TIMEOUT_MSEC := 8000

var _harness: Node
var _server: Node
var _alice: Node
var _bob: Node
var _alice_presenter: Node
var _bob_presenter: Node
var _alice_interaction_result: Dictionary = {}
var _bob_interaction_result: Dictionary = {}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_harness = Node.new()
	_harness.name = "NetworkedCadenIntegrationHarness"
	root.add_child(_harness)
	_server = _add_runtime("ServerRuntime")
	var port := _start_server_on_available_port()
	if port == 0:
		_fail("Could not allocate a loopback UDP port for the Phase D server.")
		return
	_alice = _add_client("AliceRuntime", "Alice", port)
	_bob = _add_client("BobRuntime", "Bob", port)
	if _alice == null or _bob == null:
		return
	if not await _wait_for(func() -> bool: return _is_authenticated(_alice) and _is_authenticated(_bob)):
		_fail("Two Caden clients did not authenticate.")
		return
	if not await _wait_for(func() -> bool: return _same_zone_avatar_count(_alice, 2) and _same_zone_avatar_count(_bob, 2)):
		_fail("Two clients did not receive the same-zone authoritative snapshot.")
		return

	_alice_presenter = _add_presenter("AlicePresenter", _alice)
	_bob_presenter = _add_presenter("BobPresenter", _bob)
	if not await _wait_for(
		func() -> bool:
			return (
				_alice_presenter.call("get_presented_avatar_count") == 2
				and _bob_presenter.call("get_presented_avatar_count") == 2
			)
	):
		_fail("Client presenters did not project both same-zone avatars.")
		return
	if not await _wait_for(func() -> bool: return _presentation_ownership_is_exclusive(_alice, _alice_presenter)):
		_fail("Remote network presentation retained local-only camera or UI nodes.")
		return
	if not _verify_local_and_remote_presentation(_alice, _alice_presenter):
		return

	var alice_identity := _alice.call("get_client_identity") as Dictionary
	var bob_identity := _bob.call("get_client_identity") as Dictionary
	var hub := _server.call("get_caden_hub_service_for_test") as RefCounted
	var alice_before := hub.call("get_avatar_state", alice_identity.character_id) as Dictionary
	Input.action_press("move_right")
	var moved_initially := await _wait_for_msec(
		func() -> bool:
			var state := hub.call("get_avatar_state", alice_identity.character_id) as Dictionary
			return (state.position as Vector2).x > (alice_before.position as Vector2).x,
		750
	)
	Input.action_release("move_right")
	if not moved_initially:
		_fail("Server authority did not advance Alice from cardinal input.")
		return
	if not await _wait_for(
		func() -> bool:
			return _snapshot_position(_alice, alice_identity.character_id).x > (alice_before.position as Vector2).x
	):
		_fail("Authoritative movement did not converge on Alice's client snapshot.")
		return

	var malformed_movement := Protocol.make_client_envelope(
		Protocol.MOVEMENT_INPUT,
		alice_identity.session_id,
		"development.movement.diagonal",
		2,
		{"input_sequence": 2, "direction_x": 1, "direction_y": 1}
	)
	_alice.call("send_raw_movement_envelope_for_test", malformed_movement)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_last_rejection") as Dictionary).get("reason_code", "")
				== Protocol.REASON_MALFORMED
			)
	):
		_fail("Malformed diagonal movement was not rejected across ENet.")
		return

	var registry := ZoneRegistry.new()
	var route := registry.get_exit_route(
		"wayfarers_approach", "caden.exit.wayfarers_approach.to_town_square"
	)
	hub.call(
		"set_avatar_position_for_test",
		alice_identity.character_id,
		"wayfarers_approach",
		(route.activation_rect as Rect2).get_center()
	)
	if not await _wait_for(func() -> bool: return not _snapshot_position(_alice, alice_identity.character_id).is_zero_approx()):
		_fail("Alice did not receive the server-positioned transfer setup snapshot.")
		return
	if not _alice.call(
		"send_hub_zone_transition", "caden.exit.wayfarers_approach.to_town_square"
	):
		_fail("Alice could not submit a zone transition request.")
		return
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_hub_snapshot") as Dictionary).get("zone_id", "") == "town_square"
				and (_bob.call("get_hub_snapshot") as Dictionary).get("zone_id", "") == "wayfarers_approach"
				and _alice_presenter.call("get_current_zone_id") == "town_square"
				and _bob_presenter.call("get_current_zone_id") == "wayfarers_approach"
			)
	):
		_fail("One client's zone transfer did not remain independent from the other client.")
		return
	if not _same_zone_avatar_count(_alice, 1) or not _same_zone_avatar_count(_bob, 1):
		_fail("Zone-scoped snapshots leaked an avatar from another zone.")
		return

	var interaction := registry.get_interactable(
		"town_square", "caden.interactable.town_square.square_local"
	)
	var interaction_position := (interaction.activation_rect as Rect2).get_center()
	hub.call("set_avatar_position_for_test", alice_identity.character_id, "town_square", interaction_position)
	hub.call("set_avatar_position_for_test", bob_identity.character_id, "town_square", interaction_position)
	if not await _wait_for(func() -> bool: return _same_zone_avatar_count(_alice, 2) and _same_zone_avatar_count(_bob, 2)):
		_fail("Clients did not converge after joining the same zone again.")
		return
	_alice_interaction_result.clear()
	_bob_interaction_result.clear()
	_alice.call("send_hub_interaction", "caden.interactable.town_square.square_local")
	_bob.call("send_hub_interaction", "caden.interactable.town_square.square_local")
	if not await _wait_for(
		func() -> bool:
			return (
				_alice_interaction_result.get("accepted", false)
				and _bob_interaction_result.get("accepted", false)
			)
	):
		_fail("Server did not accept two player-scoped interactions with the same NPC.")
		return

	if not await _wait_for(func() -> bool: return _npc_snapshots_match(_alice, _bob)):
		_fail("Server-owned patrol projections did not converge across clients.")
		return

	var safe_position := registry.get_entry_position("town_square", "from_wayfarers_approach")
	hub.call(
		"set_avatar_position_for_test",
		alice_identity.character_id,
		"town_square",
		safe_position
	)
	var alice_reconnect_token := _alice.call("get_reconnect_token") as String
	var safe_state := hub.call("get_avatar_state", alice_identity.character_id) as Dictionary
	_remove_presenter(_alice_presenter)
	_alice_presenter = null
	_alice.call("stop")
	if not await _wait_for(func() -> bool: return _same_zone_avatar_count(_bob, 1)):
		_fail("Remaining client did not lose the disconnected hub avatar.")
		return
	_alice.queue_free()
	await process_frame
	_alice = _add_client("ReplacementAliceRuntime", "Alice", port, alice_reconnect_token, "")
	if _alice == null:
		return
	if not await _wait_for(func() -> bool: return _is_authenticated(_alice)):
		_fail("Alice could not reconnect with the server-issued token.")
		return
	var replacement_identity := _alice.call("get_client_identity") as Dictionary
	if (
		replacement_identity.character_id != alice_identity.character_id
		or replacement_identity.account_id != alice_identity.account_id
		or replacement_identity.session_id == alice_identity.session_id
	):
		_fail("Reconnect did not preserve stable identity while rotating transient identity.")
		return
	if not await _wait_for(
		func() -> bool:
			var snapshot := _alice.call("get_hub_snapshot") as Dictionary
			return (
				snapshot.get("zone_id", "") == safe_state.zone_id
				and _snapshot_position(_alice, replacement_identity.character_id).distance_to(safe_state.position) < 0.5
			)
	):
		_fail("Reconnect did not restore the safe server-owned Caden location.")
		return
	_alice_presenter = _add_presenter("ReplacementAlicePresenter", _alice)
	if not await _wait_for(func() -> bool: return _alice_presenter.call("get_presented_avatar_count") == 2):
		_fail("Join-in-progress presenter did not reconstruct the current zone snapshot.")
		return
	var reconnect_position := (
		hub.call("get_avatar_state", replacement_identity.character_id) as Dictionary
	).position as Vector2
	Input.action_press("move_right")
	var moved_after_reconnect := await _wait_for_msec(
		func() -> bool:
			var state := hub.call(
				"get_avatar_state", replacement_identity.character_id
			) as Dictionary
			return (state.position as Vector2).x > reconnect_position.x,
		750
	)
	Input.action_release("move_right")
	if not moved_after_reconnect:
		_fail("Replacement presenter's fresh movement sequence did not move the reconnected avatar.")
		return

	_cleanup()
	print("PASS: Phase D ENet authority, presentation, movement, independent transfer, concurrent interaction, NPC convergence, and reconnect.")
	quit(0)


func _add_runtime(runtime_name: String) -> Node:
	var runtime := NetworkRuntimeScene.instantiate()
	runtime.name = runtime_name
	_harness.add_child(runtime)
	return runtime


func _add_client(
	runtime_name: String,
	display_label: String,
	port: int,
	reconnect_token: String = "",
	access_code: String = ACCESS_CODE
) -> Node:
	var runtime := _add_runtime(runtime_name)
	if runtime.call(
		"start_client", "127.0.0.1", port, access_code, display_label, reconnect_token
	) != OK:
		_fail("Loopback client could not start: %s" % runtime_name)
		return null
	if display_label == "Alice":
		runtime.interaction_result_received.connect(_on_alice_interaction_result)
	elif display_label == "Bob":
		runtime.interaction_result_received.connect(_on_bob_interaction_result)
	return runtime


func _add_presenter(presenter_name: String, runtime: Node) -> Node:
	var presenter := PresenterScene.instantiate()
	presenter.name = presenter_name
	_harness.add_child(presenter)
	if not presenter.call("configure", runtime):
		_fail("Networked Caden presenter could not be configured: %s" % presenter_name)
	return presenter


func _start_server_on_available_port() -> int:
	var starting_port := 42000 + (Time.get_ticks_msec() % 10000)
	for offset in 32:
		var candidate := starting_port + offset
		if _server.call("start_caden_server", candidate, ACCESS_CODE, 4) == OK:
			return candidate
	return 0


func _is_authenticated(runtime: Node) -> bool:
	return not (runtime.call("get_client_identity") as Dictionary).is_empty()


func _same_zone_avatar_count(runtime: Node, expected_count: int) -> bool:
	var snapshot := runtime.call("get_hub_snapshot") as Dictionary
	return not snapshot.is_empty() and (snapshot.get("avatars", []) as Array).size() == expected_count


func _snapshot_position(runtime: Node, character_id: String) -> Vector2:
	var snapshot := runtime.call("get_hub_snapshot") as Dictionary
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar := avatar_value as Dictionary
		if avatar.get("character_id", "") == character_id:
			return Vector2(float(avatar.position_x), float(avatar.position_y))
	return Vector2.ZERO


func _verify_local_and_remote_presentation(runtime: Node, presenter: Node) -> bool:
	var local_character_id := (runtime.call("get_client_identity") as Dictionary).character_id as String
	var local_count := 0
	var remote_count := 0
	var local_avatar: CharacterBody2D
	var remote_avatar: CharacterBody2D
	for avatar_value: Variant in (runtime.call("get_hub_snapshot") as Dictionary).avatars:
		var avatar_snapshot := avatar_value as Dictionary
		var avatar := presenter.call(
			"get_presented_avatar", avatar_snapshot.character_id
		) as CharacterBody2D
		if avatar == null or avatar.get("uses_local_movement_simulation"):
			return _fail("Presented avatar retained client-owned movement simulation.")
		if avatar_snapshot.character_id == local_character_id and avatar.call("is_locally_controlled"):
			local_count += 1
			local_avatar = avatar
		elif not avatar.call("is_locally_controlled"):
			remote_count += 1
			remote_avatar = avatar
	if local_count != 1 or remote_count != 1:
		return _fail("Presenter did not create exactly one local and one remote avatar.")
	if (
		local_avatar.find_children("*", "Camera2D", true, false).size() != 1
		or local_avatar.find_children("*", "CanvasLayer", true, false).size() != 2
		or remote_avatar.find_children("*", "Camera2D", true, false).size() != 0
		or remote_avatar.find_children("*", "CanvasLayer", true, false).size() != 0
	):
		return _fail(
			"Network presentation ownership mismatch (local cameras=%d UI=%d, remote cameras=%d UI=%d)." % [
				local_avatar.find_children("*", "Camera2D", true, false).size(),
				local_avatar.find_children("*", "CanvasLayer", true, false).size(),
				remote_avatar.find_children("*", "Camera2D", true, false).size(),
				remote_avatar.find_children("*", "CanvasLayer", true, false).size(),
			]
		)
	return true


func _presentation_ownership_is_exclusive(runtime: Node, presenter: Node) -> bool:
	var local_character_id := (runtime.call("get_client_identity") as Dictionary).character_id as String
	var local_avatar := presenter.call("get_presented_avatar", local_character_id) as CharacterBody2D
	if local_avatar == null:
		return false
	if (
		local_avatar.find_children("*", "Camera2D", true, false).size() != 1
		or local_avatar.find_children("*", "CanvasLayer", true, false).size() != 2
	):
		return false
	for avatar_value: Variant in (runtime.call("get_hub_snapshot") as Dictionary).avatars:
		var snapshot := avatar_value as Dictionary
		if snapshot.character_id == local_character_id:
			continue
		var remote := presenter.call("get_presented_avatar", snapshot.character_id) as CharacterBody2D
		if remote == null:
			return false
		if (
			remote.find_children("*", "Camera2D", true, false).size() != 0
			or remote.find_children("*", "CanvasLayer", true, false).size() != 0
		):
			return false
	return true


func _npc_snapshots_match(first: Node, second: Node) -> bool:
	var first_snapshot := first.call("get_hub_snapshot") as Dictionary
	var second_snapshot := second.call("get_hub_snapshot") as Dictionary
	if (
		first_snapshot.is_empty()
		or second_snapshot.is_empty()
		or first_snapshot.server_tick != second_snapshot.server_tick
		or (first_snapshot.npcs as Array).is_empty()
		or (first_snapshot.npcs as Array).size() != (second_snapshot.npcs as Array).size()
	):
		return false
	var first_npc := first_snapshot.npcs[0] as Dictionary
	var second_npc := second_snapshot.npcs[0] as Dictionary
	return (
		first_npc.npc_id == second_npc.npc_id
		and is_equal_approx(first_npc.position_x, second_npc.position_x)
		and is_equal_approx(first_npc.position_y, second_npc.position_y)
	)


func _wait_for(predicate: Callable) -> bool:
	return await _wait_for_msec(predicate, WAIT_TIMEOUT_MSEC)


func _wait_for_msec(predicate: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _remove_presenter(presenter: Node) -> void:
	if presenter != null and is_instance_valid(presenter):
		presenter.queue_free()


func _cleanup() -> void:
	_remove_presenter(_alice_presenter)
	_remove_presenter(_bob_presenter)
	if _alice != null and is_instance_valid(_alice):
		_alice.call("stop")
	if _bob != null and is_instance_valid(_bob):
		_bob.call("stop")
	if _server != null and is_instance_valid(_server):
		_server.call("stop")
	_harness.queue_free()


func _on_alice_interaction_result(result: Dictionary) -> void:
	_alice_interaction_result = result.duplicate(true)


func _on_bob_interaction_result(result: Dictionary) -> void:
	_bob_interaction_result = result.duplicate(true)


func _fail(message: String) -> bool:
	_cleanup()
	push_error(message)
	quit(1)
	return false
