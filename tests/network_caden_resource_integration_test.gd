extends SceneTree

const Controller := preload(
	"res://scripts/server/dedicated/dedicated_server_controller.gd"
)
const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")

const TEST_ROOT := "res://tests/.phase_k_network_resource_test"
const ACCESS_CODE := "phase-k-network-private"
const DISPLAY_LABEL := "Alex"
const RESOURCE_ID := "development.item.edenite"
const PROJECT_ID := "development.project.fortification_probe"
const DEPOSIT_ID := "development.deposit.phase_k.network"

var _controller: Node
var _client: Node
var _observer: Node
var _command_results: Array[Dictionary] = []


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	var started := await _start_controller()
	if not started.get("accepted", false):
		_fail("Phase K network server could not bind: %s" % started)
		return
	_client = NetworkRuntimeScene.instantiate()
	root.add_child(_client)
	_client.caden_resource_command_result_received.connect(_on_command_result)
	if _client.start_client(
		"127.0.0.1", int(started.status.port), ACCESS_CODE, DISPLAY_LABEL
	) != OK:
		_fail("Phase K network client could not start.")
		return
	if not await _wait_until(func() -> bool: return not _client.get_client_identity().is_empty()):
		_fail("Phase K network client did not authenticate.")
		return
	_observer = NetworkRuntimeScene.instantiate()
	root.add_child(_observer)
	if _observer.start_client(
		"127.0.0.1", int(started.status.port), ACCESS_CODE, "Bob"
	) != OK:
		_fail("Phase K observer client could not start.")
		return
	if not await _wait_until(
		func() -> bool:
			return (
				not _observer.get_client_identity().is_empty()
				and not (_observer.get_caden_resource_snapshot() as Dictionary).is_empty()
			)
	):
		_fail("Phase K observer did not authenticate and receive shared state.")
		return
	var identity := _client.get_client_identity() as Dictionary
	var coordinator := _controller.get_persistence_coordinator_for_test() as RefCounted
	var reward := coordinator.call(
		"grant_personal_reward",
		"development.entitlement.phase_k.network",
		identity.character_id,
		RESOURCE_ID,
		1
	) as Dictionary
	if not reward.get("accepted", false):
		_fail("Network resource fixture could not be granted: %s" % reward)
		return
	_client.request_caden_resource_snapshot()
	if not await _wait_until(
		func() -> bool:
			return _resource_quantity(
				(_client.get_caden_resource_snapshot() as Dictionary).get(
					"inventory_resources", []
				),
				RESOURCE_ID
			) == 1
	):
		_fail("Owning client did not receive its updated resource inventory projection.")
		return
	var before := _client.get_caden_resource_snapshot() as Dictionary
	if not _client.send_caden_resource_deposit(
		DEPOSIT_ID,
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		before.world_record_revision
	):
		_fail("Client resource deposit command was not sent.")
		return
	if not await _wait_until(
		func() -> bool:
			var snapshot := _client.get_caden_resource_snapshot() as Dictionary
			return (
				_resource_quantity(snapshot.get("inventory_resources", []), RESOURCE_ID) == 0
				and _resource_quantity(snapshot.get("stockpiles", []), RESOURCE_ID) == 1
				and _project_state(snapshot.get("projects", []), PROJECT_ID) == "FUNDED"
			)
	):
		_fail("Network deposit did not converge inventory, shared stockpile, and project state.")
		return
	if not await _wait_until(
		func() -> bool:
			var observer_snapshot := _observer.get_caden_resource_snapshot() as Dictionary
			return (
				_resource_quantity(observer_snapshot.get("inventory_resources", []), RESOURCE_ID) == 0
				and _resource_quantity(observer_snapshot.get("stockpiles", []), RESOURCE_ID) == 1
				and _project_state(observer_snapshot.get("projects", []), PROJECT_ID) == "FUNDED"
			)
	):
		_fail("Second client did not receive shared state while retaining private inventory isolation.")
		return
	if (
		_command_results.is_empty()
		or not _command_results[-1].get("accepted", false)
		or not (_command_results[-1].changed_project_ids as Array).has(PROJECT_ID)
	):
		_fail("Client did not receive the accepted project-transition result.")
		return
	var result_count := _command_results.size()
	_client.send_caden_resource_deposit(
		DEPOSIT_ID,
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		before.world_record_revision
	)
	if not await _wait_until(func() -> bool: return _command_results.size() > result_count):
		_fail("Network deposit replay did not return a command result.")
		return
	if not _command_results[-1].get("accepted", false) or not _command_results[-1].get("replayed", false):
		_fail("Network replay was not accepted idempotently: %s" % _command_results[-1])
		return
	result_count = _command_results.size()
	var current := _client.get_caden_resource_snapshot() as Dictionary
	_client.send_caden_resource_deposit(
		"development.deposit.phase_k.unknown",
		"development.item.unknown",
		1,
		current.inventory_record_revision,
		current.world_record_revision
	)
	if not await _wait_until(func() -> bool: return _command_results.size() > result_count):
		_fail("Unknown resource command did not receive a result.")
		return
	if _command_results[-1].get("reason_code", "") != "UNKNOWN_RESOURCE":
		_fail("Unknown resource was not rejected by the authoritative service.")
		return
	var first_character_id := identity.character_id as String
	_client.stop()
	_client.queue_free()
	_client = null
	_observer.stop()
	_observer.queue_free()
	_observer = null
	var shutdown := _controller.graceful_shutdown() as Dictionary
	if not shutdown.get("accepted", false):
		_fail("Phase K network server did not shut down durably.")
		return
	_controller.queue_free()
	_controller = null
	await process_frame
	var restarted := await _start_controller()
	if not restarted.get("accepted", false):
		_fail("Phase K network server did not restart from durable state.")
		return
	_client = NetworkRuntimeScene.instantiate()
	root.add_child(_client)
	if _client.start_client(
		"127.0.0.1", int(restarted.status.port), ACCESS_CODE, DISPLAY_LABEL
	) != OK:
		_fail("Restart client could not connect.")
		return
	if not await _wait_until(
		func() -> bool:
			var restart_identity := _client.get_client_identity() as Dictionary
			var snapshot := _client.get_caden_resource_snapshot() as Dictionary
			return (
				restart_identity.get("character_id", "") == first_character_id
				and _resource_quantity(snapshot.get("stockpiles", []), RESOURCE_ID) == 1
				and _project_state(snapshot.get("projects", []), PROJECT_ID) == "FUNDED"
			)
	):
		_fail("Reconnect did not restore stable identity and shared Phase K state.")
		return
	_client.stop()
	_client.queue_free()
	_client = null
	_controller.graceful_shutdown()
	_controller.queue_free()
	_controller = null
	_cleanup()
	print("PASS: Phase K ENet clients preserved private inventory isolation while sharing stockpile/project state, committed and replayed an authoritative deposit, rejected unknown content, and recovered state after server restart.")
	quit(0)


func _start_controller() -> Dictionary:
	for port: int in range(24820, 24840):
		var controller := Controller.new()
		root.add_child(controller)
		var result := controller.start(_config(port), TEST_ROOT, ACCESS_CODE) as Dictionary
		if result.get("accepted", false):
			_controller = controller
			return result
		controller.stop_without_backup_for_test()
		controller.queue_free()
		await process_frame
	return {"accepted": false, "reason_code": "NO_AVAILABLE_PORT"}


func _config(port: int) -> Dictionary:
	return {
		"config_schema_version": 1,
		"server_name": "Phase K Resource Integration",
		"listen_address": "127.0.0.1",
		"port": port,
		"max_connections": 4,
		"max_party_size": 4,
		"allowlist_enabled": true,
		"allowed_display_labels": [DISPLAY_LABEL, "Bob"],
		"save_path": "saves",
		"backup_path": "backups",
		"log_path": "logs",
		"backup_retention": 4,
		"load_timeout_msec": 5000,
		"turn_timeout_msec": 5000,
		"reconnect_grace_msec": 5000,
	}


func _on_command_result(result: Dictionary) -> void:
	_command_results.append(result.duplicate(true))


func _resource_quantity(rows: Array, resource_id: String) -> int:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("resource_id", "") == resource_id:
			return int(row.get("quantity", 0))
	return -1


func _project_state(rows: Array, project_id: String) -> String:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("project_id", "") == project_id:
			return row.get("state", "") as String
	return ""


func _wait_until(predicate: Callable, maximum_frames: int = 300) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return false


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_k_network_resource_test"):
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
	if _client != null and is_instance_valid(_client):
		_client.stop()
		_client.queue_free()
	if _observer != null and is_instance_valid(_observer):
		_observer.stop()
		_observer.queue_free()
	if _controller != null and is_instance_valid(_controller):
		_controller.stop_without_backup_for_test()
		_controller.queue_free()
	_cleanup()
	push_error(message)
	quit(1)
