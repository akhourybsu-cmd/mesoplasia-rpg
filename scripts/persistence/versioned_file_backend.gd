class_name VersionedFileBackend
extends RefCounted

const Codec := preload("res://scripts/persistence/canonical_record_codec.gd")

const CURRENT_SAVE_SCHEMA_VERSION := 1
const DEFAULT_CONTENT_VERSION := "phase-i-persistence-content-1"
const DEFAULT_BACKUP_LIMIT := 5
const MAX_OPERATIONS_PER_TRANSACTION := 32
const RECORD_CATEGORIES := [
	"profiles",
	"characters",
	"worlds",
	"inventories",
	"quests",
	"parties",
	"expeditions",
	"combats",
	"outcomes",
]

var _root_path := ""
var _backup_root_path := ""
var _schema_version := CURRENT_SAVE_SCHEMA_VERSION
var _content_version := DEFAULT_CONTENT_VERSION
var _initialized := false
var _maintenance_mode := false
var _maintenance_reason := ""
var _busy := false
var _fail_next_commit := false
var _interrupt_after_promotions := -1


func configure(
	root_path: String,
	schema_version: int = CURRENT_SAVE_SCHEMA_VERSION,
	content_version: String = DEFAULT_CONTENT_VERSION,
	backup_root_path: String = ""
) -> bool:
	if (
		_initialized
		or not _valid_root_path(root_path)
		or (not backup_root_path.is_empty() and not _valid_root_path(backup_root_path))
		or schema_version < 1
	):
		return false
	_root_path = _normalize_root(root_path)
	_backup_root_path = (
		_normalize_root(backup_root_path)
		if not backup_root_path.is_empty()
		else _path("backups")
	)
	_schema_version = schema_version
	_content_version = content_version.strip_edges()
	return not _content_version.is_empty()


func initialize_storage() -> bool:
	if _root_path.is_empty() or _initialized:
		return false
	for path: String in [
		_root_path,
		_path("records"),
		_path("transactions"),
		_path("staging"),
		_path("rollback"),
		_backup_root_path,
	]:
		if DirAccess.make_dir_recursive_absolute(path) != OK:
			_enter_maintenance("STORAGE_CREATE_FAILED:%s" % path)
			return false
	for category: String in RECORD_CATEGORIES:
		if DirAccess.make_dir_recursive_absolute(_record_category_path(category)) != OK:
			_enter_maintenance("CATEGORY_CREATE_FAILED:%s" % category)
			return false
	_initialized = true
	if not recover_pending_transactions():
		return false
	return validate_live_records()


func is_ready() -> bool:
	return _initialized and not _maintenance_mode


func is_in_maintenance_mode() -> bool:
	return _maintenance_mode


func get_maintenance_reason() -> String:
	return _maintenance_reason


func get_root_path() -> String:
	return _root_path


func get_schema_version() -> int:
	return _schema_version


func load_record(category: String, record_id: String) -> Dictionary:
	var identity_error := _validate_identity(category, record_id)
	if not identity_error.is_empty():
		return _rejected(identity_error)
	if not _initialized:
		return _rejected("NOT_INITIALIZED")
	var record_path := _record_path(category, record_id)
	if not FileAccess.file_exists(record_path):
		return {"accepted": true, "found": false, "record": {}}
	var record := _read_json(record_path)
	var validation := _validate_record(record, category, record_id)
	if validation.is_empty():
		return {"accepted": true, "found": true, "record": record.duplicate(true)}
	var previous_path := _previous_record_path(category, record_id)
	if FileAccess.file_exists(previous_path):
		var previous := _read_json(previous_path)
		if _validate_record(previous, category, record_id).is_empty():
			if _copy_verified(previous_path, record_path):
				return {
					"accepted": true,
					"found": true,
					"record": previous.duplicate(true),
					"recovered_from_previous": true,
				}
	_enter_maintenance("CORRUPT_RECORD:%s:%s:%s" % [category, record_id, validation])
	return _rejected("CORRUPT_RECORD")


func commit_transaction(transaction_id: String, operations: Array) -> Dictionary:
	if not is_ready():
		return _rejected("MAINTENANCE_MODE" if _maintenance_mode else "NOT_INITIALIZED")
	if _busy:
		return _rejected("BACKEND_BUSY")
	if not _valid_identifier(transaction_id):
		return _rejected("INVALID_TRANSACTION_ID")
	var committed_path := _transaction_commit_path(transaction_id)
	if FileAccess.file_exists(committed_path):
		var committed := _read_json(committed_path)
		if Codec.validate_checksum(committed):
			var replayed := committed.duplicate(true)
			replayed["replayed"] = true
			return replayed
		_enter_maintenance("CORRUPT_TRANSACTION_RESULT:%s" % transaction_id)
		return _rejected("CORRUPT_TRANSACTION_RESULT")
	if operations.is_empty() or operations.size() > MAX_OPERATIONS_PER_TRANSACTION:
		return _rejected("INVALID_OPERATION_COUNT")
	if _fail_next_commit:
		_fail_next_commit = false
		return _rejected("PERSISTENCE_WRITE_FAILED")
	_busy = true
	var prepared := _prepare_operations(transaction_id, operations)
	if not prepared.get("accepted", false):
		_cleanup_transaction_workspace(transaction_id)
		_busy = false
		return prepared
	var intent := Codec.sign_record(
		{
			"journal_schema_version": 1,
			"transaction_id": transaction_id,
			"state": "INTENT",
			"operations": prepared.operations,
		}
	)
	if not _write_json_atomic(_transaction_intent_path(transaction_id), intent):
		_cleanup_transaction_workspace(transaction_id)
		_busy = false
		return _rejected("INTENT_WRITE_FAILED")
	var promotion := _promote_prepared_transaction(transaction_id, prepared.operations)
	if not promotion.get("accepted", false):
		if not promotion.get("recovery_required", false):
			_enter_maintenance("TRANSACTION_PROMOTION_FAILED:%s" % transaction_id)
		_busy = false
		return promotion
	var result := Codec.sign_record(
		{
			"accepted": true,
			"reason_code": "OK",
			"transaction_id": transaction_id,
			"replayed": false,
			"records": prepared.results,
		}
	)
	if not _write_json_atomic(committed_path, result):
		_enter_maintenance("TRANSACTION_RESULT_WRITE_FAILED:%s" % transaction_id)
		_busy = false
		return _rejected("TRANSACTION_RESULT_WRITE_FAILED")
	_finalize_transaction_workspace(transaction_id)
	_busy = false
	return result.duplicate(true)


func validate_live_records() -> bool:
	if not _initialized:
		return false
	for category: String in RECORD_CATEGORIES:
		var directory := DirAccess.open(_record_category_path(category))
		if directory == null:
			_enter_maintenance("CATEGORY_OPEN_FAILED:%s" % category)
			return false
		directory.list_dir_begin()
		var filename := directory.get_next()
		while not filename.is_empty():
			if not directory.current_is_dir() and filename.ends_with(".json") and not filename.ends_with(".prev.json"):
				var record_id := filename.trim_suffix(".json")
				var loaded := load_record(category, record_id)
				if not loaded.get("accepted", false):
					directory.list_dir_end()
					return false
			filename = directory.get_next()
		directory.list_dir_end()
	return true


func recover_pending_transactions() -> bool:
	if not _initialized:
		return false
	var directory := DirAccess.open(_path("transactions"))
	if directory == null:
		_enter_maintenance("TRANSACTION_DIRECTORY_OPEN_FAILED")
		return false
	var intent_files: Array[String] = []
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".intent.json"):
			intent_files.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	intent_files.sort()
	for intent_file: String in intent_files:
		var intent := _read_json(_path("transactions/%s" % intent_file))
		if not Codec.validate_checksum(intent):
			_enter_maintenance("CORRUPT_TRANSACTION_INTENT:%s" % intent_file)
			return false
		var transaction_id := intent.get("transaction_id", "") as String
		if not _valid_identifier(transaction_id):
			_enter_maintenance("INVALID_TRANSACTION_INTENT:%s" % intent_file)
			return false
		if FileAccess.file_exists(_transaction_commit_path(transaction_id)):
			_finalize_transaction_workspace(transaction_id)
			continue
		var recovery := _promote_prepared_transaction(
			transaction_id, intent.get("operations", []) as Array, true
		)
		if not recovery.get("accepted", false):
			_enter_maintenance("TRANSACTION_RECOVERY_FAILED:%s" % transaction_id)
			return false
		var results: Array = []
		for operation_value: Variant in intent.get("operations", []):
			var operation := operation_value as Dictionary
			results.append(
				{
					"category": operation.category,
					"record_id": operation.record_id,
					"record_revision": operation.record_revision,
					"deleted": operation.deleted,
				}
			)
		var result := Codec.sign_record(
			{
				"accepted": true,
				"reason_code": "OK",
				"transaction_id": transaction_id,
				"replayed": false,
				"recovered_after_interruption": true,
				"records": results,
			}
		)
		if not _write_json_atomic(_transaction_commit_path(transaction_id), result):
			_enter_maintenance("RECOVERY_RESULT_WRITE_FAILED:%s" % transaction_id)
			return false
		_finalize_transaction_workspace(transaction_id)
	return true


func create_backup(backup_id: String, retain_count: int = DEFAULT_BACKUP_LIMIT) -> Dictionary:
	if not is_ready() or _busy:
		return _rejected("BACKEND_UNAVAILABLE")
	if not _valid_identifier(backup_id) or retain_count < 1:
		return _rejected("INVALID_BACKUP_REQUEST")
	var backup_root := _backup_path(backup_id)
	if DirAccess.dir_exists_absolute(backup_root):
		return _rejected("BACKUP_ALREADY_EXISTS")
	if DirAccess.make_dir_recursive_absolute("%s/records" % backup_root) != OK:
		return _rejected("BACKUP_CREATE_FAILED")
	var entries: Array = []
	for category: String in RECORD_CATEGORIES:
		var source_directory := DirAccess.open(_record_category_path(category))
		var destination_directory := "%s/records/%s" % [backup_root, category]
		DirAccess.make_dir_recursive_absolute(destination_directory)
		source_directory.list_dir_begin()
		var filename := source_directory.get_next()
		while not filename.is_empty():
			if not source_directory.current_is_dir() and filename.ends_with(".json"):
				var source := "%s/%s" % [_record_category_path(category), filename]
				var destination := "%s/%s" % [destination_directory, filename]
				if not _copy_verified(source, destination):
					source_directory.list_dir_end()
					_remove_tree(backup_root)
					return _rejected("BACKUP_COPY_FAILED")
				entries.append(
					{
						"relative_path": "records/%s/%s" % [category, filename],
						"checksum": _file_checksum(source),
					}
				)
			filename = source_directory.get_next()
		source_directory.list_dir_end()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.relative_path < b.relative_path)
	var manifest := Codec.sign_record(
		{
			"backup_schema_version": 1,
			"save_schema_version": _schema_version,
			"content_version": _content_version,
			"backup_id": backup_id,
			"entries": entries,
		}
	)
	if not _write_json_atomic("%s/manifest.json" % backup_root, manifest):
		_remove_tree(backup_root)
		return _rejected("BACKUP_MANIFEST_FAILED")
	_rotate_backups(retain_count)
	return {"accepted": true, "reason_code": "OK", "backup_id": backup_id}


func restore_backup(backup_id: String) -> Dictionary:
	if not is_ready() or _busy or not _valid_identifier(backup_id):
		return _rejected("BACKEND_UNAVAILABLE")
	var backup_root := _backup_path(backup_id)
	var manifest := _read_json("%s/manifest.json" % backup_root)
	if not Codec.validate_checksum(manifest) or manifest.get("backup_id", "") != backup_id:
		return _rejected("INVALID_BACKUP")
	if int(manifest.get("save_schema_version", 0)) != _schema_version:
		return _rejected("BACKUP_SCHEMA_MISMATCH")
	for entry_value: Variant in manifest.get("entries", []):
		var entry := entry_value as Dictionary
		var relative_path := entry.get("relative_path", "") as String
		if relative_path.contains("..") or not relative_path.begins_with("records/"):
			return _rejected("INVALID_BACKUP_PATH")
		var source := "%s/%s" % [backup_root, relative_path]
		if _file_checksum(source) != entry.get("checksum", ""):
			return _rejected("BACKUP_CHECKSUM_FAILED")
	_busy = true
	for category: String in RECORD_CATEGORIES:
		var live_category := _record_category_path(category)
		if not _clear_directory_files(live_category):
			_busy = false
			_enter_maintenance("BACKUP_RESTORE_CLEAR_FAILED:%s" % category)
			return _rejected("BACKUP_RESTORE_FAILED")
	for entry_value: Variant in manifest.get("entries", []):
		var entry := entry_value as Dictionary
		var relative_path := entry.relative_path as String
		var source := "%s/%s" % [backup_root, relative_path]
		var destination := "%s/%s" % [_root_path, relative_path]
		if not _copy_verified(source, destination):
			_busy = false
			_enter_maintenance("BACKUP_RESTORE_COPY_FAILED:%s" % relative_path)
			return _rejected("BACKUP_RESTORE_FAILED")
	_busy = false
	if not validate_live_records():
		return _rejected("BACKUP_RESTORE_VALIDATION_FAILED")
	return {"accepted": true, "reason_code": "OK", "backup_id": backup_id}


func get_backup_ids() -> Array[String]:
	var result: Array[String] = []
	if not _initialized:
		return result
	var directory := DirAccess.open(_backup_root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir() and _valid_identifier(name):
			result.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func fail_next_commit_for_test() -> void:
	_fail_next_commit = true


func interrupt_after_promotions_for_test(promotion_count: int) -> void:
	_interrupt_after_promotions = promotion_count


func _prepare_operations(transaction_id: String, operations: Array) -> Dictionary:
	var prepared_operations: Array = []
	var results: Array = []
	var seen: Dictionary = {}
	for operation_value: Variant in operations:
		if not operation_value is Dictionary:
			return _rejected("INVALID_OPERATION")
		var operation := operation_value as Dictionary
		var category := operation.get("category", "") as String
		var record_id := operation.get("record_id", "") as String
		var identity_error := _validate_identity(category, record_id)
		if not identity_error.is_empty():
			return _rejected(identity_error)
		var identity := "%s:%s" % [category, record_id]
		if seen.has(identity):
			return _rejected("DUPLICATE_OPERATION")
		seen[identity] = true
		var loaded := load_record(category, record_id)
		if not loaded.get("accepted", false):
			return loaded
		var found := loaded.get("found", false) as bool
		var current := loaded.get("record", {}) as Dictionary
		var current_revision := int(current.get("record_revision", 0)) if found else 0
		var expected_revision := int(operation.get("expected_revision", -999))
		if expected_revision == -1:
			if found:
				return _rejected("RECORD_ALREADY_EXISTS")
		elif expected_revision != current_revision:
			return _rejected("STALE_RECORD_REVISION")
		var deleted := operation.get("delete", false) as bool
		var record_revision := current_revision + 1
		var staged_path := _staged_record_path(transaction_id, category, record_id)
		var live_path := _record_path(category, record_id)
		var rollback_path := _rollback_record_path(transaction_id, category, record_id)
		DirAccess.make_dir_recursive_absolute(staged_path.get_base_dir())
		DirAccess.make_dir_recursive_absolute(rollback_path.get_base_dir())
		if found and not _copy_verified(live_path, rollback_path):
			return _rejected("ROLLBACK_STAGE_FAILED")
		var planned_checksum := ""
		if not deleted:
			var payload := operation.get("payload", {}) as Dictionary
			var extensions := current.get("extensions", {}) as Dictionary
			if operation.has("extensions"):
				extensions = (operation.get("extensions", {}) as Dictionary).duplicate(true)
			var record := Codec.sign_record(
				{
					"save_schema_version": _schema_version,
					"content_version": _content_version,
					"category": category,
					"record_id": record_id,
					"record_revision": record_revision,
					"payload": payload.duplicate(true),
					"extensions": extensions.duplicate(true),
				}
			)
			if not _write_json_atomic(staged_path, record):
				return _rejected("RECORD_STAGE_FAILED")
			planned_checksum = record.checksum
		prepared_operations.append(
			{
				"category": category,
				"record_id": record_id,
				"record_revision": record_revision,
				"deleted": deleted,
				"had_live": found,
				"planned_checksum": planned_checksum,
			}
		)
		results.append(
			{
				"category": category,
				"record_id": record_id,
				"record_revision": record_revision,
				"deleted": deleted,
			}
		)
	return {"accepted": true, "operations": prepared_operations, "results": results}


func _promote_prepared_transaction(
	transaction_id: String, operations: Array, recovering: bool = false
) -> Dictionary:
	var promoted_count := 0
	for operation_value: Variant in operations:
		var operation := operation_value as Dictionary
		var category := operation.category as String
		var record_id := operation.record_id as String
		if not _validate_identity(category, record_id).is_empty():
			return _rejected("INVALID_JOURNAL_OPERATION")
		var live_path := _record_path(category, record_id)
		var staged_path := _staged_record_path(transaction_id, category, record_id)
		var deleted := operation.deleted as bool
		if deleted:
			if FileAccess.file_exists(live_path):
				if DirAccess.remove_absolute(live_path) != OK:
					return _rejected("PROMOTION_DELETE_FAILED")
		else:
			var live := _read_json(live_path) if FileAccess.file_exists(live_path) else {}
			if live.get("checksum", "") != operation.planned_checksum:
				if not FileAccess.file_exists(staged_path):
					return _rejected("MISSING_STAGED_RECORD")
				var previous_path := _previous_record_path(category, record_id)
				if FileAccess.file_exists(live_path):
					DirAccess.remove_absolute(previous_path)
					if not _copy_verified(live_path, previous_path):
						return _rejected("PREVIOUS_RECORD_FAILED")
					if DirAccess.remove_absolute(live_path) != OK:
						return _rejected("LIVE_REPLACE_FAILED")
				if DirAccess.rename_absolute(staged_path, live_path) != OK:
					return _rejected("LIVE_PROMOTION_FAILED")
		promoted_count += 1
		if not recovering and _interrupt_after_promotions == promoted_count:
			_interrupt_after_promotions = -1
			return {
				"accepted": false,
				"reason_code": "SIMULATED_INTERRUPTION",
				"recovery_required": true,
			}
	return {"accepted": true, "reason_code": "OK"}


func _validate_record(record: Dictionary, category: String, record_id: String) -> String:
	if record.is_empty() or not Codec.validate_checksum(record):
		return "CHECKSUM"
	var schema := int(record.get("save_schema_version", 0))
	if schema > _schema_version:
		return "FUTURE_SCHEMA"
	if schema < _schema_version:
		return "MIGRATION_REQUIRED"
	if record.get("category", "") != category or record.get("record_id", "") != record_id:
		return "IDENTITY"
	if int(record.get("record_revision", 0)) < 1:
		return "REVISION"
	if not record.get("payload", {}) is Dictionary or not record.get("extensions", {}) is Dictionary:
		return "SHAPE"
	return ""


func _validate_identity(category: String, record_id: String) -> String:
	if not RECORD_CATEGORIES.has(category):
		return "INVALID_CATEGORY"
	if not _valid_identifier(record_id):
		return "INVALID_RECORD_ID"
	return ""


func _valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for character: String in value:
		if not (
			character >= "a" and character <= "z"
			or character >= "A" and character <= "Z"
			or character >= "0" and character <= "9"
			or character in [".", "_", "-"]
		):
			return false
	return not value in [".", ".."]


func _valid_root_path(root_path: String) -> bool:
	var candidate := root_path.strip_edges().replace("\\", "/")
	if candidate.is_empty() or candidate.contains("/../") or candidate.ends_with("/.."):
		return false
	var absolute := ProjectSettings.globalize_path(candidate).replace("\\", "/")
	if absolute in ["/", ""] or absolute.length() < 4:
		return false
	if absolute.length() == 3 and absolute[1] == ":":
		return false
	return true


func _normalize_root(root_path: String) -> String:
	return ProjectSettings.globalize_path(root_path.strip_edges()).replace("\\", "/").trim_suffix("/")


func _path(relative_path: String) -> String:
	return "%s/%s" % [_root_path, relative_path]


func _backup_path(backup_id: String) -> String:
	return "%s/%s" % [_backup_root_path, backup_id]


func _record_category_path(category: String) -> String:
	return _path("records/%s" % category)


func _record_path(category: String, record_id: String) -> String:
	return "%s/%s.json" % [_record_category_path(category), record_id]


func _previous_record_path(category: String, record_id: String) -> String:
	return "%s/%s.prev.json" % [_record_category_path(category), record_id]


func _transaction_intent_path(transaction_id: String) -> String:
	return _path("transactions/%s.intent.json" % transaction_id)


func _transaction_commit_path(transaction_id: String) -> String:
	return _path("transactions/%s.commit.json" % transaction_id)


func _staged_record_path(transaction_id: String, category: String, record_id: String) -> String:
	return _path("staging/%s/%s/%s.json" % [transaction_id, category, record_id])


func _rollback_record_path(transaction_id: String, category: String, record_id: String) -> String:
	return _path("rollback/%s/%s/%s.json" % [transaction_id, category, record_id])


func _write_json_atomic(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		push_warning("Persistence write could not create %s" % path.get_base_dir())
		return false
	var temporary_path := "%s.write_tmp" % path
	DirAccess.remove_absolute(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Persistence write could not open %s" % temporary_path)
		return false
	file.store_string(Codec.stringify(value))
	file.flush()
	file = null
	var reread := _read_json(temporary_path)
	if reread.is_empty() or Codec.stringify(reread) != Codec.stringify(value):
		push_warning("Persistence write verification failed for %s: %s != %s" % [temporary_path, Codec.stringify(reread), Codec.stringify(value)])
		DirAccess.remove_absolute(temporary_path)
		return false
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		push_warning("Persistence write could not replace %s" % path)
		DirAccess.remove_absolute(temporary_path)
		return false
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		push_warning("Persistence write could not promote %s to %s: %s" % [temporary_path, path, error_string(rename_error)])
	return rename_error == OK


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file = null
	return Codec.parse(text)


func _copy_verified(source: String, destination: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(destination)
	if DirAccess.copy_absolute(source, destination) != OK:
		return false
	return _file_checksum(source) == _file_checksum(destination)


func _file_checksum(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var checksum := file.get_as_text().sha256_text()
	file = null
	return checksum


func _finalize_transaction_workspace(transaction_id: String) -> void:
	DirAccess.remove_absolute(_transaction_intent_path(transaction_id))
	_remove_tree(_path("staging/%s" % transaction_id))
	_remove_tree(_path("rollback/%s" % transaction_id))


func _cleanup_transaction_workspace(transaction_id: String) -> void:
	_remove_tree(_path("staging/%s" % transaction_id))
	_remove_tree(_path("rollback/%s" % transaction_id))


func _remove_tree(path: String) -> bool:
	if not _path_is_scoped(path) or not DirAccess.dir_exists_absolute(path):
		return not DirAccess.dir_exists_absolute(path)
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := "%s/%s" % [path, name]
		if directory.current_is_dir():
			if not _remove_tree(child):
				directory.list_dir_end()
				return false
		elif DirAccess.remove_absolute(child) != OK:
			directory.list_dir_end()
			return false
		name = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(path) == OK


func _clear_directory_files(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := "%s/%s" % [path, name]
		if directory.current_is_dir():
			if not _remove_tree(child):
				directory.list_dir_end()
				return false
		elif DirAccess.remove_absolute(child) != OK:
			directory.list_dir_end()
			return false
		name = directory.get_next()
	directory.list_dir_end()
	return true


func _rotate_backups(retain_count: int) -> void:
	var backups := get_backup_ids()
	while backups.size() > retain_count:
		_remove_tree(_backup_path(backups.pop_front()))


func _path_is_scoped(path: String) -> bool:
	return path.begins_with(_root_path + "/") or path.begins_with(_backup_root_path + "/")


func _enter_maintenance(reason: String) -> void:
	_maintenance_mode = true
	_maintenance_reason = reason


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
