class_name PersistenceSandbox
extends Control

const Backend := preload("res://scripts/persistence/versioned_file_backend.gd")
const Coordinator := preload("res://scripts/persistence/server_persistence_coordinator.gd")

const ACCOUNT_ID := "development.account.persistence_sandbox"
const CHARACTER_ID := "development.character.persistence_sandbox"
const WORLD_ID := "development.world.persistence_sandbox"
const ITEM_ID := "development.item.edenite"
const ENTITLEMENT_ID := "development.entitlement.persistence_sandbox"
const BACKUP_ID_PREFIX := "development.backup.sandbox."

@export var data_root := "user://mesoplasia_phase_i_sandbox"

@onready var _status_label: Label = %StatusLabel
@onready var _records_label: Label = %RecordsLabel
@onready var _initialize_button: Button = %InitializeButton
@onready var _reward_button: Button = %RewardButton
@onready var _restart_button: Button = %RestartButton
@onready var _backup_button: Button = %BackupButton
@onready var _restore_button: Button = %RestoreButton
@onready var _fail_button: Button = %FailButton

var _backend: RefCounted
var _coordinator: RefCounted
var _last_backup_id := ""
var _backup_sequence := 0


func _ready() -> void:
	_initialize_button.pressed.connect(initialize_fixture)
	_reward_button.pressed.connect(grant_or_replay_reward)
	_restart_button.pressed.connect(simulate_restart)
	_backup_button.pressed.connect(create_backup)
	_restore_button.pressed.connect(restore_last_backup)
	_fail_button.pressed.connect(simulate_failed_save)
	_compose("Storage opened. Initialize the fixture or inspect existing durable records.")


func initialize_fixture() -> Dictionary:
	var result := _coordinator.initialize_fresh_server(
		ACCOUNT_ID, CHARACTER_ID, WORLD_ID, "Persistence Tester"
	) as Dictionary
	if result.get("accepted", false):
		_set_status("Five server-owned records committed in one atomic transaction.", true)
	elif result.get("reason_code", "") == "RECORD_ALREADY_EXISTS":
		_set_status("Fixture already exists; its durable records were left intact.", true)
	else:
		_set_status("Initialize rejected: %s" % result.get("reason_code", "UNKNOWN"), false)
	_refresh_records()
	return result


func grant_or_replay_reward() -> Dictionary:
	var result := _coordinator.grant_personal_reward(
		ENTITLEMENT_ID, CHARACTER_ID, ITEM_ID, 1
	) as Dictionary
	if result.get("accepted", false):
		_set_status(
			"Reward replayed without duplication."
			if result.get("replayed", false)
			else "Inventory + outcome committed together exactly once.",
			true
		)
	else:
		_set_status("Reward rejected: %s" % result.get("reason_code", "UNKNOWN"), false)
	_refresh_records()
	return result


func simulate_restart() -> bool:
	var opened := _compose("Process reconstructed from disk; no in-memory state was reused.")
	_refresh_records()
	return opened


func create_backup() -> Dictionary:
	_backup_sequence += 1
	_last_backup_id = "%s%03d" % [BACKUP_ID_PREFIX, _backup_sequence]
	var result := _backend.call("create_backup", _last_backup_id, 3) as Dictionary
	_set_status(
		"Consistent backup created: %s" % _last_backup_id
		if result.get("accepted", false)
		else "Backup rejected: %s" % result.get("reason_code", "UNKNOWN"),
		result.get("accepted", false)
	)
	_refresh_records()
	return result


func restore_last_backup() -> Dictionary:
	if _last_backup_id.is_empty():
		var missing := {"accepted": false, "reason_code": "NO_BACKUP"}
		_set_status("Create a backup before restoring.", false)
		return missing
	var result := _backend.call("restore_backup", _last_backup_id) as Dictionary
	_set_status(
		"Validated backup restored."
		if result.get("accepted", false)
		else "Restore rejected: %s" % result.get("reason_code", "UNKNOWN"),
		result.get("accepted", false)
	)
	_refresh_records()
	return result


func simulate_failed_save() -> Dictionary:
	_backend.call("fail_next_commit_for_test")
	var result := _coordinator.grant_personal_reward(
		"development.entitlement.persistence_sandbox.failed",
		CHARACTER_ID,
		ITEM_ID,
		5
	) as Dictionary
	_set_status(
		"Injected failure rejected before acknowledgement; inventory stayed unchanged."
		if not result.get("accepted", false)
		else "Unexpected: injected write was acknowledged.",
		not result.get("accepted", false)
	)
	_refresh_records()
	return result


func get_quantity_for_test() -> int:
	if _coordinator == null:
		return 0
	var repository := _coordinator.get_repository("inventories") as RefCounted
	var loaded := repository.call("load", CHARACTER_ID) as Dictionary
	if not loaded.get("found", false):
		return 0
	var payload := (loaded.record as Dictionary).payload as Dictionary
	return int((payload.get("stacks", {}) as Dictionary).get(ITEM_ID, 0))


func get_status_text_for_test() -> String:
	return _status_label.text


func _compose(message: String) -> bool:
	_backend = Backend.new()
	if not _backend.call("configure", data_root) or not _backend.call("initialize_storage"):
		_set_status("Storage could not open; maintenance mode is active.", false)
		return false
	_coordinator = Coordinator.new()
	if not _coordinator.call("configure", _backend):
		_set_status("Repository composition failed.", false)
		return false
	_sync_backup_state()
	_set_status(message, true)
	_refresh_records()
	return true


func _refresh_records() -> void:
	if _backend == null:
		return
	var inventory := _backend.call("load_record", "inventories", CHARACTER_ID) as Dictionary
	var outcome := _backend.call("load_record", "outcomes", ENTITLEMENT_ID) as Dictionary
	var inventory_revision := 0
	if inventory.get("found", false):
		inventory_revision = int((inventory.record as Dictionary).record_revision)
	_records_label.text = (
		"Save schema: %d\nInventory revision: %d\nEdenite quantity: %d\n"
		+ "Reward entitlement: %s\nBackups retained: %d\nMaintenance mode: %s"
	) % [
		int(_backend.call("get_schema_version")),
		inventory_revision,
		get_quantity_for_test(),
		"COMMITTED" if outcome.get("found", false) else "NOT COMMITTED",
		(_backend.call("get_backup_ids") as Array).size(),
		"YES" if _backend.call("is_in_maintenance_mode") else "NO",
	]


func _sync_backup_state() -> void:
	_backup_sequence = 0
	_last_backup_id = ""
	var backup_ids := _backend.call("get_backup_ids") as Array
	for backup_id_value: Variant in backup_ids:
		var backup_id := backup_id_value as String
		if not backup_id.begins_with(BACKUP_ID_PREFIX):
			continue
		var suffix := backup_id.trim_prefix(BACKUP_ID_PREFIX)
		if not suffix.is_valid_int():
			continue
		var sequence := int(suffix)
		if sequence >= _backup_sequence:
			_backup_sequence = sequence
			_last_backup_id = backup_id


func _set_status(message: String, successful: bool) -> void:
	_status_label.text = message
	_status_label.modulate = Color("8fe3a8") if successful else Color("ff9b8f")
