extends SceneTree

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const SessionCoordinator := preload("res://scripts/server/session/test_session_coordinator.gd")

const ACCESS_CODE := "phase-c-test-access"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_handshake_authentication_and_peer_replacement():
		return
	if not _verify_version_malformed_stale_and_rate_rejections():
		return
	print("PASS: Phase C protocol/session validation, identity binding, reconnect, and hostile-message guards.")
	quit(0)


func _verify_handshake_authentication_and_peer_replacement() -> bool:
	var coordinator := SessionCoordinator.new()
	coordinator.configure(ACCESS_CODE, 4, "Phase C Test")
	if not coordinator.connect_peer(2, 0) or not coordinator.connect_peer(3, 0):
		return _fail("Coordinator did not accept two independent transport peers.")

	var alice_auth := _authenticate_peer(coordinator, 2, "Alice", 10)
	if alice_auth.is_empty():
		return false
	var bob_auth := _authenticate_peer(coordinator, 3, "Bob", 20)
	if bob_auth.is_empty():
		return false
	if alice_auth.character_id == bob_auth.character_id or alice_auth.account_id == bob_auth.account_id:
		return _fail("Server issued duplicate stable identities to separate peers.")
	if coordinator.get_authenticated_count() != 2:
		return _fail("Coordinator did not retain two authenticated sessions.")

	if not coordinator.connect_peer(4, 30):
		return _fail("Coordinator did not accept the takeover-attempt transport peer.")
	var takeover_hello := coordinator.handle_client_envelope(4, _hello(1), 31)
	var challenge := _find_payload(takeover_hello, Protocol.SERVER_HELLO).get("session_challenge", "") as String
	var takeover_result := coordinator.handle_client_envelope(
		4,
		_authenticate(2, challenge, "", "Alice", alice_auth.reconnect_token),
		32
	)
	var takeover_rejection := _find_payload(takeover_result, Protocol.COMMAND_REJECTED)
	if takeover_rejection.get("reason_code", "") != Protocol.REASON_CHARACTER_IN_USE:
		return _fail("An active character takeover was not rejected.")

	var disconnect_result := coordinator.disconnect_peer(2, "test_disconnect")
	var despawn := _find_payload(disconnect_result, Protocol.AVATAR_DESPAWNED)
	if despawn.get("character_id", "") != alice_auth.character_id:
		return _fail("Disconnect did not broadcast the server-bound avatar identity.")
	if not coordinator.connect_peer(20, 100):
		return _fail("Coordinator did not accept a replacement peer after disconnect.")
	var reconnect_hello := coordinator.handle_client_envelope(20, _hello(1), 101)
	var reconnect_challenge := _find_payload(
		reconnect_hello, Protocol.SERVER_HELLO
	).get("session_challenge", "") as String
	var reconnect_result := coordinator.handle_client_envelope(
		20,
		_authenticate(2, reconnect_challenge, "", "Alice", alice_auth.reconnect_token),
		102
	)
	var reconnect_auth := _find_payload(reconnect_result, Protocol.AUTHENTICATION_RESULT)
	if reconnect_auth.is_empty():
		return _fail("Replacement peer was not authenticated with its reconnect proof.")
	if reconnect_auth.account_id != alice_auth.account_id or reconnect_auth.character_id != alice_auth.character_id:
		return _fail("Replacement peer did not retain its stable server-issued account and character IDs.")
	if reconnect_auth.session_id == alice_auth.session_id:
		return _fail("Replacement peer incorrectly retained the transient session ID.")
	if reconnect_auth.avatar_runtime_id == alice_auth.avatar_runtime_id:
		return _fail("Replacement peer incorrectly retained the transient avatar runtime ID.")
	return true


func _verify_version_malformed_stale_and_rate_rejections() -> bool:
	var version_coordinator := SessionCoordinator.new()
	version_coordinator.configure(ACCESS_CODE)
	version_coordinator.connect_peer(2, 0)
	var incompatible := _hello(1)
	incompatible.protocol_version = Protocol.PROTOCOL_VERSION - 1
	var version_result := version_coordinator.handle_client_envelope(2, incompatible, 1)
	var version_payload := _find_payload(version_result, Protocol.SERVER_HELLO)
	if version_payload.get("reason_code", "") != Protocol.REASON_VERSION_MISMATCH:
		return _fail("Incompatible protocol version did not receive a readable rejection.")
	if not (version_result.disconnect_peer_ids as Array).has(2):
		return _fail("Incompatible protocol peer was not scheduled for disconnect.")

	var malformed_coordinator := SessionCoordinator.new()
	malformed_coordinator.configure(ACCESS_CODE)
	malformed_coordinator.connect_peer(2, 0)
	var malformed := _hello(1)
	malformed["claimed_character_id"] = "development.character.someone_else"
	var malformed_result := malformed_coordinator.handle_client_envelope(2, malformed, 1)
	if _find_payload(malformed_result, Protocol.COMMAND_REJECTED).get("reason_code", "") != Protocol.REASON_MALFORMED:
		return _fail("Identity-claim field outside the schema was not rejected as malformed.")

	var sequence_coordinator := SessionCoordinator.new()
	sequence_coordinator.configure(ACCESS_CODE)
	sequence_coordinator.connect_peer(2, 0)
	var authentication := _authenticate_peer(sequence_coordinator, 2, "Sequence Test", 10)
	if authentication.is_empty():
		return false
	var stale_ping := Protocol.make_client_envelope(
		Protocol.PING,
		authentication.session_id,
		"development.command.stale",
		2,
		{"client_tick": 1}
	)
	var stale_result := sequence_coordinator.handle_client_envelope(2, stale_ping, 20)
	if _find_payload(stale_result, Protocol.COMMAND_REJECTED).get("reason_code", "") != Protocol.REASON_STALE_SEQUENCE:
		return _fail("Stale client sequence was not rejected.")

	var rate_coordinator := SessionCoordinator.new()
	rate_coordinator.configure(ACCESS_CODE)
	rate_coordinator.connect_peer(2, 0)
	var latest_result: Dictionary
	for sequence in range(1, 10):
		latest_result = rate_coordinator.handle_client_envelope(2, _hello(sequence), sequence)
	if _find_payload(latest_result, Protocol.COMMAND_REJECTED).get("reason_code", "") != Protocol.REASON_RATE_LIMITED:
		return _fail("Per-connection request rate limit did not reject the ninth request.")
	return true


func _authenticate_peer(
	coordinator: RefCounted,
	peer_id: int,
	display_label: String,
	now_msec: int
) -> Dictionary:
	var hello_result := coordinator.call("handle_client_envelope", peer_id, _hello(1), now_msec) as Dictionary
	var hello_payload := _find_payload(hello_result, Protocol.SERVER_HELLO)
	var challenge := hello_payload.get("session_challenge", "") as String
	if challenge.is_empty():
		_fail("Compatible client hello did not receive a session challenge.")
		return {}
	var auth_result := coordinator.call(
		"handle_client_envelope",
		peer_id,
		_authenticate(2, challenge, ACCESS_CODE, display_label, ""),
		now_msec + 1
	) as Dictionary
	var auth_payload := _find_payload(auth_result, Protocol.AUTHENTICATION_RESULT)
	if not auth_payload.get("accepted", false):
		_fail("Valid private-test authentication was rejected.")
		return {}
	return auth_payload


func _hello(sequence: int) -> Dictionary:
	return Protocol.make_client_envelope(
		Protocol.CLIENT_HELLO,
		"",
		"development.command.hello.%d" % sequence,
		sequence,
		Protocol.make_client_hello_payload("test-nonce-%d" % sequence)
	)


func _authenticate(
	sequence: int,
	challenge: String,
	access_code: String,
	display_label: String,
	reconnect_token: String
) -> Dictionary:
	return Protocol.make_client_envelope(
		Protocol.AUTHENTICATE,
		"",
		"development.command.auth.%d" % sequence,
		sequence,
		{
			"session_challenge": challenge,
			"access_code": access_code,
			"display_label": display_label,
			"reconnect_token": reconnect_token,
		}
	)


func _find_payload(result: Dictionary, message_type: String) -> Dictionary:
	for delivery: Variant in result.get("deliveries", []):
		var envelope := (delivery as Dictionary).get("envelope", {}) as Dictionary
		if envelope.get("message_type", "") == message_type:
			return (envelope.get("payload", {}) as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
