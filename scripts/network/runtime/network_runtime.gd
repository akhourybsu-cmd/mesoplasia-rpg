class_name NetworkRuntime
extends Node

signal status_changed(status_text: String)
signal client_authenticated(identity: Dictionary)
signal client_rejected(reason_code: String, reason_text: String)
signal avatar_spawned(avatar_snapshot: Dictionary)
signal avatar_despawned(character_id: String, avatar_runtime_id: String, reason: String)

const SessionCoordinator := preload("res://scripts/server/session/test_session_coordinator.gd")
const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")

enum RuntimeRole { NONE, SERVER, CLIENT }

@onready var _endpoint: Node = $NetworkEndpoint
@onready var _gateway: Node = $ProtocolGateway

var _role := RuntimeRole.NONE
var _multiplayer_api: SceneMultiplayer
var _session_coordinator: RefCounted


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


func stop() -> void:
	_endpoint.call("stop")
	_gateway.call("reset")
	_session_coordinator = null
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


func send_ping(client_tick: int) -> bool:
	return _gateway.call("send_ping", client_tick) as bool


func send_raw_envelope_for_test(envelope: Variant) -> void:
	_gateway.call("send_raw_envelope_for_test", envelope)


func get_session_coordinator_for_test() -> RefCounted:
	return _session_coordinator


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
