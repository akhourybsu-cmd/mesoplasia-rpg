extends SceneTree

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")

var _registry: RefCounted


func _initialize() -> void:
	_registry = Registry.new()
	var first := _run_guard_fixture(8831)
	var second := _run_guard_fixture(8831)
	if not first.accepted or not second.accepted:
		_fail("Guard/AI deterministic fixture could not run.")
		return
	if first.snapshot != second.snapshot:
		_fail("Same seed, state, and intents produced different combat snapshots/events.")
		return
	var damage_event := _last_event(first.snapshot.recent_events, "DAMAGE_APPLIED")
	if damage_event.is_empty() or int(damage_event.payload.blocked) != 2:
		_fail("Guard status did not reduce the next incoming AI damage.")
		return
	if not _has_event(first.snapshot.recent_events, "STATUS_APPLIED"):
		_fail("Guard status application event is missing.")
		return

	var poison_service := _new_service()
	var hero := _registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.poison-target", "controller.hero"
	) as Dictionary
	var slime := _registry.instantiate_combatant(
		"development.combatant.venom_slime", "combatant.enemy.venom"
	) as Dictionary
	hero.speed = 1
	slime.speed = 30
	slime.ability_ids = ["development.ability.venom"]
	var created := poison_service.create_combat(991, [hero, slime], 0) as Dictionary
	var state := poison_service.get_instance_state(created.combat_id) as Dictionary
	poison_service.acknowledge_ready("controller.hero", created.combat_id, state.revision, 1)
	state = poison_service.get_instance_state(created.combat_id)
	if state.lifecycle_state != CombatService.STATE_AI_SELECTING:
		_fail("High-speed AI did not receive the deterministic first turn.")
		return
	poison_service.tick(2)
	state = poison_service.get_instance_state(created.combat_id)
	hero = (state.combatants as Dictionary)["combatant.hero.poison-target"] as Dictionary
	if (
		state.lifecycle_state != CombatService.STATE_AWAITING_ACTION
		or int(hero.health) != int(hero.max_health) - 3
		or (hero.statuses as Array).size() != 1
		or not _has_event(state.events, "STATUS_DAMAGE_APPLIED")
	):
		_fail("AI Venom did not pass through damage, status, and TURN_START timing hooks.")
		return

	var outcome_service := _new_service()
	var finisher := _registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.finisher", "controller.finisher"
	) as Dictionary
	var fragile := _registry.instantiate_combatant(
		"development.combatant.venom_slime", "combatant.enemy.fragile"
	) as Dictionary
	finisher.speed = 30
	fragile.speed = 1
	fragile.health = 1
	created = outcome_service.create_combat(17, [finisher, fragile], 0)
	state = outcome_service.get_instance_state(created.combat_id)
	outcome_service.acknowledge_ready("controller.finisher", created.combat_id, state.revision, 1)
	state = outcome_service.get_instance_state(created.combat_id)
	var victory := outcome_service.submit_action(
		"controller.finisher",
		created.combat_id,
		state.revision,
		"action.finisher",
		"combatant.hero.finisher",
		"development.ability.strike",
		["combatant.enemy.fragile"],
		2
	) as Dictionary
	if (
		not victory.accepted
		or victory.lifecycle_state != CombatService.STATE_COMBAT_END
		or victory.outcome != "VICTORY:heroes"
		or not _has_event(
			(outcome_service.get_instance_state(created.combat_id) as Dictionary).events,
			"COMBATANT_DEFEATED"
		)
	):
		_fail("Terminal defeat was not evaluated before turn advancement.")
		return
	var outcome_events := (
		(outcome_service.get_instance_state(created.combat_id) as Dictionary).events as Array
	)
	if _event_index(outcome_events, "ACTION_RESOLVED") >= _event_index(outcome_events, "COMBAT_ENDED"):
		_fail("Terminal outcome was emitted before the accepted action finished resolving.")
		return

	print("PASS: Phase G deterministic initiative/RNG, AI through the normal validator, guard/poison timing, defeat, and terminal outcome.")
	quit(0)


func _run_guard_fixture(seed: int) -> Dictionary:
	var service := _new_service()
	var hero := _registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.guard", "controller.guard"
	) as Dictionary
	var enemy := _registry.instantiate_combatant(
		"development.combatant.venom_slime", "combatant.enemy.guard-test"
	) as Dictionary
	hero.speed = 30
	enemy.speed = 1
	enemy.ability_ids = ["development.ability.claw"]
	var created := service.create_combat(seed, [hero, enemy], 0) as Dictionary
	var state := service.get_instance_state(created.combat_id) as Dictionary
	service.acknowledge_ready("controller.guard", created.combat_id, state.revision, 1)
	state = service.get_instance_state(created.combat_id)
	var guarded := service.submit_action(
		"controller.guard",
		created.combat_id,
		state.revision,
		"action.guard",
		"combatant.hero.guard",
		"development.ability.guard",
		["combatant.hero.guard"],
		2
	) as Dictionary
	if not guarded.accepted:
		return {"accepted": false}
	service.tick(3)
	return {"accepted": true, "snapshot": service.get_snapshot(created.combat_id)}


func _new_service() -> RefCounted:
	var service := CombatService.new()
	service.configure(_registry, SpatialRules.new(), EnemyPolicy.new(), 1000, 64)
	return service


func _has_event(events: Array, event_type: String) -> bool:
	return not events.filter(
		func(event_value: Variant) -> bool:
			return (event_value as Dictionary).event_type == event_type
	).is_empty()


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event := events[index] as Dictionary
		if event.event_type == event_type:
			return event
	return {}


func _event_index(events: Array, event_type: String) -> int:
	for index in events.size():
		if (events[index] as Dictionary).event_type == event_type:
			return index
	return -1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
