class_name NetworkCombatCoordinator
extends RefCounted

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")

const NETWORK_COMBAT_SNAPSHOT_SCHEMA_VERSION := 1
const DEFAULT_TURN_TIMEOUT_MSEC := 10000

var _expedition_service: RefCounted
var _registry: RefCounted
var _combat_service: RefCounted
var _checkpoint_store: RefCounted
var _projection_revision := 0
var _metadata_by_combat_id: Dictionary = {}
var _combat_id_by_character_id: Dictionary = {}


func configure(
	expedition_service: RefCounted,
	turn_timeout_msec: int = DEFAULT_TURN_TIMEOUT_MSEC,
	event_limit: int = 32,
	checkpoint_store: RefCounted = null
) -> bool:
	if expedition_service == null or turn_timeout_msec < 1 or event_limit < 4:
		return false
	_registry = Registry.new()
	if not _registry.call("is_valid"):
		return false
	_combat_service = CombatService.new()
	if not _combat_service.call(
		"configure", _registry, SpatialRules.new(), EnemyPolicy.new(), turn_timeout_msec, event_limit
	):
		return false
	_expedition_service = expedition_service
	_checkpoint_store = checkpoint_store
	return true


func start_encounter(
	character_id: String,
	expedition_id: String,
	encounter_id: String,
	expected_expedition_revision: int,
	now_msec: int
) -> Dictionary:
	var validation := _expedition_service.call(
		"validate_encounter_start",
		character_id,
		expedition_id,
		encounter_id,
		expected_expedition_revision
	) as Dictionary
	if not validation.get("accepted", false):
		return validation
	var combatants: Array = []
	var member_ids := validation.member_character_ids as Array
	for index in member_ids.size():
		var member_id := member_ids[index] as String
		var template_id := (
			"development.combatant.vanguard"
			if index % 2 == 0
			else "development.combatant.warden"
		)
		combatants.append(
			_registry.call(
				"instantiate_combatant",
				template_id,
				"development.combatant.network.hero.%d" % index,
				member_id
			)
		)
	var enemy_templates := validation.enemy_template_ids as Array
	for index in enemy_templates.size():
		combatants.append(
			_registry.call(
				"instantiate_combatant",
				enemy_templates[index],
				"development.combatant.network.enemy.%d" % index
			)
		)
	var created := _combat_service.call(
		"create_combat", int(validation.seed), combatants, now_msec
	) as Dictionary
	if not created.get("accepted", false):
		return created
	var combat_id := created.combat_id as String
	if not _persist_checkpoint(combat_id):
		return _rejected("CHECKPOINT_WRITE_FAILED", combat_id)
	var committed := _expedition_service.call(
		"commit_encounter_start",
		character_id,
		expedition_id,
		encounter_id,
		expected_expedition_revision,
		combat_id,
		now_msec
	) as Dictionary
	if not committed.get("accepted", false):
		if _checkpoint_store != null:
			_checkpoint_store.call("remove_checkpoint", combat_id)
		return committed
	_metadata_by_combat_id[combat_id] = {
		"combat_id": combat_id,
		"expedition_id": expedition_id,
		"encounter_id": encounter_id,
		"member_character_ids": member_ids.duplicate(),
		"settled": false,
		"settlement_count": 0,
	}
	for member_id: Variant in member_ids:
		_combat_id_by_character_id[member_id] = combat_id
	_projection_revision += 1
	return _accepted(combat_id, {"expedition_id": expedition_id, "encounter_id": encounter_id})


func acknowledge_ready(
	character_id: String,
	combat_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	if not _character_owns_combat(character_id, combat_id):
		return _rejected("NOT_A_PARTICIPANT", combat_id)
	var before := _combat_service.call("serialize_checkpoint", combat_id) as Dictionary
	var result := _combat_service.call(
		"acknowledge_ready", character_id, combat_id, expected_revision, now_msec
	) as Dictionary
	if result.get("accepted", false) and not _persist_checkpoint(combat_id):
		_combat_service.call("restore_checkpoint", before, true)
		return _rejected("CHECKPOINT_WRITE_FAILED", combat_id)
	if result.get("accepted", false):
		_projection_revision += 1
	return result


func submit_action(
	character_id: String,
	combat_id: String,
	expected_revision: int,
	action_nonce: String,
	actor_id: String,
	ability_id: String,
	target_ids: Array,
	now_msec: int
) -> Dictionary:
	if not _character_owns_combat(character_id, combat_id):
		return _rejected("NOT_A_PARTICIPANT", combat_id)
	var before := _combat_service.call("serialize_checkpoint", combat_id) as Dictionary
	var result := _combat_service.call(
		"submit_action",
		character_id,
		combat_id,
		expected_revision,
		action_nonce,
		actor_id,
		ability_id,
		target_ids,
		now_msec
	) as Dictionary
	if result.get("accepted", false) and not _persist_checkpoint(combat_id):
		_combat_service.call("restore_checkpoint", before, true)
		return _rejected("CHECKPOINT_WRITE_FAILED", combat_id)
	if result.get("accepted", false):
		_projection_revision += 1
	return result


func set_character_connected(character_id: String, connected: bool) -> bool:
	var combat_id := _combat_id_by_character_id.get(character_id, "") as String
	if combat_id.is_empty():
		return false
	var before := _combat_service.call("serialize_checkpoint", combat_id) as Dictionary
	var result := _combat_service.call(
		"set_controller_connected", combat_id, character_id, connected
	) as Dictionary
	if result.get("accepted", false):
		if not _persist_checkpoint(combat_id):
			_combat_service.call("restore_checkpoint", before, true)
			return false
		_projection_revision += 1
		return true
	return false


func tick(now_msec: int) -> Dictionary:
	var checkpoints_before: Dictionary = {}
	if _checkpoint_store != null:
		for combat_id_value: Variant in _metadata_by_combat_id:
			var tracked_combat_id := combat_id_value as String
			checkpoints_before[tracked_combat_id] = _combat_service.call(
				"serialize_checkpoint", tracked_combat_id
			) as Dictionary
	var domain_tick := _combat_service.call("tick", now_msec) as Dictionary
	var changed := domain_tick.get("changed", false) as bool
	if changed and _checkpoint_store != null:
		for combat_id_value: Variant in checkpoints_before:
			var tracked_combat_id := combat_id_value as String
			var before := checkpoints_before[tracked_combat_id] as Dictionary
			var after := _combat_service.call("serialize_checkpoint", tracked_combat_id) as Dictionary
			if before.get("checksum", "") == after.get("checksum", ""):
				continue
			if not _persist_checkpoint(tracked_combat_id):
				_combat_service.call("restore_checkpoint", before, true)
				return {
					"changed": false,
					"settlements": [],
					"return_requests": [],
					"persistence_failed": true,
				}
	if changed:
		_projection_revision += 1
	var settlements: Array = []
	var return_requests: Array = []
	var combat_ids := _metadata_by_combat_id.keys()
	combat_ids.sort()
	for combat_id_value: Variant in combat_ids:
		var combat_id := combat_id_value as String
		var metadata := _metadata_by_combat_id[combat_id] as Dictionary
		if metadata.settled:
			continue
		var snapshot := _combat_service.call("get_snapshot", combat_id) as Dictionary
		if snapshot.get("lifecycle_state", "") != CombatService.STATE_COMBAT_END:
			continue
		var victory: bool = snapshot.get("outcome", "") == "VICTORY:heroes"
		var settlement := _expedition_service.call(
			"resolve_encounter", metadata.expedition_id, combat_id, victory, now_msec
		) as Dictionary
		if not settlement.get("accepted", false):
			continue
		metadata.settled = true
		metadata.settlement_count = int(metadata.settlement_count) + 1
		var before_close := _combat_service.call("serialize_checkpoint", combat_id) as Dictionary
		_combat_service.call("close_combat", combat_id, int(snapshot.revision))
		if not _persist_checkpoint(combat_id):
			_combat_service.call("restore_checkpoint", before_close, true)
			metadata.settled = false
			metadata.settlement_count = int(metadata.settlement_count) - 1
			continue
		_projection_revision += 1
		changed = true
		settlements.append(settlement)
		if settlement.get("return_required", false):
			return_requests.append(settlement)
	return {
		"changed": changed,
		"settlements": settlements,
		"return_requests": return_requests,
	}


func get_snapshot_for(character_id: String) -> Dictionary:
	var combat_id := _combat_id_by_character_id.get(character_id, "") as String
	if combat_id.is_empty():
		return _empty_snapshot()
	var metadata := _metadata_by_combat_id.get(combat_id, {}) as Dictionary
	var snapshot := _combat_service.call("get_snapshot", combat_id) as Dictionary
	if metadata.is_empty() or snapshot.is_empty():
		return _empty_snapshot()
	var combatant_rows: Array = []
	for combatant_value: Variant in snapshot.combatants:
		var combatant := combatant_value as Dictionary
		var status_labels: Array[String] = []
		for status_value: Variant in combatant.get("statuses", []):
			var status := status_value as Dictionary
			status_labels.append("%s:%d" % [status.status_id, status.remaining_turns])
		combatant_rows.append(
			[
				combatant.combatant_id,
				combatant.template_id,
				combatant.display_name,
				combatant.team_id,
				combatant.health,
				combatant.max_health,
				combatant.resource,
				combatant.max_resource,
				combatant.controller_id,
				combatant.ai_controlled,
				combatant.alive,
				combatant.connected,
				", ".join(status_labels),
			]
		)
	var event_rows: Array = []
	for event_value: Variant in snapshot.recent_events:
		var event := event_value as Dictionary
		event_rows.append(
			[
				event.event_sequence,
				event.combat_revision,
				event.event_type,
				event.actor_id,
				",".join(event.target_ids as Array),
				_event_detail(event),
			]
		)
	var domain_instance := _combat_service.call("get_instance_state", combat_id) as Dictionary
	var ready_controller_ids := (domain_instance.get("ready_controllers", {}) as Dictionary).keys()
	ready_controller_ids.sort()
	return {
		"combat_snapshot_schema_version": NETWORK_COMBAT_SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": _projection_revision,
		"combat_id": combat_id,
		"expedition_id": metadata.expedition_id,
		"encounter_id": metadata.encounter_id,
		"revision": snapshot.revision,
		"lifecycle_state": snapshot.lifecycle_state,
		"round_number": snapshot.round_number,
		"current_actor_id": snapshot.current_actor_id,
		"turn_deadline_msec": snapshot.turn_deadline_msec,
		"event_sequence": snapshot.event_sequence,
		"outcome": snapshot.outcome,
		"ready_controller_ids": ready_controller_ids,
		"combatants": combatant_rows,
		"events": event_rows,
	}


func get_combat_id_for_character(character_id: String) -> String:
	return _combat_id_by_character_id.get(character_id, "") as String


func get_settlement_count(combat_id: String) -> int:
	return int((_metadata_by_combat_id.get(combat_id, {}) as Dictionary).get("settlement_count", 0))


func get_combat_service_for_test() -> RefCounted:
	return _combat_service


func restore_persisted_combat(combat_id: String, metadata: Dictionary) -> Dictionary:
	if _checkpoint_store == null or combat_id.is_empty() or metadata.is_empty():
		return _rejected("CHECKPOINT_UNAVAILABLE", combat_id)
	var checkpoint := _checkpoint_store.call("load_checkpoint", combat_id) as Dictionary
	if checkpoint.is_empty():
		return _rejected("CHECKPOINT_NOT_FOUND", combat_id)
	var restored := _combat_service.call("restore_checkpoint", checkpoint) as Dictionary
	if not restored.get("accepted", false):
		return restored
	var member_ids := (metadata.get("member_character_ids", []) as Array).duplicate()
	var restored_metadata := metadata.duplicate(true)
	restored_metadata["combat_id"] = combat_id
	restored_metadata["member_character_ids"] = member_ids
	restored_metadata["settled"] = metadata.get("settled", false)
	restored_metadata["settlement_count"] = int(metadata.get("settlement_count", 0))
	_metadata_by_combat_id[combat_id] = restored_metadata
	for member_id: Variant in member_ids:
		_combat_id_by_character_id[member_id] = combat_id
	_projection_revision += 1
	return _accepted(combat_id, {"restored": true})


func _character_owns_combat(character_id: String, combat_id: String) -> bool:
	return _combat_id_by_character_id.get(character_id, "") == combat_id


func _persist_checkpoint(combat_id: String) -> bool:
	if _checkpoint_store == null:
		return true
	var checkpoint := _combat_service.call("serialize_checkpoint", combat_id) as Dictionary
	return not checkpoint.is_empty() and _checkpoint_store.call(
		"store_checkpoint", combat_id, checkpoint
	) as bool


func _event_detail(event: Dictionary) -> String:
	var payload := event.get("payload", {}) as Dictionary
	if payload.has("ability_id"):
		return payload.ability_id
	if payload.has("amount"):
		return "amount:%d" % int(payload.amount)
	if payload.has("outcome"):
		return payload.outcome
	return ""


func _empty_snapshot() -> Dictionary:
	return {
		"combat_snapshot_schema_version": NETWORK_COMBAT_SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": _projection_revision,
		"combat_id": "",
		"expedition_id": "",
		"encounter_id": "",
		"revision": -1,
		"lifecycle_state": "NONE",
		"round_number": 0,
		"current_actor_id": "",
		"turn_deadline_msec": 0,
		"event_sequence": 0,
		"outcome": "NONE",
		"ready_controller_ids": [],
		"combatants": [],
		"events": [],
	}


func _accepted(combat_id: String, extra: Dictionary = {}) -> Dictionary:
	var snapshot := _combat_service.call("get_snapshot", combat_id) as Dictionary
	var result := {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Combat command accepted.",
		"combat_id": combat_id,
		"revision": snapshot.get("revision", -1),
	}
	result.merge(extra, true)
	return result


func _rejected(reason_code: String, combat_id: String = "") -> Dictionary:
	var snapshot := (
		_combat_service.call("get_snapshot", combat_id) as Dictionary
		if _combat_service != null and not combat_id.is_empty()
		else {}
	)
	return {
		"accepted": false,
		"reason_code": reason_code,
		"reason_text": "Combat command rejected.",
		"combat_id": combat_id,
		"revision": snapshot.get("revision", -1),
	}
