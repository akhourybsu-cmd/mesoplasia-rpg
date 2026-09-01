extends SceneTree

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")


func _initialize() -> void:
	var registry := Registry.new()
	var service := CombatService.new()
	service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 1000, 64)
	var hero := registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.cooldown", "controller.hero"
	) as Dictionary
	var opponent := registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.enemy.controlled", "controller.enemy"
	) as Dictionary
	hero.speed = 30
	hero.resource = 0
	hero.ability_ids.append("development.ability.venom")
	opponent.speed = 1
	opponent.team_id = "enemies"
	var created := service.create_combat(5150, [hero, opponent], 0) as Dictionary
	var state := service.get_instance_state(created.combat_id) as Dictionary
	service.acknowledge_ready("controller.hero", created.combat_id, state.revision, 1)
	state = service.get_instance_state(created.combat_id)
	service.acknowledge_ready("controller.enemy", created.combat_id, state.revision, 2)
	state = service.get_instance_state(created.combat_id)
	var no_resource := service.submit_action(
		"controller.hero",
		created.combat_id,
		state.revision,
		"action.no-resource",
		"combatant.hero.cooldown",
		"development.ability.venom",
		["combatant.enemy.controlled"],
		3
	) as Dictionary
	if no_resource.reason_code != "INSUFFICIENT_RESOURCE":
		_fail("Ability resource precondition was not enforced.")
		return
	var guard := service.submit_action(
		"controller.hero",
		created.combat_id,
		state.revision,
		"action.guard.once",
		"combatant.hero.cooldown",
		"development.ability.guard",
		["combatant.hero.cooldown"],
		4
	) as Dictionary
	if not guard.accepted:
		_fail("Initial Guard action failed.")
		return
	state = service.get_instance_state(created.combat_id)
	service.submit_action(
		"controller.enemy",
		created.combat_id,
		state.revision,
		"action.enemy.strike.1",
		"combatant.enemy.controlled",
		"development.ability.strike",
		["combatant.hero.cooldown"],
		5
	)
	state = service.get_instance_state(created.combat_id)
	if state.current_actor_id != "combatant.hero.cooldown":
		_fail("Cooldown fixture did not return to the hero on the next round.")
		return
	var replay := service.submit_action(
		"controller.hero",
		created.combat_id,
		state.revision,
		"action.guard.once",
		"combatant.hero.cooldown",
		"development.ability.guard",
		["combatant.hero.cooldown"],
		6
	) as Dictionary
	var cooling_down := service.submit_action(
		"controller.hero",
		created.combat_id,
		state.revision,
		"action.guard.too-soon",
		"combatant.hero.cooldown",
		"development.ability.guard",
		["combatant.hero.cooldown"],
		6
	) as Dictionary
	if replay.reason_code != "DUPLICATE_ACTION" or cooling_down.reason_code != "ABILITY_COOLDOWN":
		_fail("Replay nonce or cooldown rejection did not use the stable reason code.")
		return
	hero = (state.combatants as Dictionary)["combatant.hero.cooldown"] as Dictionary
	if _has_status(hero, "development.status.guard"):
		_fail("Guard did not expire at its declared TURN_START timing hook.")
		return
	var revision_before := int(state.revision)
	var malformed := service.submit_action(
		"controller.hero",
		created.combat_id,
		state.revision,
		"bad nonce!",
		"combatant.hero.cooldown",
		"development.ability.strike",
		["combatant.enemy.controlled"],
		7
	) as Dictionary
	if (
		malformed.reason_code != "INVALID_NONCE"
		or int((service.get_instance_state(created.combat_id) as Dictionary).revision) != revision_before
	):
		_fail("Malformed nonce was accepted or mutated combat state.")
		return

	print("PASS: Phase G insufficient resource, action replay, cooldown duration, status expiry, malformed nonce, and rejection atomicity.")
	quit(0)


func _has_status(combatant: Dictionary, status_id: String) -> bool:
	for status_value: Variant in combatant.statuses:
		if (status_value as Dictionary).status_id == status_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
