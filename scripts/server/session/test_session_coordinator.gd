class_name TestSessionCoordinator
extends RefCounted

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")

const STATE_CONNECTED := "connected"
const STATE_HANDSHAKING := "handshaking"
const STATE_AUTHENTICATED := "authenticated"
const RATE_WINDOW_MSEC := 1000
const MAX_MESSAGES_PER_WINDOW := 8
const MAX_MALFORMED_BEFORE_DISCONNECT := 3

var _access_code := ""
var _server_name := "Mesoplasia Phase C Sandbox"
var _maximum_connections := 4
var _connections_by_peer: Dictionary = {}
var _identities_by_reconnect_hash: Dictionary = {}
var _active_peer_by_character_id: Dictionary = {}
var _server_sequence := 0
var _account_serial := 0
var _session_serial := 0
var _avatar_serial := 0
var _crypto := Crypto.new()


func configure(access_code: String, maximum_connections: int = 4, server_name: String = "") -> void:
	_access_code = access_code
	_maximum_connections = clampi(maximum_connections, 1, 8)
	if not server_name.strip_edges().is_empty():
		_server_name = server_name.strip_edges().left(48)


func connect_peer(peer_id: int, now_msec: int = 0) -> bool:
	if peer_id <= 1 or _connections_by_peer.has(peer_id):
		return false
	if _connections_by_peer.size() >= _maximum_connections:
		return false
	_connections_by_peer[peer_id] = {
		"state": STATE_CONNECTED,
		"challenge": "",
		"last_client_sequence": 0,
		"malformed_count": 0,
		"rate_window_started_msec": now_msec,
		"rate_count": 0,
		"session_id": "",
		"account_id": "",
		"character_id": "",
		"avatar_runtime_id": "",
		"display_label": "",
	}
	return true


func disconnect_peer(peer_id: int, reason: String = "transport_disconnected") -> Dictionary:
	var result := _empty_result()
	if not _connections_by_peer.has(peer_id):
		return result
	var connection := _connections_by_peer[peer_id] as Dictionary
	_connections_by_peer.erase(peer_id)
	if connection.state != STATE_AUTHENTICATED:
		return result
	_active_peer_by_character_id.erase(connection.character_id)
	var remaining_peers := get_authenticated_peer_ids()
	if not remaining_peers.is_empty():
		_add_delivery(
			result,
			remaining_peers,
			_server_envelope(
				Protocol.AVATAR_DESPAWNED,
				"",
				{
					"character_id": connection.character_id,
					"avatar_runtime_id": connection.avatar_runtime_id,
					"reason": reason.left(64),
				}
			)
		)
	return result


func handle_client_envelope(peer_id: int, envelope: Variant, now_msec: int) -> Dictionary:
	var result := _empty_result()
	if not _connections_by_peer.has(peer_id):
		return result
	var connection := _connections_by_peer[peer_id] as Dictionary
	if not _consume_rate(connection, now_msec):
		_reject(result, peer_id, "", Protocol.REASON_RATE_LIMITED, "Too many requests.")
		return result

	var validation := Protocol.validate_client_envelope(envelope)
	if not validation.valid:
		connection.malformed_count += 1
		_reject(result, peer_id, "", Protocol.REASON_MALFORMED, validation.reason_text)
		if connection.malformed_count >= MAX_MALFORMED_BEFORE_DISCONNECT:
			result.disconnect_peer_ids.append(peer_id)
		return result

	var command := envelope as Dictionary
	var command_id := command.command_id as String
	if command.protocol_version != Protocol.PROTOCOL_VERSION:
		_add_delivery(
			result,
			[peer_id],
			_server_hello(false, Protocol.REASON_VERSION_MISMATCH, "Protocol version is incompatible.", "", command_id)
		)
		result.disconnect_peer_ids.append(peer_id)
		return result
	if command.client_sequence <= connection.last_client_sequence:
		_reject(result, peer_id, command_id, Protocol.REASON_STALE_SEQUENCE, "Client sequence is stale.")
		return result
	connection.last_client_sequence = command.client_sequence

	match command.message_type:
		Protocol.CLIENT_HELLO:
			_handle_client_hello(result, peer_id, connection, command)
		Protocol.AUTHENTICATE:
			_handle_authenticate(result, peer_id, connection, command)
		Protocol.PING:
			_handle_ping(result, peer_id, connection, command)
		Protocol.DISCONNECT:
			if connection.state != STATE_AUTHENTICATED:
				_reject(result, peer_id, command_id, Protocol.REASON_INVALID_STATE, "Session is not authenticated.")
			else:
				result.disconnect_peer_ids.append(peer_id)
		_:
			_reject(result, peer_id, command_id, Protocol.REASON_MALFORMED, "Unsupported command.")
	return result


func get_connection_snapshot(peer_id: int) -> Dictionary:
	if not _connections_by_peer.has(peer_id):
		return {}
	return (_connections_by_peer[peer_id] as Dictionary).duplicate(true)


func get_authenticated_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id: Variant in _connections_by_peer:
		var connection := _connections_by_peer[peer_id] as Dictionary
		if connection.state == STATE_AUTHENTICATED:
			peer_ids.append(peer_id as int)
	peer_ids.sort()
	return peer_ids


func get_connection_count() -> int:
	return _connections_by_peer.size()


func get_authenticated_count() -> int:
	return get_authenticated_peer_ids().size()


func _handle_client_hello(
	result: Dictionary,
	peer_id: int,
	connection: Dictionary,
	command: Dictionary
) -> void:
	if connection.state != STATE_CONNECTED:
		_reject(result, peer_id, command.command_id, Protocol.REASON_INVALID_STATE, "Client hello is out of order.")
		return
	var payload := command.payload as Dictionary
	if (
		payload.game_build_version != Protocol.GAME_BUILD_VERSION
		or payload.content_version != Protocol.CONTENT_VERSION
		or payload.content_manifest_hash != Protocol.CONTENT_MANIFEST_HASH
	):
		_add_delivery(
			result,
			[peer_id],
			_server_hello(false, Protocol.REASON_CONTENT_MISMATCH, "Build or content is incompatible.", "", command.command_id)
		)
		result.disconnect_peer_ids.append(peer_id)
		return
	connection.challenge = _make_secret("challenge")
	connection.state = STATE_HANDSHAKING
	_add_delivery(
		result,
		[peer_id],
		_server_hello(true, Protocol.REASON_OK, "Compatible client.", connection.challenge, command.command_id)
	)


func _handle_authenticate(
	result: Dictionary,
	peer_id: int,
	connection: Dictionary,
	command: Dictionary
) -> void:
	if connection.state != STATE_HANDSHAKING:
		_reject(result, peer_id, command.command_id, Protocol.REASON_INVALID_STATE, "Authentication is out of order.")
		return
	var payload := command.payload as Dictionary
	if payload.session_challenge != connection.challenge:
		_reject(result, peer_id, command.command_id, Protocol.REASON_AUTH_FAILED, "Authentication was not accepted.")
		return

	var identity: Dictionary
	var old_reconnect_hash := ""
	if not (payload.reconnect_token as String).is_empty():
		old_reconnect_hash = (payload.reconnect_token as String).sha256_text()
		if not _identities_by_reconnect_hash.has(old_reconnect_hash):
			_reject(result, peer_id, command.command_id, Protocol.REASON_AUTH_FAILED, "Authentication was not accepted.")
			return
		identity = (_identities_by_reconnect_hash[old_reconnect_hash] as Dictionary).duplicate(true)
		if _active_peer_by_character_id.has(identity.character_id):
			_reject(result, peer_id, command.command_id, Protocol.REASON_CHARACTER_IN_USE, "Character already has an active controller.")
			return
	else:
		if _access_code.is_empty() or payload.access_code != _access_code:
			_reject(result, peer_id, command.command_id, Protocol.REASON_AUTH_FAILED, "Authentication was not accepted.")
			return
		identity = _allocate_identity(Protocol.sanitize_display_label(payload.display_label))

	_session_serial += 1
	_avatar_serial += 1
	var reconnect_token := _make_secret("reconnect")
	var reconnect_hash := reconnect_token.sha256_text()
	if not old_reconnect_hash.is_empty():
		_identities_by_reconnect_hash.erase(old_reconnect_hash)
	_identities_by_reconnect_hash[reconnect_hash] = identity.duplicate(true)

	connection.state = STATE_AUTHENTICATED
	connection.challenge = ""
	connection.session_id = "development.session.%d" % _session_serial
	connection.account_id = identity.account_id
	connection.character_id = identity.character_id
	connection.avatar_runtime_id = "development.avatar_runtime.%d" % _avatar_serial
	connection.display_label = identity.display_label
	_active_peer_by_character_id[connection.character_id] = peer_id

	_add_delivery(
		result,
		[peer_id],
		_server_envelope(
			Protocol.AUTHENTICATION_RESULT,
			command.command_id,
			{
				"accepted": true,
				"reason_code": Protocol.REASON_OK,
				"reason_text": "Authenticated for the development sandbox.",
				"session_id": connection.session_id,
				"account_id": connection.account_id,
				"character_id": connection.character_id,
				"avatar_runtime_id": connection.avatar_runtime_id,
				"display_label": connection.display_label,
				"reconnect_token": reconnect_token,
			}
		)
	)

	for existing_peer_id: int in get_authenticated_peer_ids():
		if existing_peer_id == peer_id:
			continue
		var existing := _connections_by_peer[existing_peer_id] as Dictionary
		_add_delivery(result, [peer_id], _avatar_spawn_envelope(existing))
	_add_delivery(result, get_authenticated_peer_ids(), _avatar_spawn_envelope(connection))


func _handle_ping(
	result: Dictionary,
	peer_id: int,
	connection: Dictionary,
	command: Dictionary
) -> void:
	if connection.state != STATE_AUTHENTICATED:
		_reject(result, peer_id, command.command_id, Protocol.REASON_INVALID_STATE, "Session is not authenticated.")
		return
	if command.session_id != connection.session_id:
		_reject(result, peer_id, command.command_id, Protocol.REASON_SESSION_MISMATCH, "Session binding does not match the sender.")
		return
	_add_delivery(
		result,
		[peer_id],
		_server_envelope(Protocol.PONG, command.command_id, {"client_tick": command.payload.client_tick})
	)


func _allocate_identity(display_label: String) -> Dictionary:
	_account_serial += 1
	return {
		"account_id": "development.account.%d" % _account_serial,
		"character_id": "development.character.%d" % _account_serial,
		"display_label": display_label,
	}


func _consume_rate(connection: Dictionary, now_msec: int) -> bool:
	if now_msec - connection.rate_window_started_msec >= RATE_WINDOW_MSEC:
		connection.rate_window_started_msec = now_msec
		connection.rate_count = 0
	connection.rate_count += 1
	return connection.rate_count <= MAX_MESSAGES_PER_WINDOW


func _server_hello(
	accepted: bool,
	reason_code: String,
	reason_text: String,
	challenge: String,
	causation_command_id: String
) -> Dictionary:
	return _server_envelope(
		Protocol.SERVER_HELLO,
		causation_command_id,
		{
			"accepted": accepted,
			"reason_code": reason_code,
			"reason_text": reason_text,
			"protocol_version": Protocol.PROTOCOL_VERSION,
			"game_build_version": Protocol.GAME_BUILD_VERSION,
			"content_version": Protocol.CONTENT_VERSION,
			"content_manifest_hash": Protocol.CONTENT_MANIFEST_HASH,
			"server_name": _server_name,
			"capabilities": ["connection_sandbox", "avatar_presence"],
			"session_challenge": challenge,
		}
	)


func _avatar_spawn_envelope(connection: Dictionary) -> Dictionary:
	return _server_envelope(
		Protocol.AVATAR_SPAWNED,
		"",
		{
			"character_id": connection.character_id,
			"avatar_runtime_id": connection.avatar_runtime_id,
			"display_label": connection.display_label,
		}
	)


func _reject(
	result: Dictionary,
	peer_id: int,
	command_id: String,
	reason_code: String,
	reason_text: String
) -> void:
	_add_delivery(
		result,
		[peer_id],
		_server_envelope(
			Protocol.COMMAND_REJECTED,
			command_id,
			{"reason_code": reason_code, "reason_text": reason_text}
		)
	)


func _server_envelope(message_type: String, command_id: String, payload: Dictionary) -> Dictionary:
	_server_sequence += 1
	return Protocol.make_server_envelope(message_type, _server_sequence, command_id, payload)


func _make_secret(prefix: String) -> String:
	var random_bytes := _crypto.generate_random_bytes(24)
	return "%s.%s" % [prefix, Marshalls.raw_to_base64(random_bytes)]


func _empty_result() -> Dictionary:
	return {"deliveries": [], "disconnect_peer_ids": []}


func _add_delivery(result: Dictionary, peer_ids: Array, envelope: Dictionary) -> void:
	if peer_ids.is_empty():
		return
	result.deliveries.append({"peer_ids": peer_ids.duplicate(), "envelope": envelope})
