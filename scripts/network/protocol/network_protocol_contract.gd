class_name NetworkProtocolContract
extends RefCounted

const PROTOCOL_VERSION := 6
const GAME_BUILD_VERSION := "phase-k-development-1"
const CONTENT_VERSION := "phase-k-caden-resources-content-1"
const CONTENT_MANIFEST_HASH := "phase-k-caden-resources-manifest-v1"
const SAVE_SCHEMA_VERSION := 1

const MAX_ENVELOPE_BYTES := 8192
const MAX_STRING_LENGTH := 256
const MAX_COLLECTION_SIZE := 32
const MAX_NESTING_DEPTH := 4

const CLIENT_HELLO := "client_hello"
const AUTHENTICATE := "authenticate"
const DISCONNECT := "disconnect"
const PING := "ping"
const MOVEMENT_INPUT := "movement_input"
const INTERACT := "interact"
const ZONE_TRANSITION := "zone_transition"
const REQUEST_HUB_SNAPSHOT := "request_hub_snapshot"
const CADEN_RESOURCE_DEPOSIT := "caden_resource_deposit"
const CADEN_RESOURCE_REQUEST_SNAPSHOT := "caden_resource_request_snapshot"
const PARTY_INVITE := "party_invite"
const PARTY_ACCEPT := "party_accept"
const PARTY_DECLINE := "party_decline"
const PARTY_LEAVE := "party_leave"
const PARTY_KICK := "party_kick"
const PARTY_TRANSFER_LEADERSHIP := "party_transfer_leadership"
const PARTY_READY := "party_ready"
const PARTY_SELECT_EXPEDITION := "party_select_expedition"
const PARTY_REQUEST_SNAPSHOT := "party_request_snapshot"
const EXPEDITION_LAUNCH := "expedition_launch"
const EXPEDITION_CONTENT_READY := "expedition_content_ready"
const EXPEDITION_ROOM_TRANSITION := "expedition_room_transition"
const EXPEDITION_STUB_OUTCOME := "expedition_stub_outcome"
const EXPEDITION_RETURN_ACK := "expedition_return_ack"
const EXPEDITION_REQUEST_SNAPSHOT := "expedition_request_snapshot"
const COMBAT_START_ENCOUNTER := "combat_start_encounter"
const COMBAT_READY := "combat_ready"
const COMBAT_ACTION := "combat_action"
const COMBAT_REQUEST_SNAPSHOT := "combat_request_snapshot"

const SERVER_HELLO := "server_hello"
const AUTHENTICATION_RESULT := "authentication_result"
const AVATAR_SPAWNED := "avatar_spawned"
const AVATAR_DESPAWNED := "avatar_despawned"
const COMMAND_REJECTED := "command_rejected"
const PONG := "pong"
const HUB_SNAPSHOT := "hub_snapshot"
const INTERACTION_RESULT := "interaction_result"
const ZONE_TRANSFER_RESULT := "zone_transfer_result"
const CADEN_RESOURCE_SNAPSHOT := "caden_resource_snapshot"
const CADEN_RESOURCE_COMMAND_RESULT := "caden_resource_command_result"
const PARTY_SNAPSHOT := "party_snapshot"
const PARTY_COMMAND_RESULT := "party_command_result"
const EXPEDITION_SNAPSHOT := "expedition_snapshot"
const EXPEDITION_COMMAND_RESULT := "expedition_command_result"
const COMBAT_SNAPSHOT := "combat_snapshot"
const COMBAT_COMMAND_RESULT := "combat_command_result"

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

const _CLIENT_MESSAGE_TYPES := [
	CLIENT_HELLO,
	AUTHENTICATE,
	DISCONNECT,
	PING,
	MOVEMENT_INPUT,
	INTERACT,
	ZONE_TRANSITION,
	REQUEST_HUB_SNAPSHOT,
	CADEN_RESOURCE_DEPOSIT,
	CADEN_RESOURCE_REQUEST_SNAPSHOT,
	PARTY_INVITE,
	PARTY_ACCEPT,
	PARTY_DECLINE,
	PARTY_LEAVE,
	PARTY_KICK,
	PARTY_TRANSFER_LEADERSHIP,
	PARTY_READY,
	PARTY_SELECT_EXPEDITION,
	PARTY_REQUEST_SNAPSHOT,
	EXPEDITION_LAUNCH,
	EXPEDITION_CONTENT_READY,
	EXPEDITION_ROOM_TRANSITION,
	EXPEDITION_STUB_OUTCOME,
	EXPEDITION_RETURN_ACK,
	EXPEDITION_REQUEST_SNAPSHOT,
	COMBAT_START_ENCOUNTER,
	COMBAT_READY,
	COMBAT_ACTION,
	COMBAT_REQUEST_SNAPSHOT,
]
const _SERVER_MESSAGE_TYPES := [
	SERVER_HELLO,
	AUTHENTICATION_RESULT,
	AVATAR_SPAWNED,
	AVATAR_DESPAWNED,
	COMMAND_REJECTED,
	PONG,
	HUB_SNAPSHOT,
	INTERACTION_RESULT,
	ZONE_TRANSFER_RESULT,
	CADEN_RESOURCE_SNAPSHOT,
	CADEN_RESOURCE_COMMAND_RESULT,
	PARTY_SNAPSHOT,
	PARTY_COMMAND_RESULT,
	EXPEDITION_SNAPSHOT,
	EXPEDITION_COMMAND_RESULT,
	COMBAT_SNAPSHOT,
	COMBAT_COMMAND_RESULT,
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
		"requested_capabilities": [
			"connection_sandbox", "avatar_presence", "caden_hub", "caden_resources", "party", "expedition", "combat"
		],
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
		MOVEMENT_INPUT:
			if not _has_exact_keys(payload, ["input_sequence", "direction_x", "direction_y"]):
				return _invalid("Movement input fields are invalid.")
			for key: String in ["input_sequence", "direction_x", "direction_y"]:
				if not payload[key] is int:
					return _invalid("Movement input fields must be integers.")
			if payload.input_sequence <= 0:
				return _invalid("Movement input sequence must be positive.")
			if absi(payload.direction_x) > 1 or absi(payload.direction_y) > 1:
				return _invalid("Movement direction is outside the allowed range.")
			if absi(payload.direction_x) + absi(payload.direction_y) > 1:
				return _invalid("Movement direction must be cardinal or zero.")
		INTERACT:
			if not _has_exact_keys(payload, ["interactable_id"]):
				return _invalid("Interaction fields are invalid.")
			if not payload.interactable_id is String or not _nonempty_string_within_limit(payload.interactable_id, 128):
				return _invalid("InteractableId is invalid.")
		ZONE_TRANSITION:
			if not _has_exact_keys(payload, ["exit_id"]):
				return _invalid("Zone transition fields are invalid.")
			if not payload.exit_id is String or not _nonempty_string_within_limit(payload.exit_id, 128):
				return _invalid("ExitId is invalid.")
		REQUEST_HUB_SNAPSHOT:
			if not payload.is_empty():
				return _invalid("Hub snapshot request payload must be empty.")
		CADEN_RESOURCE_DEPOSIT:
			if not _has_exact_keys(
				payload,
				[
					"deposit_id",
					"resource_id",
					"quantity",
					"expected_inventory_revision",
					"expected_world_revision",
				]
			):
				return _invalid("Caden resource deposit fields are invalid.")
			if (
				not _valid_party_id_field(payload.deposit_id)
				or not _valid_party_id_field(payload.resource_id)
				or not payload.quantity is int
				or payload.quantity < 1
				or payload.quantity > 9999
				or not _valid_expected_revision(payload.expected_inventory_revision)
				or not _valid_expected_revision(payload.expected_world_revision)
			):
				return _invalid("Caden resource deposit values are invalid.")
		CADEN_RESOURCE_REQUEST_SNAPSHOT:
			if not payload.is_empty():
				return _invalid("Caden resource snapshot request payload must be empty.")
		PARTY_INVITE:
			if not _has_exact_keys(payload, ["recipient_character_id", "expected_revision"]):
				return _invalid("Party invite fields are invalid.")
			if not _valid_party_id_field(payload.recipient_character_id):
				return _invalid("Party invite recipient is invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party revision is invalid.")
		PARTY_ACCEPT, PARTY_DECLINE:
			if not _has_exact_keys(payload, ["invite_id", "expected_revision"]):
				return _invalid("Party invite response fields are invalid.")
			if not _valid_party_id_field(payload.invite_id):
				return _invalid("Party InviteId is invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party revision is invalid.")
		PARTY_LEAVE:
			if not _has_exact_keys(payload, ["expected_revision"]):
				return _invalid("Party leave fields are invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party revision is invalid.")
		PARTY_KICK, PARTY_TRANSFER_LEADERSHIP:
			if not _has_exact_keys(payload, ["target_character_id", "expected_revision"]):
				return _invalid("Party member command fields are invalid.")
			if not _valid_party_id_field(payload.target_character_id):
				return _invalid("Party target CharacterId is invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party revision is invalid.")
		PARTY_READY:
			if not _has_exact_keys(payload, ["is_ready", "expected_revision"]):
				return _invalid("Party readiness fields are invalid.")
			if not payload.is_ready is bool or not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party readiness values are invalid.")
		PARTY_SELECT_EXPEDITION:
			if not _has_exact_keys(
				payload, ["expedition_definition_id", "expected_revision"]
			):
				return _invalid("Party expedition selection fields are invalid.")
			if not _valid_party_id_field(payload.expedition_definition_id):
				return _invalid("Expedition definition ID is invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Party revision is invalid.")
		PARTY_REQUEST_SNAPSHOT:
			if not payload.is_empty():
				return _invalid("Party snapshot request payload must be empty.")
		EXPEDITION_LAUNCH:
			if not _has_exact_keys(payload, ["expected_party_revision"]):
				return _invalid("Expedition launch fields are invalid.")
			if not _valid_expected_revision(payload.expected_party_revision):
				return _invalid("Expected party revision is invalid.")
		EXPEDITION_CONTENT_READY, EXPEDITION_RETURN_ACK:
			if not _has_exact_keys(payload, ["expedition_id", "expected_revision"]):
				return _invalid("Expedition acknowledgement fields are invalid.")
			if (
				not _valid_party_id_field(payload.expedition_id)
				or not _valid_expected_revision(payload.expected_revision)
			):
				return _invalid("Expedition acknowledgement values are invalid.")
		EXPEDITION_ROOM_TRANSITION:
			if not _has_exact_keys(
				payload, ["expedition_id", "connection_id", "expected_revision"]
			):
				return _invalid("Expedition room transition fields are invalid.")
			if (
				not _valid_party_id_field(payload.expedition_id)
				or not _valid_party_id_field(payload.connection_id)
				or not _valid_expected_revision(payload.expected_revision)
			):
				return _invalid("Expedition room transition values are invalid.")
		EXPEDITION_STUB_OUTCOME:
			if not _has_exact_keys(
				payload, ["expedition_id", "outcome_code", "expected_revision"]
			):
				return _invalid("Expedition outcome fields are invalid.")
			if (
				not _valid_party_id_field(payload.expedition_id)
				or payload.outcome_code not in ["SUCCESS", "RETREAT", "FAILURE"]
				or not _valid_expected_revision(payload.expected_revision)
			):
				return _invalid("Expedition outcome values are invalid.")
		EXPEDITION_REQUEST_SNAPSHOT:
			if not payload.is_empty():
				return _invalid("Expedition snapshot request payload must be empty.")
		COMBAT_START_ENCOUNTER:
			if not _has_exact_keys(
				payload, ["expedition_id", "encounter_id", "expected_expedition_revision"]
			):
				return _invalid("Combat encounter fields are invalid.")
			if (
				not _valid_party_id_field(payload.expedition_id)
				or not _valid_party_id_field(payload.encounter_id)
				or not _valid_expected_revision(payload.expected_expedition_revision)
			):
				return _invalid("Combat encounter values are invalid.")
		COMBAT_READY:
			if not _has_exact_keys(payload, ["combat_id", "expected_revision"]):
				return _invalid("Combat ready fields are invalid.")
			if (
				not _valid_party_id_field(payload.combat_id)
				or not _valid_expected_revision(payload.expected_revision)
			):
				return _invalid("Combat ready values are invalid.")
		COMBAT_ACTION:
			if not _has_exact_keys(
				payload,
				[
					"combat_id",
					"expected_revision",
					"action_nonce",
					"actor_id",
					"ability_id",
					"target_ids",
				]
			):
				return _invalid("Combat action fields are invalid.")
			for key: String in ["combat_id", "action_nonce", "actor_id", "ability_id"]:
				if not _valid_party_id_field(payload[key]):
					return _invalid("Combat action identity is invalid.")
			if not _valid_expected_revision(payload.expected_revision):
				return _invalid("Combat action revision is invalid.")
			if not payload.target_ids is Array or payload.target_ids.is_empty() or payload.target_ids.size() > 4:
				return _invalid("Combat action targets are invalid.")
			for target_id: Variant in payload.target_ids:
				if not _valid_party_id_field(target_id):
					return _invalid("Combat action target identity is invalid.")
		COMBAT_REQUEST_SNAPSHOT:
			if not payload.is_empty():
				return _invalid("Combat snapshot request payload must be empty.")
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
		HUB_SNAPSHOT:
			expected_keys = [
				"snapshot_schema_version",
				"zone_id",
				"world_revision",
				"server_tick",
				"avatars",
				"npcs",
			]
		INTERACTION_RESULT:
			expected_keys = [
				"accepted", "reason_code", "reason_text", "interactable_id", "zone_id"
			]
		ZONE_TRANSFER_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"exit_id",
				"zone_id",
				"entry_id",
				"world_revision",
			]
		CADEN_RESOURCE_SNAPSHOT:
			expected_keys = [
				"resource_snapshot_schema_version",
				"projection_revision",
				"world_id",
				"world_record_revision",
				"inventory_record_revision",
				"inventory_resources",
				"stockpiles",
				"projects",
			]
		CADEN_RESOURCE_COMMAND_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"command_type",
				"deposit_id",
				"inventory_record_revision",
				"world_record_revision",
				"changed_project_ids",
				"replayed",
			]
		PARTY_SNAPSHOT:
			expected_keys = [
				"party_snapshot_schema_version",
				"projection_revision",
				"party_id",
				"revision",
				"lifecycle_state",
				"leader_character_id",
				"selected_expedition_definition_id",
				"current_expedition_id",
				"max_party_size",
				"all_present_members_ready",
				"members",
				"invitations",
			]
		PARTY_COMMAND_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"command_type",
				"party_id",
				"revision",
			]
		EXPEDITION_SNAPSHOT:
			expected_keys = [
				"expedition_snapshot_schema_version",
				"projection_revision",
				"expedition_id",
				"dungeon_instance_id",
				"expedition_definition_id",
				"seed",
				"revision",
				"lifecycle_state",
				"leader_character_id",
				"current_room_id",
				"load_deadline_msec",
				"outcome",
				"active_combat_id",
				"checkpoint_revision",
				"visited_room_ids",
				"encounters",
				"avatars",
			]
		EXPEDITION_COMMAND_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"command_type",
				"expedition_id",
				"revision",
				"lifecycle_state",
			]
		COMBAT_SNAPSHOT:
			expected_keys = [
				"combat_snapshot_schema_version",
				"projection_revision",
				"combat_id",
				"expedition_id",
				"encounter_id",
				"revision",
				"lifecycle_state",
				"round_number",
				"current_actor_id",
				"turn_deadline_msec",
				"event_sequence",
				"outcome",
				"ready_controller_ids",
				"combatants",
				"events",
			]
		COMBAT_COMMAND_RESULT:
			expected_keys = [
				"accepted",
				"reason_code",
				"reason_text",
				"command_type",
				"combat_id",
				"revision",
			]
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


static func _valid_party_id_field(value: Variant) -> bool:
	return value is String and _nonempty_string_within_limit(value as String, 128)


static func _valid_expected_revision(value: Variant) -> bool:
	return value is int and int(value) >= -1


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
