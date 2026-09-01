extends SceneTree

const SandboxScene := preload("res://scenes/network/NetworkedCadenSandbox.tscn")
const WAIT_TIMEOUT_MSEC := 8000


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var sandbox := SandboxScene.instantiate()
	root.add_child(sandbox)
	sandbox.call("start_demo_for_test")
	if not await _wait_for(
		func() -> bool:
			var primary := sandbox.call("get_primary_runtime_for_test") as Node
			var guest := sandbox.call("get_guest_runtime_for_test") as Node
			return (
				primary != null
				and guest != null
				and not (primary.call("get_client_identity") as Dictionary).is_empty()
				and not (guest.call("get_client_identity") as Dictionary).is_empty()
			)
	):
		_fail(sandbox, "One-click Phase D demo did not authenticate both loopback clients.")
		return
	if not await _wait_for(
		func() -> bool:
			var presenter := sandbox.call("get_presenter_for_test") as Node
			return presenter != null and presenter.call("get_presented_avatar_count") == 2
	):
		_fail(sandbox, "One-click Phase D demo did not present two same-zone avatars.")
		return
	var guest := sandbox.call("get_guest_runtime_for_test") as Node
	var guest_identity := guest.call("get_client_identity") as Dictionary
	var initial_position := _snapshot_position(guest, guest_identity.character_id)
	if not await _wait_for(
		func() -> bool:
			return _snapshot_position(guest, guest_identity.character_id).distance_to(initial_position) > 0.5
	):
		_fail(sandbox, "Automated loopback guest did not visibly exercise server movement.")
		return
	var previous_primary := sandbox.call("get_primary_runtime_for_test") as Node
	var previous_primary_instance_id := previous_primary.get_instance_id()
	var stable_character_id := (
		previous_primary.call("get_client_identity") as Dictionary
	).character_id as String
	sandbox.call("reconnect_local_for_test")
	if not await _wait_for(
		func() -> bool:
			var replacement := sandbox.call("get_primary_runtime_for_test") as Node
			return (
				replacement != null
				and replacement.get_instance_id() != previous_primary_instance_id
				and not (replacement.call("get_client_identity") as Dictionary).is_empty()
				and (replacement.call("get_client_identity") as Dictionary).character_id
				== stable_character_id
			)
	):
		_fail(sandbox, "One-click reconnect did not restore the stable local character.")
		return
	var replacement := sandbox.call("get_primary_runtime_for_test") as Node
	var reconnect_position := _snapshot_position(replacement, stable_character_id)
	Input.action_press("move_right")
	var moved_after_reconnect := await _wait_for_msec(
		func() -> bool:
			return _snapshot_position(replacement, stable_character_id).x > reconnect_position.x,
		750
	)
	Input.action_release("move_right")
	if not moved_after_reconnect:
		_fail(sandbox, "One-click reconnect restored the avatar but did not restore movement.")
		return
	sandbox.queue_free()
	await process_frame
	print("PASS: Phase D one-click two-client Caden sandbox composition and moving guest.")
	quit(0)


func _snapshot_position(runtime: Node, character_id: String) -> Vector2:
	var snapshot := runtime.call("get_hub_snapshot") as Dictionary
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar := avatar_value as Dictionary
		if avatar.get("character_id", "") == character_id:
			return Vector2(float(avatar.position_x), float(avatar.position_y))
	return Vector2.ZERO


func _wait_for(predicate: Callable) -> bool:
	return await _wait_for_msec(predicate, WAIT_TIMEOUT_MSEC)


func _wait_for_msec(predicate: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _fail(sandbox: Node, message: String) -> void:
	if sandbox != null and is_instance_valid(sandbox):
		sandbox.queue_free()
	push_error(message)
	quit(1)
