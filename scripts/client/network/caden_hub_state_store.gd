class_name CadenHubStateStore
extends RefCounted

signal snapshot_applied(snapshot: Dictionary)
signal zone_changed(zone_id: String)

var _local_character_id := ""
var _snapshot: Dictionary = {}
var _world_revision := -1
var _server_tick := -1


func set_local_character_id(character_id: String) -> void:
	_local_character_id = character_id
	for avatar: Variant in _snapshot.get("avatars", []):
		(avatar as Dictionary).is_local = (avatar as Dictionary).character_id == _local_character_id


func apply_snapshot(payload: Dictionary) -> bool:
	if (
		int(payload.get("snapshot_schema_version", 0)) != 1
		or (payload.get("zone_id", "") as String).is_empty()
	):
		return false
	var revision := int(payload.get("world_revision", -1))
	var tick := int(payload.get("server_tick", -1))
	if revision < _world_revision or (revision == _world_revision and tick <= _server_tick):
		return false
	var previous_zone := _snapshot.get("zone_id", "") as String
	var normalized_avatars: Array = []
	for value: Variant in payload.get("avatars", []):
		if not value is Array or (value as Array).size() != 7:
			return false
		var compact := value as Array
		normalized_avatars.append(
			{
				"character_id": compact[0],
				"position_x": compact[1],
				"position_y": compact[2],
				"velocity_x": compact[3],
				"velocity_y": compact[4],
				"facing_x": compact[5],
				"facing_y": compact[6],
			}
		)
	var normalized_npcs: Array = []
	for value: Variant in payload.get("npcs", []):
		if not value is Array or (value as Array).size() != 7:
			return false
		var compact := value as Array
		normalized_npcs.append(
			{
				"npc_id": compact[0],
				"position_x": compact[1],
				"position_y": compact[2],
				"velocity_x": compact[3],
				"velocity_y": compact[4],
				"facing_x": compact[5],
				"facing_y": compact[6],
			}
		)
	_snapshot = {
		"snapshot_schema_version": 1,
		"zone_id": payload.zone_id,
		"world_revision": revision,
		"server_tick": tick,
		"avatars": normalized_avatars,
		"npcs": normalized_npcs,
	}
	_world_revision = revision
	_server_tick = tick
	for avatar: Variant in _snapshot.avatars:
		(avatar as Dictionary).is_local = (avatar as Dictionary).character_id == _local_character_id
	var new_zone := _snapshot.zone_id as String
	if new_zone != previous_zone:
		zone_changed.emit(new_zone)
	snapshot_applied.emit(_snapshot.duplicate(true))
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_zone_id() -> String:
	return _snapshot.get("zone_id", "") as String


func get_world_revision() -> int:
	return _world_revision


func clear() -> void:
	_snapshot.clear()
	_local_character_id = ""
	_world_revision = -1
	_server_tick = -1
