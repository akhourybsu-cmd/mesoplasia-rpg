extends SceneTree

const SandboxScene := preload("res://scenes/development/PersistenceSandbox.tscn")
const TEST_ROOT := "res://tests/.phase_i_persistence_sandbox_test"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	var sandbox := SandboxScene.instantiate()
	sandbox.data_root = TEST_ROOT
	root.add_child(sandbox)
	await process_frame
	var title := sandbox.get_node("Margin/Rows/Title") as Control
	var footer := sandbox.get_node("Margin/Rows/Footer") as Control
	var fail_button := sandbox.get_node("%FailButton") as Control
	if (
		title.global_position.y < 0.0
		or fail_button.get_global_rect().end.y > 360.0
		or footer.get_global_rect().end.y > 360.0
	):
		_fail("Persistence sandbox controls do not fit the 640x360 safe viewport.")
		return
	var initialized := sandbox.initialize_fixture() as Dictionary
	if not initialized.get("accepted", false):
		_fail("Persistence sandbox could not initialize its atomic fixture.")
		return
	var first_reward := sandbox.grant_or_replay_reward() as Dictionary
	var replayed_reward := sandbox.grant_or_replay_reward() as Dictionary
	if (
		not first_reward.get("accepted", false)
		or first_reward.get("replayed", false)
		or not replayed_reward.get("replayed", false)
		or sandbox.get_quantity_for_test() != 1
	):
		_fail("Sandbox reward control did not demonstrate exactly-once settlement.")
		return
	if not sandbox.simulate_restart() or sandbox.get_quantity_for_test() != 1:
		_fail("Sandbox restart control did not reload its durable inventory.")
		return
	var failure := sandbox.simulate_failed_save() as Dictionary
	if failure.get("accepted", false) or sandbox.get_quantity_for_test() != 1:
		_fail("Sandbox failure control changed acknowledged durable state.")
		return
	if not (sandbox.create_backup() as Dictionary).get("accepted", false):
		_fail("Sandbox backup control failed.")
		return
	if not sandbox.simulate_restart():
		_fail("Sandbox could not reconstruct after its first backup.")
		return
	if not (sandbox.create_backup() as Dictionary).get("accepted", false):
		_fail("Sandbox did not resume its durable backup sequence after restart.")
		return
	if not (sandbox.restore_last_backup() as Dictionary).get("accepted", false):
		_fail("Sandbox restore control failed.")
		return
	if sandbox.get_status_text_for_test().is_empty():
		_fail("Sandbox did not render authority feedback.")
		return
	_cleanup()
	print("PASS: Phase I persistence sandbox exposes atomic initialization, idempotent reward replay, restart, backup/restore, and failed-save checks.")
	quit(0)


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_i_persistence_sandbox_test"):
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
	_cleanup()
	push_error(message)
	quit(1)
