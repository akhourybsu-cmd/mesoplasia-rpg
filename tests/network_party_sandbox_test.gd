extends SceneTree

const SandboxScene := preload("res://scenes/network/NetworkPartySandbox.tscn")
const WAIT_TIMEOUT_MSEC := 8000

var _sandbox: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_sandbox = SandboxScene.instantiate()
	root.add_child(_sandbox)
	_sandbox.call("start_demo_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_ready()):
		_fail("Party sandbox did not start two authenticated clients.")
		return
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	var local_identity := local.call("get_client_identity") as Dictionary
	var guest_identity := guest.call("get_client_identity") as Dictionary

	_sandbox.call("invite_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			return (
				((guest.call("get_party_snapshot") as Dictionary).get("invitations", []) as Array).size()
				== 1
			)
	):
		_fail("Party sandbox did not expose the guest invitation.")
		return
	_sandbox.call("accept_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			return (
				((local.call("get_party_snapshot") as Dictionary).get("members", []) as Array).size()
				== 2
				and ((guest.call("get_party_snapshot") as Dictionary).get("members", []) as Array).size()
					== 2
			)
	):
		_fail("Party sandbox clients did not converge after guest acceptance.")
		return

	_sandbox.call("select_expedition_for_test")
	if not await _wait_for(
		func() -> bool:
			return (
				(local.call("get_party_snapshot") as Dictionary).get(
					"selected_expedition_definition_id", ""
				) == "development.expedition.placeholder"
				and (guest.call("get_party_snapshot") as Dictionary).get(
					"selected_expedition_definition_id", ""
				) == "development.expedition.placeholder"
			)
	):
		_fail("Party sandbox expedition selection did not converge.")
		return
	_sandbox.call("ready_local_for_test")
	if not await _wait_for(
		func() -> bool: return _member_ready(guest, local_identity.character_id)
	):
		_fail("Party sandbox local readiness did not converge.")
		return
	_sandbox.call("ready_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			return (
				(local.call("get_party_snapshot") as Dictionary).get(
					"all_present_members_ready", false
				)
				and (guest.call("get_party_snapshot") as Dictionary).get(
					"all_present_members_ready", false
				)
			)
	):
		_fail("Party sandbox did not show all-present readiness.")
		return

	_sandbox.call("reconnect_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			var replacement := _sandbox.call("get_guest_runtime_for_test") as Node
			if replacement == null:
				return false
			var identity := replacement.call("get_client_identity") as Dictionary
			var snapshot := replacement.call("get_party_snapshot") as Dictionary
			return (
				identity.get("character_id", "") == guest_identity.character_id
				and not snapshot.get("party_id", "").is_empty()
				and (snapshot.get("members", []) as Array).size() == 2
				and not _member_ready(replacement, guest_identity.character_id)
			)
	):
		_fail("Party sandbox reconnect did not preserve membership and clear guest readiness.")
		return
	if _sandbox.find_children("*", "Button", true, false).any(
		func(button: Button) -> bool: return "launch" in button.text.to_lower()
	):
		_fail("Phase E sandbox exposed an out-of-scope expedition launch control.")
		return

	_cleanup()
	print("PASS: Phase E party sandbox start, invite, accept, select, ready convergence, reconnect grace, and scope boundary.")
	quit(0)


func _both_clients_ready() -> bool:
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	if local == null or guest == null:
		return false
	return (
		not (local.call("get_client_identity") as Dictionary).is_empty()
		and not (guest.call("get_client_identity") as Dictionary).is_empty()
		and not (local.call("get_party_snapshot") as Dictionary).is_empty()
		and not (guest.call("get_party_snapshot") as Dictionary).is_empty()
	)


func _member_ready(runtime: Node, character_id: String) -> bool:
	if runtime == null or not is_instance_valid(runtime):
		return false
	var snapshot := runtime.call("get_party_snapshot") as Dictionary
	for member_value: Variant in snapshot.get("members", []):
		var member := member_value as Dictionary
		if member.get("character_id", "") == character_id:
			return member.get("ready", false)
	return false


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
