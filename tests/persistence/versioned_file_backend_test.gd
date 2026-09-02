extends SceneTree

const Backend := preload("res://scripts/persistence/versioned_file_backend.gd")
const Repository := preload("res://scripts/persistence/file_record_repository.gd")

const TEST_ROOT := "res://tests/.phase_i_backend_test"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_cleanup()
	var backend := Backend.new()
	if not backend.configure(TEST_ROOT) or not backend.initialize_storage():
		_fail("Versioned file backend could not initialize its isolated root.")
		return
	var profiles := Repository.new()
	profiles.configure(backend, "profiles")
	var created := profiles.store(
		"development.account.1",
		{"display_label": "Alex", "admin": false},
		-1,
		"development.tx.profile.create"
	) as Dictionary
	if not created.get("accepted", false):
		_fail("Profile repository could not create a versioned record: %s" % created)
		return
	var loaded := profiles.load("development.account.1") as Dictionary
	var profile_record := loaded.get("record", {}) as Dictionary
	if (
		not loaded.get("found", false)
		or profile_record.get("record_revision", 0) != 1
		or (profile_record.get("payload", {}) as Dictionary).get("display_label", "") != "Alex"
		or profile_record.get("checksum", "").is_empty()
	):
		_fail("Stored profile did not round-trip as a signed schema-v1 record.")
		return
	var replay := profiles.store(
		"development.account.1",
		{"display_label": "Changed by replay"},
		1,
		"development.tx.profile.create"
	) as Dictionary
	if not replay.get("accepted", false) or not replay.get("replayed", false):
		_fail("Committed transaction ID was not replay-safe.")
		return
	if (
		((profiles.load("development.account.1") as Dictionary).record.payload as Dictionary).display_label
		!= "Alex"
	):
		_fail("Transaction replay changed an already committed result.")
		return

	var transaction := backend.commit_transaction(
		"development.tx.multi.create",
		[
			{
				"category": "characters",
				"record_id": "development.character.1",
				"expected_revision": -1,
				"payload": {"owner_account_id": "development.account.1", "safe_zone": "wayfarers_approach"},
			},
			{
				"category": "worlds",
				"record_id": "development.world.1",
				"expected_revision": -1,
				"payload": {"flags": {"development.fixture": true}},
			},
		]
	) as Dictionary
	if not transaction.get("accepted", false):
		_fail("Two-record transaction did not commit: %s" % transaction)
		return
	var stale := backend.commit_transaction(
		"development.tx.multi.stale",
		[
			{
				"category": "characters",
				"record_id": "development.character.1",
				"expected_revision": 0,
				"payload": {"safe_zone": "invalid"},
			},
			{
				"category": "worlds",
				"record_id": "development.world.1",
				"expected_revision": 1,
				"payload": {"flags": {}},
			},
		]
	) as Dictionary
	if stale.get("reason_code", "") != "STALE_RECORD_REVISION":
		_fail("A stale record did not reject the complete transaction.")
		return
	if (
		((backend.load_record("worlds", "development.world.1") as Dictionary).record.payload as Dictionary).flags
		!= {"development.fixture": true}
	):
		_fail("Rejected multi-record transaction partially mutated another record.")
		return

	backend.interrupt_after_promotions_for_test(1)
	var interrupted := backend.commit_transaction(
		"development.tx.interrupted",
		[
			{
				"category": "characters",
				"record_id": "development.character.1",
				"expected_revision": 1,
				"payload": {"owner_account_id": "development.account.1", "safe_zone": "town_square"},
			},
			{
				"category": "worlds",
				"record_id": "development.world.1",
				"expected_revision": 1,
				"payload": {"flags": {"development.fixture": true, "recovered": true}},
			},
		]
	) as Dictionary
	if interrupted.get("reason_code", "") != "SIMULATED_INTERRUPTION":
		_fail("Interrupted promotion fixture did not leave a recovery journal.")
		return
	backend = null
	var restarted := Backend.new()
	if not restarted.configure(TEST_ROOT) or not restarted.initialize_storage():
		_fail("Restart did not recover the interrupted transaction journal.")
		return
	var recovered_character := restarted.load_record(
		"characters", "development.character.1"
	) as Dictionary
	var recovered_world := restarted.load_record("worlds", "development.world.1") as Dictionary
	if (
		(recovered_character.record.payload as Dictionary).safe_zone != "town_square"
		or not (recovered_world.record.payload as Dictionary).flags.get("recovered", false)
	):
		_fail("Restart did not complete every operation in the interrupted transaction.")
		return
	var recovered_result := restarted.commit_transaction(
		"development.tx.interrupted",
		[
			{
				"category": "characters",
				"record_id": "development.character.1",
				"expected_revision": 2,
				"payload": {},
			}
		]
	) as Dictionary
	if not recovered_result.get("replayed", false):
		_fail("Recovered transaction did not retain its durable idempotency result.")
		return

	if not (restarted.create_backup("development.backup.001", 2) as Dictionary).get("accepted", false):
		_fail("Consistent backup creation failed.")
		return
	var profile_update := restarted.commit_transaction(
		"development.tx.profile.update",
		[
			{
				"category": "profiles",
				"record_id": "development.account.1",
				"expected_revision": 1,
				"payload": {"display_label": "After Backup", "admin": false},
			}
		]
	) as Dictionary
	if not profile_update.get("accepted", false):
		_fail("Post-backup mutation failed.")
		return
	if not (restarted.restore_backup("development.backup.001") as Dictionary).get("accepted", false):
		_fail("Validated backup restore failed.")
		return
	if (
		((restarted.load_record("profiles", "development.account.1") as Dictionary).record.payload as Dictionary).display_label
		!= "Alex"
	):
		_fail("Backup restore did not restore the consistent pre-mutation snapshot.")
		return

	var invalid_path := restarted.load_record("profiles", "../../outside") as Dictionary
	if invalid_path.get("reason_code", "") != "INVALID_RECORD_ID":
		_fail("Repository path traversal was not rejected.")
		return
	restarted.fail_next_commit_for_test()
	if (
		(restarted.commit_transaction(
			"development.tx.failed",
			[
				{
					"category": "quests",
					"record_id": "development.quest.1",
					"expected_revision": -1,
					"payload": {"state": "COMPLETE"},
				}
			]
		) as Dictionary).get("reason_code", "")
		!= "PERSISTENCE_WRITE_FAILED"
	):
		_fail("Injected persistence failure was not reported before acknowledgement.")
		return
	if (restarted.load_record("quests", "development.quest.1") as Dictionary).get("found", false):
		_fail("Failed transaction left a durable record behind.")
		return

	_cleanup()
	print("PASS: Phase I versioned files, canonical checksums, revisions, idempotent transactions, interrupted-journal recovery, backups, path guards, and failed-write atomicity.")
	quit(0)


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT).replace("\\", "/")
	if absolute.ends_with("/tests/.phase_i_backend_test"):
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
