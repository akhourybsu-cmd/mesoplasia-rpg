extends SceneTree

const Backend := preload("res://scripts/persistence/versioned_file_backend.gd")
const Coordinator := preload("res://scripts/persistence/server_persistence_coordinator.gd")
const MigrationRunner := preload("res://scripts/persistence/migration_runner.gd")
const Codec := preload("res://scripts/persistence/canonical_record_codec.gd")
const CombatStore := preload("res://scripts/persistence/durable_combat_checkpoint_store.gd")
const ExpeditionStore := preload("res://scripts/persistence/durable_expedition_checkpoint_store.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")
const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")

const TEST_ROOT := "res://tests/.phase_i_durable_restart_test"
const ACCOUNT_ID := "development.account.restart"
const CHARACTER_ID := "development.character.restart"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	var backend := _new_backend()
	if backend == null:
		_fail("Persistence backend did not initialize.")
		return
	var coordinator := Coordinator.new()
	if not coordinator.configure(backend):
		_fail("Server persistence coordinator did not configure.")
		return
	var bootstrap := coordinator.initialize_fresh_server(
		ACCOUNT_ID, CHARACTER_ID, "development.world.restart", "Restart Tester"
	) as Dictionary
	if not bootstrap.get("accepted", false):
		_fail("Fresh server records did not commit atomically: %s" % bootstrap)
		return
	var reward := coordinator.grant_personal_reward(
		"development.entitlement.first", CHARACTER_ID, "development.item.edenite", 3
	) as Dictionary
	if not reward.get("accepted", false) or reward.get("resulting_quantity", 0) != 3:
		_fail("Initial reward transaction did not commit exactly once: %s" % reward)
		return

	backend = null
	coordinator = null
	var restarted := _new_backend()
	var restarted_coordinator := Coordinator.new()
	if restarted == null or not restarted_coordinator.configure(restarted):
		_fail("Restarted persistence composition did not initialize.")
		return
	var replay := restarted_coordinator.grant_personal_reward(
		"development.entitlement.first", CHARACTER_ID, "development.item.edenite", 3
	) as Dictionary
	if not replay.get("accepted", false) or not replay.get("replayed", false):
		_fail("Reward entitlement did not replay its original durable result.")
		return
	var inventory_before_failure := _inventory_quantity(restarted_coordinator, "development.item.edenite")
	restarted.fail_next_commit_for_test()
	var failed_reward := restarted_coordinator.grant_personal_reward(
		"development.entitlement.failed", CHARACTER_ID, "development.item.edenite", 5
	) as Dictionary
	if failed_reward.get("accepted", false):
		_fail("Injected write failure was acknowledged as a reward success.")
		return
	if _inventory_quantity(restarted_coordinator, "development.item.edenite") != inventory_before_failure:
		_fail("Failed reward partially changed the inventory.")
		return
	if (restarted.load_record("outcomes", "development.entitlement.failed") as Dictionary).get("found", false):
		_fail("Failed reward left an entitlement outcome behind.")
		return

	if not _test_combat_checkpoint(restarted):
		return
	if not _test_expedition_checkpoint(restarted):
		return
	if not _test_migrations():
		return
	if not _test_backup_rotation_and_previous_recovery(restarted):
		return

	_cleanup()
	print("PASS: Phase I restart-safe rewards, durable combat checkpoints, migrations, backup rotation, and previous-record recovery.")
	quit(0)


func _test_combat_checkpoint(backend: RefCounted) -> bool:
	var store := CombatStore.new()
	if not store.configure(backend):
		_fail("Durable combat checkpoint repository did not configure.")
		return false
	var registry := Registry.new()
	var service := CombatService.new()
	if not service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 10000, 32):
		_fail("Combat service fixture did not configure.")
		return false
	var hero := registry.instantiate_combatant(
		"development.combatant.vanguard", "development.combatant.restart.hero", CHARACTER_ID
	) as Dictionary
	var enemy := registry.instantiate_combatant(
		"development.combatant.venom_slime", "development.combatant.restart.enemy"
	) as Dictionary
	var created := service.create_combat(3901, [hero, enemy], 1000) as Dictionary
	if not created.get("accepted", false):
		_fail("Combat checkpoint fixture did not start.")
		return false
	var combat_id := created.combat_id as String
	var checkpoint := service.serialize_checkpoint(combat_id) as Dictionary
	if not store.store_checkpoint(combat_id, checkpoint):
		_fail("Combat checkpoint was not durably stored.")
		return false
	var round_tripped := JSON.parse_string(JSON.stringify(store.load_checkpoint(combat_id))) as Dictionary
	var restored_service := CombatService.new()
	restored_service.configure(registry, SpatialRules.new(), EnemyPolicy.new(), 10000, 32)
	var restored := restored_service.restore_checkpoint(round_tripped) as Dictionary
	if not restored.get("accepted", false):
		_fail("Combat checkpoint did not restore after a JSON/file round trip: %s" % restored)
		return false
	if (restored_service.get_snapshot(combat_id) as Dictionary).get("revision", -1) != checkpoint.instance.revision:
		_fail("Restored combat revision did not match the acknowledged checkpoint.")
		return false
	return true


func _test_expedition_checkpoint(backend: RefCounted) -> bool:
	var store := ExpeditionStore.new()
	if not store.configure(backend):
		_fail("Durable expedition checkpoint repository did not configure.")
		return false
	var checkpoint := {
		"checkpoint_schema_version": 1,
		"checkpoint_revision": 4,
		"expedition_id": "development.expedition.restart",
		"definition_id": "development.expedition.test_depths",
		"party_id": "development.party.restart",
		"state": "ACTIVE",
		"current_room_id": "development.room.threshold",
		"member_character_ids": [CHARACTER_ID],
		"completed_encounter_ids": [],
	}
	if not store.store_checkpoint(checkpoint):
		_fail("Active expedition checkpoint was not durably stored.")
		return false
	var restarted_store := ExpeditionStore.new()
	restarted_store.configure(backend)
	var loaded := restarted_store.load_checkpoint("development.expedition.restart") as Dictionary
	if (
		loaded.get("state", "") != "ACTIVE"
		or loaded.get("current_room_id", "") != "development.room.threshold"
		or not Codec.validate_checksum(loaded)
	):
		_fail("Active expedition checkpoint did not survive repository reconstruction.")
		return false
	return true


func _test_migrations() -> bool:
	var runner := MigrationRunner.new()
	var legacy := {
		"save_schema_version": 0,
		"record_type": "profiles",
		"id": "development.account.legacy",
		"revision": 1,
		"data": {"display_label": "Legacy"},
		"old_plugin_field": {"kept": true},
	}
	var migrated_set := runner.migrate_record_set(
		[legacy], "phase-i-persistence-content-1", "development.backup.pre_migration"
	) as Dictionary
	if not migrated_set.get("accepted", false):
		_fail("Supported schema migration failed: %s" % migrated_set)
		return false
	var migrated := (migrated_set.records as Array)[0] as Dictionary
	var unknown := (migrated.extensions as Dictionary).get("legacy_unknown_fields", {}) as Dictionary
	if (
		int(migrated.save_schema_version) != 1
		or not Codec.validate_checksum(migrated)
		or not (unknown.get("old_plugin_field", {}) as Dictionary).get("kept", false)
		or not Codec.validate_checksum(migrated_set.pre_migration_backup as Dictionary)
	):
		_fail("Migration did not preserve unknown data and a signed pre-migration backup.")
		return false
	var future := Codec.sign_record(
		{
			"save_schema_version": 2,
			"content_version": "future",
			"category": "profiles",
			"record_id": "development.account.future",
			"record_revision": 1,
			"payload": {},
			"extensions": {},
		}
	)
	if (runner.plan(future) as Dictionary).get("reason_code", "") != "DOWNGRADE_REFUSED":
		_fail("Migration runner did not refuse a future-schema downgrade.")
		return false
	return true


func _test_backup_rotation_and_previous_recovery(backend: RefCounted) -> bool:
	for backup_id: String in ["development.backup.101", "development.backup.102", "development.backup.103"]:
		if not (backend.create_backup(backup_id, 2) as Dictionary).get("accepted", false):
			_fail("Backup fixture failed for %s." % backup_id)
			return false
	var backup_ids := backend.get_backup_ids() as Array
	if backup_ids != ["development.backup.102", "development.backup.103"]:
		_fail("Backup retention did not rotate deterministically: %s" % [backup_ids])
		return false
	var profiles := backend.load_record("profiles", ACCOUNT_ID) as Dictionary
	var record := profiles.record as Dictionary
	var update := backend.commit_transaction(
		"development.tx.profile.previous",
		[{
			"category": "profiles",
			"record_id": ACCOUNT_ID,
			"expected_revision": int(record.record_revision),
			"payload": {"display_label": "New Label", "character_ids": [CHARACTER_ID]},
		}]
	) as Dictionary
	if not update.get("accepted", false):
		_fail("Previous-record recovery fixture did not update.")
		return false
	var live_path := "%s/records/profiles/%s.json" % [backend.get_root_path(), ACCOUNT_ID]
	var corrupt_file := FileAccess.open(live_path, FileAccess.WRITE)
	if corrupt_file == null:
		_fail("Could not create corruption fixture.")
		return false
	corrupt_file.store_string("{corrupt")
	corrupt_file = null
	var recovered := backend.load_record("profiles", ACCOUNT_ID) as Dictionary
	if not recovered.get("accepted", false) or not recovered.get("recovered_from_previous", false):
		_fail("Corrupt live record did not recover from its last valid previous version.")
		return false
	return true


func _new_backend() -> RefCounted:
	var backend := Backend.new()
	if not backend.configure(TEST_ROOT) or not backend.initialize_storage():
		return null
	return backend


func _inventory_quantity(coordinator: RefCounted, item_id: String) -> int:
	var inventory_repository := coordinator.get_repository("inventories") as RefCounted
	var loaded := inventory_repository.call("load", CHARACTER_ID) as Dictionary
	return int(((loaded.record as Dictionary).payload as Dictionary).get("stacks", {}).get(item_id, 0))


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_i_durable_restart_test"):
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
