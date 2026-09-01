class_name NetworkProtocolGateway
extends Node

signal status_changed(status_text: String)
signal client_authenticated(identity: Dictionary)
signal client_rejected(reason_code: String, reason_text: String)
signal avatar_spawned(avatar_snapshot: Dictionary)
signal avatar_despawned(character_id: String, avatar_runtime_id: String, reason: String)
signal server_peer_authenticated(peer_id: int, identity: Dictionary)
signal server_peer_disconnected_identity(peer_id: int, identity: Dictionary)
signal hub_snapshot_received(snapshot: Dictionary)
signal interaction_result_received(result: Dictionary)
signal zone_transfer_result_received(result: Dictionary)
signal party_snapshot_received(snapshot: Dictionary)
signal party_command_result_received(result: Dictionary)
signal expedition_snapshot_received(snapshot: Dictionary)
signal expedition_command_result_received(result: Dictionary)
signal server_expedition_transfer_committed(member_character_ids: Array)
signal server_expedition_return_required(return_data: Dictionary)

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const AvatarStore := preload("res://scripts/client/network/network_avatar_store.gd")
const HubStateStore := preload("res://scripts/client/network/caden_hub_state_store.gd")
const PartyStateStore := preload("res://scripts/client/network/party_state_store.gd")
const ExpeditionStateStore := preload("res://scripts/client/network/expedition_state_store.gd")

enum GatewayRole { NONE, SERVER, CLIENT }

var _role := GatewayRole.NONE
var _session_coordinator: RefCounted
var _endpoint: Node
var _avatar_store: RefCounted = AvatarStore.new()
var _hub_state_store: RefCounted = HubStateStore.new()
var _party_state_store: RefCounted = PartyStateStore.new()
var _expedition_state_store: RefCounted = ExpeditionStateStore.new()
var _caden_hub_service: RefCounted
var _party_service: RefCounted
var _expedition_service: RefCounted
var _client_access_code := ""
var _client_display_label := ""
var _client_reconnect_token := ""
var _client_session_id := ""
var _client_identity: Dictionary = {}
var _client_sequence := 0
var _movement_envelope_sequence := 0
var _client_protocol_version := Protocol.PROTOCOL_VERSION
var _client_content_version := Protocol.CONTENT_VERSION
var _last_rejection: Dictionary = {}
var _last_pong_tick := -1
var _crypto := Crypto.new()


func _ready() -> void:
	_avatar_store.avatar_spawned.connect(_on_avatar_store_spawned)
	_avatar_store.avatar_despawned.connect(_on_avatar_store_despawned)
	_hub_state_store.snapshot_applied.connect(_on_hub_snapshot_applied)
	_party_state_store.snapshot_applied.connect(_on_party_snapshot_applied)
	_expedition_state_store.snapshot_applied.connect(_on_expedition_snapshot_applied)


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


func configure_caden_hub(caden_hub_service: RefCounted) -> void:
	_caden_hub_service = caden_hub_service
	status_changed.emit("Caden hub protocol enabled.")


func configure_party_service(party_service: RefCounted) -> void:
	_party_service = party_service
	status_changed.emit("Authoritative party protocol enabled.")


func configure_expedition_service(expedition_service: RefCounted) -> void:
	_expedition_service = expedition_service
	status_changed.emit("Authoritative expedition protocol enabled.")


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
	var connection := _session_coordinator.call("get_connection_snapshot", peer_id) as Dictionary
	if connection.get("state", "") == "authenticated":
		server_peer_disconnected_identity.emit(peer_id, connection.duplicate(true))
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


func send_hub_movement(direction: Vector2, input_sequence: int) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty():
		return false
	if not direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		return false
	_movement_envelope_sequence += 1
	var envelope := Protocol.make_client_envelope(
		Protocol.MOVEMENT_INPUT,
		_client_session_id,
		"development.movement.%d" % _movement_envelope_sequence,
		_movement_envelope_sequence,
		{
			"input_sequence": input_sequence,
			"direction_x": int(direction.x),
			"direction_y": int(direction.y),
		}
	)
	submit_movement_envelope.rpc_id(1, envelope)
	return true


func send_hub_interaction(interactable_id: String) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty() or interactable_id.is_empty():
		return false
	_send_client_message(Protocol.INTERACT, {"interactable_id": interactable_id}, _client_session_id)
	return true


func send_hub_zone_transition(exit_id: String) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty() or exit_id.is_empty():
		return false
	_send_client_message(Protocol.ZONE_TRANSITION, {"exit_id": exit_id}, _client_session_id)
	return true


func request_hub_snapshot() -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty():
		return false
	_send_client_message(Protocol.REQUEST_HUB_SNAPSHOT, {}, _client_session_id)
	return true


func send_party_invite(recipient_character_id: String, expected_revision: int) -> bool:
	return _send_party_command(
		Protocol.PARTY_INVITE,
		{
			"recipient_character_id": recipient_character_id,
			"expected_revision": expected_revision,
		}
	)


func send_party_accept(invite_id: String, expected_revision: int) -> bool:
	return _send_party_command(
		Protocol.PARTY_ACCEPT,
		{"invite_id": invite_id, "expected_revision": expected_revision}
	)


func send_party_decline(invite_id: String, expected_revision: int) -> bool:
	return _send_party_command(
		Protocol.PARTY_DECLINE,
		{"invite_id": invite_id, "expected_revision": expected_revision}
	)


func send_party_leave(expected_revision: int) -> bool:
	return _send_party_command(Protocol.PARTY_LEAVE, {"expected_revision": expected_revision})


func send_party_kick(target_character_id: String, expected_revision: int) -> bool:
	return _send_party_command(
		Protocol.PARTY_KICK,
		{
			"target_character_id": target_character_id,
			"expected_revision": expected_revision,
		}
	)


func send_party_transfer_leadership(
	target_character_id: String,
	expected_revision: int
) -> bool:
	return _send_party_command(
		Protocol.PARTY_TRANSFER_LEADERSHIP,
		{
			"target_character_id": target_character_id,
			"expected_revision": expected_revision,
		}
	)


func send_party_ready(is_ready: bool, expected_revision: int) -> bool:
	return _send_party_command(
		Protocol.PARTY_READY,
		{"is_ready": is_ready, "expected_revision": expected_revision}
	)


func send_party_select_expedition(
	expedition_definition_id: String,
	expected_revision: int
) -> bool:
	return _send_party_command(
		Protocol.PARTY_SELECT_EXPEDITION,
		{
			"expedition_definition_id": expedition_definition_id,
			"expected_revision": expected_revision,
		}
	)


func request_party_snapshot() -> bool:
	return _send_party_command(Protocol.PARTY_REQUEST_SNAPSHOT, {})


func send_expedition_launch(expected_party_revision: int) -> bool:
	return _send_expedition_command(
		Protocol.EXPEDITION_LAUNCH,
		{"expected_party_revision": expected_party_revision}
	)


func send_expedition_content_ready(expedition_id: String, expected_revision: int) -> bool:
	return _send_expedition_command(
		Protocol.EXPEDITION_CONTENT_READY,
		{"expedition_id": expedition_id, "expected_revision": expected_revision}
	)


func send_expedition_movement(direction: Vector2, input_sequence: int) -> bool:
	return send_hub_movement(direction, input_sequence)


func send_expedition_room_transition(
	expedition_id: String,
	connection_id: String,
	expected_revision: int
) -> bool:
	return _send_expedition_command(
		Protocol.EXPEDITION_ROOM_TRANSITION,
		{
			"expedition_id": expedition_id,
			"connection_id": connection_id,
			"expected_revision": expected_revision,
		}
	)


func send_expedition_stub_outcome(
	expedition_id: String,
	outcome_code: String,
	expected_revision: int
) -> bool:
	return _send_expedition_command(
		Protocol.EXPEDITION_STUB_OUTCOME,
		{
			"expedition_id": expedition_id,
			"outcome_code": outcome_code,
			"expected_revision": expected_revision,
		}
	)


func send_expedition_return_ack(expedition_id: String, expected_revision: int) -> bool:
	return _send_expedition_command(
		Protocol.EXPEDITION_RETURN_ACK,
		{"expedition_id": expedition_id, "expected_revision": expected_revision}
	)


func request_expedition_snapshot() -> bool:
	return _send_expedition_command(Protocol.EXPEDITION_REQUEST_SNAPSHOT, {})


func send_raw_envelope_for_test(envelope: Variant) -> void:
	if _role == GatewayRole.CLIENT:
		submit_client_envelope.rpc_id(1, envelope)


func send_raw_movement_envelope_for_test(envelope: Variant) -> void:
	if _role == GatewayRole.CLIENT:
		submit_movement_envelope.rpc_id(1, envelope)


func get_avatar_store() -> RefCounted:
	return _avatar_store


func get_hub_state_store() -> RefCounted:
	return _hub_state_store


func get_party_state_store() -> RefCounted:
	return _party_state_store


func get_expedition_state_store() -> RefCounted:
	return _expedition_state_store


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
	_caden_hub_service = null
	_party_service = null
	_expedition_service = null
	_client_access_code = ""
	_client_display_label = ""
	_client_reconnect_token = ""
	_client_session_id = ""
	_client_identity.clear()
	_client_sequence = 0
	_movement_envelope_sequence = 0
	_client_protocol_version = Protocol.PROTOCOL_VERSION
	_client_content_version = Protocol.CONTENT_VERSION
	_last_rejection.clear()
	_last_pong_tick = -1
	_avatar_store.clear()
	_hub_state_store.clear()
	_party_state_store.clear()
	_expedition_state_store.clear()


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_client_envelope(envelope: Variant) -> void:
	if _role != GatewayRole.SERVER or _session_coordinator == null:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	if sender_peer_id <= 1:
		return
	if (
		_caden_hub_service != null
		and envelope is Dictionary
		and (envelope as Dictionary).get("message_type", "") in [
			Protocol.INTERACT,
			Protocol.ZONE_TRANSITION,
			Protocol.REQUEST_HUB_SNAPSHOT,
		]
	):
		_handle_hub_application_command(sender_peer_id, envelope)
		return
	if (
		_expedition_service != null
		and envelope is Dictionary
		and (envelope as Dictionary).get("message_type", "") in [
			Protocol.EXPEDITION_LAUNCH,
			Protocol.EXPEDITION_CONTENT_READY,
			Protocol.EXPEDITION_ROOM_TRANSITION,
			Protocol.EXPEDITION_STUB_OUTCOME,
			Protocol.EXPEDITION_RETURN_ACK,
			Protocol.EXPEDITION_REQUEST_SNAPSHOT,
		]
	):
		_handle_expedition_application_command(sender_peer_id, envelope)
		return
	if (
		_party_service != null
		and envelope is Dictionary
		and (envelope as Dictionary).get("message_type", "") in [
			Protocol.PARTY_INVITE,
			Protocol.PARTY_ACCEPT,
			Protocol.PARTY_DECLINE,
			Protocol.PARTY_LEAVE,
			Protocol.PARTY_KICK,
			Protocol.PARTY_TRANSFER_LEADERSHIP,
			Protocol.PARTY_READY,
			Protocol.PARTY_SELECT_EXPEDITION,
			Protocol.PARTY_REQUEST_SNAPSHOT,
		]
	):
		_handle_party_application_command(sender_peer_id, envelope)
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


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_movement_envelope(envelope: Variant) -> void:
	if (
		_role != GatewayRole.SERVER
		or _session_coordinator == null
		or (_caden_hub_service == null and _expedition_service == null)
	):
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	if sender_peer_id <= 1:
		return
	var authorization := _session_coordinator.call(
		"authorize_movement_envelope", sender_peer_id, envelope, Time.get_ticks_msec()
	) as Dictionary
	if not authorization.accepted:
		_send_command_rejection(sender_peer_id, envelope, authorization)
		if authorization.get("disconnect_peer", false):
			_disconnect_after_delivery(sender_peer_id)
		return
	var connection := _session_coordinator.call("get_connection_snapshot", sender_peer_id) as Dictionary
	var command := envelope as Dictionary
	var payload := command.payload as Dictionary
	var direction := Vector2(int(payload.direction_x), int(payload.direction_y))
	var result: Dictionary
	if (
		_expedition_service != null
		and _expedition_service.call(
			"has_character_in_active_expedition", connection.character_id
		)
	):
		var expedition_id := _expedition_service.call(
			"get_expedition_id_for_character", connection.character_id
		) as String
		result = _expedition_service.call(
			"submit_movement",
			connection.character_id,
			expedition_id,
			int(payload.input_sequence),
			direction,
			Time.get_ticks_msec()
		) as Dictionary
	else:
		result = _caden_hub_service.call(
			"submit_movement_input",
			connection.character_id,
			int(payload.input_sequence),
			direction,
			Time.get_ticks_msec()
		) as Dictionary
	if not result.accepted and result.reason_code != Protocol.REASON_STALE_SEQUENCE:
		_send_command_rejection(sender_peer_id, envelope, result)


@rpc("authority", "call_remote", "reliable", 0)
func receive_server_envelope(envelope: Variant) -> void:
	_handle_received_server_envelope(envelope)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_hub_snapshot(envelope: Variant) -> void:
	_handle_received_server_envelope(envelope)


func _handle_received_server_envelope(envelope: Variant) -> void:
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
		Protocol.HUB_SNAPSHOT:
			_hub_state_store.apply_snapshot(message.payload)
		Protocol.INTERACTION_RESULT:
			interaction_result_received.emit((message.payload as Dictionary).duplicate(true))
		Protocol.ZONE_TRANSFER_RESULT:
			var transfer_result := (message.payload as Dictionary).duplicate(true)
			zone_transfer_result_received.emit(transfer_result)
			if transfer_result.accepted:
				status_changed.emit("Transferred to %s." % transfer_result.zone_id)
		Protocol.PARTY_SNAPSHOT:
			_party_state_store.apply_snapshot(message.payload)
		Protocol.PARTY_COMMAND_RESULT:
			var party_result := (message.payload as Dictionary).duplicate(true)
			party_command_result_received.emit(party_result)
			if party_result.accepted:
				status_changed.emit("Party command accepted: %s." % party_result.command_type)
			else:
				status_changed.emit(
					"Party command rejected: %s — %s" % [
						party_result.reason_code,
						party_result.reason_text,
					]
				)
		Protocol.EXPEDITION_SNAPSHOT:
			_expedition_state_store.apply_snapshot(message.payload)
		Protocol.EXPEDITION_COMMAND_RESULT:
			var expedition_result := (message.payload as Dictionary).duplicate(true)
			expedition_command_result_received.emit(expedition_result)
			if expedition_result.accepted:
				status_changed.emit(
					"Expedition command accepted: %s." % expedition_result.command_type
				)
			else:
				status_changed.emit(
					"Expedition command rejected: %s — %s" % [
						expedition_result.reason_code,
						expedition_result.reason_text,
					]
				)


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
	_hub_state_store.set_local_character_id(payload.character_id)
	status_changed.emit("Authenticated as %s." % payload.display_label)
	client_authenticated.emit(_client_identity.duplicate(true))


func broadcast_hub_snapshots(reliable: bool = false) -> void:
	if _role != GatewayRole.SERVER or _caden_hub_service == null:
		return
	for peer_id: int in _session_coordinator.call("get_authenticated_peer_ids"):
		var connection := _session_coordinator.call("get_connection_snapshot", peer_id) as Dictionary
		var snapshot := _caden_hub_service.call(
			"get_snapshot_for", connection.character_id
		) as Dictionary
		if snapshot.is_empty():
			continue
		var envelope := _session_coordinator.call(
			"make_application_server_envelope", Protocol.HUB_SNAPSHOT, "", snapshot
		) as Dictionary
		_send_server_envelope(peer_id, envelope, reliable)


func send_hub_snapshot_to_peer(peer_id: int, reliable: bool = true) -> void:
	if _role != GatewayRole.SERVER or _caden_hub_service == null:
		return
	var connection := _session_coordinator.call("get_connection_snapshot", peer_id) as Dictionary
	if connection.get("state", "") != "authenticated":
		return
	var snapshot := _caden_hub_service.call("get_snapshot_for", connection.character_id) as Dictionary
	if snapshot.is_empty():
		return
	var envelope := _session_coordinator.call(
		"make_application_server_envelope", Protocol.HUB_SNAPSHOT, "", snapshot
	) as Dictionary
	_send_server_envelope(peer_id, envelope, reliable)


func broadcast_party_snapshots() -> void:
	if _role != GatewayRole.SERVER or _party_service == null:
		return
	for peer_id: int in _session_coordinator.call("get_authenticated_peer_ids"):
		send_party_snapshot_to_peer(peer_id)


func send_party_snapshot_to_peer(peer_id: int) -> void:
	if _role != GatewayRole.SERVER or _party_service == null:
		return
	var connection := _session_coordinator.call("get_connection_snapshot", peer_id) as Dictionary
	if connection.get("state", "") != "authenticated":
		return
	var snapshot := _party_service.call("get_snapshot_for", connection.character_id) as Dictionary
	var envelope := _session_coordinator.call(
		"make_application_server_envelope", Protocol.PARTY_SNAPSHOT, "", snapshot
	) as Dictionary
	_send_server_envelope(peer_id, envelope, true)


func broadcast_expedition_snapshots(reliable: bool = false) -> void:
	if _role != GatewayRole.SERVER or _expedition_service == null:
		return
	for peer_id: int in _session_coordinator.call("get_authenticated_peer_ids"):
		send_expedition_snapshot_to_peer(peer_id, reliable)


func send_expedition_snapshot_to_peer(peer_id: int, reliable: bool = true) -> void:
	if _role != GatewayRole.SERVER or _expedition_service == null:
		return
	var connection := _session_coordinator.call("get_connection_snapshot", peer_id) as Dictionary
	if connection.get("state", "") != "authenticated":
		return
	var snapshot := _expedition_service.call(
		"get_snapshot_for", connection.character_id
	) as Dictionary
	var envelope := _session_coordinator.call(
		"make_application_server_envelope", Protocol.EXPEDITION_SNAPSHOT, "", snapshot
	) as Dictionary
	_send_server_envelope(peer_id, envelope, reliable)


func _handle_hub_application_command(sender_peer_id: int, envelope: Variant) -> void:
	var authorization := _session_coordinator.call(
		"authorize_application_command", sender_peer_id, envelope, Time.get_ticks_msec()
	) as Dictionary
	if not authorization.accepted:
		_send_command_rejection(sender_peer_id, envelope, authorization)
		if authorization.get("disconnect_peer", false):
			_disconnect_after_delivery(sender_peer_id)
		return
	var connection := _session_coordinator.call("get_connection_snapshot", sender_peer_id) as Dictionary
	var command := envelope as Dictionary
	var payload := command.payload as Dictionary
	match command.message_type:
		Protocol.INTERACT:
			var interaction := _caden_hub_service.call(
				"request_interaction", connection.character_id, payload.interactable_id
			) as Dictionary
			var interaction_payload := {
				"accepted": interaction.get("accepted", false),
				"reason_code": interaction.get("reason_code", "INVALID_TARGET"),
				"reason_text": interaction.get("reason_text", "Interaction rejected."),
				"interactable_id": payload.interactable_id,
				"zone_id": interaction.get("zone_id", ""),
			}
			_send_application_result(
				sender_peer_id,
				Protocol.INTERACTION_RESULT,
				command.command_id,
				interaction_payload
			)
		Protocol.ZONE_TRANSITION:
			var transfer := _caden_hub_service.call(
				"request_zone_transition", connection.character_id, payload.exit_id
			) as Dictionary
			var transfer_payload := {
				"accepted": transfer.get("accepted", false),
				"reason_code": transfer.get("reason_code", "INVALID_EXIT"),
				"reason_text": transfer.get("reason_text", "Zone transfer rejected."),
				"exit_id": payload.exit_id,
				"zone_id": transfer.get("zone_id", ""),
				"entry_id": transfer.get("entry_id", ""),
				"world_revision": transfer.get("world_revision", -1),
			}
			_send_application_result(
				sender_peer_id,
				Protocol.ZONE_TRANSFER_RESULT,
				command.command_id,
				transfer_payload
			)
			if transfer.get("accepted", false):
				broadcast_hub_snapshots(true)
		Protocol.REQUEST_HUB_SNAPSHOT:
			send_hub_snapshot_to_peer(sender_peer_id, true)


func _handle_party_application_command(sender_peer_id: int, envelope: Variant) -> void:
	var authorization := _session_coordinator.call(
		"authorize_application_command", sender_peer_id, envelope, Time.get_ticks_msec()
	) as Dictionary
	if not authorization.accepted:
		_send_command_rejection(sender_peer_id, envelope, authorization)
		if authorization.get("disconnect_peer", false):
			_disconnect_after_delivery(sender_peer_id)
		return
	var connection := _session_coordinator.call("get_connection_snapshot", sender_peer_id) as Dictionary
	var command := envelope as Dictionary
	var payload := command.payload as Dictionary
	var result: Dictionary
	match command.message_type:
		Protocol.PARTY_INVITE:
			result = _party_service.call(
				"invite_character",
				connection.character_id,
				payload.recipient_character_id,
				payload.expected_revision,
				Time.get_ticks_msec()
			)
		Protocol.PARTY_ACCEPT:
			result = _party_service.call(
				"accept_invite",
				connection.character_id,
				payload.invite_id,
				payload.expected_revision,
				Time.get_ticks_msec()
			)
		Protocol.PARTY_DECLINE:
			result = _party_service.call(
				"decline_invite",
				connection.character_id,
				payload.invite_id,
				payload.expected_revision,
				Time.get_ticks_msec()
			)
		Protocol.PARTY_LEAVE:
			result = _party_service.call(
				"leave_party", connection.character_id, payload.expected_revision
			)
		Protocol.PARTY_KICK:
			result = _party_service.call(
				"kick_member",
				connection.character_id,
				payload.target_character_id,
				payload.expected_revision
			)
		Protocol.PARTY_TRANSFER_LEADERSHIP:
			result = _party_service.call(
				"transfer_leadership",
				connection.character_id,
				payload.target_character_id,
				payload.expected_revision
			)
		Protocol.PARTY_READY:
			result = _party_service.call(
				"set_ready",
				connection.character_id,
				payload.is_ready,
				payload.expected_revision
			)
		Protocol.PARTY_SELECT_EXPEDITION:
			result = _party_service.call(
				"select_expedition",
				connection.character_id,
				payload.expedition_definition_id,
				payload.expected_revision
			)
		Protocol.PARTY_REQUEST_SNAPSHOT:
			send_party_snapshot_to_peer(sender_peer_id)
			return
		_:
			result = {
				"accepted": false,
				"reason_code": Protocol.REASON_MALFORMED,
				"reason_text": "Unsupported party command.",
				"party_id": "",
				"revision": -1,
			}
	_send_party_command_result(sender_peer_id, command, result)
	if result.get("accepted", false):
		broadcast_party_snapshots()
	else:
		send_party_snapshot_to_peer(sender_peer_id)


func _handle_expedition_application_command(sender_peer_id: int, envelope: Variant) -> void:
	var authorization := _session_coordinator.call(
		"authorize_application_command", sender_peer_id, envelope, Time.get_ticks_msec()
	) as Dictionary
	if not authorization.accepted:
		_send_command_rejection(sender_peer_id, envelope, authorization)
		if authorization.get("disconnect_peer", false):
			_disconnect_after_delivery(sender_peer_id)
		return
	var connection := _session_coordinator.call(
		"get_connection_snapshot", sender_peer_id
	) as Dictionary
	var command := envelope as Dictionary
	var payload := command.payload as Dictionary
	var result: Dictionary
	var now_msec := Time.get_ticks_msec()
	match command.message_type:
		Protocol.EXPEDITION_LAUNCH:
			result = _expedition_service.call(
				"launch_expedition",
				connection.character_id,
				payload.expected_party_revision,
				now_msec
			) as Dictionary
		Protocol.EXPEDITION_CONTENT_READY:
			result = _expedition_service.call(
				"acknowledge_content_ready",
				connection.character_id,
				payload.expedition_id,
				payload.expected_revision,
				now_msec
			) as Dictionary
		Protocol.EXPEDITION_ROOM_TRANSITION:
			result = _expedition_service.call(
				"request_room_transition",
				connection.character_id,
				payload.expedition_id,
				payload.connection_id,
				payload.expected_revision,
				now_msec
			) as Dictionary
		Protocol.EXPEDITION_STUB_OUTCOME:
			result = _expedition_service.call(
				"request_stub_outcome",
				connection.character_id,
				payload.expedition_id,
				payload.outcome_code,
				payload.expected_revision,
				now_msec
			) as Dictionary
		Protocol.EXPEDITION_RETURN_ACK:
			result = _expedition_service.call(
				"acknowledge_caden_return",
				connection.character_id,
				payload.expedition_id,
				payload.expected_revision,
				now_msec
			) as Dictionary
		Protocol.EXPEDITION_REQUEST_SNAPSHOT:
			send_expedition_snapshot_to_peer(sender_peer_id)
			return
		_:
			result = {
				"accepted": false,
				"reason_code": Protocol.REASON_MALFORMED,
				"reason_text": "Unsupported expedition command.",
				"expedition_id": "",
				"revision": -1,
			}
	_send_expedition_command_result(sender_peer_id, command, result)
	if result.get("transfer_committed", false):
		server_expedition_transfer_committed.emit(
			(result.get("member_character_ids", []) as Array).duplicate()
		)
	if result.get("return_required", false):
		server_expedition_return_required.emit(result.duplicate(true))
	if result.get("accepted", false):
		broadcast_expedition_snapshots(true)
		broadcast_party_snapshots()
	else:
		send_expedition_snapshot_to_peer(sender_peer_id)


func _send_expedition_command_result(
	peer_id: int,
	command: Dictionary,
	result: Dictionary
) -> void:
	var expedition_id := result.get("expedition_id", "") as String
	var lifecycle_state := ""
	if not expedition_id.is_empty():
		var state := _expedition_service.call("get_instance_state", expedition_id) as Dictionary
		lifecycle_state = state.get("lifecycle_state", "") as String
	_send_application_result(
		peer_id,
		Protocol.EXPEDITION_COMMAND_RESULT,
		command.command_id,
		{
			"accepted": result.get("accepted", false),
			"reason_code": result.get("reason_code", "EXPEDITION_COMMAND_REJECTED"),
			"reason_text": result.get("reason_text", "Expedition command rejected."),
			"command_type": command.message_type,
			"expedition_id": expedition_id,
			"revision": result.get("revision", -1),
			"lifecycle_state": lifecycle_state,
		}
	)


func _send_party_command_result(
	peer_id: int,
	command: Dictionary,
	result: Dictionary
) -> void:
	_send_application_result(
		peer_id,
		Protocol.PARTY_COMMAND_RESULT,
		command.command_id,
		{
			"accepted": result.get("accepted", false),
			"reason_code": result.get("reason_code", "PARTY_COMMAND_REJECTED"),
			"reason_text": result.get("reason_text", "Party command rejected."),
			"command_type": command.message_type,
			"party_id": result.get("party_id", ""),
			"revision": result.get("revision", -1),
		}
	)


func _send_application_result(
	peer_id: int,
	message_type: String,
	command_id: String,
	payload: Dictionary
) -> void:
	var envelope := _session_coordinator.call(
		"make_application_server_envelope", message_type, command_id, payload
	) as Dictionary
	_send_server_envelope(peer_id, envelope, true)


func _send_command_rejection(peer_id: int, source_envelope: Variant, rejection: Dictionary) -> void:
	var command_id := ""
	if source_envelope is Dictionary:
		command_id = (source_envelope as Dictionary).get("command_id", "") as String
	_send_application_result(
		peer_id,
		Protocol.COMMAND_REJECTED,
		command_id,
		{
			"reason_code": rejection.get("reason_code", Protocol.REASON_MALFORMED),
			"reason_text": rejection.get("reason_text", "Command rejected."),
		}
	)


func _send_server_envelope(peer_id: int, envelope: Dictionary, reliable: bool) -> void:
	if (
		_endpoint == null
		or not multiplayer.get_peers().has(peer_id)
		or not _endpoint.call("is_peer_connected", peer_id)
	):
		return
	if reliable:
		receive_server_envelope.rpc_id(peer_id, envelope)
	else:
		receive_hub_snapshot.rpc_id(peer_id, envelope)


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


func _send_party_command(message_type: String, payload: Dictionary) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty():
		return false
	_send_client_message(message_type, payload, _client_session_id)
	return true


func _send_expedition_command(message_type: String, payload: Dictionary) -> bool:
	if _role != GatewayRole.CLIENT or _client_session_id.is_empty():
		return false
	_send_client_message(message_type, payload, _client_session_id)
	return true


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


func _on_hub_snapshot_applied(snapshot: Dictionary) -> void:
	hub_snapshot_received.emit(snapshot)


func _on_party_snapshot_applied(snapshot: Dictionary) -> void:
	party_snapshot_received.emit(snapshot)


func _on_expedition_snapshot_applied(snapshot: Dictionary) -> void:
	expedition_snapshot_received.emit(snapshot)
