extends SceneTree

const ExpeditionRegistry := preload("res://scripts/server/expedition/expedition_definition_registry.gd")
const CheckpointStore := preload("res://scripts/server/expedition/in_memory_expedition_checkpoint_store.gd")
const ExpeditionService := preload("res://scripts/server/expedition/expedition_service.gd")
const PartyService := preload("res://scripts/server/party/party_service.gd")
const Coordinator := preload("res://scripts/server/combat/network_combat_coordinator.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")

var _party: RefCounted
var _expedition: RefCounted
var _coordinator: RefCounted


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_party = PartyService.new()
	_party.configure(2, 1000, 200)
	for row: Array in [
		["development.character.1", "Alice"],
		["development.character.2", "Bob"],
	]:
		_party.connect_character(_identity(row[0], row[1]), 0)
	var invite := _party.invite_character(
		"development.character.1", "development.character.2", -1, 0
	) as Dictionary
	var party_state := _party.get_party_for_character("development.character.1") as Dictionary
	_party.accept_invite("development.character.2", invite.invite_id, party_state.revision, 1)
	party_state = _party.get_party_for_character("development.character.1")
	_party.select_expedition(
		"development.character.1", "development.expedition.placeholder", party_state.revision
	)
	party_state = _party.get_party_for_character("development.character.1")
	_party.set_ready("development.character.1", true, party_state.revision)
	party_state = _party.get_party_for_character("development.character.1")
	_party.set_ready("development.character.2", true, party_state.revision)
	_expedition = ExpeditionService.new()
	if not _expedition.configure(
		ExpeditionRegistry.new(), _party, CheckpointStore.new(), 1, 1000, 730001
	):
		return _fail("Expedition setup failed.")
	for row: Array in [
		["development.character.1", "Alice"],
		["development.character.2", "Bob"],
	]:
		_expedition.connect_character(_identity(row[0], row[1]), 0)
	party_state = _party.get_party_for_character("development.character.1")
	var launch := _expedition.launch_expedition(
		"development.character.1", party_state.revision, 2
	) as Dictionary
	var expedition_id := launch.expedition_id as String
	var instance := _expedition.get_instance_state(expedition_id) as Dictionary
	_expedition.acknowledge_content_ready(
		"development.character.1", expedition_id, instance.revision, 3
	)
	instance = _expedition.get_instance_state(expedition_id)
	_expedition.acknowledge_content_ready(
		"development.character.2", expedition_id, instance.revision, 4
	)
	for character_id: String in ["development.character.1", "development.character.2"]:
		_expedition.set_avatar_position_for_test(
			character_id, "development.room.test_threshold", Vector2(530, 180)
		)
	instance = _expedition.get_instance_state(expedition_id)
	var transfer := _expedition.request_room_transition(
		"development.character.1",
		expedition_id,
		"development.connection.threshold_to_depths",
		instance.revision,
		5
	) as Dictionary
	if not transfer.accepted:
		return _fail("Could not enter the encounter room.")
	for character_id: String in ["development.character.1", "development.character.2"]:
		_expedition.set_avatar_position_for_test(
			character_id, "development.room.test_depths", Vector2(530, 180)
		)
	_coordinator = Coordinator.new()
	if not _coordinator.configure(_expedition, 100, 16):
		return _fail("Network combat coordinator configuration failed.")
	instance = _expedition.get_instance_state(expedition_id)
	var stale := _coordinator.start_encounter(
		"development.character.1",
		expedition_id,
		"development.encounter.venom_slime",
		instance.revision - 1,
		10
	) as Dictionary
	if stale.accepted or stale.reason_code != "STALE_REVISION":
		return _fail("Stale encounter launch was not rejected.")
	var unauthorized := _coordinator.start_encounter(
		"development.character.2",
		expedition_id,
		"development.encounter.venom_slime",
		instance.revision,
		10
	) as Dictionary
	if unauthorized.accepted or unauthorized.reason_code != "NOT_LEADER":
		return _fail("Non-leader encounter launch was not rejected.")
	var started := _coordinator.start_encounter(
		"development.character.1",
		expedition_id,
		"development.encounter.venom_slime",
		instance.revision,
		10
	) as Dictionary
	if not started.accepted:
		return _fail("Encounter could not allocate combat: %s" % started.reason_code)
	var combat_id := started.combat_id as String
	instance = _expedition.get_instance_state(expedition_id)
	if (
		instance.lifecycle_state != ExpeditionService.STATE_ACTIVE_COMBAT
		or instance.active_combat_id != combat_id
	):
		return _fail("Expedition did not lock into its server-owned combat context.")
	var snapshot := _coordinator.get_snapshot_for("development.character.1") as Dictionary
	var ready := _coordinator.acknowledge_ready(
		"development.character.1", combat_id, snapshot.revision, 11
	) as Dictionary
	snapshot = _coordinator.get_snapshot_for("development.character.2")
	var second_ready := _coordinator.acknowledge_ready(
		"development.character.2", combat_id, snapshot.revision, 12
	) as Dictionary
	if not ready.accepted or not second_ready.accepted:
		return _fail("Both combat controllers could not cross the ready barrier.")
	snapshot = _coordinator.get_snapshot_for("development.character.1")
	var forged := _coordinator.submit_action(
		"development.character.2",
		combat_id,
		snapshot.revision,
		"network.action.forged",
		snapshot.current_actor_id,
		"development.ability.strike",
		["development.combatant.network.enemy.0"],
		13
	) as Dictionary
	if forged.accepted or forged.reason_code != "NOT_CONTROLLER":
		return _fail("A client controlled another player's active combatant.")
	var opening := _coordinator.submit_action(
		"development.character.1",
		combat_id,
		snapshot.revision,
		"network.action.opening",
		snapshot.current_actor_id,
		"development.ability.strike",
		["development.combatant.network.enemy.0"],
		14
	) as Dictionary
	if not opening.accepted:
		return _fail("The owning client could not submit a reliable combat action.")
	var duplicate := _coordinator.submit_action(
		"development.character.1",
		combat_id,
		opening.revision,
		"network.action.opening",
		snapshot.current_actor_id,
		"development.ability.strike",
		["development.combatant.network.enemy.0"],
		15
	) as Dictionary
	if duplicate.accepted or duplicate.reason_code != "DUPLICATE_ACTION":
		return _fail("A duplicated network action nonce was not replay-safe.")
	_coordinator.set_character_connected("development.character.2", false)
	if not _coordinator.set_character_connected("development.character.2", true):
		return _fail("Combat reconnect did not restore the stable controller.")
	var now_msec := 20
	var nonce := 0
	while now_msec < 2000:
		_coordinator.tick(now_msec)
		var domain_snapshot := (
			_coordinator.get_combat_service_for_test().get_snapshot(combat_id) as Dictionary
		)
		if domain_snapshot.lifecycle_state in [CombatService.STATE_COMBAT_END, CombatService.STATE_CLOSED]:
			_coordinator.tick(now_msec + 1)
			break
		if domain_snapshot.lifecycle_state == CombatService.STATE_AWAITING_ACTION:
			var actor := _domain_combatant(domain_snapshot, domain_snapshot.current_actor_id)
			if actor.get("connected", false):
				nonce += 1
				_coordinator.submit_action(
					actor.controller_id,
					combat_id,
					domain_snapshot.revision,
					"network.action.%d" % nonce,
					actor.combatant_id,
					"development.ability.strike",
					["development.combatant.network.enemy.0"],
					now_msec
				)
		now_msec += 110
	instance = _expedition.get_instance_state(expedition_id)
	if (
		instance.lifecycle_state != ExpeditionService.STATE_ACTIVE_EXPLORATION
		or instance.active_combat_id != ""
		or _coordinator.get_settlement_count(combat_id) != 1
	):
		return _fail("Victory did not resume exploration exactly once.")
	_coordinator.tick(now_msec + 500)
	if _coordinator.get_settlement_count(combat_id) != 1:
		return _fail("Repeated ticks duplicated the encounter outcome.")
	print("PASS: Phase H encounter boundary, controller authority, ready barrier, replay safety, reconnect, timeout/AI progression, and outcome-once exploration resume.")
	quit(0)


func _domain_combatant(snapshot: Dictionary, combatant_id: String) -> Dictionary:
	for combatant_value: Variant in snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		if combatant.get("combatant_id", "") == combatant_id:
			return combatant
	return {}


func _identity(character_id: String, display_label: String) -> Dictionary:
	return {"character_id": character_id, "display_label": display_label}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
