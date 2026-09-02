class_name StructuredServerLogger
extends RefCounted

const SENSITIVE_FRAGMENTS := ["password", "access_code", "token", "secret", "challenge"]
const MAX_EVENTS_IN_MEMORY := 128

var _log_path := ""
var _events: Array[Dictionary] = []


func configure(log_directory: String) -> bool:
	if not _log_path.is_empty() or log_directory.strip_edges().is_empty():
		return false
	var normalized := log_directory.replace("\\", "/").trim_suffix("/")
	if DirAccess.make_dir_recursive_absolute(normalized) != OK:
		return false
	_log_path = "%s/server.jsonl" % normalized
	return true


func write(level: String, category: String, event_name: String, fields: Dictionary = {}) -> bool:
	if _log_path.is_empty() or not level in ["ERROR", "WARN", "INFO", "DEBUG"]:
		return false
	var event := {
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"level": level,
		"category": category.left(48),
		"event": event_name.left(64),
		"fields": _redact(fields),
	}
	_events.append(event.duplicate(true))
	while _events.size() > MAX_EVENTS_IN_MEMORY:
		_events.pop_front()
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(event, "", true, true))
	file.flush()
	file = null
	return true


func get_events_for_test() -> Array[Dictionary]:
	return _events.duplicate(true)


func get_log_path() -> String:
	return _log_path


func _redact(value: Variant, key_hint: String = "") -> Variant:
	var lowered := key_hint.to_lower()
	for fragment: String in SENSITIVE_FRAGMENTS:
		if lowered.contains(fragment):
			return "[REDACTED]"
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _redact((value as Dictionary)[key], str(key))
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_redact(entry, key_hint))
		return result
	return value
