class_name CadenResourceSandbox
extends Control

const Controller := preload(
	"res://scripts/server/dedicated/dedicated_server_controller.gd"
)
const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")

const ACCESS_CODE := "phase-k-sandbox-private"
const DISPLAY_LABEL := "Alex"
const RESOURCE_ID := "development.item.edenite"
const PROJECT_ID := "development.project.fortification_probe"

@export var data_root := "user://mesoplasia_phase_k_sandbox"
@export var starting_port := 24920

@onready var _status_label: Label = %StatusLabel
@onready var _inventory_label: Label = %InventoryValue
@onready var _stockpile_label: Label = %StockpileValue
@onready var _project_label: Label = %ProjectValue
@onready var _grant_button: Button = %GrantButton
@onready var _deposit_button: Button = %DepositButton
@onready var _replay_button: Button = %ReplayButton
@onready var _reconnect_button: Button = %ReconnectButton
@onready var _fail_button: Button = %FailButton

var _controller: Node
var _client: Node
var _active_port := 0
var _last_deposit_id := ""
var _operation_sequence := 0
var _last_command_result: Dictionary = {}


func _ready() -> void:
	_grant_button.pressed.connect(grant_test_resource)
	_deposit_button.pressed.connect(deposit_one)
	_replay_button.pressed.connect(replay_last_deposit)
	_reconnect_button.pressed.connect(reconnect_client)
	_fail_button.pressed.connect(simulate_failed_deposit)
	_set_actions_enabled(false)
	_start_sandbox.call_deferred()


func _exit_tree() -> void:
	if _client != null and is_instance_valid(_client):
		_client.stop()
	if _controller != null and is_instance_valid(_controller):
		_controller.stop_without_backup_for_test()


func grant_test_resource() -> Dictionary:
	if _controller == null or _client == null or _client.get_client_identity().is_empty():
		return {"accepted": false, "reason_code": "NOT_READY"}
	_operation_sequence += 1
	var identity := _client.get_client_identity() as Dictionary
	var result := (_controller.get_persistence_coordinator_for_test() as RefCounted).call(
		"grant_personal_reward",
		"development.entitlement.phase_k.sandbox.%d.%d" % [
			Time.get_ticks_usec(), _operation_sequence
		],
		identity.character_id,
		RESOURCE_ID,
		1
	) as Dictionary
	_status_label.text = (
		"Granted one development Edenite on the authoritative server."
		if result.get("accepted", false)
		else "Grant rejected: %s" % result.get("reason_code", "UNKNOWN")
	)
	_client.request_caden_resource_snapshot()
	return result


func deposit_one() -> bool:
	var snapshot := get_resource_snapshot_for_test()
	if snapshot.is_empty():
		return false
	_operation_sequence += 1
	_last_deposit_id = "development.deposit.phase_k.sandbox.%d.%d" % [
		Time.get_ticks_usec(), _operation_sequence
	]
	_status_label.text = "Submitting one resource as client intent…"
	return _client.send_caden_resource_deposit(
		_last_deposit_id,
		RESOURCE_ID,
		1,
		int(snapshot.inventory_record_revision),
		int(snapshot.world_record_revision)
	)


func replay_last_deposit() -> bool:
	if _last_deposit_id.is_empty():
		_status_label.text = "Deposit once before replaying its transaction ID."
		return false
	var snapshot := get_resource_snapshot_for_test()
	_status_label.text = "Replaying the last deposit ID…"
	return _client.send_caden_resource_deposit(
		_last_deposit_id,
		RESOURCE_ID,
		1,
		int(snapshot.get("inventory_record_revision", -1)),
		int(snapshot.get("world_record_revision", -1))
	)


func reconnect_client() -> void:
	if _client == null:
		return
	var reconnect_token := _client.get_reconnect_token() as String
	_client.stop()
	_client.queue_free()
	_client = null
	await get_tree().process_frame
	_create_client(reconnect_token)
	_status_label.text = "Reconnecting the disposable client projection…"


func simulate_failed_deposit() -> bool:
	var snapshot := get_resource_snapshot_for_test()
	if _resource_quantity(snapshot.get("inventory_resources", [])) < 1:
		_status_label.text = "Grant a development resource before injecting a failed deposit."
		return false
	(_controller.get_backend_for_test() as RefCounted).call("fail_next_commit_for_test")
	_operation_sequence += 1
	_last_deposit_id = "development.deposit.phase_k.sandbox.failed.%d.%d" % [
		Time.get_ticks_usec(), _operation_sequence
	]
	_status_label.text = "Injected the next persistence failure; submitting deposit…"
	return _client.send_caden_resource_deposit(
		_last_deposit_id,
		RESOURCE_ID,
		1,
		int(snapshot.inventory_record_revision),
		int(snapshot.world_record_revision)
	)


func get_resource_snapshot_for_test() -> Dictionary:
	return _client.get_caden_resource_snapshot() as Dictionary if _client != null else {}


func get_last_command_result_for_test() -> Dictionary:
	return _last_command_result.duplicate(true)


func is_ready_for_test() -> bool:
	return (
		_client != null
		and not _client.get_client_identity().is_empty()
		and not get_resource_snapshot_for_test().is_empty()
	)


func _start_sandbox() -> void:
	for port: int in range(starting_port, starting_port + 20):
		var controller := Controller.new()
		$Runtimes.add_child(controller)
		var result := controller.start(_config(port), data_root, ACCESS_CODE) as Dictionary
		if result.get("accepted", false):
			_controller = controller
			_active_port = port
			break
		controller.stop_without_backup_for_test()
		controller.queue_free()
		await get_tree().process_frame
	if _controller == null:
		_status_label.text = "Could not bind a local Phase K server port."
		return
	_create_client()
	_status_label.text = "Local authoritative server started; authenticating client…"


func _create_client(reconnect_token: String = "") -> void:
	_client = NetworkRuntimeScene.instantiate()
	$Runtimes.add_child(_client)
	_client.client_authenticated.connect(_on_authenticated)
	_client.client_rejected.connect(_on_client_rejected)
	_client.caden_resource_snapshot_received.connect(_on_resource_snapshot)
	_client.caden_resource_command_result_received.connect(_on_resource_command_result)
	_client.start_client("127.0.0.1", _active_port, ACCESS_CODE, DISPLAY_LABEL, reconnect_token)


func _on_authenticated(identity: Dictionary) -> void:
	_status_label.text = "Authenticated durable character %s." % identity.character_id
	_client.request_caden_resource_snapshot()


func _on_client_rejected(reason_code: String, reason_text: String) -> void:
	_status_label.text = "Client rejected: %s — %s" % [reason_code, reason_text]


func _on_resource_snapshot(_snapshot: Dictionary) -> void:
	_refresh_projection()
	_set_actions_enabled(true)


func _on_resource_command_result(result: Dictionary) -> void:
	_last_command_result = result.duplicate(true)
	if result.get("accepted", false):
		_status_label.text = (
			"Deposit replay returned the original committed result; no duplicate mutation."
			if result.get("replayed", false)
			else "Deposit committed atomically; shared project state recalculated."
		)
	else:
		_status_label.text = "Deposit rejected safely: %s" % result.get("reason_code", "UNKNOWN")
	_refresh_projection()


func _refresh_projection() -> void:
	var snapshot := get_resource_snapshot_for_test()
	_inventory_label.text = str(_resource_quantity(snapshot.get("inventory_resources", [])))
	_stockpile_label.text = str(_resource_quantity(snapshot.get("stockpiles", [])))
	_project_label.text = _project_state(snapshot.get("projects", []))
	_replay_button.disabled = _last_deposit_id.is_empty()


func _resource_quantity(rows: Array) -> int:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("resource_id", "") == RESOURCE_ID:
			return int(row.get("quantity", 0))
	return 0


func _project_state(rows: Array) -> String:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("project_id", "") == PROJECT_ID:
			return row.get("state", "") as String
	return "NOT LOADED"


func _set_actions_enabled(enabled: bool) -> void:
	_grant_button.disabled = not enabled
	_deposit_button.disabled = not enabled
	_reconnect_button.disabled = not enabled
	_fail_button.disabled = not enabled
	_replay_button.disabled = not enabled or _last_deposit_id.is_empty()


func _config(port: int) -> Dictionary:
	return {
		"config_schema_version": 1,
		"server_name": "Phase K Caden Resource Sandbox",
		"listen_address": "127.0.0.1",
		"port": port,
		"max_connections": 4,
		"max_party_size": 4,
		"allowlist_enabled": true,
		"allowed_display_labels": [DISPLAY_LABEL],
		"save_path": "saves",
		"backup_path": "backups",
		"log_path": "logs",
		"backup_retention": 4,
		"load_timeout_msec": 5000,
		"turn_timeout_msec": 5000,
		"reconnect_grace_msec": 5000,
	}
