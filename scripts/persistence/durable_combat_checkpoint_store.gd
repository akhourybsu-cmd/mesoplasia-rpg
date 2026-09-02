class_name DurableCombatCheckpointStore
extends RefCounted

const Repository := preload("res://scripts/persistence/file_record_repository.gd")

var _repository: RefCounted


func configure(backend: RefCounted) -> bool:
	if backend == null or _repository != null:
		return false
	_repository = Repository.new()
	return _repository.call("configure", backend, "combats") as bool


func store_checkpoint(combat_id: String, checkpoint: Dictionary) -> bool:
	if _repository == null or combat_id.is_empty() or checkpoint.is_empty():
		return false
	var instance := checkpoint.get("instance", {}) as Dictionary
	if instance.get("combat_id", "") != combat_id:
		return false
	var loaded := _repository.call("load", combat_id) as Dictionary
	if not loaded.get("accepted", false):
		return false
	var expected_revision := (
		int((loaded.record as Dictionary).record_revision)
		if loaded.get("found", false)
		else -1
	)
	var combat_revision := int(instance.get("revision", 0))
	var result := _repository.call(
		"store",
		combat_id,
		checkpoint,
		expected_revision,
		"checkpoint.combat.%s.%d" % [combat_id, combat_revision]
	) as Dictionary
	return result.get("accepted", false)


func load_checkpoint(combat_id: String) -> Dictionary:
	if _repository == null:
		return {}
	var loaded := _repository.call("load", combat_id) as Dictionary
	if not loaded.get("accepted", false) or not loaded.get("found", false):
		return {}
	return ((loaded.record as Dictionary).payload as Dictionary).duplicate(true)


func remove_checkpoint(combat_id: String) -> bool:
	if _repository == null:
		return false
	var loaded := _repository.call("load", combat_id) as Dictionary
	if not loaded.get("accepted", false) or not loaded.get("found", false):
		return false
	var revision := int((loaded.record as Dictionary).record_revision)
	return (_repository.call(
		"remove", combat_id, revision, "checkpoint.combat.%s.remove.%d" % [combat_id, revision]
	) as Dictionary).get("accepted", false)
