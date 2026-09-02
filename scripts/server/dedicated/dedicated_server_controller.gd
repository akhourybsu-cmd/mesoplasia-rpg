class_name DedicatedServerController
extends Node

signal status_changed(status: Dictionary)

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const Config := preload("res://scripts/server/dedicated/dedicated_server_config.gd")
const ServerLogger := preload("res://scripts/server/dedicated/structured_server_logger.gd")
const Backend := preload("res://scripts/persistence/versioned_file_backend.gd")
const PersistenceCoordinator := preload(
	"res://scripts/persistence/server_persistence_coordinator.gd"
)
const IdentityResolver := preload(
	"res://scripts/server/dedicated/persistent_identity_resolver.gd"
)
const ExpeditionStore := preload(
	"res://scripts/persistence/durable_expedition_checkpoint_store.gd"
)
const CombatStore := preload(
	"res://scripts/persistence/durable_combat_checkpoint_store.gd"
)
const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")

const STATE_STOPPED := "STOPPED"
const STATE_RUNNING := "RUNNING"
const STATE_DRAINING := "DRAINING"
const STATE_MAINTENANCE := "MAINTENANCE"
const BACKUP_PREFIX := "server.backup."

var _state := STATE_STOPPED
var _config: Dictionary = {}
var _logger: RefCounted
var _backend: RefCounted
var _persistence_coordinator: RefCounted
var _identity_resolver: RefCounted
var _expedition_store: RefCounted
var _combat_store: RefCounted
var _network_runtime: Node
var _backup_sequence := 0


func start(
	source_config: Dictionary,
	instance_root: String = Config.DEFAULT_INSTANCE_ROOT,
	access_code_override: String = ""
) -> Dictionary:
	if _state != STATE_STOPPED or _network_runtime != null:
		return _rejected("ALREADY_STARTED")
	var parsed := Config.parse(source_config, instance_root, access_code_override)
	if not parsed.get("accepted", false):
		return parsed
	_config = (parsed.config as Dictionary).duplicate(true)
	for directory: String in [_config.save_path, _config.backup_path, _config.log_path]:
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			return _rejected("DIRECTORY_CREATE_FAILED")
	_logger = ServerLogger.new()
	if not _logger.call("configure", _config.log_path):
		return _rejected("LOGGER_CONFIGURE_FAILED")
	_backend = Backend.new()
	if not _backend.call(
		"configure",
		_config.save_path,
		Protocol.SAVE_SCHEMA_VERSION,
		Protocol.CONTENT_VERSION,
		_config.backup_path
	) or not _backend.call("initialize_storage"):
		_state = STATE_MAINTENANCE
		_log("ERROR", "persistence", "storage_start_failed")
		return _rejected("PERSISTENCE_START_FAILED")
	_persistence_coordinator = PersistenceCoordinator.new()
	if not _persistence_coordinator.call("configure", _backend):
		return _rejected("PERSISTENCE_COMPOSITION_FAILED")
	_identity_resolver = IdentityResolver.new()
	if not _identity_resolver.call("configure", _persistence_coordinator):
		return _rejected("IDENTITY_COMPOSITION_FAILED")
	_expedition_store = ExpeditionStore.new()
	_combat_store = CombatStore.new()
	if not _expedition_store.call("configure", _backend) or not _combat_store.call("configure", _backend):
		return _rejected("CHECKPOINT_COMPOSITION_FAILED")
	_network_runtime = NetworkRuntimeScene.instantiate()
	add_child(_network_runtime)
	_network_runtime.status_changed.connect(_on_network_status_changed)
	var network_error := _network_runtime.call(
		"start_dedicated_server",
		_config,
		_identity_resolver,
		_expedition_store,
		_combat_store,
		_persistence_coordinator
	) as Error
	if network_error != OK:
		_network_runtime.queue_free()
		_network_runtime = null
		_log("ERROR", "network", "server_start_failed", {"error": error_string(network_error)})
		return {
			"accepted": false,
			"reason_code": "NETWORK_START_FAILED",
			"error": network_error,
		}
	_sync_backup_sequence()
	_state = STATE_RUNNING
	_log(
		"INFO",
		"lifecycle",
		"server_started",
		{
			"config": Config.redacted_snapshot(_config),
			"protocol_version": Protocol.PROTOCOL_VERSION,
			"save_schema_version": Protocol.SAVE_SCHEMA_VERSION,
		}
	)
	_emit_status()
	return {"accepted": true, "reason_code": "OK", "status": get_status()}


func execute_admin_command(command_line: String) -> Dictionary:
	var sanitized := command_line.strip_edges()
	if sanitized.is_empty():
		return _rejected("EMPTY_ADMIN_COMMAND")
	var parts := sanitized.split(" ", false)
	var command := (parts[0] as String).to_lower()
	match command:
		"status":
			return {"accepted": true, "reason_code": "OK", "status": get_status()}
		"players":
			return {
				"accepted": true,
				"reason_code": "OK",
				"players": _network_runtime.call("get_authenticated_connections_for_admin") as Array,
			}
		"save":
			var valid := _backend != null and _backend.call("validate_live_records") as bool
			_log("INFO" if valid else "ERROR", "admin", "save_validation", {"accepted": valid})
			return {"accepted": valid, "reason_code": "OK" if valid else "SAVE_VALIDATION_FAILED"}
		"backup":
			return _create_backup("manual")
		"drain":
			return begin_drain()
		"kick":
			if parts.size() != 2 or not (parts[1] as String).is_valid_int():
				return _rejected("ADMIN_ARGUMENT")
			var peer_id := int(parts[1])
			var kicked := _network_runtime != null and _network_runtime.call(
				"disconnect_peer_for_admin", peer_id
			) as bool
			_log("INFO", "admin", "peer_kick", {"peer_id": peer_id, "accepted": kicked})
			return {"accepted": kicked, "reason_code": "OK" if kicked else "PEER_NOT_FOUND"}
		"shutdown":
			return graceful_shutdown()
		_:
			return _rejected("UNKNOWN_ADMIN_COMMAND")


func begin_drain() -> Dictionary:
	if _state == STATE_DRAINING:
		return {"accepted": true, "reason_code": "OK", "replayed": true}
	if _state != STATE_RUNNING or _network_runtime == null:
		return _rejected("NOT_RUNNING")
	if not _network_runtime.call("set_accepting_connections", false):
		return _rejected("DRAIN_FAILED")
	_state = STATE_DRAINING
	_log("INFO", "lifecycle", "server_draining")
	_emit_status()
	return {"accepted": true, "reason_code": "OK", "replayed": false}


func graceful_shutdown() -> Dictionary:
	if _state == STATE_STOPPED:
		return {"accepted": true, "reason_code": "OK", "replayed": true}
	if _state == STATE_MAINTENANCE:
		return _rejected("MAINTENANCE_REQUIRES_OPERATOR")
	var drain_result := begin_drain()
	if not drain_result.get("accepted", false):
		return drain_result
	if not _backend.call("validate_live_records"):
		_state = STATE_MAINTENANCE
		_log("ERROR", "persistence", "shutdown_validation_failed")
		_emit_status()
		return _rejected("SHUTDOWN_SAVE_FAILED")
	var backup_result := _create_backup("shutdown")
	if not backup_result.get("accepted", false):
		_state = STATE_MAINTENANCE
		_log("ERROR", "persistence", "shutdown_backup_failed", backup_result)
		_emit_status()
		return _rejected("SHUTDOWN_BACKUP_FAILED")
	_network_runtime.call("stop")
	_network_runtime.queue_free()
	_network_runtime = null
	_state = STATE_STOPPED
	_log("INFO", "lifecycle", "server_stopped", {"backup_id": backup_result.backup_id})
	_emit_status()
	return {
		"accepted": true,
		"reason_code": "OK",
		"replayed": false,
		"backup_id": backup_result.backup_id,
	}


func stop_without_backup_for_test() -> void:
	if _network_runtime != null:
		_network_runtime.call("stop")
		_network_runtime.queue_free()
		_network_runtime = null
	_state = STATE_STOPPED


func get_status() -> Dictionary:
	var network_status := (
		_network_runtime.call("get_server_status") as Dictionary
		if _network_runtime != null
		else {"running": false, "connections": 0, "authenticated": 0, "accepting": false}
	)
	return {
		"state": _state,
		"server_name": _config.get("server_name", ""),
		"listen_address": _config.get("listen_address", ""),
		"port": int(_config.get("port", 0)),
		"connections": int(network_status.get("connections", 0)),
		"authenticated": int(network_status.get("authenticated", 0)),
		"accepting_connections": network_status.get("accepting", false),
		"maintenance": _state == STATE_MAINTENANCE or (
			_backend != null and _backend.call("is_in_maintenance_mode") as bool
		),
		"backups": (_backend.call("get_backup_ids") as Array).size() if _backend != null else 0,
		"protocol_version": Protocol.PROTOCOL_VERSION,
		"content_version": Protocol.CONTENT_VERSION,
		"save_schema_version": Protocol.SAVE_SCHEMA_VERSION,
	}


func get_network_runtime_for_test() -> Node:
	return _network_runtime


func get_backend_for_test() -> RefCounted:
	return _backend


func get_persistence_coordinator_for_test() -> RefCounted:
	return _persistence_coordinator


func get_logger_for_test() -> RefCounted:
	return _logger


func get_config_redacted() -> Dictionary:
	return Config.redacted_snapshot(_config)


func _create_backup(kind: String) -> Dictionary:
	if _backend == null or not kind in ["manual", "shutdown"]:
		return _rejected("BACKUP_UNAVAILABLE")
	_backup_sequence += 1
	var backup_id := "%s%s.%06d" % [BACKUP_PREFIX, kind, _backup_sequence]
	var result := _backend.call(
		"create_backup", backup_id, int(_config.get("backup_retention", 5))
	) as Dictionary
	if not result.get("accepted", false):
		_backup_sequence -= 1
		_log("ERROR", "admin", "backup_failed", {"reason_code": result.get("reason_code", "")})
		return result
	_log("INFO", "admin", "backup_created", {"backup_id": backup_id, "kind": kind})
	return {"accepted": true, "reason_code": "OK", "backup_id": backup_id}


func _sync_backup_sequence() -> void:
	_backup_sequence = 0
	for backup_id_value: Variant in _backend.call("get_backup_ids") as Array:
		var backup_id := backup_id_value as String
		if not backup_id.begins_with(BACKUP_PREFIX):
			continue
		var suffix := backup_id.get_slice(".", backup_id.get_slice_count(".") - 1)
		if suffix.is_valid_int():
			_backup_sequence = maxi(_backup_sequence, int(suffix))


func _on_network_status_changed(message: String) -> void:
	_log("INFO", "network", "runtime_status", {"message": message})


func _emit_status() -> void:
	status_changed.emit(get_status())


func _log(level: String, category: String, event_name: String, fields: Dictionary = {}) -> void:
	if _logger != null:
		_logger.call("write", level, category, event_name, fields)


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
