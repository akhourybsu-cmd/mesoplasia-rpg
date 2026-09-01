extends SceneTree

const NETWORK_RUNTIME_SCENE := preload("res://scenes/network/NetworkRuntime.tscn")
const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")

const ACCESS_CODE := "phase-c-test-access"
const WAIT_TIMEOUT_MSEC := 6000

var _harness: Node
var _server: Node
var _client_one: Node
var _client_two: Node
var _incompatible_client: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_harness = Node.new()
	_harness.name = "NetworkConnectionHarness"
	root.add_child(_harness)
	_server = _add_runtime("ServerRuntime")
	var port := _start_server_on_available_port()
	if port == 0:
		_fail("Could not allocate a loopback UDP port for the Phase C server.")
		return

	_client_one = _add_runtime("ClientOneRuntime")
	_client_two = _add_runtime("ClientTwoRuntime")
	if _client_one.call("start_client", "127.0.0.1", port, ACCESS_CODE, "Alice") != OK:
		_fail("First loopback client could not start.")
		return
	if _client_two.call("start_client", "127.0.0.1", port, ACCESS_CODE, "Bob") != OK:
		_fail("Second loopback client could not start.")
		return
	if not await _wait_for(func() -> bool: return _is_authenticated(_client_one) and _is_authenticated(_client_two)):
		_fail("Server and two loopback clients did not complete handshake/authentication.")
		return
	if not await _wait_for(func() -> bool: return _client_one.call("get_avatar_count") == 2 and _client_two.call("get_avatar_count") == 2):
		_fail("Both clients did not converge on the two server-issued avatar spawns.")
		return

	var first_identity := _client_one.call("get_client_identity") as Dictionary
	var second_identity := _client_two.call("get_client_identity") as Dictionary
	if first_identity.character_id == second_identity.character_id:
		_fail("Network clients received the same CharacterId.")
		return
	if not _client_sees_only_server_issued_presence(_client_one, first_identity.character_id):
		return
	if not _client_sees_only_server_issued_presence(_client_two, second_identity.character_id):
		return

	_incompatible_client = _add_runtime("IncompatibleClientRuntime")
	if _incompatible_client.call(
		"start_client",
		"127.0.0.1",
		port,
		ACCESS_CODE,
		"Old Build",
		"",
		Protocol.PROTOCOL_VERSION - 1,
		Protocol.CONTENT_VERSION
	) != OK:
		_fail("Incompatible test client transport could not start.")
		return
	if not await _wait_for(
		func() -> bool:
			return (_incompatible_client.call("get_last_rejection") as Dictionary).get("reason_code", "") == Protocol.REASON_VERSION_MISMATCH
	):
		_fail("Actual ENet client did not receive the readable version rejection.")
		return

	var malicious_envelope := Protocol.make_client_envelope(
		"spawn_avatar",
		first_identity.session_id,
		"development.command.illegal-spawn",
		3,
		{"claimed_character_id": second_identity.character_id}
	)
	_client_one.call("send_raw_envelope_for_test", malicious_envelope)
	if not await _wait_for(
		func() -> bool:
			return (_client_one.call("get_last_rejection") as Dictionary).get("reason_code", "") == Protocol.REASON_MALFORMED
	):
		_fail("Client attempt to spawn/control another identity was not rejected at the gateway.")
		return

	var second_reconnect_token := _client_two.call("get_reconnect_token") as String
	var second_stable_account := second_identity.account_id as String
	var second_stable_character := second_identity.character_id as String
	_client_two.call("stop")
	if not await _wait_for(func() -> bool: return _client_one.call("get_avatar_count") == 1):
		_fail("Remaining client did not receive the disconnected avatar despawn.")
		return
	_client_two.queue_free()
	await process_frame
	_client_two = _add_runtime("ReplacementClientRuntime")
	if _client_two.call(
		"start_client", "127.0.0.1", port, "", "Bob", second_reconnect_token
	) != OK:
		_fail("Replacement loopback client could not start.")
		return
	if not await _wait_for(func() -> bool: return _is_authenticated(_client_two)):
		_fail("Replacement peer did not reconnect with its server-issued proof.")
		return
	var replacement_identity := _client_two.call("get_client_identity") as Dictionary
	if (
		replacement_identity.account_id != second_stable_account
		or replacement_identity.character_id != second_stable_character
	):
		_fail("Replacement peer did not retain stable account/character identity.")
		return
	if replacement_identity.session_id == second_identity.session_id:
		_fail("Replacement peer retained a transient session ID.")
		return
	if not await _wait_for(func() -> bool: return _client_one.call("get_avatar_count") == 2):
		_fail("Replacement peer spawn did not converge on the existing client.")
		return

	_incompatible_client.call("stop")
	await process_frame
	_client_two.call("stop")
	if not await _wait_for(func() -> bool: return _client_one.call("get_avatar_count") == 1):
		_fail("Final remote despawn did not reach the remaining client during teardown.")
		return
	_client_one.call("stop")
	if not await _wait_for(
		func() -> bool:
			var coordinator := _server.call("get_session_coordinator_for_test") as RefCounted
			return coordinator != null and coordinator.call("get_authenticated_count") == 0
	):
		_fail("Server did not cleanly remove client sessions during teardown.")
		return
	_server.call("stop")
	if _server.call("get_connection_status") != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_fail("Server ENet endpoint did not close cleanly.")
		return
	_harness.queue_free()
	await process_frame
	print("PASS: Phase C ENet server, two clients, rejection, spawn/despawn, reconnect, and teardown.")
	quit(0)


func _add_runtime(runtime_name: String) -> Node:
	var runtime := NETWORK_RUNTIME_SCENE.instantiate()
	runtime.name = runtime_name
	_harness.add_child(runtime)
	return runtime


func _start_server_on_available_port() -> int:
	var starting_port := 32000 + (Time.get_ticks_msec() % 10000)
	for offset in 32:
		var candidate := starting_port + offset
		if _server.call("start_server", candidate, ACCESS_CODE, 4, "Phase C Test") == OK:
			return candidate
	return 0


func _is_authenticated(runtime: Node) -> bool:
	return not (runtime.call("get_client_identity") as Dictionary).is_empty()


func _client_sees_only_server_issued_presence(runtime: Node, local_character_id: String) -> bool:
	var snapshots := runtime.call("get_avatar_snapshots") as Array
	var local_count := 0
	for snapshot: Variant in snapshots:
		var avatar := snapshot as Dictionary
		if avatar.character_id == local_character_id and avatar.is_local:
			local_count += 1
		if not (avatar.character_id as String).begins_with("development.character."):
			return _fail("Client avatar store accepted a non-server-issued CharacterId.")
	if local_count != 1:
		return _fail("Client avatar store did not identify exactly one local server binding.")
	return true


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _fail(message: String) -> bool:
	if _client_one != null and is_instance_valid(_client_one):
		_client_one.call("stop")
	if _client_two != null and is_instance_valid(_client_two):
		_client_two.call("stop")
	if _incompatible_client != null and is_instance_valid(_incompatible_client):
		_incompatible_client.call("stop")
	if _server != null and is_instance_valid(_server):
		_server.call("stop")
	push_error(message)
	quit(1)
	return false
