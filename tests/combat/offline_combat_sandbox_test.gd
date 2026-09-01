extends SceneTree

const SandboxScene := preload("res://scenes/development/OfflineCombatSandbox.tscn")
const WAIT_TIMEOUT_MSEC := 5000

var _sandbox: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_sandbox = SandboxScene.instantiate()
	root.add_child(_sandbox)
	if not await _wait_for(func() -> bool: return _player_turn_or_end()):
		_fail("Offline combat viewer did not initialize its pure domain fixture.")
		return
	var initial := _sandbox.call("get_snapshot_for_test") as Dictionary
	if (
		initial.get("combat_id", "").is_empty()
		or (initial.get("combatants", []) as Array).size() != 3
		or not _sandbox.find_children("*", "MultiplayerSpawner", true, false).is_empty()
	):
		_fail("Offline viewer fixture or no-network boundary is incorrect.")
		return
	var layout_error := _menu_layout_error()
	if not layout_error.is_empty():
		_fail(layout_error)
		return
	var safety := 0
	while safety < 20:
		var snapshot := _sandbox.call("get_snapshot_for_test") as Dictionary
		if snapshot.get("lifecycle_state", "") == "COMBAT_END":
			break
		if snapshot.get("lifecycle_state", "") == "AWAITING_ACTION":
			var result := _sandbox.call(
				"use_ability_for_test", "development.ability.strike"
			) as Dictionary
			if not result.get("accepted", false):
				_fail("Viewer could not submit a legal player Strike: %s" % result.get("reason_code", ""))
				return
		if not await _wait_for(func() -> bool: return _player_turn_or_end()):
			_fail("Viewer did not advance through its AI turn.")
			return
		safety += 1
	var final := _sandbox.call("get_snapshot_for_test") as Dictionary
	if (
		final.get("lifecycle_state", "") != "COMBAT_END"
		or not (final.get("outcome", "") as String).begins_with("VICTORY:")
		or (final.get("recent_events", []) as Array).is_empty()
	):
		_fail("Viewer did not reflect a terminal authoritative combat outcome.")
		return
	layout_error = _menu_layout_error()
	if not layout_error.is_empty():
		_fail(layout_error)
		return
	_sandbox.call("restart_for_test")
	if not await _wait_for(func() -> bool: return _player_turn_or_end()):
		_fail("Viewer fixture did not restart cleanly.")
		return
	final = _sandbox.call("get_snapshot_for_test") as Dictionary
	if final.get("outcome", "") != "NONE" or (final.get("combatants", []) as Array).size() != 3:
		_fail("Restarted viewer retained terminal state.")
		return

	_cleanup()
	print("PASS: Phase G optional viewer fits the 640x360 viewport, consumes snapshots, submits intents, advances deterministic AI, reflects outcome, restarts, and owns no network state.")
	quit(0)


func _menu_layout_error() -> String:
	var sandbox_control := _sandbox as Control
	if sandbox_control == null:
		return "Offline viewer root is not a Control."
	var viewport_rect := Rect2(Vector2.ZERO, sandbox_control.size)
	var minimum_size := sandbox_control.get_combined_minimum_size()
	if minimum_size.x > viewport_rect.size.x or minimum_size.y > viewport_rect.size.y:
		return "Offline viewer minimum size %s exceeds its %s viewport." % [
			minimum_size, viewport_rect.size
		]
	var visible_controls: Array[Control] = [
		_sandbox.get_node("%RestartButton") as Control,
		_sandbox.get_node("%StateLabel") as Control,
		_sandbox.get_node("Margin/Rows/Body/CombatantsPanel") as Control,
		_sandbox.get_node("Margin/Rows/Body/EventsPanel") as Control,
		_sandbox.get_node("%StrikeButton") as Control,
		_sandbox.get_node("%MendButton") as Control,
		_sandbox.get_node("%GuardButton") as Control,
		_sandbox.get_node("%ResultLabel") as Control,
		_sandbox.get_node("Margin/Rows/Boundary") as Control,
	]
	for control: Control in visible_controls:
		var control_rect := control.get_global_rect()
		if (
			control_rect.position.x < viewport_rect.position.x
			or control_rect.position.y < viewport_rect.position.y
			or control_rect.end.x > viewport_rect.end.x
			or control_rect.end.y > viewport_rect.end.y
		):
			return "%s extends outside the 640x360 combat sandbox viewport: %s." % [
				control.name, control_rect
			]
	return ""


func _player_turn_or_end() -> bool:
	if _sandbox == null:
		return false
	var snapshot := _sandbox.call("get_snapshot_for_test") as Dictionary
	return snapshot.get("lifecycle_state", "") in ["AWAITING_ACTION", "COMBAT_END"]


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
