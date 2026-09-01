class_name InMemoryExpeditionCheckpointStore
extends RefCounted

var _checkpoints_by_expedition_id: Dictionary = {}
var _fail_next_write := false


func store_checkpoint(checkpoint: Dictionary) -> bool:
	if _fail_next_write:
		_fail_next_write = false
		return false
	var expedition_id := checkpoint.get("expedition_id", "") as String
	if expedition_id.is_empty() or int(checkpoint.get("checkpoint_schema_version", 0)) != 1:
		return false
	var stored := checkpoint.duplicate(true)
	stored["checksum"] = str(stored).sha256_text()
	_checkpoints_by_expedition_id[expedition_id] = stored
	return true


func load_checkpoint(expedition_id: String) -> Dictionary:
	var checkpoint := _checkpoints_by_expedition_id.get(expedition_id, {}) as Dictionary
	return checkpoint.duplicate(true) if not checkpoint.is_empty() else {}


func remove_checkpoint(expedition_id: String) -> bool:
	return _checkpoints_by_expedition_id.erase(expedition_id)


func get_checkpoint_count() -> int:
	return _checkpoints_by_expedition_id.size()


func fail_next_write_for_test() -> void:
	_fail_next_write = true
