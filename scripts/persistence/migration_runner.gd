class_name PersistenceMigrationRunner
extends RefCounted

const Codec := preload("res://scripts/persistence/canonical_record_codec.gd")

const TARGET_SCHEMA_VERSION := 1


func plan(record: Dictionary, target_schema_version: int = TARGET_SCHEMA_VERSION) -> Dictionary:
	var source_schema := int(record.get("save_schema_version", 0))
	if source_schema > target_schema_version:
		return _rejected("DOWNGRADE_REFUSED")
	if target_schema_version != TARGET_SCHEMA_VERSION:
		return _rejected("UNSUPPORTED_TARGET_SCHEMA")
	if source_schema == target_schema_version:
		if not Codec.validate_checksum(record):
			return _rejected("CURRENT_RECORD_CHECKSUM")
		return {"accepted": true, "steps": [], "source_schema": source_schema, "target_schema": target_schema_version}
	if source_schema == 0:
		return {
			"accepted": true,
			"steps": ["phase_i.legacy_record.0_to_1"],
			"source_schema": 0,
			"target_schema": 1,
		}
	return _rejected("MIGRATION_PATH_MISSING")


func migrate_record(
	record: Dictionary,
	default_content_version: String,
	target_schema_version: int = TARGET_SCHEMA_VERSION
) -> Dictionary:
	var migration_plan := plan(record, target_schema_version)
	if not migration_plan.get("accepted", false):
		return migration_plan
	if (migration_plan.steps as Array).is_empty():
		return {"accepted": true, "record": record.duplicate(true), "migration_history": []}
	var category := record.get("category", record.get("record_type", "")) as String
	var record_id := record.get("record_id", record.get("id", "")) as String
	var record_revision := int(record.get("record_revision", record.get("revision", 0)))
	var payload := record.get("payload", record.get("data", {})) as Dictionary
	if category.is_empty() or record_id.is_empty() or record_revision < 1:
		return _rejected("INVALID_LEGACY_RECORD")
	var recognized := [
		"save_schema_version",
		"content_version",
		"category",
		"record_type",
		"record_id",
		"id",
		"record_revision",
		"revision",
		"payload",
		"data",
		"extensions",
		"checksum",
	]
	var legacy_unknown: Dictionary = {}
	for key: Variant in record:
		if not recognized.has(key):
			legacy_unknown[key] = record[key]
	var extensions := (record.get("extensions", {}) as Dictionary).duplicate(true)
	if not legacy_unknown.is_empty():
		extensions["legacy_unknown_fields"] = legacy_unknown
	var migrated := Codec.sign_record(
		{
			"save_schema_version": 1,
			"content_version": record.get("content_version", default_content_version),
			"category": category,
			"record_id": record_id,
			"record_revision": record_revision,
			"payload": payload.duplicate(true),
			"extensions": extensions,
		}
	)
	return {
		"accepted": true,
		"record": migrated,
		"migration_history": [
			{
				"migration_id": "phase_i.legacy_record.0_to_1",
				"from_schema": 0,
				"to_schema": 1,
			}
		],
	}


func migrate_record_set(
	records: Array,
	default_content_version: String,
	backup_id: String,
	target_schema_version: int = TARGET_SCHEMA_VERSION
) -> Dictionary:
	if records.is_empty() or backup_id.is_empty():
		return _rejected("INVALID_MIGRATION_SET")
	var plans: Array = []
	for record_value: Variant in records:
		if not record_value is Dictionary:
			return _rejected("INVALID_MIGRATION_RECORD")
		var migration_plan := plan(record_value as Dictionary, target_schema_version)
		if not migration_plan.get("accepted", false):
			return migration_plan
		plans.append(migration_plan)
	var pre_migration_backup := Codec.sign_record(
		{
			"backup_schema_version": 1,
			"backup_id": backup_id,
			"target_save_schema_version": target_schema_version,
			"records": records.duplicate(true),
		}
	)
	var migrated_records: Array = []
	var migration_history: Array = []
	for record_value: Variant in records:
		var migrated := migrate_record(
			record_value as Dictionary, default_content_version, target_schema_version
		)
		if not migrated.get("accepted", false):
			return migrated
		migrated_records.append((migrated.record as Dictionary).duplicate(true))
		migration_history.append_array(migrated.migration_history as Array)
	return {
		"accepted": true,
		"pre_migration_backup": pre_migration_backup,
		"records": migrated_records,
		"migration_history": migration_history,
		"plans": plans,
	}


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
