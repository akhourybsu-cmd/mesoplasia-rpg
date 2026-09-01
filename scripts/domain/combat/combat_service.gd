class_name CombatService
extends RefCounted

const CombatRngScript := preload("res://scripts/domain/combat/combat_rng.gd")

const COMBAT_SCHEMA_VERSION := 1
const CHECKPOINT_SCHEMA_VERSION := 1

const STATE_WAITING_FOR_CLIENTS := "WAITING_FOR_CLIENTS"
const STATE_ROUND_START := "ROUND_START"
const STATE_AWAITING_ACTION := "AWAITING_ACTION"
const STATE_AI_SELECTING := "AI_SELECTING"
const STATE_RESOLVING_ACTION := "RESOLVING_ACTION"
const STATE_COMBAT_END := "COMBAT_END"
const STATE_CLOSED := "CLOSED"

const OUTCOME_NONE := "NONE"
const OUTCOME_DRAW := "DRAW"
const DEFAULT_TURN_TIMEOUT_MSEC := 60000
const DEFAULT_EVENT_LIMIT := 64

var _registry: RefCounted
var _spatial_rules: RefCounted
var _enemy_policy: RefCounted
var _turn_timeout_msec := DEFAULT_TURN_TIMEOUT_MSEC
var _event_limit := DEFAULT_EVENT_LIMIT
var _combat_id_sequence := 0
var _instances: Dictionary = {}


func configure(
	registry: RefCounted,
	spatial_rules: RefCounted,
	enemy_policy: RefCounted,
	turn_timeout_msec: int = DEFAULT_TURN_TIMEOUT_MSEC,
	event_limit: int = DEFAULT_EVENT_LIMIT
) -> bool:
	if (
		registry == null
		or not registry.call("is_valid")
		or spatial_rules == null
		or enemy_policy == null
		or turn_timeout_msec <= 0
		or event_limit < 8
	):
		return false
	_registry = registry
	_spatial_rules = spatial_rules
	_enemy_policy = enemy_policy
	_turn_timeout_msec = turn_timeout_msec
	_event_limit = event_limit
	return true


func create_combat(seed: int, combatants: Array, now_msec: int) -> Dictionary:
	if _registry == null:
		return _rejected("NOT_CONFIGURED")
	var normalized := _normalize_combatants(combatants)
	if not normalized.accepted:
		return normalized
	_combat_id_sequence += 1
	var combat_id := "development.combat.instance.%d" % _combat_id_sequence
	var initiative_rng := CombatRngScript.new()
	initiative_rng.configure(seed ^ 0x13579BDF)
	var effect_rng := CombatRngScript.new()
	effect_rng.configure(seed ^ 0x2468ACE0)
	var instance := {
		"combat_schema_version": COMBAT_SCHEMA_VERSION,
		"combat_id": combat_id,
		"seed": seed,
		"revision": 0,
		"lifecycle_state": STATE_WAITING_FOR_CLIENTS,
		"round_number": 0,
		"turn_queue": [],
		"turn_index": -1,
		"current_actor_id": "",
		"turn_deadline_msec": 0,
		"combatants": normalized.combatants,
		"ready_controllers": {},
		"used_action_nonces": {},
		"rng_streams": {
			"initiative": initiative_rng.get_state(),
			"effects": effect_rng.get_state(),
		},
		"event_sequence": 0,
		"events": [],
		"outcome": OUTCOME_NONE,
	}
	_instances[combat_id] = instance
	_mutate(instance)
	_emit_event(instance, "COMBAT_CREATED", "", [], {"seed": seed})
	if _required_controller_ids(instance).is_empty():
		_begin_round(instance, now_msec)
	return _accepted(instance, {"combat_id": combat_id})


func acknowledge_ready(
	controller_id: String,
	combat_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	var check := _require_state(instance, expected_revision, STATE_WAITING_FOR_CLIENTS)
	if not check.accepted:
		return check
	if controller_id not in _required_controller_ids(instance):
		return _rejected("NOT_A_CONTROLLER", instance)
	if (instance.ready_controllers as Dictionary).has(controller_id):
		return _accepted(instance)
	(instance.ready_controllers as Dictionary)[controller_id] = true
	_mutate(instance)
	_emit_event(instance, "CONTROLLER_READY", "", [], {"controller_id": controller_id})
	if _all_controllers_ready(instance):
		_begin_round(instance, now_msec)
	return _accepted(instance)


func submit_action(
	controller_id: String,
	combat_id: String,
	expected_revision: int,
	action_nonce: String,
	actor_id: String,
	ability_id: String,
	target_ids: Array,
	now_msec: int
) -> Dictionary:
	return _submit_action_internal(
		controller_id,
		combat_id,
		expected_revision,
		action_nonce,
		actor_id,
		ability_id,
		target_ids,
		now_msec,
		false
	)


func resolve_ai_turn(combat_id: String, now_msec: int) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty() or instance.lifecycle_state != STATE_AI_SELECTING:
		return _rejected("INVALID_STATE", instance)
	var actor_id := instance.current_actor_id as String
	var action := _enemy_policy.call(
		"choose_action", actor_id, instance.combatants, _registry, _spatial_rules
	) as Dictionary
	if action.is_empty():
		_apply_end_turn_fallback(instance, actor_id, "AI_NO_ACTION", now_msec)
		return _accepted(instance, {"fallback": true})
	var nonce := "ai.%d.%s.%d" % [instance.round_number, actor_id, instance.revision]
	return _submit_action_internal(
		"",
		combat_id,
		instance.revision,
		nonce,
		actor_id,
		action.ability_id,
		action.target_ids,
		now_msec,
		true
	)


func tick(now_msec: int) -> Dictionary:
	var changed := false
	var timed_out_ids: Array[String] = []
	var ai_resolved_ids: Array[String] = []
	var combat_ids := _instances.keys()
	combat_ids.sort()
	for combat_id_value: Variant in combat_ids:
		var combat_id := combat_id_value as String
		var instance := _instances[combat_id] as Dictionary
		if instance.lifecycle_state == STATE_AI_SELECTING:
			resolve_ai_turn(combat_id, now_msec)
			changed = true
			ai_resolved_ids.append(combat_id)
		elif (
			instance.lifecycle_state == STATE_AWAITING_ACTION
			and now_msec >= int(instance.turn_deadline_msec)
		):
			_resolve_timeout(instance, now_msec)
			changed = true
			timed_out_ids.append(combat_id)
	return {
		"changed": changed,
		"timed_out_combat_ids": timed_out_ids,
		"ai_resolved_combat_ids": ai_resolved_ids,
	}


func set_controller_connected(
	combat_id: String,
	controller_id: String,
	connected: bool
) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty():
		return _rejected("UNKNOWN_COMBAT")
	var changed := false
	for combatant_value: Variant in (instance.combatants as Dictionary).values():
		var combatant := combatant_value as Dictionary
		if combatant.controller_id == controller_id and combatant.connected != connected:
			combatant.connected = connected
			changed = true
	if changed:
		_mutate(instance)
		_emit_event(
			instance,
			"CONTROLLER_CONNECTION_CHANGED",
			"",
			[],
			{"controller_id": controller_id, "connected": connected}
		)
	return _accepted(instance)


func close_combat(combat_id: String, expected_revision: int) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	var check := _require_state(instance, expected_revision, STATE_COMBAT_END)
	if not check.accepted:
		return check
	instance.lifecycle_state = STATE_CLOSED
	_mutate(instance)
	_emit_event(instance, "COMBAT_CLOSED", "", [], {"outcome": instance.outcome})
	return _accepted(instance)


func get_snapshot(combat_id: String) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty():
		return {}
	var combatant_rows: Array = []
	var combatant_ids := (instance.combatants as Dictionary).keys()
	combatant_ids.sort()
	for combatant_id: Variant in combatant_ids:
		combatant_rows.append(
			((instance.combatants as Dictionary)[combatant_id] as Dictionary).duplicate(true)
		)
	return {
		"combat_schema_version": COMBAT_SCHEMA_VERSION,
		"combat_id": instance.combat_id,
		"seed": instance.seed,
		"revision": instance.revision,
		"lifecycle_state": instance.lifecycle_state,
		"round_number": instance.round_number,
		"turn_queue": (instance.turn_queue as Array).duplicate(true),
		"turn_index": instance.turn_index,
		"current_actor_id": instance.current_actor_id,
		"turn_deadline_msec": instance.turn_deadline_msec,
		"combatants": combatant_rows,
		"rng_streams": (instance.rng_streams as Dictionary).duplicate(true),
		"event_sequence": instance.event_sequence,
		"recent_events": (instance.events as Array).duplicate(true),
		"outcome": instance.outcome,
	}


func get_recent_events(combat_id: String, after_sequence: int) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty():
		return {"requires_snapshot": true, "events": []}
	var events := instance.events as Array
	if not events.is_empty() and after_sequence < int((events[0] as Dictionary).event_sequence) - 1:
		return {"requires_snapshot": true, "events": []}
	var result: Array = []
	for event_value: Variant in events:
		var event := event_value as Dictionary
		if int(event.event_sequence) > after_sequence:
			result.append(event.duplicate(true))
	return {"requires_snapshot": false, "events": result}


func serialize_checkpoint(combat_id: String) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty():
		return {}
	var checkpoint := {
		"checkpoint_schema_version": CHECKPOINT_SCHEMA_VERSION,
		"instance": instance.duplicate(true),
	}
	checkpoint["checksum"] = JSON.stringify(checkpoint).sha256_text()
	return checkpoint


func restore_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("checkpoint_schema_version", 0)) != CHECKPOINT_SCHEMA_VERSION:
		return _rejected("CHECKPOINT_SCHEMA")
	var expected_checksum := checkpoint.get("checksum", "") as String
	var check_copy := checkpoint.duplicate(true)
	check_copy.erase("checksum")
	if expected_checksum.is_empty() or JSON.stringify(check_copy).sha256_text() != expected_checksum:
		return _rejected("CHECKPOINT_CHECKSUM")
	var instance := checkpoint.get("instance", {}) as Dictionary
	var validation := _validate_restored_instance(instance)
	if not validation.accepted:
		return validation
	var combat_id := instance.combat_id as String
	if _instances.has(combat_id):
		return _rejected("DUPLICATE_COMBAT")
	_instances[combat_id] = instance.duplicate(true)
	_combat_id_sequence = maxi(_combat_id_sequence, _combat_id_suffix(combat_id))
	return _accepted(_instances[combat_id] as Dictionary, {"restored": true})


func get_instance_state(combat_id: String) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	return instance.duplicate(true) if not instance.is_empty() else {}


func _submit_action_internal(
	controller_id: String,
	combat_id: String,
	expected_revision: int,
	action_nonce: String,
	actor_id: String,
	ability_id: String,
	target_ids: Array,
	now_msec: int,
	is_ai: bool
) -> Dictionary:
	var instance := _instances.get(combat_id, {}) as Dictionary
	if instance.is_empty():
		return _rejected("UNKNOWN_COMBAT")
	if not _valid_nonce(action_nonce):
		return _rejected("INVALID_NONCE", instance)
	if (instance.used_action_nonces as Dictionary).has(action_nonce):
		return _rejected("DUPLICATE_ACTION", instance)
	var required_state := STATE_AI_SELECTING if is_ai else STATE_AWAITING_ACTION
	var check := _require_state(instance, expected_revision, required_state)
	if not check.accepted:
		return check
	if actor_id != instance.current_actor_id:
		return _rejected("NOT_CURRENT_ACTOR", instance)
	var actor := (instance.combatants as Dictionary).get(actor_id, {}) as Dictionary
	if actor.is_empty() or not actor.alive:
		return _rejected("ACTOR_UNAVAILABLE", instance)
	if is_ai:
		if not actor.ai_controlled:
			return _rejected("ACTOR_NOT_AI", instance)
	elif actor.ai_controlled or actor.controller_id != controller_id:
		return _rejected("NOT_CONTROLLER", instance)
	if ability_id not in (actor.ability_ids as Array):
		return _rejected("ABILITY_NOT_EQUIPPED", instance)
	var ability := _registry.call("get_ability", ability_id) as Dictionary
	if ability.is_empty():
		return _rejected("UNKNOWN_ABILITY", instance)
	if int(actor.resource) < int(ability.resource_cost):
		return _rejected("INSUFFICIENT_RESOURCE", instance)
	if int((actor.cooldowns as Dictionary).get(ability_id, 0)) > 0:
		return _rejected("ABILITY_COOLDOWN", instance)
	var target_check := _spatial_rules.call(
		"validate_targets", actor_id, target_ids, instance.combatants, ability.target_rule
	) as Dictionary
	if not target_check.accepted:
		return _rejected(target_check.reason_code, instance)

	(instance.used_action_nonces as Dictionary)[action_nonce] = true
	instance.lifecycle_state = STATE_RESOLVING_ACTION
	actor.resource = int(actor.resource) - int(ability.resource_cost)
	(actor.cooldowns as Dictionary)[ability_id] = int(ability.cooldown_turns) + 1
	_mutate(instance)
	_emit_event(
		instance,
		"ACTION_STARTED",
		actor_id,
		target_check.target_ids,
		{
			"ability_id": ability_id,
			"action_nonce": action_nonce,
			"resource_cost": ability.resource_cost,
			"resource_after": actor.resource,
		}
	)
	for effect_value: Variant in ability.effects:
		var effect := effect_value as Dictionary
		for target_id_value: Variant in target_check.target_ids:
			_apply_effect(instance, actor_id, target_id_value as String, ability_id, effect)
	_emit_event(
		instance,
		"ACTION_RESOLVED",
		actor_id,
		target_check.target_ids,
		{"ability_id": ability_id, "action_nonce": action_nonce}
	)
	if not _evaluate_outcome(instance):
		_advance_turn(instance, now_msec)
	return _accepted(instance, {"action_nonce": action_nonce, "ability_id": ability_id})


func _normalize_combatants(combatants: Array) -> Dictionary:
	if combatants.size() < 2 or combatants.size() > 12:
		return _rejected("COMBATANT_COUNT")
	var result: Dictionary = {}
	var teams: Dictionary = {}
	for combatant_value: Variant in combatants:
		if not combatant_value is Dictionary:
			return _rejected("INVALID_COMBATANT")
		var combatant := (combatant_value as Dictionary).duplicate(true)
		var combatant_id := combatant.get("combatant_id", "") as String
		if (
			combatant_id.is_empty()
			or combatant_id.length() > 96
			or result.has(combatant_id)
			or not _registry.call("get_template", combatant.get("template_id", "")).has("template_id")
		):
			return _rejected("INVALID_COMBATANT_ID_OR_TEMPLATE")
		if (
			int(combatant.get("max_health", 0)) <= 0
			or int(combatant.get("health", 0)) <= 0
			or int(combatant.health) > int(combatant.max_health)
			or int(combatant.get("resource", -1)) < 0
			or int(combatant.resource) > int(combatant.max_resource)
			or int(combatant.get("speed", 0)) <= 0
		):
			return _rejected("INVALID_COMBATANT_STATE")
		if not combatant.get("ai_controlled", false) and (combatant.get("controller_id", "") as String).is_empty():
			return _rejected("MISSING_CONTROLLER")
		for ability_id: Variant in combatant.get("ability_ids", []):
			if not _registry.call("has_ability", ability_id):
				return _rejected("UNKNOWN_ABILITY")
		combatant.alive = true
		combatant.cooldowns = (combatant.get("cooldowns", {}) as Dictionary).duplicate(true)
		combatant.statuses = (combatant.get("statuses", []) as Array).duplicate(true)
		combatant.connected = combatant.get("connected", true)
		combatant.position = _spatial_rules.call("serialize_position", combatant)
		result[combatant_id] = combatant
		teams[combatant.team_id] = true
	if teams.size() < 2:
		return _rejected("TEAM_COUNT")
	return {"accepted": true, "reason_code": "OK", "combatants": result}


func _begin_round(instance: Dictionary, now_msec: int) -> void:
	instance.lifecycle_state = STATE_ROUND_START
	instance.round_number = int(instance.round_number) + 1
	instance.turn_index = -1
	instance.current_actor_id = ""
	instance.turn_queue = _build_initiative_queue(instance)
	_mutate(instance)
	_emit_event(
		instance,
		"ROUND_STARTED",
		"",
		[],
		{"round_number": instance.round_number, "turn_queue": instance.turn_queue.duplicate(true)}
	)
	_advance_turn(instance, now_msec)


func _build_initiative_queue(instance: Dictionary) -> Array:
	var rng := CombatRngScript.new()
	rng.restore_state((instance.rng_streams as Dictionary).initiative)
	var queue: Array = []
	var ids := (instance.combatants as Dictionary).keys()
	ids.sort()
	for combatant_id_value: Variant in ids:
		var combatant_id := combatant_id_value as String
		var combatant := (instance.combatants as Dictionary)[combatant_id] as Dictionary
		if not combatant.alive:
			continue
		queue.append(
			{
				"combatant_id": combatant_id,
				"initiative": int(combatant.speed) + rng.range_inclusive(0, 2),
				"tie_value": _stable_tie_value(combatant_id),
			}
		)
	(instance.rng_streams as Dictionary).initiative = rng.get_state()
	queue.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.initiative) != int(b.initiative):
				return int(a.initiative) > int(b.initiative)
			if int(a.tie_value) != int(b.tie_value):
				return int(a.tie_value) < int(b.tie_value)
			return String(a.combatant_id) < String(b.combatant_id)
	)
	return queue


func _advance_turn(instance: Dictionary, now_msec: int) -> void:
	while true:
		instance.turn_index = int(instance.turn_index) + 1
		if int(instance.turn_index) >= (instance.turn_queue as Array).size():
			_begin_round(instance, now_msec)
			return
		var entry := (instance.turn_queue as Array)[instance.turn_index] as Dictionary
		var actor_id := entry.combatant_id as String
		var actor := (instance.combatants as Dictionary).get(actor_id, {}) as Dictionary
		if actor.is_empty() or not actor.alive:
			continue
		_apply_turn_start(instance, actor_id)
		if _evaluate_outcome(instance):
			return
		if not actor.alive:
			continue
		instance.current_actor_id = actor_id
		instance.turn_deadline_msec = now_msec + _turn_timeout_msec
		instance.lifecycle_state = STATE_AI_SELECTING if actor.ai_controlled else STATE_AWAITING_ACTION
		_mutate(instance)
		_emit_event(
			instance,
			"TURN_STARTED",
			actor_id,
			[],
			{
				"round_number": instance.round_number,
				"turn_index": instance.turn_index,
				"deadline_msec": instance.turn_deadline_msec,
			}
		)
		return


func _apply_turn_start(instance: Dictionary, actor_id: String) -> void:
	var actor := (instance.combatants as Dictionary)[actor_id] as Dictionary
	var cooldowns := actor.cooldowns as Dictionary
	for ability_id: Variant in cooldowns.keys():
		cooldowns[ability_id] = maxi(0, int(cooldowns[ability_id]) - 1)
	var retained_statuses: Array = []
	for status_value: Variant in actor.statuses:
		var status := (status_value as Dictionary).duplicate(true)
		var definition := _registry.call("get_status", status.status_id) as Dictionary
		if definition.effect_type == "DAMAGE_OVER_TIME" and actor.alive:
			var amount := mini(int(actor.health), maxi(1, int(status.magnitude)))
			actor.health = int(actor.health) - amount
			if int(actor.health) <= 0:
				actor.health = 0
				actor.alive = false
			_emit_event(
				instance,
				"STATUS_DAMAGE_APPLIED",
				status.get("source_actor_id", ""),
				[actor_id],
				{"status_id": status.status_id, "amount": amount, "health_after": actor.health}
			)
			if not actor.alive:
				_emit_event(instance, "COMBATANT_DEFEATED", actor_id, [actor_id], {"cause": status.status_id})
		status.remaining_turns = int(status.remaining_turns) - 1
		if int(status.remaining_turns) > 0 and actor.alive:
			retained_statuses.append(status)
		else:
			_emit_event(
				instance,
				"STATUS_EXPIRED",
				actor_id,
				[actor_id],
				{"status_id": status.status_id}
			)
	actor.statuses = retained_statuses


func _apply_effect(
	instance: Dictionary,
	actor_id: String,
	target_id: String,
	ability_id: String,
	effect: Dictionary
) -> void:
	var target := (instance.combatants as Dictionary)[target_id] as Dictionary
	if not target.alive:
		return
	match effect.effect_type:
		"DAMAGE":
			var raw_amount := _roll_amount(instance, int(effect.amount), int(effect.variance))
			var blocked := _incoming_damage_reduction(target)
			var amount := mini(int(target.health), maxi(1, raw_amount - blocked))
			target.health = int(target.health) - amount
			if int(target.health) <= 0:
				target.health = 0
				target.alive = false
			_emit_event(
				instance,
				"DAMAGE_APPLIED",
				actor_id,
				[target_id],
				{
					"ability_id": ability_id,
					"raw_amount": raw_amount,
					"blocked": mini(blocked, raw_amount - 1),
					"amount": amount,
					"health_after": target.health,
				}
			)
			if not target.alive:
				_emit_event(
					instance,
					"COMBATANT_DEFEATED",
					actor_id,
					[target_id],
					{"cause": ability_id}
				)
		"HEAL":
			var rolled := _roll_amount(instance, int(effect.amount), int(effect.variance))
			var amount := mini(rolled, int(target.max_health) - int(target.health))
			target.health = int(target.health) + amount
			_emit_event(
				instance,
				"HEAL_APPLIED",
				actor_id,
				[target_id],
				{"ability_id": ability_id, "amount": amount, "health_after": target.health}
			)
		"APPLY_STATUS":
			_apply_status(instance, actor_id, target_id, ability_id, effect)


func _apply_status(
	instance: Dictionary,
	actor_id: String,
	target_id: String,
	ability_id: String,
	effect: Dictionary
) -> void:
	var target := (instance.combatants as Dictionary)[target_id] as Dictionary
	var statuses := target.statuses as Array
	var replacement := {
		"status_id": effect.status_id,
		"remaining_turns": effect.duration_turns,
		"magnitude": effect.magnitude,
		"source_actor_id": actor_id,
	}
	var replaced := false
	for index in statuses.size():
		if (statuses[index] as Dictionary).status_id == effect.status_id:
			statuses[index] = replacement
			replaced = true
			break
	if not replaced:
		statuses.append(replacement)
	_emit_event(
		instance,
		"STATUS_APPLIED",
		actor_id,
		[target_id],
		{
			"ability_id": ability_id,
			"status_id": effect.status_id,
			"duration_turns": effect.duration_turns,
			"magnitude": effect.magnitude,
		}
	)


func _roll_amount(instance: Dictionary, base_amount: int, variance: int) -> int:
	if variance <= 0:
		return maxi(0, base_amount)
	var rng := CombatRngScript.new()
	rng.restore_state((instance.rng_streams as Dictionary).effects)
	var amount := base_amount + rng.range_inclusive(-variance, variance)
	(instance.rng_streams as Dictionary).effects = rng.get_state()
	return maxi(0, amount)


func _incoming_damage_reduction(combatant: Dictionary) -> int:
	var reduction := 0
	for status_value: Variant in combatant.statuses:
		var status := status_value as Dictionary
		var definition := _registry.call("get_status", status.status_id) as Dictionary
		if definition.get("effect_type", "") == "INCOMING_DAMAGE_REDUCTION":
			reduction += int(status.magnitude)
	return reduction


func _evaluate_outcome(instance: Dictionary) -> bool:
	var alive_teams: Dictionary = {}
	for combatant_value: Variant in (instance.combatants as Dictionary).values():
		var combatant := combatant_value as Dictionary
		if combatant.alive:
			alive_teams[combatant.team_id] = true
	if alive_teams.size() > 1:
		return false
	instance.lifecycle_state = STATE_COMBAT_END
	instance.current_actor_id = ""
	instance.turn_deadline_msec = 0
	instance.outcome = (
		OUTCOME_DRAW
		if alive_teams.is_empty()
		else "VICTORY:%s" % String(alive_teams.keys()[0])
	)
	_mutate(instance)
	_emit_event(instance, "COMBAT_ENDED", "", [], {"outcome": instance.outcome})
	return true


func _resolve_timeout(instance: Dictionary, now_msec: int) -> void:
	var actor_id := instance.current_actor_id as String
	var actor := (instance.combatants as Dictionary)[actor_id] as Dictionary
	var guard_id := "development.ability.guard"
	if (
		guard_id in (actor.ability_ids as Array)
		and int(actor.resource) >= int((_registry.call("get_ability", guard_id) as Dictionary).resource_cost)
		and int((actor.cooldowns as Dictionary).get(guard_id, 0)) <= 0
	):
		var nonce := "timeout.%d.%s.%d" % [instance.round_number, actor_id, instance.revision]
		_emit_event(instance, "TURN_TIMEOUT_FALLBACK", actor_id, [actor_id], {"fallback": "DEFEND"})
		_submit_action_internal(
			actor.controller_id,
			instance.combat_id,
			instance.revision,
			nonce,
			actor_id,
			guard_id,
			[actor_id],
			now_msec,
			false
		)
	else:
		_apply_end_turn_fallback(instance, actor_id, "TURN_TIMEOUT", now_msec)


func _apply_end_turn_fallback(
	instance: Dictionary,
	actor_id: String,
	reason: String,
	now_msec: int
) -> void:
	_mutate(instance)
	_emit_event(instance, "TURN_ENDED_WITHOUT_ACTION", actor_id, [], {"reason": reason})
	_advance_turn(instance, now_msec)


func _emit_event(
	instance: Dictionary,
	event_type: String,
	actor_id: String,
	target_ids: Array,
	payload: Dictionary
) -> void:
	instance.event_sequence = int(instance.event_sequence) + 1
	var event := {
		"combat_id": instance.combat_id,
		"combat_revision": instance.revision,
		"event_sequence": instance.event_sequence,
		"event_type": event_type,
		"actor_id": actor_id,
		"target_ids": target_ids.duplicate(),
		"payload": payload.duplicate(true),
	}
	(instance.events as Array).append(event)
	while (instance.events as Array).size() > _event_limit:
		(instance.events as Array).pop_front()


func _required_controller_ids(instance: Dictionary) -> Array[String]:
	var unique: Dictionary = {}
	for combatant_value: Variant in (instance.combatants as Dictionary).values():
		var combatant := combatant_value as Dictionary
		var controller_id := combatant.controller_id as String
		if not combatant.ai_controlled and not controller_id.is_empty():
			unique[controller_id] = true
	var result: Array[String] = []
	result.assign(unique.keys())
	result.sort()
	return result


func _all_controllers_ready(instance: Dictionary) -> bool:
	for controller_id: String in _required_controller_ids(instance):
		if not (instance.ready_controllers as Dictionary).has(controller_id):
			return false
	return true


func _validate_restored_instance(instance: Dictionary) -> Dictionary:
	if (
		int(instance.get("combat_schema_version", 0)) != COMBAT_SCHEMA_VERSION
		or (instance.get("combat_id", "") as String).is_empty()
		or instance.get("lifecycle_state", "") not in [
			STATE_WAITING_FOR_CLIENTS,
			STATE_ROUND_START,
			STATE_AWAITING_ACTION,
			STATE_AI_SELECTING,
			STATE_RESOLVING_ACTION,
			STATE_COMBAT_END,
			STATE_CLOSED,
		]
	):
		return _rejected("INVALID_CHECKPOINT_STATE")
	var restored_combatants := instance.get("combatants", {}) as Dictionary
	if restored_combatants.size() < 2 or restored_combatants.size() > 12:
		return _rejected("INVALID_CHECKPOINT_COMBATANTS")
	for combatant_id_value: Variant in restored_combatants:
		var combatant_id := combatant_id_value as String
		var combatant := restored_combatants[combatant_id] as Dictionary
		if (
			combatant_id.is_empty()
			or combatant.get("combatant_id", "") != combatant_id
			or (_registry.call("get_template", combatant.get("template_id", "")) as Dictionary).is_empty()
			or int(combatant.get("max_health", 0)) <= 0
			or int(combatant.get("health", -1)) < 0
			or int(combatant.health) > int(combatant.max_health)
			or bool(combatant.get("alive", false)) != (int(combatant.health) > 0)
		):
			return _rejected("INVALID_CHECKPOINT_COMBATANTS")
		for ability_id: Variant in combatant.get("ability_ids", []):
			if not _registry.call("has_ability", ability_id):
				return _rejected("INVALID_CHECKPOINT_COMBATANTS")
	var rng_streams := instance.get("rng_streams", {}) as Dictionary
	if not rng_streams.has("initiative") or not rng_streams.has("effects"):
		return _rejected("INVALID_CHECKPOINT_RNG")
	return {"accepted": true, "reason_code": "OK"}


func _require_state(
	instance: Dictionary,
	expected_revision: int,
	required_state: String
) -> Dictionary:
	if instance.is_empty():
		return _rejected("UNKNOWN_COMBAT")
	if int(instance.revision) != expected_revision:
		return _rejected("STALE_REVISION", instance)
	if instance.lifecycle_state != required_state:
		return _rejected("INVALID_STATE", instance)
	return {"accepted": true, "reason_code": "OK"}


func _mutate(instance: Dictionary) -> void:
	instance.revision = int(instance.revision) + 1


func _stable_tie_value(value: String) -> int:
	var result := 2166136261
	for index in value.length():
		result = ((result ^ value.unicode_at(index)) * 16777619) & 0x7FFFFFFF
	return result


func _valid_nonce(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for character in value:
		if not (
			(character >= "a" and character <= "z")
			or (character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
			or character in [".", "-", "_"]
		):
			return false
	return true


func _combat_id_suffix(combat_id: String) -> int:
	return int(combat_id.get_slice(".", combat_id.get_slice_count(".") - 1))


func _accepted(instance: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": true,
		"reason_code": "OK",
		"combat_id": instance.get("combat_id", ""),
		"revision": instance.get("revision", -1),
		"lifecycle_state": instance.get("lifecycle_state", ""),
		"outcome": instance.get("outcome", OUTCOME_NONE),
	}
	result.merge(extra, true)
	return result


func _rejected(reason_code: String, instance: Dictionary = {}) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"combat_id": instance.get("combat_id", ""),
		"revision": instance.get("revision", -1),
		"lifecycle_state": instance.get("lifecycle_state", ""),
		"outcome": instance.get("outcome", OUTCOME_NONE),
	}
