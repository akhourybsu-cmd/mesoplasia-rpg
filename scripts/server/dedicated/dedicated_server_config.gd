class_name DedicatedServerConfig
extends RefCounted

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")

const CONFIG_SCHEMA_VERSION := 1
const DEFAULT_INSTANCE_ROOT := "user://mesoplasia-server"
const MIN_PORT := 1024
const MAX_PORT := 65535
const MAX_CONNECTIONS := 8
const MAX_ALLOWLIST_ENTRIES := 64


static func parse(
	source: Dictionary,
	instance_root: String = DEFAULT_INSTANCE_ROOT,
	access_code_override: String = ""
) -> Dictionary:
	if int(source.get("config_schema_version", 0)) != CONFIG_SCHEMA_VERSION:
		return _rejected("CONFIG_SCHEMA_VERSION")
	var server_name := (source.get("server_name", "") as String).strip_edges()
	var listen_address := (source.get("listen_address", "127.0.0.1") as String).strip_edges()
	var port := int(source.get("port", 0))
	var max_connections := int(source.get("max_connections", 0))
	var max_party_size := int(source.get("max_party_size", 0))
	var access_code := access_code_override.strip_edges()
	if access_code.is_empty():
		access_code = (source.get("development_access_code", "") as String).strip_edges()
	if server_name.is_empty() or server_name.length() > 48:
		return _rejected("SERVER_NAME")
	if not listen_address in ["127.0.0.1", "0.0.0.0", "::", "::1"]:
		return _rejected("LISTEN_ADDRESS")
	if port < MIN_PORT or port > MAX_PORT:
		return _rejected("PORT")
	if max_connections < 1 or max_connections > MAX_CONNECTIONS:
		return _rejected("MAX_CONNECTIONS")
	if max_party_size < 1 or max_party_size > max_connections:
		return _rejected("MAX_PARTY_SIZE")
	if access_code.length() < 8 or access_code.length() > 128:
		return _rejected("ACCESS_CODE_POLICY")
	var allowlist_enabled := source.get("allowlist_enabled", true) as bool
	var allowlist_source: Variant = source.get("allowed_display_labels", [])
	if not allowlist_source is Array or (allowlist_source as Array).size() > MAX_ALLOWLIST_ENTRIES:
		return _rejected("ALLOWLIST")
	var allowed_display_labels: Array[String] = []
	for label_value: Variant in allowlist_source as Array:
		if not label_value is String:
			return _rejected("ALLOWLIST")
		var label: String = Protocol.sanitize_display_label(label_value as String)
		if label.is_empty():
			return _rejected("ALLOWLIST")
		if not allowed_display_labels.has(label):
			allowed_display_labels.append(label)
	allowed_display_labels.sort()
	if allowlist_enabled and allowed_display_labels.is_empty():
		return _rejected("ALLOWLIST_EMPTY")

	var root_result := _resolve_instance_root(instance_root)
	if not root_result.get("accepted", false):
		return root_result
	var resolved_root := root_result.path as String
	var save_path_result := _resolve_child_path(
		resolved_root, source.get("save_path", "saves") as String
	)
	var backup_path_result := _resolve_child_path(
		resolved_root, source.get("backup_path", "backups") as String
	)
	var log_path_result := _resolve_child_path(
		resolved_root, source.get("log_path", "logs") as String
	)
	for path_result: Dictionary in [save_path_result, backup_path_result, log_path_result]:
		if not path_result.get("accepted", false):
			return path_result
	var load_timeout_msec := int(source.get("load_timeout_msec", 15000))
	var turn_timeout_msec := int(source.get("turn_timeout_msec", 10000))
	var reconnect_grace_msec := int(source.get("reconnect_grace_msec", 15000))
	var backup_retention := int(source.get("backup_retention", 5))
	if load_timeout_msec < 1000 or load_timeout_msec > 120000:
		return _rejected("LOAD_TIMEOUT")
	if turn_timeout_msec < 1000 or turn_timeout_msec > 120000:
		return _rejected("TURN_TIMEOUT")
	if reconnect_grace_msec < 1000 or reconnect_grace_msec > 300000:
		return _rejected("RECONNECT_GRACE")
	if backup_retention < 1 or backup_retention > 32:
		return _rejected("BACKUP_RETENTION")
	return {
		"accepted": true,
		"reason_code": "OK",
		"config": {
			"config_schema_version": CONFIG_SCHEMA_VERSION,
			"server_name": server_name,
			"listen_address": listen_address,
			"port": port,
			"max_connections": max_connections,
			"max_party_size": max_party_size,
			"access_code": access_code,
			"allowlist_enabled": allowlist_enabled,
			"allowed_display_labels": allowed_display_labels,
			"instance_root": resolved_root,
			"save_path": save_path_result.path,
			"backup_path": backup_path_result.path,
			"log_path": log_path_result.path,
			"backup_retention": backup_retention,
			"load_timeout_msec": load_timeout_msec,
			"turn_timeout_msec": turn_timeout_msec,
			"reconnect_grace_msec": reconnect_grace_msec,
		}
	}


static func redacted_snapshot(config: Dictionary) -> Dictionary:
	var safe := config.duplicate(true)
	if safe.has("access_code"):
		safe.access_code = "[REDACTED]"
	return safe


static func _resolve_instance_root(root_path: String) -> Dictionary:
	var candidate := root_path.strip_edges().replace("\\", "/").trim_suffix("/")
	if candidate.is_empty() or candidate.contains("/../") or candidate.ends_with("/.."):
		return _rejected("INSTANCE_ROOT")
	var absolute := ProjectSettings.globalize_path(candidate).replace("\\", "/").trim_suffix("/")
	if absolute.is_empty() or absolute in ["/", "C:", "C:/"] or absolute.length() < 4:
		return _rejected("INSTANCE_ROOT")
	return {"accepted": true, "path": absolute}


static func _resolve_child_path(root_path: String, relative_path: String) -> Dictionary:
	var candidate: String = relative_path.strip_edges().replace("\\", "/")
	while candidate.begins_with("/"):
		candidate = candidate.trim_prefix("/")
	while candidate.ends_with("/"):
		candidate = candidate.trim_suffix("/")
	if (
		candidate.is_empty()
		or candidate.contains(":")
		or candidate.begins_with("../")
		or candidate.contains("/../")
		or candidate == ".."
		or candidate.ends_with("/..")
	):
		return _rejected("INSTANCE_CHILD_PATH")
	var resolved := "%s/%s" % [root_path, candidate]
	if not resolved.begins_with(root_path + "/"):
		return _rejected("INSTANCE_CHILD_PATH")
	return {"accepted": true, "path": resolved}


static func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
