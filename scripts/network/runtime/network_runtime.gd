class_name NetworkRuntime
extends Node

signal status_changed(status_text: String)
signal client_authenticated(identity: Dictionary)
signal client_rejected(reason_code: String, reason_text: String)
signal avatar_spawned(avatar_snapshot: Dictionary)
signal avatar_despawned(character_id: String, avatar_runtime_id: String, reason: String)
signal hub_snapshot_received(snapshot: Dictionary)
signal interaction_result_received(result: Dictionary)
signal zone_transfer_result_received(result: Dictionary)
signal party_snapshot_received(snapshot: Dictionary)
signal party_command_result_received(result: Dictionary)
signal expedition_snapshot_received(snapshot: Dictionary)
signal expedition_command_result_received(result: Dictionary)

const SessionCoordinator := preload("res://scripts/server/session/test_session_coordinator.gd")
const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const CadenHubService := preload("res://scripts/server/hub/caden_hub_service.gd")
const CadenZoneRegistry := preload("res://scripts/world/caden_zone_registry.gd")
const PartyService := preload("res://scripts/server/party/party_service.gd")
const ExpeditionDefinitionRegistry := preload(
	"res://scripts/server/expedition/expedition_definition_registry.gd"
)
const ExpeditionCheckpointStore := preload(
	"res://scripts/server/expedition/in_memory_expedition_checkpoint_store.gd"
)
const ExpeditionService := preload("res://scripts/server/expedition/expedition_service.gd")

const HUB_SNAPSHOT_INTERVAL_SECONDS := 1.0 / 15.0

enum RuntimeRole { NONE, SERVER, CLIENT }

@onready var _endpoint: Node = $NetworkEndpoint
@onready var _gateway: Node = $ProtocolGateway

var _role := RuntimeRole.NONE
var _multiplayer_api: SceneMultiplayer
var _session_coordinator: RefCounted
var _caden_hub_service: RefCounted
var _party_service: RefCounted
var _expedition_service: RefCounted
var _expedition_checkpoint_store: RefCounted
var _hub_snapshot_accumulator := 0.0
var _expedition_snapshot_accumulator := 0.0


func _ready() -> void:
	_endpoint.peer_connected.connect(_on_peer_connected)
	_endpoint.peer_disconnected.connect(_on_peer_disconnected)
	_endpoint.connected_to_server.connect(_on_connected_to_server)
	_endpoint.connection_failed.connect(_on_connection_failed)
	_endpoint.server_disconnected.connect(_on_server_disconnected)
	_gateway.status_changed.connect(status_changed.emit)
	_gateway.client_authenticated.connect(client_authenticated.emit)
	_gateway.client_rejected.connect(client_rejected.emit)
	_gateway.avatar_spawned.connect(avatar_spawned.emit)
	_gateway.avatar_despawned.connect(avatar_despawned.emit)
	_gateway.hub_snapshot_received.connect(hub_snapshot_received.emit)
	_gateway.interaction_result_received.connect(interaction_result_received.emit)
	_gateway.zone_transfer_result_received.connect(zone_transfer_result_received.emit)
	_gateway.party_snapshot_received.connect(party_snapshot_received.emit)
	_gateway.party_command_result_received.connect(party_command_result_received.emit)
	_gateway.expedition_snapshot_received.connect(expedition_snapshot_received.emit)
	_gateway.expedition_command_result_received.connect(expedition_command_result_received.emit)
	_gateway.server_peer_authenticated.connect(_on_server_peer_authenticated)
	_gateway.server_peer_disconnected_identity.connect(_on_server_peer_disconnected_identity)
	_gateway.server_expedition_transfer_committed.connect(
		_on_server_expedition_transfer_committed
	)
	_gateway.server_expedition_return_required.connect(_on_server_expedition_return_required)
	set_physics_process(false)


func start_server(
	port: int,
	access_code: String,
	maximum_connections: int = 4,
	server_name: String = "Mesoplasia Phase C Sandbox"
) -> Error:
	if _role != RuntimeRole.NONE or access_code.is_empty():
		return ERR_INVALID_PARAMETER
	_prepare_multiplayer_api()
	_session_coordinator = SessionCoordinator.new()
	_session_coordinator.call("configure", access_code, maximum_connections, server_name)
	_gateway.call("configure_server", _session_coordinator, _endpoint)
	var error: Error = _endpoint.call("start_server", port, maximum_connections)
	if error != OK:
		_gateway.call("reset")
		_session_coordinator = null
		return error
	_role = RuntimeRole.SERVER
	status_changed.emit("Server listening on UDP port %d." % port)
	return OK


func start_client(
	address: String,
	port: int,
	access_code: String,
	display_label: String,
	reconnect_token: String = "",
	protocol_version: int = Protocol.PROTOCOL_VERSION,
	content_version: String = Protocol.CONTENT_VERSION
) -> Error:
	if _role != RuntimeRole.NONE or address.strip_edges().is_empty() or display_label.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	_prepare_multiplayer_api()
	_gateway.call(
		"configure_client",
		access_code,
		display_label,
		reconnect_token,
		protocol_version,
		content_version
	)
	var error: Error = _endpoint.call("start_client", address.strip_edges(), port)
	if error != OK:
		_gateway.call("reset")
		return error
	_role = RuntimeRole.CLIENT
	status_changed.emit("Connecting to %s:%d…" % [address.strip_edges(), port])
	return OK


func start_caden_server(
	port: int,
	access_code: String,
	maximum_connections: int = 4,
	server_name: String = "Mesoplasia Phase D Caden Hub"
) -> Error:
	var error := start_server(port, access_code, maximum_connections, server_name)
	if error != OK:
		return error
	if enable_caden_hub():
		return OK
	stop()
	return ERR_CANT_CREATE


func start_party_caden_server(
	port: int,
	access_code: String,
	maximum_connections: int = 4,
	max_party_size: int = PartyService.DEFAULT_MAX_PARTY_SIZE,
	invite_lifetime_msec: int = PartyService.DEFAULT_INVITE_LIFETIME_MSEC,
	disconnect_grace_msec: int = PartyService.DEFAULT_DISCONNECT_GRACE_MSEC,
	server_name: String = "Mesoplasia Phase E Party Sandbox"
) -> Error:
	var error := start_caden_server(port, access_code, maximum_connections, server_name)
	if error != OK:
		return error
	if enable_party_service(max_party_size, invite_lifetime_msec, disconnect_grace_msec):
		return OK
	stop()
	return ERR_CANT_CREATE


func start_expedition_caden_server(
	port: int,
	access_code: String,
	maximum_connections: int = 4,
	max_party_size: int = PartyService.DEFAULT_MAX_PARTY_SIZE,
	load_timeout_msec: int = ExpeditionService.DEFAULT_LOAD_TIMEOUT_MSEC,
	server_name: String = "Mesoplasia Phase F Expedition Sandbox"
) -> Error:
	var error := start_party_caden_server(
		port,
		access_code,
		maximum_connections,
		max_party_size,
		PartyService.DEFAULT_INVITE_LIFETIME_MSEC,
		PartyService.DEFAULT_DISCONNECT_GRACE_MSEC,
		server_name
	)
	if error != OK:
		return error
	if enable_expedition_service(1, load_timeout_msec):
		return OK
	stop()
	return ERR_CANT_CREATE


func enable_caden_hub() -> bool:
	if _role != RuntimeRole.SERVER or _caden_hub_service != null:
		return false
	var registry := CadenZoneRegistry.new()
	var service := CadenHubService.new()
	if not service.configure(registry):
		return false
	_caden_hub_service = service
	_hub_snapshot_accumulator = 0.0
	_session_coordinator.call("enable_capability", "caden_hub")
	_gateway.call("configure_caden_hub", _caden_hub_service)
	set_physics_process(true)
	status_changed.emit("Authoritative five-zone Caden hub enabled.")
	return true


func enable_party_service(
	max_party_size: int = PartyService.DEFAULT_MAX_PARTY_SIZE,
	invite_lifetime_msec: int = PartyService.DEFAULT_INVITE_LIFETIME_MSEC,
	disconnect_grace_msec: int = PartyService.DEFAULT_DISCONNECT_GRACE_MSEC
) -> bool:
	if _role != RuntimeRole.SERVER or _party_service != null:
		return false
	var service := PartyService.new()
	if not service.configure(max_party_size, invite_lifetime_msec, disconnect_grace_msec):
		return false
	_party_service = service
	_session_coordinator.call("enable_capability", "party")
	_gateway.call("configure_party_service", _party_service)
	set_physics_process(true)
	status_changed.emit("Authoritative party service enabled (capacity %d)." % max_party_size)
	return true


func enable_expedition_service(
	max_active_expeditions: int = ExpeditionService.DEFAULT_MAX_ACTIVE_EXPEDITIONS,
	load_timeout_msec: int = ExpeditionService.DEFAULT_LOAD_TIMEOUT_MSEC
) -> bool:
	if (
		_role != RuntimeRole.SERVER
		or _party_service == null
		or _caden_hub_service == null
		or _expedition_service != null
	):
		return false
	var registry := ExpeditionDefinitionRegistry.new()
	var checkpoint_store := ExpeditionCheckpointStore.new()
	var service := ExpeditionService.new()
	if not service.configure(
		registry,
		_party_service,
		checkpoint_store,
		max_active_expeditions,
		load_timeout_msec
	):
		return false
	_expedition_checkpoint_store = checkpoint_store
	_expedition_service = service
	_expedition_snapshot_accumulator = 0.0
	_session_coordinator.call("enable_capability", "expedition")
	_gateway.call("configure_expedition_service", _expedition_service)
	set_physics_process(true)
	status_changed.emit("Authoritative authored expedition service enabled.")
	return true


func stop() -> void:
	set_physics_process(false)
	_endpoint.call("stop")
	_gateway.call("reset")
	_session_coordinator = null
	_caden_hub_service = null
	_party_service = null
	_expedition_service = null
	_expedition_checkpoint_store = null
	_hub_snapshot_accumulator = 0.0
	_expedition_snapshot_accumulator = 0.0
	_role = RuntimeRole.NONE
	status_changed.emit("Network runtime stopped.")


func get_role() -> RuntimeRole:
	return _role


func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _endpoint.call("get_connection_status")


func get_client_identity() -> Dictionary:
	return _gateway.call("get_client_identity") as Dictionary


func get_reconnect_token() -> String:
	return _gateway.call("get_reconnect_token") as String


func get_avatar_snapshots() -> Array[Dictionary]:
	var store := _gateway.call("get_avatar_store") as RefCounted
	var snapshots: Array[Dictionary] = []
	snapshots.assign(store.call("get_avatar_snapshots"))
	return snapshots


func get_avatar_count() -> int:
	var store := _gateway.call("get_avatar_store") as RefCounted
	return store.call("get_avatar_count") as int


func get_last_rejection() -> Dictionary:
	return _gateway.call("get_last_rejection") as Dictionary


func get_hub_snapshot() -> Dictionary:
	var store := _gateway.call("get_hub_state_store") as RefCounted
	return store.call("get_snapshot") as Dictionary


func get_party_snapshot() -> Dictionary:
	var store := _gateway.call("get_party_state_store") as RefCounted
	return store.call("get_snapshot") as Dictionary


func get_expedition_snapshot() -> Dictionary:
	var store := _gateway.call("get_expedition_state_store") as RefCounted
	return store.call("get_snapshot") as Dictionary


func send_ping(client_tick: int) -> bool:
	return _gateway.call("send_ping", client_tick) as bool


func send_hub_movement(direction: Vector2, input_sequence: int) -> bool:
	return _gateway.call("send_hub_movement", direction, input_sequence) as bool


func send_hub_interaction(interactable_id: String) -> bool:
	return _gateway.call("send_hub_interaction", interactable_id) as bool


func send_hub_zone_transition(exit_id: String) -> bool:
	return _gateway.call("send_hub_zone_transition", exit_id) as bool


func request_hub_snapshot() -> bool:
	return _gateway.call("request_hub_snapshot") as bool


func send_party_invite(recipient_character_id: String, expected_revision: int) -> bool:
	return _gateway.call("send_party_invite", recipient_character_id, expected_revision) as bool


func send_party_accept(invite_id: String, expected_revision: int) -> bool:
	return _gateway.call("send_party_accept", invite_id, expected_revision) as bool


func send_party_decline(invite_id: String, expected_revision: int) -> bool:
	return _gateway.call("send_party_decline", invite_id, expected_revision) as bool


func send_party_leave(expected_revision: int) -> bool:
	return _gateway.call("send_party_leave", expected_revision) as bool


func send_party_kick(target_character_id: String, expected_revision: int) -> bool:
	return _gateway.call("send_party_kick", target_character_id, expected_revision) as bool


func send_party_transfer_leadership(
	target_character_id: String,
	expected_revision: int
) -> bool:
	return _gateway.call(
		"send_party_transfer_leadership", target_character_id, expected_revision
	) as bool


func send_party_ready(is_ready: bool, expected_revision: int) -> bool:
	return _gateway.call("send_party_ready", is_ready, expected_revision) as bool


func send_party_select_expedition(
	expedition_definition_id: String,
	expected_revision: int
) -> bool:
	return _gateway.call(
		"send_party_select_expedition", expedition_definition_id, expected_revision
	) as bool


func request_party_snapshot() -> bool:
	return _gateway.call("request_party_snapshot") as bool


func send_expedition_launch(expected_party_revision: int) -> bool:
	return _gateway.call("send_expedition_launch", expected_party_revision) as bool


func send_expedition_content_ready(expedition_id: String, expected_revision: int) -> bool:
	return _gateway.call(
		"send_expedition_content_ready", expedition_id, expected_revision
	) as bool


func send_expedition_movement(direction: Vector2, input_sequence: int) -> bool:
	return _gateway.call("send_expedition_movement", direction, input_sequence) as bool


func send_expedition_room_transition(
	expedition_id: String,
	connection_id: String,
	expected_revision: int
) -> bool:
	return _gateway.call(
		"send_expedition_room_transition",
		expedition_id,
		connection_id,
		expected_revision
	) as bool


func send_expedition_stub_outcome(
	expedition_id: String,
	outcome_code: String,
	expected_revision: int
) -> bool:
	return _gateway.call(
		"send_expedition_stub_outcome", expedition_id, outcome_code, expected_revision
	) as bool


func send_expedition_return_ack(expedition_id: String, expected_revision: int) -> bool:
	return _gateway.call(
		"send_expedition_return_ack", expedition_id, expected_revision
	) as bool


func request_expedition_snapshot() -> bool:
	return _gateway.call("request_expedition_snapshot") as bool


func send_raw_envelope_for_test(envelope: Variant) -> void:
	_gateway.call("send_raw_envelope_for_test", envelope)


func send_raw_movement_envelope_for_test(envelope: Variant) -> void:
	_gateway.call("send_raw_movement_envelope_for_test", envelope)


func get_session_coordinator_for_test() -> RefCounted:
	return _session_coordinator


func get_caden_hub_service_for_test() -> RefCounted:
	return _caden_hub_service


func get_party_service_for_test() -> RefCounted:
	return _party_service


func get_expedition_service_for_test() -> RefCounted:
	return _expedition_service


func get_expedition_checkpoint_store_for_test() -> RefCounted:
	return _expedition_checkpoint_store


func _physics_process(delta: float) -> void:
	if _role != RuntimeRole.SERVER:
		return
	var now_msec := Time.get_ticks_msec()
	if _caden_hub_service != null:
		_caden_hub_service.call("tick", delta, now_msec)
		_hub_snapshot_accumulator += delta
		if _hub_snapshot_accumulator >= HUB_SNAPSHOT_INTERVAL_SECONDS:
			_hub_snapshot_accumulator = fmod(
				_hub_snapshot_accumulator, HUB_SNAPSHOT_INTERVAL_SECONDS
			)
			_gateway.call("broadcast_hub_snapshots", false)
	if _party_service != null and _party_service.call("tick", now_msec):
		_gateway.call("broadcast_party_snapshots")
	if _expedition_service != null:
		var expedition_tick := _expedition_service.call("tick", delta, now_msec) as Dictionary
		if expedition_tick.get("party_changed", false):
			_gateway.call("broadcast_party_snapshots")
		_expedition_snapshot_accumulator += delta
		if _expedition_snapshot_accumulator >= HUB_SNAPSHOT_INTERVAL_SECONDS:
			_expedition_snapshot_accumulator = fmod(
				_expedition_snapshot_accumulator, HUB_SNAPSHOT_INTERVAL_SECONDS
			)
			_gateway.call("broadcast_expedition_snapshots", false)


func _prepare_multiplayer_api() -> void:
	if _multiplayer_api != null:
		return
	_multiplayer_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(_multiplayer_api, get_path())
	_endpoint.call("configure", _multiplayer_api)


func _on_peer_connected(peer_id: int) -> void:
	if _role == RuntimeRole.SERVER:
		_gateway.call("server_peer_connected", peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _role == RuntimeRole.SERVER:
		_gateway.call("server_peer_disconnected", peer_id)


func _on_connected_to_server() -> void:
	if _role == RuntimeRole.CLIENT:
		_gateway.call("begin_client_handshake")


func _on_connection_failed() -> void:
	status_changed.emit("Connection failed. Check address, UDP port, and host status.")


func _on_server_disconnected() -> void:
	var rejection := get_last_rejection()
	if rejection.is_empty():
		status_changed.emit("Server disconnected.")
	else:
		status_changed.emit(
			"Disconnected after rejection: %s — %s" % [
				rejection.reason_code,
				rejection.reason_text,
			]
		)


func _on_server_peer_authenticated(peer_id: int, identity: Dictionary) -> void:
	if _role != RuntimeRole.SERVER:
		return
	var now_msec := Time.get_ticks_msec()
	if _party_service != null:
		var party_result := _party_service.call(
			"connect_character", identity, now_msec
		) as Dictionary
		if not party_result.get("accepted", false):
			status_changed.emit("Authenticated peer %d could not join the party service." % peer_id)
		else:
			_gateway.call("broadcast_party_snapshots")
	var in_active_expedition := false
	if _expedition_service != null:
		var expedition_result := _expedition_service.call(
			"connect_character", identity, now_msec
		) as Dictionary
		in_active_expedition = expedition_result.get("in_expedition", false)
		_gateway.call("broadcast_expedition_snapshots", true)
	if _caden_hub_service != null and not in_active_expedition:
		var hub_result := _caden_hub_service.call(
			"attach_avatar", identity, now_msec
		) as Dictionary
		if not hub_result.get("accepted", false):
			status_changed.emit("Authenticated peer %d could not join the Caden hub." % peer_id)
		else:
			_gateway.call("send_hub_snapshot_to_peer", peer_id, true)
			_gateway.call("broadcast_hub_snapshots", true)


func _on_server_peer_disconnected_identity(_peer_id: int, identity: Dictionary) -> void:
	if _role != RuntimeRole.SERVER:
		return
	var character_id := identity.get("character_id", "") as String
	if character_id.is_empty():
		return
	if _caden_hub_service != null:
		_caden_hub_service.call("detach_avatar", character_id)
		_gateway.call("broadcast_hub_snapshots", true)
	if _party_service != null:
		_party_service.call("disconnect_character", character_id, Time.get_ticks_msec())
		_gateway.call("broadcast_party_snapshots")
	if _expedition_service != null:
		_expedition_service.call("disconnect_character", character_id, Time.get_ticks_msec())
		_gateway.call("broadcast_expedition_snapshots", true)


func _on_server_expedition_transfer_committed(member_character_ids: Array) -> void:
	if _role != RuntimeRole.SERVER or _caden_hub_service == null:
		return
	for character_id: Variant in member_character_ids:
		_caden_hub_service.call("detach_avatar", character_id as String)
	_gateway.call("broadcast_hub_snapshots", true)


func _on_server_expedition_return_required(return_data: Dictionary) -> void:
	if _role != RuntimeRole.SERVER or _caden_hub_service == null:
		return
	var zone_id := return_data.get("return_zone_id", "") as String
	var entry_id := return_data.get("return_entry_id", "") as String
	var member_ids := return_data.get("member_character_ids", []) as Array
	for character_id_value: Variant in member_ids:
		var character_id := character_id_value as String
		_caden_hub_service.call("prepare_avatar_return", character_id, zone_id, entry_id)
		for peer_id: int in _session_coordinator.call("get_authenticated_peer_ids"):
			var identity := _session_coordinator.call(
				"get_connection_snapshot", peer_id
			) as Dictionary
			if identity.get("character_id", "") == character_id:
				_caden_hub_service.call("attach_avatar", identity, Time.get_ticks_msec())
	_gateway.call("broadcast_hub_snapshots", true)
