class_name NetworkProtocolGateway
extends Node

signal status_changed(status_text: String)
signal client_authenticated(identity: Dictionary)
signal client_rejected(reason_code: String, reason_text: String)
signal avatar_spawned(avatar_snapshot: Dictionary)
signal avatar_despawned(character_id: String, avatar_runtime_id: String, reason: String)
signal server_peer_authenticated(peer_id: int, identity: Dictionary)

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const AvatarStore := preload("res://scripts/client/network/network_avatar_store.gd")

enum GatewayRole { NONE, SERVER, CLIENT }

var _role := GatewayRole.NONE
var _session_coordinator: RefCounted
var _endpoint: Node
var _avatar_store: RefCounted = AvatarStore.new()
var _client_access_code := ""
var _client_display_label := ""
var _client_reconnect_token := ""
var _client_session_id := ""
var _client_identity: Dictionary = {}
var _client_sequence := 0
var _client_protocol_version := Protocol.PROTOCOL_VERSION
var _client_content_version := Protocol.CONTENT_VERSION
var _last_rejection: Dictionary = {}
var _last_pong_tick := -1
var _crypto := Crypto.new()


func _ready() -> void:
	_avatar_store.avatar_spawned.connect(_on_avatar_store_spawned)
	_avatar_store.avatar_despawned.connect(_on_avatar_store_despawned)


func configure_server(session_coordinator: RefCounted, endpoint: Node) -> void:
	reset()
	_role = GatewayRole.SERVER
	_session_coordinator = session_coordinator
	_endpoint = endpoint
	status_changed.emit("Server gateway ready.")


func configure_client(
	access_code: String,
	display_label: String,
	reconnect_token: String = "",
	protocol_version: int = Protocol.PROTOCOL_VERSION,
	content_version: String = Protocol.CONTENT_VERSION
) -> void:
	reset()
	_role = GatewayRole.CLIENT
	_client_access_code = access_code
	_client_display_label = Protocol.sanitize_display_label(display_label)
	_client_reconnect_token = reconnect_token
	_client_protocol_version = protocol_version
	_client_content_version = content_version
	status_changed.emit("Client gateway ready.")


func server_peer_connected(peer_id: int) -> void:
	if _role != GatewayRole.SERVER:
		return
	if not _session_coordinator.call("connect_peer", peer_id, Time.get_ticks_msec()):
		status_changed.emit("Connection capacity rejected peer %d." % peer_id)
		_endpoint.call("disconnect_peer", peer_id)
	else:
		status_changed.emit("Transport peer %d connected; awaiting handshake." % peer_id)


func server_peer_disconnected(peer_id: int) -> void:
	if _role != GatewayRole.SERVER:
		return
	var result := _session_coordinator.call("disconnect_peer", peer_id, "transport_disconnected") as Dictionary
	_dispatch_server_result(result)
	status_changed.emit("Transport peer %d disconnected." % peer_id)


func begin_client_handshake() -> void:
	if _role != GatewayRole.CLIENT:
		return
	status_changed.emit("Connected; negotiating protocol and content versions.")
	var client_nonce := _make_nonce()
	var payload := Protocol.make_client_hello_payload(client_nonce)
	payload.content_version = _client_content_version
	_send_client_message(Protocol.CLIENT_HELLO, payload, "", _client_protocol_version)


func send_ping(client_tick: int) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty():
		return false
	_send_client_message(Protocol.PING, {"client_tick": maxi(client_tick, 0)}, _client_session_id)
	return true


func send_raw_envelope_for_test(envelope: Variant) -> void:
	if _role == GatewayRole.CLIENT:
		submit_client_envelope.rpc_id(1, envelope)


func get_avatar_store() -> RefCounted:
	return _avatar_store


func get_client_identity() -> Dictionary:
	return _client_identity.duplicate(true)


func get_reconnect_token() -> String:
	return _client_reconnect_token


func get_last_rejection() -> Dictionary:
	return _last_rejection.duplicate(true)


func get_last_pong_tick() -> int:
	return _last_pong_tick


func reset() -> void:
	_role = GatewayRole.NONE
	_session_coordinator = null
	_endpoint = null
	_client_access_code = ""
	_client_display_label = ""
	_client_reconnect_token = ""
	_client_session_id = ""
	_client_identity.clear()
	_client_sequence = 0
	_client_protocol_version = Protocol.PROTOCOL_VERSION
	_client_content_version = Protocol.CONTENT_VERSION
	_last_rejection.clear()
	_last_pong_tick = -1
	_avatar_store.clear()


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_client_envelope(envelope: Variant) -> void:
	if _role != GatewayRole.SERVER or _session_coordinator == null:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	if sender_peer_id <= 1:
		return
	var previous_connection := _session_coordinator.call(
		"get_connection_snapshot", sender_peer_id
	) as Dictionary
	var previous_session_id := previous_connection.get("session_id", "") as String
	var was_authenticated: bool = not previous_session_id.is_empty()
	var result := _session_coordinator.call(
		"handle_client_envelope", sender_peer_id, envelope, Time.get_ticks_msec()
	) as Dictionary
	_dispatch_server_result(result)
	var connection := _session_coordinator.call("get_connection_snapshot", sender_peer_id) as Dictionary
	if not was_authenticated and connection.get("state", "") == "authenticated":
		server_peer_authenticated.emit(sender_peer_id, connection)


@rpc("authority", "call_remote", "reliable", 0)
func receive_server_envelope(envelope: Variant) -> void:
	if _role != GatewayRole.CLIENT:
		return
	var validation := Protocol.validate_server_envelope(envelope)
	if not validation.valid:
		_set_rejection(Protocol.REASON_MALFORMED, "Server sent an invalid protocol envelope.")
		return
	var message := envelope as Dictionary
	match message.message_type:
		Protocol.SERVER_HELLO:
			_handle_server_hello(message)
		Protocol.AUTHENTICATION_RESULT:
			_handle_authentication_result(message)
		Protocol.AVATAR_SPAWNED:
			_avatar_store.apply_spawn(message.payload)
		Protocol.AVATAR_DESPAWNED:
			_avatar_store.apply_despawn(message.payload)
		Protocol.COMMAND_REJECTED:
			_set_rejection(message.payload.reason_code, message.payload.reason_text)
		Protocol.PONG:
			_last_pong_tick = message.payload.client_tick


func _handle_server_hello(message: Dictionary) -> void:
	var payload := message.payload as Dictionary
	if not payload.accepted:
		_set_rejection(payload.reason_code, payload.reason_text)
		return
	status_changed.emit("Versions accepted; authenticating private-test access.")
	_send_client_message(
		Protocol.AUTHENTICATE,
		{
			"session_challenge": payload.session_challenge,
			"access_code": _client_access_code,
			"display_label": _client_display_label,
			"reconnect_token": _client_reconnect_token,
		},
		""
	)


func _handle_authentication_result(message: Dictionary) -> void:
	var payload := message.payload as Dictionary
	if not payload.accepted:
		_set_rejection(payload.reason_code, payload.reason_text)
		return
	_client_session_id = payload.session_id
	_client_reconnect_token = payload.reconnect_token
	_client_identity = {
		"session_id": payload.session_id,
		"account_id": payload.account_id,
		"character_id": payload.character_id,
		"avatar_runtime_id": payload.avatar_runtime_id,
		"display_label": payload.display_label,
	}
	_avatar_store.set_local_character_id(payload.character_id)
	status_changed.emit("Authenticated as %s." % payload.display_label)
	client_authenticated.emit(_client_identity.duplicate(true))


func _send_client_message(
	message_type: String,
	payload: Dictionary,
	session_id: String,
	protocol_version: int = Protocol.PROTOCOL_VERSION
) -> void:
	_client_sequence += 1
	var command_id := "development.command.%d" % _client_sequence
	var envelope := Protocol.make_client_envelope(
		message_type,
		session_id,
		command_id,
		_client_sequence,
		payload,
		protocol_version
	)
	submit_client_envelope.rpc_id(1, envelope)


func _dispatch_server_result(result: Dictionary) -> void:
	var connected_peer_ids := multiplayer.get_peers()
	for delivery: Variant in result.get("deliveries", []):
		var delivery_data := delivery as Dictionary
		for peer_id: Variant in delivery_data.peer_ids:
			var target_peer_id := peer_id as int
			if (
				connected_peer_ids.has(target_peer_id)
				and _endpoint != null
				and _endpoint.call("is_peer_connected", target_peer_id)
			):
				receive_server_envelope.rpc_id(target_peer_id, delivery_data.envelope)
	for peer_id: Variant in result.get("disconnect_peer_ids", []):
		_disconnect_after_delivery(peer_id as int)


func _disconnect_after_delivery(peer_id: int) -> void:
	await get_tree().create_timer(0.1).timeout
	if _endpoint != null:
		_endpoint.call("disconnect_peer", peer_id)


func _set_rejection(reason_code: String, reason_text: String) -> void:
	_last_rejection = {"reason_code": reason_code, "reason_text": reason_text}
	status_changed.emit("Rejected: %s — %s" % [reason_code, reason_text])
	client_rejected.emit(reason_code, reason_text)


func _make_nonce() -> String:
	return Marshalls.raw_to_base64(_crypto.generate_random_bytes(16))


func _on_avatar_store_spawned(snapshot: Dictionary) -> void:
	avatar_spawned.emit(snapshot)


func _on_avatar_store_despawned(character_id: String, avatar_runtime_id: String, reason: String) -> void:
	avatar_despawned.emit(character_id, avatar_runtime_id, reason)
