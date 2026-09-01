class_name NetworkProtocolContract
extends RefCounted

const PROTOCOL_VERSION := 1
const GAME_BUILD_VERSION := "phase-c-development-1"
const CONTENT_VERSION := "phase-c-sandbox-content-1"
const CONTENT_MANIFEST_HASH := "phase-c-sandbox-manifest-v1"
const SAVE_SCHEMA_VERSION := 0

const MAX_ENVELOPE_BYTES := 8192
const MAX_STRING_LENGTH := 256
const MAX_COLLECTION_SIZE := 32
const MAX_NESTING_DEPTH := 4

const CLIENT_HELLO := "client_hello"
const AUTHENTICATE := "authenticate"
const DISCONNECT := "disconnect"
const PING := "ping"

const SERVER_HELLO := "server_hello"
const AUTHENTICATION_RESULT := "authentication_result"
const AVATAR_SPAWNED := "avatar_spawned"
const AVATAR_DESPAWNED := "avatar_despawned"
const COMMAND_REJECTED := "command_rejected"
const PONG := "pong"

const REASON_OK := "OK"
const REASON_MALFORMED := "MALFORMED_MESSAGE"
const REASON_VERSION_MISMATCH := "VERSION_MISMATCH"
const REASON_CONTENT_MISMATCH := "CONTENT_MISMATCH"
const REASON_INVALID_STATE := "INVALID_SESSION_STATE"
const REASON_AUTH_FAILED := "AUTHENTICATION_FAILED"
const REASON_CHARACTER_IN_USE := "CHARACTER_IN_USE"
const REASON_STALE_SEQUENCE := "STALE_SEQUENCE"
const REASON_RATE_LIMITED := "RATE_LIMITED"
const REASON_SESSION_MISMATCH := "SESSION_MISMATCH"

const _CLIENT_MESSAGE_TYPES := [CLIENT_HELLO, AUTHENTICATE, DISCONNECT, PING]
const _SERVER_MESSAGE_TYPES := [
	SERVER_HELLO,
	AUTHENTICATION_RESULT,
	AVATAR_SPAWNED,
	AVATAR_DESPAWNED,
	COMMAND_REJECTED,
	PONG,
]


static func make_client_envelope(
	message_type: String,
	session_id: String,
	command_id: String,
	client_sequence: int,
	payload: Dictionary,
	protocol_version: int = PROTOCOL_VERSION
) -> Dictionary:
	return {
		"protocol_version": protocol_version,
		"message_type": message_type,
		"session_id": session_id,
		"command_id": command_id,
		"client_sequence": client_sequence,
		"payload": payload.duplicate(true),
	}


static func make_server_envelope(
	message_type: String,
	server_sequence: int,
	causation_command_id: String,
	payload: Dictionary
) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"message_type": message_type,
		"server_sequence": server_sequence,
		"causation_command_id": causation_command_id,
		"payload": payload.duplicate(true),
	}


static func make_client_hello_payload(client_nonce: String) -> Dictionary:
	return {
		"game_build_version": GAME_BUILD_VERSION,
		"content_version": CONTENT_VERSION,
		"content_manifest_hash": CONTENT_MANIFEST_HASH,
		"requested_capabilities": ["connection_sandbox", "avatar_presence"],
		"client_nonce": client_nonce,
	}


static func validate_client_envelope(value: Variant) -> Dictionary:
	var common_result := _validate_envelope_common(
		value,
		[
			"protocol_version",
			"message_type",
			"session_id",
			"command_id",
			"client_sequence",
			"payload",
		]
	)
	if not common_result.valid:
		return common_result
	var envelope := value as Dictionary
	if not envelope.message_type in _CLIENT_MESSAGE_TYPES:
		return _invalid("Unsupported client message type.")
	if not envelope.session_id is String or not _string_within_limit(envelope.session_id, 96):
		return _invalid("Client session ID is invalid.")
	if not envelope.command_id is String or not _nonempty_string_within_limit(envelope.command_id, 96):
		return _invalid("Client command ID is invalid.")
	if not envelope.client_sequence is int or envelope.client_sequence <= 0:
		return _invalid("Client sequence must be a positive integer.")
	return _validate_client_payload(envelope.message_type, envelope.payload)


static func validate_server_envelope(value: Variant) -> Dictionary:
	var common_result := _validate_envelope_common(
		value,
		[
			"protocol_version",
			"message_type",
			"server_sequence",
			"causation_command_id",
			"payload",
		]
	)
	if not common_result.valid:
		return common_result
	var envelope := value as Dictionary
	if not envelope.message_type in _SERVER_MESSAGE_TYPES:
		return _invalid("Unsupported server message type.")
	if not envelope.server_sequence is int or envelope.server_sequence <= 0:
		return _invalid("Server sequence must be a positive integer.")
	if (
		not envelope.causation_command_id is String
		or not _string_within_limit(envelope.causation_command_id, 96)
	):
		return _invalid("Server causation command ID is invalid.")
	return _validate_server_payload(envelope.message_type, envelope.payload)


static func is_safe_display_label(value: String) -> bool:
	var stripped := value.strip_edges()
	if stripped.is_empty() or stripped.length() > 24:
		return false
	for index in stripped.length():
		var codepoint := stripped.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true


static func sanitize_display_label(value: String) -> String:
	return value.strip_edges().left(24)


static func _validate_envelope_common(value: Variant, required_keys: Array) -> Dictionary:
	if not value is Dictionary:
		return _invalid("Envelope must be a dictionary.")
	var envelope := value as Dictionary
	if not _has_exact_keys(envelope, required_keys):
		return _invalid("Envelope fields do not match the protocol schema.")
	if not _is_bounded_primitive(value, 0):
		return _invalid("Envelope contains unsupported or oversized values.")
	if var_to_bytes(value).size() > MAX_ENVELOPE_BYTES:
		return _invalid("Envelope exceeds the byte limit.")
	if not envelope.protocol_version is int:
		return _invalid("Protocol version must be an integer.")
	if not envelope.message_type is String:
		return _invalid("Message type must be a string.")
	if not envelope.payload is Dictionary:
		return _invalid("Envelope payload must be a dictionary.")
	return _valid()


static func _validate_client_payload(message_type: String, payload: Dictionary) -> Dictionary:
	match message_type:
		CLIENT_HELLO:
			if not _has_exact_keys(
				payload,
				[
					"game_build_version",
					"content_version",
					"content_manifest_hash",
					"requested_capabilities",
					"client_nonce",
				]
			):
				return _invalid("Client hello fields are invalid.")
			for key: String in [
				"game_build_version", "content_version", "content_manifest_hash", "client_nonce"
			]:
				if not payload[key] is String or not _nonempty_string_within_limit(payload[key], 128):
					return _invalid("Client hello string field is invalid.")
			if not payload.requested_capabilities is Array:
				return _invalid("Requested capabilities must be an array.")
			if payload.requested_capabilities.size() > 8:
				return _invalid("Too many requested capabilities.")
			for capability: Variant in payload.requested_capabilities:
				if not capability is String or not _nonempty_string_within_limit(capability, 64):
					return _invalid("Requested capability is invalid.")
		AUTHENTICATE:
			if not _has_exact_keys(
				payload,
				["session_challenge", "access_code", "display_label", "reconnect_token"]
			):
				return _invalid("Authentication fields are invalid.")
			for key: String in ["session_challenge", "access_code", "display_label", "reconnect_token"]:
				if not payload[key] is String or not _string_within_limit(payload[key], 256):
					return _invalid("Authentication string field is invalid.")
			if not is_safe_display_label(payload.display_label):
				return _invalid("Display label is invalid.")
		DISCONNECT:
			if not payload.is_empty():
				return _invalid("Disconnect payload must be empty.")
		PING:
			if not _has_exact_keys(payload, ["client_tick"]):
				return _invalid("Ping fields are invalid.")
			if not payload.client_tick is int or payload.client_tick < 0:
				return _invalid("Client tick is invalid.")
		_:
			return _invalid("Unsupported client payload.")
	return _valid()


static func _validate_server_payload(message_type: String, payload: Dictionary) -> Dictionary:
	var expected_keys: Array = []
	match message_type:
		SERVER_HELLO:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"protocol_version",
				"game_build_version",
				"content_version",
				"content_manifest_hash",
				"server_name",
				"capabilities",
				"session_challenge",
			]
		AUTHENTICATION_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"session_id",
				"account_id",
				"character_id",
				"avatar_runtime_id",
				"display_label",
				"reconnect_token",
			]
		AVATAR_SPAWNED:
			expected_keys = ["character_id", "avatar_runtime_id", "display_label"]
		AVATAR_DESPAWNED:
			expected_keys = ["character_id", "avatar_runtime_id", "reason"]
		COMMAND_REJECTED:
			expected_keys = ["reason_code", "reason_text"]
		PONG:
			expected_keys = ["client_tick"]
		_:
			return _invalid("Unsupported server payload.")
	if not _has_exact_keys(payload, expected_keys):
		return _invalid("Server payload fields are invalid.")
	return _valid()


static func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key: Variant in expected_keys:
		if not value.has(key):
			return false
	return true


static func _is_bounded_primitive(value: Variant, depth: int) -> bool:
	if depth > MAX_NESTING_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return true
		TYPE_STRING:
			return (value as String).length() <= MAX_STRING_LENGTH
		TYPE_ARRAY:
			var array := value as Array
			if array.size() > MAX_COLLECTION_SIZE:
				return false
			for item: Variant in array:
				if not _is_bounded_primitive(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var dictionary := value as Dictionary
			if dictionary.size() > MAX_COLLECTION_SIZE:
				return false
			for key: Variant in dictionary:
				if not key is String or not _nonempty_string_within_limit(key, 64):
					return false
				if not _is_bounded_primitive(dictionary[key], depth + 1):
					return false
			return true
		_:
			return false


static func _string_within_limit(value: String, maximum: int) -> bool:
	return value.length() <= maximum


static func _nonempty_string_within_limit(value: String, maximum: int) -> bool:
	return not value.is_empty() and value.length() <= maximum


static func _valid() -> Dictionary:
	return {"valid": true, "reason_code": REASON_OK, "reason_text": ""}


static func _invalid(reason_text: String) -> Dictionary:
	return {"valid": false, "reason_code": REASON_MALFORMED, "reason_text": reason_text}
