extends SceneTree

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")

var _registry: RefCounted
var _service: RefCounted


func _initialize() -> void:
	_registry = Registry.new()
	_service = CombatService.new()
	if not _service.configure(_registry, SpatialRules.new(), EnemyPolicy.new(), 1000, 64):
		_fail("Combat service configuration failed.")
		return
	var vanguard := _registry.instantiate_combatant(
		"development.combatant.vanguard", "combatant.hero.vanguard", "controller.alice"
	) as Dictionary
	var warden := _registry.instantiate_combatant(
		"development.combatant.warden", "combatant.hero.warden", "controller.bob"
	) as Dictionary
	var enemy := _registry.instantiate_combatant(
		"development.combatant.venom_slime", "combatant.enemy.slime"
	) as Dictionary
	vanguard.speed = 30
	vanguard.health = 10
	warden.speed = 20
	enemy.speed = 1
	var created := _service.create_combat(4401, [vanguard, warden, enemy], 0) as Dictionary
	if not created.accepted or created.lifecycle_state != CombatService.STATE_WAITING_FOR_CLIENTS:
		_fail("Valid combat fixture was not allocated into the ready barrier.")
		return
	var combat_id := created.combat_id as String
	var instance := _service.get_instance_state(combat_id) as Dictionary
	var alice_ready := _service.acknowledge_ready(
		"controller.alice", combat_id, instance.revision, 1
	) as Dictionary
	instance = _service.get_instance_state(combat_id)
	var bob_ready := _service.acknowledge_ready(
		"controller.bob", combat_id, instance.revision, 2
	) as Dictionary
	instance = _service.get_instance_state(combat_id)
	if (
		not alice_ready.accepted
		or not bob_ready.accepted
		or instance.lifecycle_state != CombatService.STATE_AWAITING_ACTION
		or instance.current_actor_id != "combatant.hero.vanguard"
	):
		_fail("Ready barrier did not create the deterministic first player turn.")
		return

	var base_revision := int(instance.revision)
	var forged := _service.submit_action(
		"controller.bob",
		combat_id,
		base_revision,
		"action.forged",
		"combatant.hero.vanguard",
		"development.ability.strike",
		["combatant.enemy.slime"],
		3
	) as Dictionary
	var invalid_target := _service.submit_action(
		"controller.alice",
		combat_id,
		base_revision,
		"action.bad-target",
		"combatant.hero.vanguard",
		"development.ability.strike",
		["combatant.hero.warden"],
		3
	) as Dictionary
	var unequipped := _service.submit_action(
		"controller.alice",
		combat_id,
		base_revision,
		"action.unequipped",
		"combatant.hero.vanguard",
		"development.ability.mend",
		["combatant.hero.vanguard"],
		3
	) as Dictionary
	if (
		forged.reason_code != "NOT_CONTROLLER"
		or invalid_target.reason_code != "TARGET_NOT_ENEMY"
		or unequipped.reason_code != "ABILITY_NOT_EQUIPPED"
		or (_service.get_instance_state(combat_id) as Dictionary).revision != base_revision
	):
		_fail("Rejected combat intents mutated state or returned the wrong authority reason.")
		return

	var strike := _service.submit_action(
		"controller.alice",
		combat_id,
		base_revision,
		"action.strike.1",
		"combatant.hero.vanguard",
		"development.ability.strike",
		["combatant.enemy.slime"],
		4
	) as Dictionary
	if not strike.accepted:
		_fail("A legal controlled Strike was rejected: %s" % strike.reason_code)
		return
	instance = _service.get_instance_state(combat_id)
	var slime := (instance.combatants as Dictionary)["combatant.enemy.slime"] as Dictionary
	if int(slime.health) >= int(slime.max_health) or instance.current_actor_id != "combatant.hero.warden":
		_fail("Strike did not resolve damage and advance the initiative queue.")
		return
	var action_events := _events_for_nonce(instance.events, "action.strike.1")
	if (
		action_events.size() != 2
		or (action_events[0] as Dictionary).event_type != "ACTION_STARTED"
		or (action_events[1] as Dictionary).event_type != "ACTION_RESOLVED"
		or not _event_type_between(instance.events, "ACTION_STARTED", "DAMAGE_APPLIED", "ACTION_RESOLVED")
	):
		_fail("Ordered action/effect events were not emitted around damage resolution.")
		return

	var mend := _service.submit_action(
		"controller.bob",
		combat_id,
		instance.revision,
		"action.mend.1",
		"combatant.hero.warden",
		"development.ability.mend",
		["combatant.hero.vanguard"],
		5
	) as Dictionary
	if not mend.accepted:
		_fail("Legal Mend action was rejected: %s" % mend.reason_code)
		return
	instance = _service.get_instance_state(combat_id)
	vanguard = (instance.combatants as Dictionary)["combatant.hero.vanguard"] as Dictionary
	warden = (instance.combatants as Dictionary)["combatant.hero.warden"] as Dictionary
	if (
		int(vanguard.health) != 15
		or int(warden.resource) != int(warden.max_resource) - 2
		or int((warden.cooldowns as Dictionary).get("development.ability.mend", 0)) != 3
	):
		_fail("Healing, resource cost, or cooldown mutation is incorrect.")
		return
	var stale := _service.submit_action(
		"controller.bob",
		combat_id,
		base_revision,
		"action.stale",
		"combatant.hero.warden",
		"development.ability.mend",
		["combatant.hero.vanguard"],
		6
	) as Dictionary
	if stale.reason_code != "STALE_REVISION":
		_fail("Stale combat revision was not rejected.")
		return

	print("PASS: Phase G ready barrier, controller authority, validation, ordered damage/heal effects, resource costs, cooldowns, and revision safety.")
	quit(0)


func _events_for_nonce(events: Array, nonce: String) -> Array:
	return events.filter(
		func(event_value: Variant) -> bool:
			return (event_value as Dictionary).payload.get("action_nonce", "") == nonce
	)


func _event_type_between(events: Array, first: String, middle: String, last: String) -> bool:
	var first_index := -1
	var middle_index := -1
	var last_index := -1
	for index in events.size():
		var event_type := (events[index] as Dictionary).event_type as String
		if event_type == first:
			first_index = index
		elif event_type == middle and first_index >= 0:
			middle_index = index
		elif event_type == last and middle_index >= 0:
			last_index = index
	return first_index >= 0 and first_index < middle_index and middle_index < last_index


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
