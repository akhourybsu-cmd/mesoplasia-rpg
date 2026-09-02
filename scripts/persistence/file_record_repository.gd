class_name FileRecordRepository
extends RefCounted

var _backend: RefCounted
var _category := ""


func configure(backend: RefCounted, category: String) -> bool:
	if backend == null or category.is_empty() or _backend != null:
		return false
	_backend = backend
	_category = category
	return true


func load(record_id: String) -> Dictionary:
	if _backend == null:
		return {"accepted": false, "reason_code": "NOT_CONFIGURED"}
	return _backend.call("load_record", _category, record_id) as Dictionary


func store(
	record_id: String,
	payload: Dictionary,
	expected_revision: int,
	transaction_id: String,
	extensions: Dictionary = {}
) -> Dictionary:
	if _backend == null:
		return {"accepted": false, "reason_code": "NOT_CONFIGURED"}
	return _backend.call(
		"commit_transaction",
		transaction_id,
		[
			{
				"category": _category,
				"record_id": record_id,
				"payload": payload.duplicate(true),
				"extensions": extensions.duplicate(true),
				"expected_revision": expected_revision,
			}
		]
	) as Dictionary


func remove(record_id: String, expected_revision: int, transaction_id: String) -> Dictionary:
	if _backend == null:
		return {"accepted": false, "reason_code": "NOT_CONFIGURED"}
	return _backend.call(
		"commit_transaction",
		transaction_id,
		[
			{
				"category": _category,
				"record_id": record_id,
				"expected_revision": expected_revision,
				"delete": true,
			}
		]
	) as Dictionary


func get_category() -> String:
	return _category
