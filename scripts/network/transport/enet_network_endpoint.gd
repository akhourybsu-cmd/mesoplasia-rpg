class_name EnetNetworkEndpoint
extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected
signal transport_stopped

const CHANNEL_COUNT := 3

var _multiplayer_api: MultiplayerAPI
var _peer: ENetMultiplayerPeer
var _is_server := false
var _listening_port := 0


func configure(multiplayer_api: MultiplayerAPI) -> void:
	_multiplayer_api = multiplayer_api
	_connect_api_signal(_multiplayer_api.peer_connected, _on_peer_connected)
	_connect_api_signal(_multiplayer_api.peer_disconnected, _on_peer_disconnected)
	_connect_api_signal(_multiplayer_api.connected_to_server, _on_connected_to_server)
	_connect_api_signal(_multiplayer_api.connection_failed, _on_connection_failed)
	_connect_api_signal(_multiplayer_api.server_disconnected, _on_server_disconnected)


func start_server(port: int, maximum_connections: int) -> Error:
	if _multiplayer_api == null or _peer != null:
		return ERR_ALREADY_IN_USE
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, clampi(maximum_connections, 1, 8), CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	_is_server = true
	_listening_port = port
	_multiplayer_api.multiplayer_peer = _peer
	return OK


func start_client(address: String, port: int) -> Error:
	if _multiplayer_api == null or _peer != null:
		return ERR_ALREADY_IN_USE
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, port, CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	_is_server = false
	_listening_port = 0
	_multiplayer_api.multiplayer_peer = _peer
	return OK


func stop() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_is_server = false
	_listening_port = 0
	if _multiplayer_api != null:
		_multiplayer_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	transport_stopped.emit()


func disconnect_peer(peer_id: int) -> void:
	if _peer != null and _is_server and peer_id > 1:
		_peer.disconnect_peer(peer_id)


func is_peer_connected(peer_id: int) -> bool:
	if _peer == null or not _is_server or peer_id <= 1:
		return false
	var packet_peer := _peer.get_peer(peer_id)
	return packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED


func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if _peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return _peer.get_connection_status()


func get_listening_port() -> int:
	return _listening_port


func is_server() -> bool:
	return _is_server


func _connect_api_signal(api_signal: Signal, callback: Callable) -> void:
	if not api_signal.is_connected(callback):
		api_signal.connect(callback)


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	server_disconnected.emit()
