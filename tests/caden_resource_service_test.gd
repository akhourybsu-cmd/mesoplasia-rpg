extends SceneTree

const Backend := preload("res://scripts/persistence/versioned_file_backend.gd")
const PersistenceCoordinator := preload(
	"res://scripts/persistence/server_persistence_coordinator.gd"
)
const Registry := preload(
	"res://scripts/server/caden/caden_resource_definition_registry.gd"
)
const ResourceService := preload("res://scripts/server/caden/caden_resource_service.gd")
const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")
const ClientStore := preload(
	"res://scripts/client/network/caden_resource_state_store.gd"
)

const TEST_ROOT := "res://tests/.phase_k_resource_service_test"
const ACCOUNT_ID := "development.account.phase_k"
const CHARACTER_ID := "development.character.phase_k"
const WORLD_ID := "world.caden.private"
const RESOURCE_ID := "development.item.edenite"
const PROJECT_ID := "development.project.fortification_probe"
const DEPOSIT_ID := "development.deposit.phase_k.first"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	if not _test_protocol_boundary():
		return
	var composition := _compose()
	if composition.is_empty():
		return
	var backend := composition.backend as RefCounted
	var coordinator := composition.coordinator as RefCounted
	var service := composition.service as RefCounted
	var bootstrap := coordinator.initialize_fresh_server(
		ACCOUNT_ID, CHARACTER_ID, WORLD_ID, "Phase K Tester"
	) as Dictionary
	if not bootstrap.get("accepted", false):
		_fail("Phase K persistence fixture did not initialize: %s" % bootstrap)
		return
	var reward := coordinator.grant_personal_reward(
		"development.entitlement.phase_k.first", CHARACTER_ID, RESOURCE_ID, 1
	) as Dictionary
	if not reward.get("accepted", false):
		_fail("Phase K resource fixture could not be granted: %s" % reward)
		return
	var before := service.get_snapshot_for(CHARACTER_ID) as Dictionary
	if (
		_quantity(before.inventory_resources, RESOURCE_ID) != 1
		or _quantity(before.stockpiles, RESOURCE_ID) != 0
		or _project_state(before.projects, PROJECT_ID) != "AWAITING_RESOURCES"
	):
		_fail("Initial resource/project projection was incorrect: %s" % before)
		return
	var unknown := service.request_deposit(
		CHARACTER_ID,
		"development.deposit.phase_k.unknown",
		"development.item.unknown",
		1,
		before.inventory_record_revision,
		before.world_record_revision
	) as Dictionary
	if unknown.get("reason_code", "") != "UNKNOWN_RESOURCE":
		_fail("Unknown resource deposit was not rejected.")
		return
	var stale := service.request_deposit(
		CHARACTER_ID,
		"development.deposit.phase_k.stale",
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		int(before.world_record_revision) + 1
	) as Dictionary
	if stale.get("reason_code", "") != "STALE_WORLD_REVISION":
		_fail("Stale shared-world revision was not rejected.")
		return
	backend.call("fail_next_commit_for_test")
	var failed := service.request_deposit(
		CHARACTER_ID,
		DEPOSIT_ID,
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		before.world_record_revision
	) as Dictionary
	if failed.get("accepted", false) or failed.get("reason_code", "") != "PERSISTENCE_WRITE_FAILED":
		_fail("Injected deposit persistence failure was acknowledged: %s" % failed)
		return
	var after_failure := service.get_snapshot_for(CHARACTER_ID) as Dictionary
	if (
		_quantity(after_failure.inventory_resources, RESOURCE_ID) != 1
		or _quantity(after_failure.stockpiles, RESOURCE_ID) != 0
		or _project_state(after_failure.projects, PROJECT_ID) != "AWAITING_RESOURCES"
	):
		_fail("Failed deposit partially mutated inventory, stockpile, or project state.")
		return
	var committed := service.request_deposit(
		CHARACTER_ID,
		DEPOSIT_ID,
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		before.world_record_revision
	) as Dictionary
	if (
		not committed.get("accepted", false)
		or committed.get("replayed", true)
		or not (committed.get("changed_project_ids", []) as Array).has(PROJECT_ID)
	):
		_fail("Valid resource deposit did not commit the first project transition: %s" % committed)
		return
	var replay := service.request_deposit(
		CHARACTER_ID,
		DEPOSIT_ID,
		RESOURCE_ID,
		1,
		before.inventory_record_revision,
		before.world_record_revision
	) as Dictionary
	if not replay.get("accepted", false) or not replay.get("replayed", false):
		_fail("Committed deposit did not replay idempotently: %s" % replay)
		return
	var conflict := service.request_deposit(
		CHARACTER_ID,
		DEPOSIT_ID,
		RESOURCE_ID,
		2,
		-1,
		-1
	) as Dictionary
	if conflict.get("reason_code", "") != "DEPOSIT_ID_CONFLICT":
		_fail("A reused deposit ID with different intent was not rejected.")
		return
	var after := service.get_snapshot_for(CHARACTER_ID) as Dictionary
	if (
		_quantity(after.inventory_resources, RESOURCE_ID) != 0
		or _quantity(after.stockpiles, RESOURCE_ID) != 1
		or _project_state(after.projects, PROJECT_ID) != "FUNDED"
	):
		_fail("Committed/replayed deposit produced an incorrect durable projection: %s" % after)
		return
	composition.clear()
	var restarted := _compose()
	if restarted.is_empty():
		return
	var recovered := (restarted.service as RefCounted).call(
		"get_snapshot_for", CHARACTER_ID
	) as Dictionary
	if (
		_quantity(recovered.inventory_resources, RESOURCE_ID) != 0
		or _quantity(recovered.stockpiles, RESOURCE_ID) != 1
		or _project_state(recovered.projects, PROJECT_ID) != "FUNDED"
	):
		_fail("Restart did not recover the resource deposit and project state.")
		return
	_cleanup()
	print("PASS: Phase K resource service atomically deposited inventory into Caden, funded the development project, rejected stale/failed/conflicting requests, replayed exactly once, and recovered after restart.")
	quit(0)


func _test_protocol_boundary() -> bool:
	var valid := Protocol.make_client_envelope(
		Protocol.CADEN_RESOURCE_DEPOSIT,
		"development.session.phase_k",
		"development.command.phase_k.deposit",
		1,
		{
			"deposit_id": DEPOSIT_ID,
			"resource_id": RESOURCE_ID,
			"quantity": 1,
			"expected_inventory_revision": 2,
			"expected_world_revision": 1,
		}
	)
	if not (Protocol.validate_client_envelope(valid) as Dictionary).get("valid", false):
		_fail("Valid Phase K protocol deposit did not satisfy the strict schema.")
		return false
	var forged := valid.duplicate(true)
	(forged.payload as Dictionary).replacement_world_state = {"stockpiles": {RESOURCE_ID: 999}}
	if (Protocol.validate_client_envelope(forged) as Dictionary).get("valid", false):
		_fail("Phase K protocol accepted client-submitted replacement world state.")
		return false
	var snapshot := {
		"resource_snapshot_schema_version": 1,
		"projection_revision": 100002,
		"world_id": WORLD_ID,
		"world_record_revision": 1,
		"inventory_record_revision": 2,
		"inventory_resources": [[RESOURCE_ID, 1]],
		"stockpiles": [[RESOURCE_ID, 0]],
		"projects": [[PROJECT_ID, "AWAITING_RESOURCES", 0, 1]],
	}
	var envelope := Protocol.make_server_envelope(
		Protocol.CADEN_RESOURCE_SNAPSHOT, 1, "", snapshot
	)
	if not (Protocol.validate_server_envelope(envelope) as Dictionary).get("valid", false):
		_fail("Valid Phase K resource projection did not satisfy the server schema.")
		return false
	var store := ClientStore.new()
	if not store.apply_snapshot(snapshot) or store.apply_snapshot(snapshot):
		_fail("Phase K client projection did not reject a duplicate revision.")
		return false
	return true


func _compose() -> Dictionary:
	var backend := Backend.new()
	if not backend.configure(TEST_ROOT) or not backend.initialize_storage():
		_fail("Phase K test backend did not initialize.")
		return {}
	var coordinator := PersistenceCoordinator.new()
	if not coordinator.configure(backend):
		_fail("Phase K persistence coordinator did not configure.")
		return {}
	var registry := Registry.new()
	if not registry.is_valid():
		_fail("Phase K definitions were invalid: %s" % registry.get_validation_errors())
		return {}
	var service := ResourceService.new()
	if not service.configure(registry, coordinator, WORLD_ID):
		_fail("Phase K resource service did not configure.")
		return {}
	return {"backend": backend, "coordinator": coordinator, "service": service}


func _quantity(rows: Array, resource_id: String) -> int:
	for value: Variant in rows:
		var row := value as Array
		if row.size() == 2 and row[0] == resource_id:
			return int(row[1])
	return -1


func _project_state(rows: Array, project_id: String) -> String:
	for value: Variant in rows:
		var row := value as Array
		if row.size() == 4 and row[0] == project_id:
			return row[1] as String
	return ""


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_k_resource_service_test"):
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
