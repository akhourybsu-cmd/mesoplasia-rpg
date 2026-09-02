extends SceneTree

const SandboxScene := preload("res://scenes/development/CadenResourceSandbox.tscn")

const TEST_ROOT := "res://tests/.phase_k_resource_sandbox_test"
const RESOURCE_ID := "development.item.edenite"
const PROJECT_ID := "development.project.fortification_probe"

var _sandbox: Control


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	_sandbox = SandboxScene.instantiate()
	_sandbox.set("data_root", TEST_ROOT)
	_sandbox.set("starting_port", 24960)
	root.add_child(_sandbox)
	if not await _wait_until(func() -> bool: return _sandbox.is_ready_for_test()):
		_fail("Phase K sandbox did not compose its local authoritative server and client.")
		return
	if not (_sandbox.grant_test_resource() as Dictionary).get("accepted", false):
		_fail("Phase K sandbox could not grant its development resource fixture.")
		return
	if not await _wait_until(
		func() -> bool:
			return _quantity(
				(_sandbox.get_resource_snapshot_for_test() as Dictionary).get(
					"inventory_resources", []
				)
			) == 1
	):
		_fail("Phase K sandbox did not project the granted private resource.")
		return
	if not _sandbox.simulate_failed_deposit():
		_fail("Phase K sandbox failed-deposit action was not submitted.")
		return
	if not await _wait_until(
		func() -> bool:
			return (_sandbox.get_last_command_result_for_test() as Dictionary).get(
				"reason_code", ""
			) == "PERSISTENCE_WRITE_FAILED"
	):
		_fail("Phase K sandbox did not surface the injected persistence rejection.")
		return
	var after_failure := _sandbox.get_resource_snapshot_for_test() as Dictionary
	if (
		_quantity(after_failure.inventory_resources) != 1
		or _quantity(after_failure.stockpiles) != 0
		or _project_state(after_failure.projects) != "AWAITING_RESOURCES"
	):
		_fail("Phase K sandbox failed deposit partially changed projected state.")
		return
	if not _sandbox.deposit_one():
		_fail("Phase K sandbox valid deposit action was not submitted.")
		return
	if not await _wait_until(
		func() -> bool:
			var snapshot := _sandbox.get_resource_snapshot_for_test() as Dictionary
			return (
				_quantity(snapshot.get("inventory_resources", [])) == 0
				and _quantity(snapshot.get("stockpiles", [])) == 1
				and _project_state(snapshot.get("projects", [])) == "FUNDED"
			)
	):
		_fail("Phase K sandbox did not show its funded project transition.")
		return
	if not _sandbox.replay_last_deposit():
		_fail("Phase K sandbox replay action was not submitted.")
		return
	if not await _wait_until(
		func() -> bool:
			return (_sandbox.get_last_command_result_for_test() as Dictionary).get(
				"replayed", false
			)
	):
		_fail("Phase K sandbox did not report exact-once replay.")
		return
	await _sandbox.reconnect_client()
	if not await _wait_until(
		func() -> bool:
			var snapshot := _sandbox.get_resource_snapshot_for_test() as Dictionary
			return (
				_sandbox.is_ready_for_test()
				and _quantity(snapshot.get("stockpiles", [])) == 1
				and _project_state(snapshot.get("projects", [])) == "FUNDED"
			)
	):
		_fail("Phase K sandbox client reconnect did not reconstruct shared state.")
		return
	await process_frame
	if not _verify_layout_bounds():
		return
	_sandbox.queue_free()
	await process_frame
	_sandbox = null
	_cleanup()
	print("PASS: Phase K sandbox displayed the complete 640x360 resource menu and exercised grant, failed deposit, atomic deposit, exact-once replay, funded project state, and disposable-client reconnect.")
	quit(0)


func _verify_layout_bounds() -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(640, 360))
	for path: String in [
		"Margin/Layout/Title",
		"Margin/Layout/StatusLabel",
		"Margin/Layout/Actions/GrantButton",
		"Margin/Layout/Actions/FailButton",
		"Margin/Layout/Footer",
	]:
		var control := _sandbox.get_node(path) as Control
		if control == null or not viewport_rect.encloses(control.get_global_rect()):
			_fail("Phase K sandbox control is outside 640x360: %s" % path)
			return false
	return true


func _quantity(rows: Array) -> int:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("resource_id", "") == RESOURCE_ID:
			return int(row.get("quantity", 0))
	return -1


func _project_state(rows: Array) -> String:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("project_id", "") == PROJECT_ID:
			return row.get("state", "") as String
	return ""


func _wait_until(predicate: Callable, maximum_frames: int = 360) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return false


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_k_resource_sandbox_test"):
		_remove_tree(absolute)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := "%s/%s" % [path, name]
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	if _sandbox != null and is_instance_valid(_sandbox):
		_sandbox.queue_free()
	_cleanup()
	push_error(message)
	quit(1)
