class_name NetworkAvatarStore
extends RefCounted

signal avatar_spawned(avatar_snapshot: Dictionary)
signal avatar_despawned(character_id: String, avatar_runtime_id: String, reason: String)

var _local_character_id := ""
var _avatars_by_character_id: Dictionary = {}


func set_local_character_id(character_id: String) -> void:
	_local_character_id = character_id
	for stored_character_id: Variant in _avatars_by_character_id:
		var snapshot := _avatars_by_character_id[stored_character_id] as Dictionary
		snapshot.is_local = stored_character_id == _local_character_id


func apply_spawn(payload: Dictionary) -> bool:
	var character_id := payload.get("character_id", "") as String
	var avatar_runtime_id := payload.get("avatar_runtime_id", "") as String
	var display_label := payload.get("display_label", "") as String
	if character_id.is_empty() or avatar_runtime_id.is_empty() or display_label.is_empty():
		return false
	var snapshot := {
		"character_id": character_id,
		"avatar_runtime_id": avatar_runtime_id,
		"display_label": display_label,
		"is_local": character_id == _local_character_id,
	}
	_avatars_by_character_id[character_id] = snapshot
	avatar_spawned.emit(snapshot.duplicate(true))
	return true


func apply_despawn(payload: Dictionary) -> bool:
	var character_id := payload.get("character_id", "") as String
	var avatar_runtime_id := payload.get("avatar_runtime_id", "") as String
	var reason := payload.get("reason", "") as String
	if not _avatars_by_character_id.has(character_id):
		return false
	var current := _avatars_by_character_id[character_id] as Dictionary
	if current.avatar_runtime_id != avatar_runtime_id:
		return false
	_avatars_by_character_id.erase(character_id)
	avatar_despawned.emit(character_id, avatar_runtime_id, reason)
	return true


func get_avatar(character_id: String) -> Dictionary:
	if not _avatars_by_character_id.has(character_id):
		return {}
	return (_avatars_by_character_id[character_id] as Dictionary).duplicate(true)


func get_avatar_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var character_ids := _avatars_by_character_id.keys()
	character_ids.sort()
	for character_id: Variant in character_ids:
		snapshots.append((_avatars_by_character_id[character_id] as Dictionary).duplicate(true))
	return snapshots


func get_avatar_count() -> int:
	return _avatars_by_character_id.size()


func clear() -> void:
	_avatars_by_character_id.clear()
	_local_character_id = ""
