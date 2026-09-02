class_name ExpeditionService
extends RefCounted

const EXPEDITION_SNAPSHOT_SCHEMA_VERSION := 2
const DEFAULT_MAX_ACTIVE_EXPEDITIONS := 1
const DEFAULT_LOAD_TIMEOUT_MSEC := 5000
const MOVEMENT_SPEED := 150.0
const INPUT_TIMEOUT_MSEC := 250
const PLAYER_HALF_SIZE := Vector2(12.0, 12.0)

const STATE_LOADING := "LOADING"
const STATE_ACTIVE_EXPLORATION := "ACTIVE_EXPLORATION"
const STATE_ACTIVE_COMBAT := "ACTIVE_COMBAT"
const STATE_RETURNING_TO_CADEN := "RETURNING_TO_CADEN"
const STATE_CLOSED := "CLOSED"
const STATE_FAILED := "FAILED"

const OUTCOME_NONE := "NONE"
const OUTCOME_SUCCESS := "SUCCESS"
const OUTCOME_RETREAT := "RETREAT"
const OUTCOME_FAILURE := "FAILURE"

var _definition_registry: RefCounted
var _party_service: RefCounted
var _checkpoint_store: RefCounted
var _max_active_expeditions := DEFAULT_MAX_ACTIVE_EXPEDITIONS
var _load_timeout_msec := DEFAULT_LOAD_TIMEOUT_MSEC
var _seed_base := 730_001
var _expedition_serial := 0
var _projection_revision := 0
var _instances_by_id: Dictionary = {}
var _expedition_id_by_character_id: Dictionary = {}
var _identities_by_character_id: Dictionary = {}


func configure(
	definition_registry: RefCounted,
	party_service: RefCounted,
	checkpoint_store: RefCounted,
	max_active_expeditions: int = DEFAULT_MAX_ACTIVE_EXPEDITIONS,
	load_timeout_msec: int = DEFAULT_LOAD_TIMEOUT_MSEC,
	seed_base: int = 730_001
) -> bool:
	if (
		definition_registry == null
		or party_service == null
		or checkpoint_store == null
		or not definition_registry.call("is_valid")
		or max_active_expeditions < 1
		or max_active_expeditions > 16
		or load_timeout_msec < 1
	):
		return false
	_definition_registry = definition_registry
	_party_service = party_service
	_checkpoint_store = checkpoint_store
	_max_active_expeditions = max_active_expeditions
	_load_timeout_msec = load_timeout_msec
	_seed_base = seed_base
	return true


func connect_character(identity: Dictionary, _now_msec: int) -> Dictionary:
	var character_id := identity.get("character_id", "") as String
	if character_id.is_empty():
		return _rejected("INVALID_IDENTITY", "Character identity is missing.")
	_identities_by_character_id[character_id] = identity.duplicate(true)
	var instance := _instance_for_character(character_id)
	if instance.is_empty() or instance.lifecycle_state in [STATE_CLOSED, STATE_FAILED]:
		return _accepted({"character_id": character_id, "in_expedition": false})
	var avatar := (instance.avatars as Dictionary).get(character_id, {}) as Dictionary
	if avatar.is_empty():
		return _rejected("NOT_A_MEMBER", "Character is not part of the expedition.")
	avatar.connected = true
	avatar.velocity = Vector2.ZERO
	avatar.input_direction = Vector2.ZERO
	avatar.last_input_sequence = 0
	avatar.last_input_msec = 0
	avatar.return_acknowledged = false
	if instance.lifecycle_state == STATE_LOADING:
		avatar.content_ready = false
	_increment_revision(instance)
	return _accepted(
		{
			"character_id": character_id,
			"expedition_id": instance.expedition_id,
			"in_expedition": instance.lifecycle_state in [
				STATE_LOADING,
				STATE_ACTIVE_EXPLORATION,
				STATE_ACTIVE_COMBAT,
			],
		}
	)


func disconnect_character(character_id: String, _now_msec: int) -> bool:
	var instance := _instance_for_character(character_id)
	if instance.is_empty() or instance.lifecycle_state in [STATE_CLOSED, STATE_FAILED]:
		return false
	var avatar := (instance.avatars as Dictionary).get(character_id, {}) as Dictionary
	if avatar.is_empty() or not avatar.connected:
		return false
	avatar.connected = false
	avatar.content_ready = false if instance.lifecycle_state == STATE_LOADING else avatar.content_ready
	avatar.return_acknowledged = false
	avatar.velocity = Vector2.ZERO
	avatar.input_direction = Vector2.ZERO
	_increment_revision(instance)
	return true


func launch_expedition(
	leader_character_id: String,
	expected_party_revision: int,
	now_msec: int
) -> Dictionary:
	if get_active_expedition_count() >= _max_active_expeditions:
		return _rejected("EXPEDITION_CAPACITY", "The server already has an active expedition.")
	var party := _party_service.call(
		"get_party_for_character", leader_character_id
	) as Dictionary
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var definition_id := party.get("selected_expedition_definition_id", "") as String
	var definition := _definition_registry.call("get_definition", definition_id) as Dictionary
	if definition.is_empty():
		return _rejected("INVALID_DEFINITION", "The selected expedition definition is unavailable.")
	_expedition_serial += 1
	var expedition_id := "development.expedition_instance.%d" % _expedition_serial
	var dungeon_instance_id := "development.dungeon_instance.%d" % _expedition_serial
	var member_ids := _sorted_party_member_ids(party)
	var entry_room := (definition.rooms as Dictionary)[definition.entry_room_id] as Dictionary
	var avatars: Dictionary = {}
	for index in member_ids.size():
		var character_id := member_ids[index]
		var member := (party.members as Dictionary)[character_id] as Dictionary
		var spawn_positions := entry_room.spawn_positions as Array
		avatars[character_id] = {
			"character_id": character_id,
			"display_label": _display_label(character_id),
			"connected": member.connected,
			"content_ready": false,
			"return_acknowledged": false,
			"position": spawn_positions[index % spawn_positions.size()],
			"velocity": Vector2.ZERO,
			"facing": Vector2.DOWN,
			"input_direction": Vector2.ZERO,
			"last_input_sequence": 0,
			"last_input_msec": 0,
		}
	var instance := {
		"expedition_id": expedition_id,
		"dungeon_instance_id": dungeon_instance_id,
		"expedition_definition_id": definition_id,
		"dungeon_definition_id": definition.dungeon_definition_id,
		"party_id": party.party_id,
		"leader_character_id": party.leader_character_id,
		"seed": _seed_base + _expedition_serial,
		"revision": 1,
		"lifecycle_state": STATE_LOADING,
		"current_room_id": definition.entry_room_id,
		"visited_room_ids": [definition.entry_room_id],
		"avatars": avatars,
		"load_deadline_msec": now_msec + _load_timeout_msec,
		"outcome": OUTCOME_NONE,
		"active_combat_id": "",
		"encounters": _initial_encounter_states(definition),
		"checkpoint_revision": 0,
		"return_zone_id": definition.return_zone_id,
		"return_entry_id": definition.return_entry_id,
	}
	var reservation := _party_service.call(
		"reserve_expedition",
		leader_character_id,
		expedition_id,
		definition_id,
		expected_party_revision
	) as Dictionary
	if not reservation.accepted:
		return reservation
	if not _store_checkpoint(instance, now_msec):
		_party_service.call("rollback_expedition", expedition_id)
		return _rejected("CHECKPOINT_FAILED", "Launch checkpoint could not be recorded.")
	_instances_by_id[expedition_id] = instance
	for character_id: String in member_ids:
		_expedition_id_by_character_id[character_id] = expedition_id
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"dungeon_instance_id": dungeon_instance_id,
			"revision": instance.revision,
			"lifecycle_state": STATE_LOADING,
		}
	)


func acknowledge_content_ready(
	character_id: String,
	expedition_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	var check := _require_instance_command(instance, character_id, expected_revision, STATE_LOADING)
	if not check.accepted:
		return check
	var avatar := (instance.avatars as Dictionary)[character_id] as Dictionary
	if not avatar.connected:
		return _rejected("MEMBER_DISCONNECTED", "A disconnected client cannot complete loading.", instance)
	if avatar.content_ready:
		return _accepted({"expedition_id": expedition_id, "revision": instance.revision})
	avatar.content_ready = true
	_increment_revision(instance)
	if not _all_required_content_ready(instance):
		return _accepted({"expedition_id": expedition_id, "revision": instance.revision})
	var candidate := instance.duplicate(true)
	candidate.lifecycle_state = STATE_ACTIVE_EXPLORATION
	candidate.load_deadline_msec = 0
	candidate.revision = int(instance.revision) + 1
	if not _store_checkpoint(candidate, now_msec):
		_cancel_loading(instance, "CHECKPOINT_FAILED", now_msec)
		return _rejected(
			"CHECKPOINT_FAILED",
			"The load barrier could not be committed; the party remained in Caden.",
			instance
		)
	var party_commit := _party_service.call("commit_expedition", expedition_id) as Dictionary
	if not party_commit.accepted:
		_cancel_loading(instance, "PARTY_COMMIT_FAILED", now_msec)
		return _rejected("PARTY_COMMIT_FAILED", "The party transfer could not be committed.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"revision": candidate.revision,
			"transfer_committed": true,
			"member_character_ids": (candidate.avatars as Dictionary).keys(),
		}
	)


func submit_movement(
	character_id: String,
	expedition_id: String,
	input_sequence: int,
	direction: Vector2,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	if instance.is_empty() or instance.lifecycle_state != STATE_ACTIVE_EXPLORATION:
		return _rejected("INVALID_STATE", "Expedition exploration is not active.", instance)
	var avatar := (instance.avatars as Dictionary).get(character_id, {}) as Dictionary
	if avatar.is_empty() or not avatar.connected:
		return _rejected("NOT_A_MEMBER", "Character is not an active expedition member.", instance)
	if input_sequence <= int(avatar.last_input_sequence):
		return _rejected("STALE_INPUT", "Movement input sequence is stale.", instance)
	if not _is_cardinal_or_zero(direction):
		return _rejected("INVALID_DIRECTION", "Movement input must be cardinal or zero.", instance)
	avatar.last_input_sequence = input_sequence
	avatar.input_direction = direction
	avatar.last_input_msec = now_msec
	return _accepted({"expedition_id": expedition_id, "revision": instance.revision})


func request_room_transition(
	character_id: String,
	expedition_id: String,
	connection_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	var check := _require_instance_command(
		instance, character_id, expected_revision, STATE_ACTIVE_EXPLORATION
	)
	if not check.accepted:
		return check
	if instance.leader_character_id != character_id:
		return _rejected("NOT_LEADER", "Only the party leader may change rooms.", instance)
	var connection := _definition_registry.call(
		"get_connection",
		instance.expedition_definition_id,
		instance.current_room_id,
		connection_id
	) as Dictionary
	if connection.is_empty():
		return _rejected("INVALID_CONNECTION", "The room connection is not available.", instance)
	if not _all_connected_members_in_rect(instance, connection.activation_rect):
		return _rejected("PARTY_NOT_COHESIVE", "All connected members must gather at the exit.", instance)
	var candidate := instance.duplicate(true)
	candidate.current_room_id = connection.destination_room_id
	if not (candidate.visited_room_ids as Array).has(connection.destination_room_id):
		(candidate.visited_room_ids as Array).append(connection.destination_room_id)
	var destination_positions := connection.destination_positions as Array
	var member_ids := (candidate.avatars as Dictionary).keys()
	member_ids.sort()
	for index in member_ids.size():
		var avatar := (candidate.avatars as Dictionary)[member_ids[index]] as Dictionary
		avatar.position = destination_positions[index % destination_positions.size()]
		avatar.velocity = Vector2.ZERO
		avatar.input_direction = Vector2.ZERO
	candidate.revision = int(instance.revision) + 1
	if not _store_checkpoint(candidate, now_msec):
		return _rejected("CHECKPOINT_FAILED", "Room transition checkpoint failed.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"revision": candidate.revision,
			"room_id": candidate.current_room_id,
		}
	)


func request_stub_outcome(
	character_id: String,
	expedition_id: String,
	outcome_code: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	var check := _require_instance_command(
		instance, character_id, expected_revision, STATE_ACTIVE_EXPLORATION
	)
	if not check.accepted:
		return check
	if instance.leader_character_id != character_id:
		return _rejected("NOT_LEADER", "Only the party leader may resolve the test expedition.", instance)
	if outcome_code not in [OUTCOME_SUCCESS, OUTCOME_RETREAT, OUTCOME_FAILURE]:
		return _rejected("INVALID_OUTCOME", "The requested test outcome is unsupported.", instance)
	if outcome_code == OUTCOME_SUCCESS:
		var room := _definition_registry.call(
			"get_room", instance.expedition_definition_id, instance.current_room_id
		) as Dictionary
		if room.is_empty() or not (room.goal_rect as Rect2).has_area():
			return _rejected("GOAL_UNAVAILABLE", "This room has no completion goal.", instance)
		if not _all_connected_members_in_rect(instance, room.goal_rect):
			return _rejected("PARTY_NOT_COHESIVE", "All connected members must gather at the goal.", instance)
	var candidate := instance.duplicate(true)
	candidate.lifecycle_state = STATE_RETURNING_TO_CADEN
	candidate.outcome = outcome_code
	candidate.revision = int(instance.revision) + 1
	for avatar_value: Variant in (candidate.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		avatar.velocity = Vector2.ZERO
		avatar.input_direction = Vector2.ZERO
		avatar.return_acknowledged = false
	if not _store_checkpoint(candidate, now_msec):
		return _rejected("CHECKPOINT_FAILED", "Outcome checkpoint failed; exploration remains active.", instance)
	var party_return := _party_service.call("begin_return", expedition_id) as Dictionary
	if not party_return.accepted:
		return _rejected("PARTY_RETURN_FAILED", "The party could not begin its safe return.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"revision": candidate.revision,
			"outcome": outcome_code,
			"return_required": true,
			"member_character_ids": (candidate.avatars as Dictionary).keys(),
			"return_zone_id": candidate.return_zone_id,
			"return_entry_id": candidate.return_entry_id,
		}
	)


func validate_encounter_start(
	character_id: String,
	expedition_id: String,
	encounter_id: String,
	expected_revision: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	var check := _require_instance_command(
		instance, character_id, expected_revision, STATE_ACTIVE_EXPLORATION
	)
	if not check.accepted:
		return check
	if instance.leader_character_id != character_id:
		return _rejected("NOT_LEADER", "Only the party leader may start an encounter.", instance)
	var encounter := _definition_registry.call(
		"get_encounter",
		instance.expedition_definition_id,
		instance.current_room_id,
		encounter_id
	) as Dictionary
	if encounter.is_empty():
		return _rejected("ENCOUNTER_NOT_FOUND", "The encounter is not in this room.", instance)
	var encounter_state := (instance.encounters as Dictionary).get(encounter_id, {}) as Dictionary
	if encounter_state.get("status", "") != "PENDING":
		return _rejected("ENCOUNTER_ALREADY_RESOLVED", "The encounter is not pending.", instance)
	if not _all_connected_members_in_rect(instance, encounter.activation_rect):
		return _rejected(
			"PARTY_NOT_COHESIVE", "All connected members must gather at the encounter.", instance
		)
	var member_ids: Array = (instance.avatars as Dictionary).keys()
	member_ids.sort()
	return _accepted(
		{
			"expedition_id": expedition_id,
			"encounter_id": encounter_id,
			"seed": int(instance.seed) ^ int(encounter_id.hash()),
			"member_character_ids": member_ids,
			"enemy_template_ids": (encounter.enemy_template_ids as Array).duplicate(),
		}
	)


func commit_encounter_start(
	character_id: String,
	expedition_id: String,
	encounter_id: String,
	expected_revision: int,
	combat_id: String,
	now_msec: int
) -> Dictionary:
	var validation := validate_encounter_start(
		character_id, expedition_id, encounter_id, expected_revision
	)
	if not validation.accepted:
		return validation
	if combat_id.is_empty():
		return _rejected("INVALID_COMBAT", "The combat identity is missing.")
	var instance := _active_instance(expedition_id)
	var candidate := instance.duplicate(true)
	candidate.lifecycle_state = STATE_ACTIVE_COMBAT
	candidate.active_combat_id = combat_id
	candidate.revision = int(instance.revision) + 1
	var encounter_state := (candidate.encounters as Dictionary)[encounter_id] as Dictionary
	encounter_state.status = "ACTIVE"
	encounter_state.combat_id = combat_id
	for avatar_value: Variant in (candidate.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		avatar.velocity = Vector2.ZERO
		avatar.input_direction = Vector2.ZERO
	if not _store_checkpoint(candidate, now_msec):
		return _rejected("CHECKPOINT_FAILED", "Combat boundary checkpoint failed.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"revision": candidate.revision,
			"combat_id": combat_id,
			"lifecycle_state": STATE_ACTIVE_COMBAT,
		}
	)


func resolve_encounter(
	expedition_id: String,
	combat_id: String,
	victory: bool,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	if instance.is_empty() or instance.lifecycle_state != STATE_ACTIVE_COMBAT:
		return _rejected("INVALID_STATE", "The expedition is not in combat.", instance)
	if instance.active_combat_id != combat_id:
		return _rejected("COMBAT_MISMATCH", "The combat does not own this expedition.", instance)
	var encounter_id := ""
	for candidate_id: Variant in instance.encounters:
		var state := (instance.encounters as Dictionary)[candidate_id] as Dictionary
		if state.get("combat_id", "") == combat_id and state.get("status", "") == "ACTIVE":
			encounter_id = candidate_id as String
			break
	if encounter_id.is_empty():
		return _rejected("ENCOUNTER_NOT_FOUND", "The active encounter is missing.", instance)
	var candidate := instance.duplicate(true)
	candidate.active_combat_id = ""
	candidate.revision = int(instance.revision) + 1
	var encounter_state := (candidate.encounters as Dictionary)[encounter_id] as Dictionary
	encounter_state.status = "COMPLETED" if victory else "FAILED"
	if victory:
		candidate.lifecycle_state = STATE_ACTIVE_EXPLORATION
	else:
		candidate.lifecycle_state = STATE_RETURNING_TO_CADEN
		candidate.outcome = OUTCOME_FAILURE
		for avatar_value: Variant in (candidate.avatars as Dictionary).values():
			(avatar_value as Dictionary).return_acknowledged = false
	if not _store_checkpoint(candidate, now_msec):
		return _rejected("CHECKPOINT_FAILED", "Combat outcome checkpoint failed.", instance)
	if not victory:
		var party_return := _party_service.call("begin_return", expedition_id) as Dictionary
		if not party_return.accepted:
			return _rejected("PARTY_RETURN_FAILED", "Combat defeat could not begin return.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	var result := {
		"expedition_id": expedition_id,
		"revision": candidate.revision,
		"encounter_id": encounter_id,
		"resumed_exploration": victory,
		"return_required": not victory,
	}
	if not victory:
		result.merge(
			{
				"member_character_ids": (candidate.avatars as Dictionary).keys(),
				"return_zone_id": candidate.return_zone_id,
				"return_entry_id": candidate.return_entry_id,
			},
			true
		)
	return _accepted(result)


func acknowledge_caden_return(
	character_id: String,
	expedition_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var instance := _active_instance(expedition_id)
	var check := _require_instance_command(
		instance, character_id, expected_revision, STATE_RETURNING_TO_CADEN
	)
	if not check.accepted:
		return check
	var avatar := (instance.avatars as Dictionary)[character_id] as Dictionary
	if avatar.return_acknowledged:
		return _accepted({"expedition_id": expedition_id, "revision": instance.revision})
	avatar.return_acknowledged = true
	_increment_revision(instance)
	if not _all_connected_returns_acknowledged(instance):
		return _accepted({"expedition_id": expedition_id, "revision": instance.revision})
	var candidate := instance.duplicate(true)
	candidate.lifecycle_state = STATE_CLOSED
	candidate.revision = int(instance.revision) + 1
	if not _store_checkpoint(candidate, now_msec):
		return _rejected("CHECKPOINT_FAILED", "Final return checkpoint failed.", instance)
	var party_complete := _party_service.call("complete_return", expedition_id) as Dictionary
	if not party_complete.accepted:
		return _rejected("PARTY_RETURN_FAILED", "The party return could not be completed.", instance)
	_instances_by_id[expedition_id] = candidate
	_projection_revision += 1
	return _accepted(
		{
			"expedition_id": expedition_id,
			"revision": candidate.revision,
			"closed": true,
		}
	)


func tick(delta: float, now_msec: int) -> Dictionary:
	var result := {"changed": false, "party_changed": false, "load_cancelled": false}
	for expedition_id: Variant in _instances_by_id:
		var instance := _instances_by_id[expedition_id] as Dictionary
		if (
			instance.lifecycle_state == STATE_LOADING
			and now_msec >= int(instance.load_deadline_msec)
		):
			_cancel_loading(instance, "LOAD_TIMEOUT", now_msec)
			result.changed = true
			result.party_changed = true
			result.load_cancelled = true
		elif instance.lifecycle_state == STATE_ACTIVE_EXPLORATION:
			if _advance_movement(instance, delta, now_msec):
				_increment_revision(instance)
				result.changed = true
	return result


func get_snapshot_for(character_id: String) -> Dictionary:
	var instance := _instance_for_character(character_id)
	if instance.is_empty():
		return _empty_snapshot()
	var avatar_rows: Array = []
	var member_ids := (instance.avatars as Dictionary).keys()
	member_ids.sort()
	for member_id: Variant in member_ids:
		var avatar := (instance.avatars as Dictionary)[member_id] as Dictionary
		var position := avatar.position as Vector2
		var velocity := avatar.velocity as Vector2
		var facing := avatar.facing as Vector2
		avatar_rows.append(
			[
				member_id,
				avatar.display_label,
				avatar.connected,
				avatar.content_ready,
				avatar.return_acknowledged,
				position.x,
				position.y,
				velocity.x,
				velocity.y,
				facing.x,
				facing.y,
			]
		)
	var encounter_rows: Array = []
	var encounter_ids := (instance.encounters as Dictionary).keys()
	encounter_ids.sort()
	for encounter_id: Variant in encounter_ids:
		var encounter := (instance.encounters as Dictionary)[encounter_id] as Dictionary
		encounter_rows.append(
			[encounter_id, encounter.get("status", "PENDING"), encounter.get("combat_id", "")]
		)
	return {
		"expedition_snapshot_schema_version": EXPEDITION_SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": _projection_revision,
		"expedition_id": instance.expedition_id,
		"dungeon_instance_id": instance.dungeon_instance_id,
		"expedition_definition_id": instance.expedition_definition_id,
		"seed": instance.seed,
		"revision": instance.revision,
		"lifecycle_state": instance.lifecycle_state,
		"leader_character_id": instance.leader_character_id,
		"current_room_id": instance.current_room_id,
		"load_deadline_msec": instance.load_deadline_msec,
		"outcome": instance.outcome,
		"active_combat_id": instance.active_combat_id,
		"checkpoint_revision": instance.checkpoint_revision,
		"visited_room_ids": (instance.visited_room_ids as Array).duplicate(),
		"encounters": encounter_rows,
		"avatars": avatar_rows,
	}


func get_instance_state(expedition_id: String) -> Dictionary:
	var instance := _instances_by_id.get(expedition_id, {}) as Dictionary
	return instance.duplicate(true) if not instance.is_empty() else {}


func get_expedition_id_for_character(character_id: String) -> String:
	return _expedition_id_by_character_id.get(character_id, "") as String


func has_character_in_active_expedition(character_id: String) -> bool:
	var instance := _instance_for_character(character_id)
	return not instance.is_empty() and instance.lifecycle_state in [
		STATE_LOADING,
		STATE_ACTIVE_EXPLORATION,
		STATE_ACTIVE_COMBAT,
	]


func get_active_expedition_count() -> int:
	var count := 0
	for instance_value: Variant in _instances_by_id.values():
		if (instance_value as Dictionary).lifecycle_state in [
			STATE_LOADING,
			STATE_ACTIVE_EXPLORATION,
			STATE_ACTIVE_COMBAT,
			STATE_RETURNING_TO_CADEN,
		]:
			count += 1
	return count


func set_avatar_position_for_test(
	character_id: String,
	room_id: String,
	position: Vector2
) -> bool:
	var instance := _instance_for_character(character_id)
	if instance.is_empty() or not (instance.avatars as Dictionary).has(character_id):
		return false
	var room := _definition_registry.call(
		"get_room", instance.expedition_definition_id, room_id
	) as Dictionary
	if room.is_empty() or not _position_in_room(position, room.bounds):
		return false
	instance.current_room_id = room_id
	((instance.avatars as Dictionary)[character_id] as Dictionary).position = position
	_increment_revision(instance)
	return true


func _advance_movement(instance: Dictionary, delta: float, now_msec: int) -> bool:
	var changed := false
	var room := _definition_registry.call(
		"get_room", instance.expedition_definition_id, instance.current_room_id
	) as Dictionary
	for avatar_value: Variant in (instance.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		if not avatar.connected:
			continue
		var direction := avatar.input_direction as Vector2
		if now_msec - int(avatar.last_input_msec) > INPUT_TIMEOUT_MSEC:
			direction = Vector2.ZERO
			avatar.input_direction = Vector2.ZERO
		var velocity := direction * MOVEMENT_SPEED
		var next_position := (avatar.position as Vector2) + velocity * delta
		if not _position_in_room(next_position, room.bounds):
			velocity = Vector2.ZERO
			next_position = avatar.position
		if next_position != avatar.position or velocity != avatar.velocity:
			avatar.position = next_position
			avatar.velocity = velocity
			if direction != Vector2.ZERO:
				avatar.facing = direction
			changed = true
	return changed


func _cancel_loading(instance: Dictionary, reason: String, now_msec: int) -> void:
	_party_service.call("rollback_expedition", instance.expedition_id)
	instance.lifecycle_state = STATE_FAILED
	instance.outcome = reason
	instance.load_deadline_msec = 0
	_increment_revision(instance)
	_store_checkpoint(instance, now_msec)


func _store_checkpoint(instance: Dictionary, now_msec: int) -> bool:
	var checkpoint_revision := int(instance.get("checkpoint_revision", 0)) + 1
	var avatar_rows: Array = []
	var member_ids := (instance.avatars as Dictionary).keys()
	member_ids.sort()
	for character_id: Variant in member_ids:
		var avatar := (instance.avatars as Dictionary)[character_id] as Dictionary
		var position := avatar.position as Vector2
		avatar_rows.append([character_id, avatar.connected, position.x, position.y])
	var checkpoint := {
		"checkpoint_schema_version": 1,
		"expedition_id": instance.expedition_id,
		"dungeon_instance_id": instance.dungeon_instance_id,
		"expedition_definition_id": instance.expedition_definition_id,
		"dungeon_definition_id": instance.dungeon_definition_id,
		"seed": instance.seed,
		"revision": instance.revision,
		"lifecycle_state": instance.lifecycle_state,
		"party_id": instance.party_id,
		"leader_character_id": instance.leader_character_id,
		"current_room_id": instance.current_room_id,
		"visited_room_ids": (instance.visited_room_ids as Array).duplicate(),
		"outcome": instance.outcome,
		"active_combat_id": instance.active_combat_id,
		"encounters": (instance.encounters as Dictionary).duplicate(true),
		"checkpoint_revision": checkpoint_revision,
		"avatars": avatar_rows,
		"recorded_msec": now_msec,
	}
	if not _checkpoint_store.call("store_checkpoint", checkpoint):
		return false
	instance.checkpoint_revision = checkpoint_revision
	return true


func _all_required_content_ready(instance: Dictionary) -> bool:
	for avatar_value: Variant in (instance.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		if not avatar.connected or not avatar.content_ready:
			return false
	return not (instance.avatars as Dictionary).is_empty()


func _initial_encounter_states(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for room_value: Variant in (definition.rooms as Dictionary).values():
		var room := room_value as Dictionary
		for encounter_id: Variant in room.encounters:
			result[encounter_id] = {"status": "PENDING", "combat_id": ""}
	return result


func _all_connected_returns_acknowledged(instance: Dictionary) -> bool:
	var connected_count := 0
	for avatar_value: Variant in (instance.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		if avatar.connected:
			connected_count += 1
			if not avatar.return_acknowledged:
				return false
	return connected_count > 0


func _all_connected_members_in_rect(instance: Dictionary, area: Rect2) -> bool:
	var connected_count := 0
	for avatar_value: Variant in (instance.avatars as Dictionary).values():
		var avatar := avatar_value as Dictionary
		if avatar.connected:
			connected_count += 1
			if not area.has_point(avatar.position):
				return false
	return connected_count > 0


func _require_instance_command(
	instance: Dictionary,
	character_id: String,
	expected_revision: int,
	required_state: String
) -> Dictionary:
	if instance.is_empty():
		return _rejected("EXPEDITION_NOT_FOUND", "The expedition does not exist.")
	if instance.lifecycle_state != required_state:
		return _rejected("INVALID_STATE", "The expedition command is out of state.", instance)
	if not (instance.avatars as Dictionary).has(character_id):
		return _rejected("NOT_A_MEMBER", "Character is not an expedition member.", instance)
	if int(instance.revision) != expected_revision:
		return _rejected("STALE_REVISION", "Expedition revision is stale.", instance)
	return _accepted()


func _sorted_party_member_ids(party: Dictionary) -> Array[String]:
	var rows: Array[Dictionary] = []
	for character_id: Variant in party.members:
		var member := (party.members as Dictionary)[character_id] as Dictionary
		rows.append({"character_id": character_id, "join_order": member.join_order})
	rows.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			if first.join_order == second.join_order:
				return first.character_id < second.character_id
			return int(first.join_order) < int(second.join_order)
	)
	var ids: Array[String] = []
	for row: Dictionary in rows:
		ids.append(row.character_id)
	return ids


func _display_label(character_id: String) -> String:
	var identity := _identities_by_character_id.get(character_id, {}) as Dictionary
	return identity.get("display_label", character_id) as String


func _position_in_room(position: Vector2, bounds: Rect2) -> bool:
	var allowed := Rect2(
		bounds.position + PLAYER_HALF_SIZE,
		bounds.size - PLAYER_HALF_SIZE * 2.0
	)
	return allowed.has_point(position)


func _is_cardinal_or_zero(direction: Vector2) -> bool:
	return (
		direction == Vector2.ZERO
		or direction == Vector2.UP
		or direction == Vector2.DOWN
		or direction == Vector2.LEFT
		or direction == Vector2.RIGHT
	)


func _instance_for_character(character_id: String) -> Dictionary:
	var expedition_id := _expedition_id_by_character_id.get(character_id, "") as String
	return _instances_by_id.get(expedition_id, {}) as Dictionary


func _active_instance(expedition_id: String) -> Dictionary:
	var instance := _instances_by_id.get(expedition_id, {}) as Dictionary
	if instance.is_empty() or instance.lifecycle_state in [STATE_CLOSED, STATE_FAILED]:
		return {}
	return instance


func _increment_revision(instance: Dictionary) -> void:
	instance.revision = int(instance.revision) + 1
	_projection_revision += 1


func _empty_snapshot() -> Dictionary:
	return {
		"expedition_snapshot_schema_version": EXPEDITION_SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": _projection_revision,
		"expedition_id": "",
		"dungeon_instance_id": "",
		"expedition_definition_id": "",
		"seed": 0,
		"revision": -1,
		"lifecycle_state": "NONE",
		"leader_character_id": "",
		"current_room_id": "",
		"load_deadline_msec": 0,
		"outcome": OUTCOME_NONE,
		"active_combat_id": "",
		"checkpoint_revision": 0,
		"visited_room_ids": [],
		"encounters": [],
		"avatars": [],
	}


func _accepted(extra: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Expedition command accepted.",
		"expedition_id": "",
		"revision": -1,
	}
	result.merge(extra, true)
	return result


func _rejected(
	reason_code: String,
	reason_text: String,
	instance: Dictionary = {}
) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"reason_text": reason_text,
		"expedition_id": instance.get("expedition_id", ""),
		"revision": instance.get("revision", -1),
	}
