class_name DurableExpeditionCheckpointStore
extends RefCounted

const Codec := preload("res://scripts/persistence/canonical_record_codec.gd")
const Repository := preload("res://scripts/persistence/file_record_repository.gd")

var _repository: RefCounted


func configure(backend: RefCounted) -> bool:
	if backend == null or _repository != null:
		return false
	_repository = Repository.new()
	return _repository.call("configure", backend, "expeditions") as bool


func store_checkpoint(checkpoint: Dictionary) -> bool:
	if _repository == null:
		return false
	var expedition_id := checkpoint.get("expedition_id", "") as String
	var checkpoint_revision := int(checkpoint.get("checkpoint_revision", 0))
	if expedition_id.is_empty() or int(checkpoint.get("checkpoint_schema_version", 0)) != 1 or checkpoint_revision < 1:
		return false
	var signed_checkpoint := checkpoint.duplicate(true)
	signed_checkpoint.erase("checksum")
	signed_checkpoint = Codec.sign_record(signed_checkpoint)
	var loaded := _repository.call("load", expedition_id) as Dictionary
	if not loaded.get("accepted", false):
		return false
	var expected_revision := (
		int((loaded.record as Dictionary).record_revision)
		if loaded.get("found", false)
		else -1
	)
	var result := _repository.call(
		"store",
		expedition_id,
		signed_checkpoint,
		expected_revision,
		"checkpoint.expedition.%s.%d" % [expedition_id, checkpoint_revision]
	) as Dictionary
	return result.get("accepted", false)


func load_checkpoint(expedition_id: String) -> Dictionary:
	if _repository == null:
		return {}
	var loaded := _repository.call("load", expedition_id) as Dictionary
	if not loaded.get("accepted", false) or not loaded.get("found", false):
		return {}
	var checkpoint := ((loaded.record as Dictionary).payload as Dictionary).duplicate(true)
	return checkpoint if Codec.validate_checksum(checkpoint) else {}


func remove_checkpoint(expedition_id: String) -> bool:
	if _repository == null:
		return false
	var loaded := _repository.call("load", expedition_id) as Dictionary
	if not loaded.get("accepted", false) or not loaded.get("found", false):
		return false
	var revision := int((loaded.record as Dictionary).record_revision)
	var result := _repository.call(
		"remove", expedition_id, revision, "checkpoint.expedition.%s.remove.%d" % [expedition_id, revision]
	) as Dictionary
	return result.get("accepted", false)
