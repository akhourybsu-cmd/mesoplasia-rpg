extends SceneTree

const Controller := preload(
	"res://scripts/server/dedicated/dedicated_server_controller.gd"
)
const Config := preload("res://scripts/server/dedicated/dedicated_server_config.gd")
const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")

const TEST_ROOT := "res://tests/.phase_j_dedicated_test"
const ACCESS_CODE := "phase-j-private-access"
const ALLOWED_LABEL := "Alex"

var _controller: Node
var _clients: Array[Node] = []


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	if not _test_config_guards():
		return
	var started := await _start_controller_on_available_port()
	if not started.get("accepted", false):
		_fail("Dedicated controller could not bind an available loopback port: %s" % started)
		return
	var port := int(started.status.port)
	var allowed_client := _add_client("AllowedClient")
	if allowed_client.start_client("127.0.0.1", port, ACCESS_CODE, ALLOWED_LABEL) != OK:
		_fail("Allowed client could not start its loopback connection.")
		return
	if not await _wait_until(func() -> bool: return not allowed_client.get_client_identity().is_empty()):
		_fail("Allowlisted friend did not authenticate to the dedicated runtime.")
		return
	var first_identity := (allowed_client.get_client_identity() as Dictionary).duplicate(true)
	var backend := _controller.get_backend_for_test() as RefCounted
	if not (backend.call("load_record", "profiles", first_identity.account_id) as Dictionary).get("found", false):
		_fail("Authenticated friend identity was not durably bootstrapped.")
		return
	var denied_client := _add_client("DeniedClient")
	if denied_client.start_client("127.0.0.1", port, ACCESS_CODE, "Mallory") != OK:
		_fail("Denied-client transport fixture could not start.")
		return
	if not await _wait_until(
		func() -> bool:
			return (denied_client.get_last_rejection() as Dictionary).get("reason_code", "") == "AUTHENTICATION_FAILED"
	):
		_fail("A non-allowlisted label was not generically rejected.")
		return
	if not denied_client.get_client_identity().is_empty():
		_fail("Denied client received a server identity.")
		return
	var players := _controller.execute_admin_command("players") as Dictionary
	if not players.get("accepted", false) or (players.players as Array).size() != 1:
		_fail("Protected local players command did not return the one authenticated friend.")
		return
	var backup := _controller.execute_admin_command("backup") as Dictionary
	if not backup.get("accepted", false):
		_fail("Manual server backup failed: %s" % backup)
		return
	var events := (_controller.get_logger_for_test() as RefCounted).call("get_events_for_test") as Array
	if JSON.stringify(events).contains(ACCESS_CODE):
		_fail("Structured server events exposed the raw access code.")
		return
	var drain := _controller.execute_admin_command("drain") as Dictionary
	if not drain.get("accepted", false) or _controller.get_status().accepting_connections:
		_fail("Drain did not stop new session acceptance.")
		return
	var late_client := _add_client("LateClient")
	late_client.start_client("127.0.0.1", port, ACCESS_CODE, ALLOWED_LABEL)
	await _wait_frames(30)
	if not late_client.get_client_identity().is_empty() or _controller.get_status().authenticated != 1:
		_fail("Draining server accepted a new authenticated session.")
		return
	var shutdown := _controller.execute_admin_command("shutdown") as Dictionary
	if not shutdown.get("accepted", false) or _controller.get_status().state != Controller.STATE_STOPPED:
		_fail("Graceful shutdown did not validate, back up, close transport, and stop.")
		return
	await _wait_frames(5)
	_free_clients()
	_controller.queue_free()
	_controller = null
	await process_frame

	var restarted := await _start_controller_on_available_port()
	if not restarted.get("accepted", false):
		_fail("Dedicated controller did not restart against existing durable data.")
		return
	var restart_client := _add_client("RestartClient")
	if restart_client.start_client(
		"127.0.0.1", int(restarted.status.port), ACCESS_CODE, ALLOWED_LABEL
	) != OK:
		_fail("Restart identity client could not connect.")
		return
	if not await _wait_until(func() -> bool: return not restart_client.get_client_identity().is_empty()):
		_fail("Allowlisted friend did not authenticate after server restart.")
		return
	var restarted_identity := restart_client.get_client_identity() as Dictionary
	if (
		restarted_identity.account_id != first_identity.account_id
		or restarted_identity.character_id != first_identity.character_id
	):
		_fail("Server restart did not recover the same durable account and character identity.")
		return
	if not (_controller.execute_admin_command("shutdown") as Dictionary).get("accepted", false):
		_fail("Restarted server did not shut down cleanly.")
		return
	_free_clients()
	_controller.queue_free()
	_controller = null
	_cleanup()
	print("PASS: Phase J validated private config, redacted logs, durable identity, allowlist auth, loopback join, admin backup, drain, graceful shutdown, and restart recovery.")
	quit(0)


func _test_config_guards() -> bool:
	var source := _valid_config(24567)
	if (Config.parse(source, TEST_ROOT, "short") as Dictionary).get("reason_code", "") != "ACCESS_CODE_POLICY":
		_fail("Short private access code was not rejected.")
		return false
	var traversal := source.duplicate(true)
	traversal.save_path = "../outside"
	if (Config.parse(traversal, TEST_ROOT, ACCESS_CODE) as Dictionary).get("reason_code", "") != "INSTANCE_CHILD_PATH":
		_fail("Dedicated config accepted path traversal.")
		return false
	var unsafe_public := source.duplicate(true)
	unsafe_public.allowlist_enabled = true
	unsafe_public.allowed_display_labels = []
	if (Config.parse(unsafe_public, TEST_ROOT, ACCESS_CODE) as Dictionary).get("reason_code", "") != "ALLOWLIST_EMPTY":
		_fail("Private default accepted an empty enabled allowlist.")
		return false
	return true


func _start_controller_on_available_port() -> Dictionary:
	for port: int in range(24720, 24740):
		var controller := Controller.new()
		root.add_child(controller)
		var result := controller.start(_valid_config(port), TEST_ROOT, ACCESS_CODE) as Dictionary
		if result.get("accepted", false):
			_controller = controller
			return result
		controller.stop_without_backup_for_test()
		controller.queue_free()
		await process_frame
	return {"accepted": false, "reason_code": "NO_AVAILABLE_PORT"}


func _valid_config(port: int) -> Dictionary:
	return {
		"config_schema_version": 1,
		"server_name": "Phase J Private Test",
		"listen_address": "127.0.0.1",
		"port": port,
		"max_connections": 4,
		"max_party_size": 4,
		"allowlist_enabled": true,
		"allowed_display_labels": [ALLOWED_LABEL],
		"save_path": "saves",
		"backup_path": "backups",
		"log_path": "logs",
		"backup_retention": 4,
		"load_timeout_msec": 5000,
		"turn_timeout_msec": 5000,
		"reconnect_grace_msec": 5000,
	}


func _add_client(node_name: String) -> Node:
	var client := NetworkRuntimeScene.instantiate()
	client.name = node_name
	root.add_child(client)
	_clients.append(client)
	return client


func _wait_until(predicate: Callable, maximum_frames: int = 240) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return false


func _wait_frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _free_clients() -> void:
	for client: Node in _clients:
		if is_instance_valid(client):
			client.stop()
			client.queue_free()
	_clients.clear()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_j_dedicated_test"):
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
	_free_clients()
	if _controller != null and is_instance_valid(_controller):
		_controller.stop_without_backup_for_test()
		_controller.queue_free()
	_cleanup()
	push_error(message)
	quit(1)
