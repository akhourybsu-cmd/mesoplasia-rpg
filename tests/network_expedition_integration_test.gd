extends SceneTree

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")
const ExpeditionService := preload("res://scripts/server/expedition/expedition_service.gd")
const PartyService := preload("res://scripts/server/party/party_service.gd")

const ACCESS_CODE := "phase-f-test-access"
const WAIT_TIMEOUT_MSEC := 8000

var _harness: Node
var _server: Node
var _alice: Node
var _bob: Node
var _alice_party_result: Dictionary = {}
var _bob_party_result: Dictionary = {}
var _alice_expedition_result: Dictionary = {}
var _bob_expedition_result: Dictionary = {}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_harness = Node.new()
	_harness.name = "NetworkExpeditionIntegrationHarness"
	root.add_child(_harness)
	_server = _add_runtime("ServerRuntime")
	var port := _start_server_on_available_port()
	if port == 0:
		_fail("Could not allocate a loopback UDP port for Phase F.")
		return
	_alice = _add_client("AliceRuntime", "Alice", port)
	_bob = _add_client("BobRuntime", "Bob", port)
	if _alice == null or _bob == null:
		return
	if not await _wait_for(
		func() -> bool:
			return (
				_authenticated(_alice)
				and _authenticated(_bob)
				and not (_alice.call("get_expedition_snapshot") as Dictionary).is_empty()
				and not (_bob.call("get_expedition_snapshot") as Dictionary).is_empty()
			)
	):
		_fail("Two clients did not authenticate with initial expedition projections.")
		return
	var alice_identity := _alice.call("get_client_identity") as Dictionary
	var bob_identity := _bob.call("get_client_identity") as Dictionary
	if not await _form_ready_party(alice_identity, bob_identity):
		return
	await create_timer(1.05).timeout

	_clear_results()
	var party_revision := int((_bob.call("get_party_snapshot") as Dictionary).revision)
	_bob.call("send_expedition_launch", party_revision)
	if not await _wait_for(
		func() -> bool: return _bob_expedition_result.get("reason_code", "") == "NOT_LEADER"
	):
		_fail("A non-leader launch was not rejected over ENet.")
		return
	_clear_results()
	party_revision = int((_alice.call("get_party_snapshot") as Dictionary).revision)
	_alice.call("send_expedition_launch", party_revision)
	if not await _wait_for(func() -> bool: return _shared_expedition_state(ExpeditionService.STATE_LOADING)):
		_fail("Expedition reservation/load snapshot did not converge.")
		return
	var loading_snapshot := _alice.call("get_expedition_snapshot") as Dictionary
	var expedition_id := loading_snapshot.expedition_id as String
	var dungeon_instance_id := loading_snapshot.dungeon_instance_id as String
	if expedition_id.is_empty() or dungeon_instance_id.is_empty():
		_fail("Network launch did not deliver stable instance IDs.")
		return
	if (_alice.call("get_party_snapshot") as Dictionary).lifecycle_state != PartyService.STATE_EXPEDITION_RESERVED:
		_fail("Party projection did not enter expedition-reserved state.")
		return

	_clear_results()
	_alice.call(
		"send_expedition_content_ready", expedition_id, int(loading_snapshot.revision) - 1
	)
	if not await _wait_for(
		func() -> bool:
			return _alice_expedition_result.get("reason_code", "") == "STALE_REVISION"
	):
		_fail("Stale content-ready acknowledgement was not rejected.")
		return
	_clear_results()
	_alice.call(
		"send_expedition_content_ready", expedition_id, int(loading_snapshot.revision)
	)
	if not await _wait_for(
		func() -> bool:
			return _avatar_content_ready(_bob, alice_identity.character_id)
	):
		_fail("Alice's load acknowledgement did not converge.")
		return
	var bob_loading := _bob.call("get_expedition_snapshot") as Dictionary
	_bob.call(
		"send_expedition_content_ready", expedition_id, int(bob_loading.revision)
	)
	if not await _wait_for(
		func() -> bool:
			return (
				_shared_expedition_state(ExpeditionService.STATE_ACTIVE_EXPLORATION)
				and (_alice.call("get_party_snapshot") as Dictionary).get(
					"lifecycle_state", ""
				) == PartyService.STATE_IN_EXPEDITION
			)
	):
		_fail("Two-client load barrier did not commit exploration.")
		return
	var hub := _server.call("get_caden_hub_service_for_test") as RefCounted
	if (
		(hub.call("get_avatar_state", alice_identity.character_id) as Dictionary).connected
		or (hub.call("get_avatar_state", bob_identity.character_id) as Dictionary).connected
	):
		_fail("Committed expedition members remained active in Caden.")
		return

	var service := _server.call("get_expedition_service_for_test") as RefCounted
	var before := _server_avatar_position(service, expedition_id, alice_identity.character_id)
	var movement_observed := false
	for input_sequence in range(1, 31):
		if not _alice.call("send_expedition_movement", Vector2.RIGHT, input_sequence):
			_fail("Authenticated client refused to submit expedition movement.")
			return
		await physics_frame
		if _server_avatar_position(service, expedition_id, alice_identity.character_id).x > before.x:
			movement_observed = true
			break
	if not movement_observed:
		_fail(
			"Expedition movement was not routed to server exploration state. state=%s rejection=%s sessions=%s" % [
				service.call("get_instance_state", expedition_id),
				_alice.call("get_last_rejection"),
				_server_session_snapshots(),
			]
		)
		return
	_alice.call("send_expedition_movement", Vector2.ZERO, 31)
	if not await _wait_for(
		func() -> bool:
			var current := service.call("get_instance_state", expedition_id) as Dictionary
			var avatar := (current.avatars as Dictionary)[alice_identity.character_id] as Dictionary
			return (
				(avatar.velocity as Vector2).is_zero_approx()
				and _client_revision_matches_server(service, expedition_id)
			)
	):
		_fail("Expedition movement did not settle before the room command.")
		return

	var instance := service.call("get_instance_state", expedition_id) as Dictionary
	_clear_results()
	_bob.call(
		"send_expedition_room_transition",
		expedition_id,
		"development.connection.threshold_to_depths",
		(_bob.call("get_expedition_snapshot") as Dictionary).revision
	)
	if not await _wait_for(
		func() -> bool: return _bob_expedition_result.get("reason_code", "") == "NOT_LEADER"
	):
		_fail("Non-leader room transition was not rejected.")
		return
	service.call(
		"set_avatar_position_for_test",
		alice_identity.character_id,
		"development.room.test_threshold",
		Vector2(530, 180)
	)
	service.call(
		"set_avatar_position_for_test",
		bob_identity.character_id,
		"development.room.test_threshold",
		Vector2(550, 180)
	)
	_alice.call("request_expedition_snapshot")
	_bob.call("request_expedition_snapshot")
	if not await _wait_for(func() -> bool: return _client_revision_matches_server(service, expedition_id)):
		_fail("Clients did not resynchronize the cohesion setup revision.")
		return
	var alice_snapshot := _alice.call("get_expedition_snapshot") as Dictionary
	_alice.call(
		"send_expedition_room_transition",
		expedition_id,
		"development.connection.threshold_to_depths",
		alice_snapshot.revision
	)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_expedition_snapshot") as Dictionary).get(
					"current_room_id", ""
				) == "development.room.test_depths"
				and (_bob.call("get_expedition_snapshot") as Dictionary).get(
					"current_room_id", ""
				) == "development.room.test_depths"
			)
	):
		_fail("Shared-room transition did not converge.")
		return

	var bob_token := _bob.call("get_reconnect_token") as String
	_bob.call("stop")
	if not await _wait_for(
		func() -> bool:
			var current := service.call("get_instance_state", expedition_id) as Dictionary
			return not ((current.avatars as Dictionary)[bob_identity.character_id] as Dictionary).connected
	):
		_fail("Expedition disconnect was not recorded.")
		return
	_bob.queue_free()
	await process_frame
	_bob = _add_client("ReplacementBobRuntime", "Bob", port, bob_token, "")
	if _bob == null:
		return
	if not await _wait_for(
		func() -> bool:
			var identity := _bob.call("get_client_identity") as Dictionary
			var snapshot := _bob.call("get_expedition_snapshot") as Dictionary
			return (
				identity.get("character_id", "") == bob_identity.character_id
				and snapshot.get("expedition_id", "") == expedition_id
				and snapshot.get("dungeon_instance_id", "") == dungeon_instance_id
				and snapshot.get("current_room_id", "") == "development.room.test_depths"
			)
	):
		_fail("Reconnect did not reconstruct the same expedition instance and room.")
		return
	if (hub.call("get_avatar_state", bob_identity.character_id) as Dictionary).connected:
		_fail("Reconnected expedition member was incorrectly respawned in Caden.")
		return

	service.call(
		"set_avatar_position_for_test",
		alice_identity.character_id,
		"development.room.test_depths",
		Vector2(530, 180)
	)
	service.call(
		"set_avatar_position_for_test",
		bob_identity.character_id,
		"development.room.test_depths",
		Vector2(550, 180)
	)
	_alice.call("request_expedition_snapshot")
	_bob.call("request_expedition_snapshot")
	if not await _wait_for(func() -> bool: return _client_revision_matches_server(service, expedition_id)):
		_fail("Clients did not resynchronize the goal setup revision.")
		return
	_clear_results()
	alice_snapshot = _alice.call("get_expedition_snapshot") as Dictionary
	_alice.call(
		"send_expedition_stub_outcome",
		expedition_id,
		ExpeditionService.OUTCOME_SUCCESS,
		alice_snapshot.revision
	)
	if not await _wait_for(
		func() -> bool:
			return _shared_expedition_state(ExpeditionService.STATE_RETURNING_TO_CADEN)
	):
		_fail("Validated stub success did not begin Caden return.")
		return
	if not await _wait_for(
		func() -> bool:
			return (
				(hub.call("get_avatar_state", alice_identity.character_id) as Dictionary).connected
				and (hub.call("get_avatar_state", bob_identity.character_id) as Dictionary).connected
				and (hub.call("get_avatar_state", alice_identity.character_id) as Dictionary).zone_id
					== "wayfarers_approach"
			)
	):
		_fail("Return did not restore connected members to the authored Caden point.")
		return

	alice_snapshot = _alice.call("get_expedition_snapshot") as Dictionary
	_alice.call("send_expedition_return_ack", expedition_id, alice_snapshot.revision)
	if not await _wait_for(
		func() -> bool: return _avatar_return_acknowledged(_bob, alice_identity.character_id)
	):
		_fail("Alice's Caden return acknowledgement did not converge.")
		return
	var bob_return := _bob.call("get_expedition_snapshot") as Dictionary
	_bob.call("send_expedition_return_ack", expedition_id, bob_return.revision)
	if not await _wait_for(
		func() -> bool:
			return (
				_shared_expedition_state(ExpeditionService.STATE_CLOSED)
				and (_alice.call("get_party_snapshot") as Dictionary).get(
					"lifecycle_state", ""
				) == PartyService.STATE_FORMING
				and (_alice.call("get_party_snapshot") as Dictionary).get(
					"current_expedition_id", "not-cleared"
				).is_empty()
			)
	):
		_fail("Return acknowledgements did not close the instance and restore party state.")
		return
	var checkpoint_store := _server.call(
		"get_expedition_checkpoint_store_for_test"
	) as RefCounted
	var checkpoint := checkpoint_store.call("load_checkpoint", expedition_id) as Dictionary
	if checkpoint.get("lifecycle_state", "") != ExpeditionService.STATE_CLOSED:
		_fail("Final in-memory checkpoint did not record closure.")
		return

	_cleanup()
	print("PASS: Phase F ENet launch, load barrier, Caden transfer, movement, authority, room cohesion, reconnect, success, return, and cleanup.")
	quit(0)


func _form_ready_party(alice_identity: Dictionary, bob_identity: Dictionary) -> bool:
	_alice.call("send_party_invite", bob_identity.character_id, -1)
	if not await _wait_for(
		func() -> bool:
			return ((_bob.call("get_party_snapshot") as Dictionary).get("invitations", []) as Array).size() == 1
	):
		return _fail("Party invitation did not arrive before launch setup.")
	var invite := ((_bob.call("get_party_snapshot") as Dictionary).invitations as Array)[0] as Dictionary
	_bob.call("send_party_accept", invite.invite_id, invite.current_party_revision)
	if not await _wait_for(
		func() -> bool:
			return ((_alice.call("get_party_snapshot") as Dictionary).get("members", []) as Array).size() == 2
	):
		return _fail("Party acceptance did not converge before launch setup.")
	var snapshot := _alice.call("get_party_snapshot") as Dictionary
	_alice.call(
		"send_party_select_expedition", "development.expedition.placeholder", snapshot.revision
	)
	if not await _wait_for(
		func() -> bool:
			return (_bob.call("get_party_snapshot") as Dictionary).get(
				"selected_expedition_definition_id", ""
			) == "development.expedition.placeholder"
	):
		return _fail("Expedition selection did not converge before launch setup.")
	snapshot = _alice.call("get_party_snapshot") as Dictionary
	_alice.call("send_party_ready", true, snapshot.revision)
	if not await _wait_for(
		func() -> bool: return _party_member_ready(_bob, alice_identity.character_id)
	):
		return _fail("Alice readiness did not converge before launch setup.")
	snapshot = _bob.call("get_party_snapshot") as Dictionary
	_bob.call("send_party_ready", true, snapshot.revision)
	if not await _wait_for(
		func() -> bool:
			return (_alice.call("get_party_snapshot") as Dictionary).get(
				"all_present_members_ready", false
			)
	):
		return _fail("Party did not become launch-ready.")
	return true


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
		_fail("Loopback expedition client could not start: %s" % runtime_name)
		return null
	if display_label == "Alice":
		runtime.party_command_result_received.connect(_on_alice_party_result)
		runtime.expedition_command_result_received.connect(_on_alice_expedition_result)
	else:
		runtime.party_command_result_received.connect(_on_bob_party_result)
		runtime.expedition_command_result_received.connect(_on_bob_expedition_result)
	return runtime


func _start_server_on_available_port() -> int:
	var starting_port := 46000 + (Time.get_ticks_msec() % 6000)
	for offset in 32:
		var candidate := starting_port + offset
		if _server.call(
			"start_expedition_caden_server", candidate, ACCESS_CODE, 4, 2, 4000
		) == OK:
			return candidate
	return 0


func _authenticated(runtime: Node) -> bool:
	return not (runtime.call("get_client_identity") as Dictionary).is_empty()


func _shared_expedition_state(state: String) -> bool:
	var alice_snapshot := _alice.call("get_expedition_snapshot") as Dictionary
	var bob_snapshot := _bob.call("get_expedition_snapshot") as Dictionary
	return (
		alice_snapshot.get("lifecycle_state", "") == state
		and bob_snapshot.get("lifecycle_state", "") == state
		and alice_snapshot.get("expedition_id", "") == bob_snapshot.get("expedition_id", "missing")
		and alice_snapshot.get("revision", -1) == bob_snapshot.get("revision", -2)
	)


func _client_revision_matches_server(service: RefCounted, expedition_id: String) -> bool:
	var revision := int((service.call("get_instance_state", expedition_id) as Dictionary).revision)
	return (
		int((_alice.call("get_expedition_snapshot") as Dictionary).get("revision", -1)) == revision
		and int((_bob.call("get_expedition_snapshot") as Dictionary).get("revision", -1)) == revision
	)


func _server_avatar_position(
	service: RefCounted,
	expedition_id: String,
	character_id: String
) -> Vector2:
	var instance := service.call("get_instance_state", expedition_id) as Dictionary
	return ((instance.avatars as Dictionary)[character_id] as Dictionary).position as Vector2


func _server_session_snapshots() -> Array[Dictionary]:
	var coordinator := _server.call("get_session_coordinator_for_test") as RefCounted
	var snapshots: Array[Dictionary] = []
	for peer_id: int in coordinator.call("get_authenticated_peer_ids"):
		snapshots.append(coordinator.call("get_connection_snapshot", peer_id) as Dictionary)
	return snapshots


func _avatar_content_ready(runtime: Node, character_id: String) -> bool:
	return _avatar_flag(runtime, character_id, "content_ready")


func _avatar_return_acknowledged(runtime: Node, character_id: String) -> bool:
	return _avatar_flag(runtime, character_id, "return_acknowledged")


func _avatar_flag(runtime: Node, character_id: String, key: String) -> bool:
	for avatar_value: Variant in (
		(runtime.call("get_expedition_snapshot") as Dictionary).get("avatars", []) as Array
	):
		var avatar := avatar_value as Dictionary
		if avatar.get("character_id", "") == character_id:
			return avatar.get(key, false)
	return false


func _party_member_ready(runtime: Node, character_id: String) -> bool:
	for member_value: Variant in (
		(runtime.call("get_party_snapshot") as Dictionary).get("members", []) as Array
	):
		var member := member_value as Dictionary
		if member.get("character_id", "") == character_id:
			return member.get("ready", false)
	return false


func _clear_results() -> void:
	_alice_party_result.clear()
	_bob_party_result.clear()
	_alice_expedition_result.clear()
	_bob_expedition_result.clear()


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _cleanup() -> void:
	if _alice != null and is_instance_valid(_alice):
		_alice.call("stop")
	if _bob != null and is_instance_valid(_bob):
		_bob.call("stop")
	if _server != null and is_instance_valid(_server):
		_server.call("stop")
	if _harness != null and is_instance_valid(_harness):
		_harness.queue_free()


func _on_alice_party_result(result: Dictionary) -> void:
	_alice_party_result = result.duplicate(true)


func _on_bob_party_result(result: Dictionary) -> void:
	_bob_party_result = result.duplicate(true)


func _on_alice_expedition_result(result: Dictionary) -> void:
	_alice_expedition_result = result.duplicate(true)


func _on_bob_expedition_result(result: Dictionary) -> void:
	_bob_expedition_result = result.duplicate(true)


func _fail(message: String) -> bool:
	_cleanup()
	push_error(message)
	quit(1)
	return false
