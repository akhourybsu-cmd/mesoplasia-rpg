extends SceneTree

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")


func _initialize() -> void:
	var registry := Registry.new()
	var service := CombatService.new()
	service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 100, 8)
	var hero := registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.timeout", "controller.timeout"
	) as Dictionary
	var enemy := registry.instantiate_combatant(
		"development.combatant.venom_slime", "combatant.enemy.timeout"
	) as Dictionary
	hero.speed = 30
	enemy.speed = 1
	enemy.ability_ids = ["development.ability.claw"]
	var created := service.create_combat(701, [hero, enemy], 0) as Dictionary
	var state := service.get_instance_state(created.combat_id) as Dictionary
	service.acknowledge_ready("controller.timeout", created.combat_id, state.revision, 1)
	state = service.get_instance_state(created.combat_id)
	var deadline := int(state.turn_deadline_msec)
	service.set_controller_connected(created.combat_id, "controller.timeout", false)
	var timeout_result := service.tick(deadline) as Dictionary
	state = service.get_instance_state(created.combat_id)
	if (
		created.combat_id not in (timeout_result.timed_out_combat_ids as Array)
		or state.lifecycle_state != CombatService.STATE_AI_SELECTING
		or not _has_event(state.events, "TURN_TIMEOUT_FALLBACK")
		or not _has_status(
			(state.combatants as Dictionary)["combatant.hero.timeout"],
			"development.status.guard"
		)
	):
		_fail("Disconnected player timeout did not deterministically Defend and advance.")
		return
	service.tick(deadline + 1)
	state = service.get_instance_state(created.combat_id)
	if state.lifecycle_state != CombatService.STATE_AWAITING_ACTION:
		_fail("AI timeout fixture did not return control to the next player turn.")
		return

	var checkpoint := service.serialize_checkpoint(created.combat_id) as Dictionary
	if (
		checkpoint.get("checkpoint_schema_version", 0) != 1
		or checkpoint.get("checksum", "").is_empty()
	):
		_fail("Combat checkpoint serialization is incomplete.")
		return
	var original_snapshot := service.get_snapshot(created.combat_id) as Dictionary
	var restored_service := CombatService.new()
	restored_service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 100, 8)
	var restored := restored_service.restore_checkpoint(checkpoint) as Dictionary
	if not restored.accepted:
		_fail("Valid combat checkpoint could not be restored: %s" % restored.reason_code)
		return
	if restored_service.get_snapshot(created.combat_id) != original_snapshot:
		_fail("Combat snapshot round-trip changed authoritative state, queue, RNG, or events.")
		return
	var tampered := checkpoint.duplicate(true)
	(tampered.instance as Dictionary).revision = int((tampered.instance as Dictionary).revision) + 1
	var rejecting_service := CombatService.new()
	rejecting_service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 100, 8)
	if (rejecting_service.restore_checkpoint(tampered) as Dictionary).reason_code != "CHECKPOINT_CHECKSUM":
		_fail("Tampered combat checkpoint bypassed checksum validation.")
		return

	var current := restored_service.get_instance_state(created.combat_id) as Dictionary
	for action_index in 12:
		if current.lifecycle_state == CombatService.STATE_COMBAT_END:
			break
		if current.lifecycle_state == CombatService.STATE_AI_SELECTING:
			restored_service.tick(int(current.turn_deadline_msec) - 50)
		else:
			var actor := (current.combatants as Dictionary)[current.current_actor_id] as Dictionary
			var enemies := SpatialRules.new().get_valid_target_ids(
				current.current_actor_id, current.combatants, "ENEMY"
			)
			if enemies.is_empty():
				break
			restored_service.submit_action(
				actor.controller_id,
				created.combat_id,
				current.revision,
				"action.bound.%d" % action_index,
				current.current_actor_id,
				"development.ability.strike",
				[enemies[0]],
				action_index + 500
			)
		current = restored_service.get_instance_state(created.combat_id)
	var bounded_snapshot := restored_service.get_snapshot(created.combat_id) as Dictionary
	if (bounded_snapshot.recent_events as Array).size() > 8:
		_fail("Bounded combat event window exceeded its configured limit.")
		return
	var aged := restored_service.get_recent_events(created.combat_id, 0) as Dictionary
	if not aged.requires_snapshot:
		_fail("Aged-out combat event request did not require a full snapshot.")
		return
	if current.lifecycle_state == CombatService.STATE_COMBAT_END:
		var closed := restored_service.close_combat(created.combat_id, current.revision) as Dictionary
		if not closed.accepted or closed.lifecycle_state != CombatService.STATE_CLOSED:
			_fail("Terminal offline combat could not close cleanly.")
			return

	print("PASS: Phase G disconnect timeout fallback, bounded event recovery, checkpoint checksum, snapshot round-trip, RNG/queue restoration, and cleanup.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event_value: Variant in events:
		if (event_value as Dictionary).event_type == event_type:
			return true
	return false


func _has_status(combatant: Dictionary, status_id: String) -> bool:
	for status_value: Variant in combatant.statuses:
		if (status_value as Dictionary).status_id == status_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
