extends SceneTree

const SandboxScene := preload("res://scenes/network/NetworkCombatSandbox.tscn")
const WAIT_TIMEOUT_MSEC := 10000
const COMBAT_TIMEOUT_MSEC := 30000
const DEPTHS_ROOM := "development.room.test_depths"
const ENCOUNTER_ID := "development.encounter.venom_slime"

var _sandbox: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_sandbox = SandboxScene.instantiate()
	root.add_child(_sandbox)
	_sandbox.call("start_demo_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_authenticated()):
		_fail("Phase H sandbox did not authenticate both loopback clients.")
		return

	_sandbox.call("prepare_party_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_show_ready_party()):
		_fail("Phase H sandbox did not prepare the two-member ready party.")
		return
	_sandbox.call("launch_expedition_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_exploring()):
		_fail("Phase H sandbox did not cross the content-ready barrier.")
		return

	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	var server := _sandbox.call("get_server_runtime_for_test") as Node
	var local_id := (local.call("get_client_identity") as Dictionary).character_id as String
	var guest_id := (guest.call("get_client_identity") as Dictionary).character_id as String
	var expedition_id := (
		(local.call("get_expedition_snapshot") as Dictionary).expedition_id as String
	)
	if not _sandbox.call("place_party_at_encounter_for_test"):
		_fail("Phase H sandbox could not gather the party at the authored encounter.")
		return
	local.call("request_expedition_snapshot")
	guest.call("request_expedition_snapshot")
	if not await _wait_for(func() -> bool: return _both_clients_in_depths()):
		_fail("The gathered encounter setup did not converge to both clients.")
		return

	_sandbox.call("enter_combat_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_in_same_active_combat()):
		_fail(
			"The encounter did not cross the two-client ready barrier into combat. enabled=%s coordinator=%s local=%s guest=%s rejection=%s expedition=%s" % [
				_sandbox.get("enable_network_combat"),
				server.call("get_combat_coordinator_for_test"),
				local.call("get_combat_snapshot"),
				guest.call("get_combat_snapshot"),
				local.call("get_last_rejection"),
				local.call("get_expedition_snapshot"),
			]
		)
		return
	var first_combat := local.call("get_combat_snapshot") as Dictionary
	var combat_id := first_combat.combat_id as String
	var old_presenter := _sandbox.call("get_combat_presenter_for_test") as Node
	var layout_error := _combat_layout_error(old_presenter)
	if not layout_error.is_empty():
		_fail(layout_error)
		return
	var old_presenter_id := old_presenter.get_instance_id()
	_sandbox.call("reload_combat_presenter_for_test")
	if not await _wait_for(
		func() -> bool:
			var presenter := _sandbox.call("get_combat_presenter_for_test") as Node
			if presenter == null or presenter.get_instance_id() == old_presenter_id:
				return false
			return (presenter.call("get_snapshot_for_test") as Dictionary).get(
				"combat_id", ""
			) == combat_id
	):
		_fail("Reloading the combat presentation did not reconstruct the active combat.")
		return

	var previous_guest_instance_id := guest.get_instance_id()
	_sandbox.call("reconnect_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			var replacement := _sandbox.call("get_guest_runtime_for_test") as Node
			if replacement == null or replacement.get_instance_id() == previous_guest_instance_id:
				return false
			var identity := replacement.call("get_client_identity") as Dictionary
			var combat := replacement.call("get_combat_snapshot") as Dictionary
			return (
				identity.get("character_id", "") == guest_id
				and combat.get("combat_id", "") == combat_id
				and combat.get("lifecycle_state", "") == "AWAITING_ACTION"
			)
	):
		_fail("Guest reconnect did not reconstruct the same active combat window.")
		return

	var presenter := _sandbox.call("get_combat_presenter_for_test") as Node
	var last_local_action_revision := -1
	var deadline := Time.get_ticks_msec() + COMBAT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var expedition := local.call("get_expedition_snapshot") as Dictionary
		if (
			expedition.get("lifecycle_state", "") == "ACTIVE_EXPLORATION"
			and expedition.get("active_combat_id", "").is_empty()
		):
			break
		var combat := local.call("get_combat_snapshot") as Dictionary
		if combat.get("lifecycle_state", "") == "AWAITING_ACTION":
			var actor := _combatant(combat, combat.get("current_actor_id", ""))
			var revision := int(combat.get("revision", -1))
			if (
				actor.get("controller_id", "") == local_id
				and revision != last_local_action_revision
			):
				last_local_action_revision = revision
				if not presenter.call("submit_ability_for_test", "development.ability.strike"):
					_fail("The local combat presenter could not submit its authoritative turn.")
					return
		await process_frame
	if not _both_clients_resumed_exploration(combat_id):
		_fail("Combat did not resolve once and resume the authored expedition.")
		return

	var coordinator := server.call("get_combat_coordinator_for_test") as RefCounted
	await create_timer(0.25).timeout
	if coordinator.call("get_settlement_count", combat_id) != 1:
		_fail("The authoritative combat outcome was not settled exactly once.")
		return
	var expedition_service := server.call("get_expedition_service_for_test") as RefCounted
	var instance := expedition_service.call("get_instance_state", expedition_id) as Dictionary
	var encounter := (instance.encounters as Dictionary).get(ENCOUNTER_ID, {}) as Dictionary
	if encounter.get("status", "") != "COMPLETED":
		_fail("The victory did not persist the authored encounter as completed.")
		return
	if (presenter.call("get_snapshot_for_test") as Dictionary).get(
		"lifecycle_state", ""
	) != "CLOSED":
		_fail("The dedicated combat presentation did not receive its reliable closed snapshot.")
		return

	_cleanup()
	print("PASS: Phase H sandbox encounter launch, ready barrier, presentation reload, reconnect reconstruction, reliable turns/AI, outcome-once settlement, and exploration resume.")
	quit(0)


func _both_clients_authenticated() -> bool:
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	return (
		local != null
		and guest != null
		and not (local.call("get_client_identity") as Dictionary).is_empty()
		and not (guest.call("get_client_identity") as Dictionary).is_empty()
	)


func _both_clients_show_ready_party() -> bool:
	for runtime: Node in _client_runtimes():
		var party := runtime.call("get_party_snapshot") as Dictionary
		if (
			not party.get("all_present_members_ready", false)
			or (party.get("members", []) as Array).size() != 2
		):
			return false
	return _client_runtimes().size() == 2


func _both_clients_exploring() -> bool:
	for runtime: Node in _client_runtimes():
		if (runtime.call("get_expedition_snapshot") as Dictionary).get(
			"lifecycle_state", ""
		) != "ACTIVE_EXPLORATION":
			return false
	return _client_runtimes().size() == 2


func _both_clients_in_depths() -> bool:
	for runtime: Node in _client_runtimes():
		var snapshot := runtime.call("get_expedition_snapshot") as Dictionary
		if (
			snapshot.get("lifecycle_state", "") != "ACTIVE_EXPLORATION"
			or snapshot.get("current_room_id", "") != DEPTHS_ROOM
		):
			return false
	return _client_runtimes().size() == 2


func _both_clients_in_same_active_combat() -> bool:
	var combat_id := ""
	for runtime: Node in _client_runtimes():
		var snapshot := runtime.call("get_combat_snapshot") as Dictionary
		if snapshot.get("lifecycle_state", "") != "AWAITING_ACTION":
			return false
		if combat_id.is_empty():
			combat_id = snapshot.get("combat_id", "") as String
		elif snapshot.get("combat_id", "") != combat_id:
			return false
	return not combat_id.is_empty() and _client_runtimes().size() == 2


func _both_clients_resumed_exploration(combat_id: String) -> bool:
	for runtime: Node in _client_runtimes():
		var expedition := runtime.call("get_expedition_snapshot") as Dictionary
		var combat := runtime.call("get_combat_snapshot") as Dictionary
		if (
			expedition.get("lifecycle_state", "") != "ACTIVE_EXPLORATION"
			or not expedition.get("active_combat_id", "").is_empty()
			or combat.get("combat_id", "") != combat_id
			or combat.get("lifecycle_state", "") != "CLOSED"
		):
			return false
	return _client_runtimes().size() == 2


func _client_runtimes() -> Array[Node]:
	var result: Array[Node] = []
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	if local != null:
		result.append(local)
	if guest != null:
		result.append(guest)
	return result


func _combatant(snapshot: Dictionary, combatant_id: String) -> Dictionary:
	for value: Variant in snapshot.get("combatants", []):
		var combatant := value as Dictionary
		if combatant.get("combatant_id", "") == combatant_id:
			return combatant
	return {}


func _combat_layout_error(presenter: Node) -> String:
	if presenter == null:
		return "The dedicated combat presenter is missing."
	var combat_root := presenter.get_node("%CombatRoot") as Control
	var viewport_rect := Rect2(Vector2.ZERO, combat_root.size)
	var minimum_size := combat_root.get_combined_minimum_size()
	if minimum_size.x > viewport_rect.size.x or minimum_size.y > viewport_rect.size.y:
		return "Network combat minimum size %s exceeds its %s viewport." % [
			minimum_size, viewport_rect.size
		]
	var visible_controls: Array[Control] = [
		presenter.get_node("%StateLabel") as Control,
		presenter.get_node("CombatRoot/Margin/Rows/Body/CombatantsPanel") as Control,
		presenter.get_node("CombatRoot/Margin/Rows/Body/EventsPanel") as Control,
		presenter.get_node("%StrikeButton") as Control,
		presenter.get_node("%MendButton") as Control,
		presenter.get_node("%GuardButton") as Control,
		presenter.get_node("%ResultLabel") as Control,
		presenter.get_node("CombatRoot/Margin/Rows/Boundary") as Control,
	]
	for control: Control in visible_controls:
		var control_rect := control.get_global_rect()
		if (
			control_rect.position.x < viewport_rect.position.x
			or control_rect.position.y < viewport_rect.position.y
			or control_rect.end.x > viewport_rect.end.x
			or control_rect.end.y > viewport_rect.end.y
		):
			return "%s extends outside the 640x360 network combat viewport: %s." % [
				control.name, control_rect
			]
	return ""


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _cleanup() -> void:
	if _sandbox != null and is_instance_valid(_sandbox):
		_sandbox.queue_free()


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
