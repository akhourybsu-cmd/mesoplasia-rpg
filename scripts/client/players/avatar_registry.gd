class_name AvatarRegistry
extends Node

signal avatar_registered(character_id: StringName, avatar: Node2D)
signal avatar_unregistered(character_id: StringName)

const CharacterIdentityContract := preload("res://scripts/core/character_identity.gd")

var _avatars_by_character_id: Dictionary[StringName, Node2D] = {}
var _local_character_id: StringName


func register_avatar(avatar: Node2D) -> bool:
	if (
		not is_instance_valid(avatar)
		or not avatar.has_method("get_character_id")
		or not avatar.has_method("is_locally_controlled")
	):
		return false

	var character_id := avatar.call("get_character_id") as StringName
	if not CharacterIdentityContract.is_valid(character_id):
		return false
	if _avatars_by_character_id.has(character_id):
		return false

	var is_local_avatar := avatar.call("is_locally_controlled") as bool
	if is_local_avatar and _local_character_id != &"":
		return false

	_avatars_by_character_id[character_id] = avatar
	if is_local_avatar:
		_local_character_id = character_id
	avatar_registered.emit(character_id, avatar)
	return true


func unregister_avatar(character_id: StringName) -> bool:
	if not _avatars_by_character_id.erase(character_id):
		return false
	if _local_character_id == character_id:
		_local_character_id = &""
	avatar_unregistered.emit(character_id)
	return true


func has_avatar(character_id: StringName) -> bool:
	return _avatars_by_character_id.has(character_id)


func get_avatar(character_id: StringName) -> Node2D:
	var avatar := _avatars_by_character_id.get(character_id) as Node2D
	return avatar if is_instance_valid(avatar) else null


func get_local_avatar() -> Node2D:
	return get_avatar(_local_character_id)


func get_local_character_id() -> StringName:
	return _local_character_id


func get_avatar_count() -> int:
	return _avatars_by_character_id.size()


func get_registered_character_ids() -> Array[StringName]:
	var character_ids: Array[StringName] = []
	character_ids.assign(_avatars_by_character_id.keys())
	character_ids.sort()
	return character_ids
