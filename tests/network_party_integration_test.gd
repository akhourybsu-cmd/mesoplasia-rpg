extends SceneTree

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")

const ACCESS_CODE := "phase-e-test-access"
const EXPEDITION_ID := "development.expedition.placeholder"
const WAIT_TIMEOUT_MSEC := 8000

var _harness: Node
var _server: Node
var _alice: Node
var _bob: Node
var _alice_result: Dictionary = {}
var _bob_result: Dictionary = {}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_harness = Node.new()
	_harness.name = "NetworkPartyIntegrationHarness"
	root.add_child(_harness)
	_server = _add_runtime("ServerRuntime")
	var port := _start_server_on_available_port()
	if port == 0:
		_fail("Could not allocate a loopback UDP port for the Phase E server.")
		return
	_alice = _add_client("AliceRuntime", "Alice", port)
	_bob = _add_client("BobRuntime", "Bob", port)
	if _alice == null or _bob == null:
		return
	if not await _wait_for(
		func() -> bool:
			return (
				_is_authenticated(_alice)
				and _is_authenticated(_bob)
				and not (_alice.call("get_party_snapshot") as Dictionary).is_empty()
				and not (_bob.call("get_party_snapshot") as Dictionary).is_empty()
			)
	):
		_fail("Two party clients did not authenticate and receive initial projections.")
		return

	var alice_identity := _alice.call("get_client_identity") as Dictionary
	var bob_identity := _bob.call("get_client_identity") as Dictionary
	_clear_results()
	if not _alice.call("send_party_invite", bob_identity.character_id, -1):
		_fail("Alice could not submit an invitation.")
		return
	if not await _wait_for(
		func() -> bool:
			return (
				_alice_result.get("accepted", false)
				and (_bob.call("get_party_snapshot") as Dictionary).get("invitations", []).size() == 1
			)
	):
		_fail("The server did not deliver Alice's invitation to Bob.")
		return
	var invitation := (
		((_bob.call("get_party_snapshot") as Dictionary).invitations as Array)[0]
	) as Dictionary
	var invite_id := invitation.invite_id as String
	var invite_revision := int(invitation.current_party_revision)

	_clear_results()
	_alice.call("send_party_accept", invite_id, invite_revision)
	if not await _wait_for(
		func() -> bool: return _alice_result.get("reason_code", "") == "INVALID_INVITE"
	):
		_fail("A client accepted an invitation bound to another character.")
		return
	if not (_alice.call("get_party_snapshot") as Dictionary).get("members", []).size() == 1:
		_fail("Forged invitation acceptance mutated party membership.")
		return

	_clear_results()
	_bob.call("send_party_accept", invite_id, invite_revision - 1)
	if not await _wait_for(
		func() -> bool: return _bob_result.get("reason_code", "") == "STALE_REVISION"
	):
		_fail("A stale invitation acceptance was not rejected over ENet.")
		return

	_clear_results()
	_bob.call("send_party_accept", invite_id, invite_revision)
	if not await _wait_for(func() -> bool: return _clients_share_party(2)):
		_fail("Invitation acceptance did not converge a two-member party.")
		return
	var party_id := (_alice.call("get_party_snapshot") as Dictionary).party_id as String

	_clear_results()
	var revision := int((_bob.call("get_party_snapshot") as Dictionary).revision)
	_bob.call("send_party_select_expedition", EXPEDITION_ID, revision)
	if not await _wait_for(
		func() -> bool: return _bob_result.get("reason_code", "") == "NOT_LEADER"
	):
		_fail("A non-leader selected the expedition placeholder.")
		return

	_clear_results()
	revision = int((_alice.call("get_party_snapshot") as Dictionary).revision)
	_alice.call("send_party_select_expedition", EXPEDITION_ID, revision)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_party_snapshot") as Dictionary).get(
					"selected_expedition_definition_id", ""
				) == EXPEDITION_ID
				and (_bob.call("get_party_snapshot") as Dictionary).get(
					"selected_expedition_definition_id", ""
				) == EXPEDITION_ID
			)
	):
		_fail("Leader expedition selection did not converge.")
		return

	revision = int((_alice.call("get_party_snapshot") as Dictionary).revision)
	_alice.call("send_party_ready", true, revision)
	if not await _wait_for(
		func() -> bool: return _member_ready(_bob, alice_identity.character_id)
	):
		_fail("Alice's readiness did not converge on Bob.")
		return
	revision = int((_bob.call("get_party_snapshot") as Dictionary).revision)
	_bob.call("send_party_ready", true, revision)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_party_snapshot") as Dictionary).get(
					"all_present_members_ready", false
				)
				and (_bob.call("get_party_snapshot") as Dictionary).get(
					"all_present_members_ready", false
				)
			)
	):
		_fail("All-present readiness did not converge.")
		return

	var bob_reconnect_token := _bob.call("get_reconnect_token") as String
	_bob.call("stop")
	if not await _wait_for(
		func() -> bool:
			return (
				_member_connected(_alice, bob_identity.character_id) == false
				and not _member_ready(_alice, bob_identity.character_id)
				and (_alice.call("get_party_snapshot") as Dictionary).party_id == party_id
			)
	):
		_fail("Disconnect did not preserve membership while clearing readiness.")
		return
	_bob.queue_free()
	await process_frame
	_bob = _add_client("ReplacementBobRuntime", "Bob", port, bob_reconnect_token, "")
	if _bob == null:
		return
	if not await _wait_for(
		func() -> bool:
			return (
				_is_authenticated(_bob)
				and (_bob.call("get_client_identity") as Dictionary).get("character_id", "")
					== bob_identity.character_id
				and (_bob.call("get_party_snapshot") as Dictionary).get("party_id", "") == party_id
				and _member_connected(_alice, bob_identity.character_id)
			)
	):
		_fail("Reconnect within grace did not restore stable party membership.")
		return
	if _member_ready(_bob, bob_identity.character_id):
		_fail("Reconnect incorrectly restored the disconnected member's stale readiness.")
		return

	_clear_results()
	revision = int((_alice.call("get_party_snapshot") as Dictionary).revision)
	_alice.call("send_party_transfer_leadership", bob_identity.character_id, revision)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_party_snapshot") as Dictionary).get("leader_character_id", "")
					== bob_identity.character_id
				and (_bob.call("get_party_snapshot") as Dictionary).get("leader_character_id", "")
					== bob_identity.character_id
			)
	):
		_fail("Explicit leadership transfer did not converge.")
		return

	revision = int((_alice.call("get_party_snapshot") as Dictionary).revision)
	_alice.call("send_party_leave", revision)
	if not await _wait_for(
		func() -> bool:
			return (
				(_alice.call("get_party_snapshot") as Dictionary).get("party_id", "").is_empty()
				and (_bob.call("get_party_snapshot") as Dictionary).get("members", []).size() == 1
			)
	):
		_fail("Leaving did not converge the former member and remaining party.")
		return
	revision = int((_bob.call("get_party_snapshot") as Dictionary).revision)
	_bob.call("send_party_leave", revision)
	if not await _wait_for(
		func() -> bool:
			return (
				(_bob.call("get_party_snapshot") as Dictionary).get("party_id", "").is_empty()
				and (_server.call("get_party_service_for_test") as RefCounted).call(
					"get_active_party_count"
				) == 0
			)
	):
		_fail("Final-member departure did not disband the ephemeral party.")
		return

	_cleanup()
	print("PASS: Phase E ENet invites, identity binding, stale revisions, leader authority, readiness, reconnect grace, transfer, and disband.")
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
		_fail("Loopback party client could not start: %s" % runtime_name)
		return null
	if display_label == "Alice":
		runtime.party_command_result_received.connect(_on_alice_result)
	else:
		runtime.party_command_result_received.connect(_on_bob_result)
	return runtime


func _start_server_on_available_port() -> int:
	var starting_port := 44000 + (Time.get_ticks_msec() % 8000)
	for offset in 32:
		var candidate := starting_port + offset
		if _server.call(
			"start_party_caden_server", candidate, ACCESS_CODE, 4, 2, 2000, 4000
		) == OK:
			return candidate
	return 0


func _is_authenticated(runtime: Node) -> bool:
	return not (runtime.call("get_client_identity") as Dictionary).is_empty()


func _clients_share_party(expected_member_count: int) -> bool:
	var alice_snapshot := _alice.call("get_party_snapshot") as Dictionary
	var bob_snapshot := _bob.call("get_party_snapshot") as Dictionary
	return (
		not alice_snapshot.get("party_id", "").is_empty()
		and alice_snapshot.party_id == bob_snapshot.get("party_id", "")
		and (alice_snapshot.get("members", []) as Array).size() == expected_member_count
		and (bob_snapshot.get("members", []) as Array).size() == expected_member_count
		and alice_snapshot.revision == bob_snapshot.get("revision", -2)
	)


func _member_ready(runtime: Node, character_id: String) -> bool:
	for member_value: Variant in (_party_members(runtime)):
		var member := member_value as Dictionary
		if member.get("character_id", "") == character_id:
			return member.get("ready", false)
	return false


func _member_connected(runtime: Node, character_id: String) -> bool:
	for member_value: Variant in (_party_members(runtime)):
		var member := member_value as Dictionary
		if member.get("character_id", "") == character_id:
			return member.get("connected", false)
	return false


func _party_members(runtime: Node) -> Array:
	return (_runtime_party_snapshot(runtime).get("members", []) as Array)


func _runtime_party_snapshot(runtime: Node) -> Dictionary:
	if runtime == null or not is_instance_valid(runtime):
		return {}
	return runtime.call("get_party_snapshot") as Dictionary


func _clear_results() -> void:
	_alice_result.clear()
	_bob_result.clear()


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


func _on_alice_result(result: Dictionary) -> void:
	_alice_result = result.duplicate(true)


func _on_bob_result(result: Dictionary) -> void:
	_bob_result = result.duplicate(true)


func _fail(message: String) -> bool:
	_cleanup()
	push_error(message)
	quit(1)
	return false
