class_name ExpeditionStateStore
extends RefCounted

signal snapshot_applied(snapshot: Dictionary)
signal lifecycle_changed(lifecycle_state: String)

var _snapshot: Dictionary = {}
var _projection_revision := -1


func apply_snapshot(payload: Dictionary) -> bool:
	if int(payload.get("expedition_snapshot_schema_version", 0)) != 2:
		return false
	var projection_revision := int(payload.get("projection_revision", -1))
	if projection_revision <= _projection_revision:
		return false
	var avatars: Array[Dictionary] = []
	for value: Variant in payload.get("avatars", []):
		if not value is Array or (value as Array).size() != 11:
			return false
		var row := value as Array
		avatars.append(
			{
				"character_id": row[0],
				"display_label": row[1],
				"connected": row[2],
				"content_ready": row[3],
				"return_acknowledged": row[4],
				"position_x": row[5],
				"position_y": row[6],
				"velocity_x": row[7],
				"velocity_y": row[8],
				"facing_x": row[9],
				"facing_y": row[10],
			}
		)
	var previous_lifecycle := _snapshot.get("lifecycle_state", "NONE") as String
	_snapshot = {
		"expedition_snapshot_schema_version": 2,
		"projection_revision": projection_revision,
		"expedition_id": payload.get("expedition_id", ""),
		"dungeon_instance_id": payload.get("dungeon_instance_id", ""),
		"expedition_definition_id": payload.get("expedition_definition_id", ""),
		"seed": payload.get("seed", 0),
		"revision": payload.get("revision", -1),
		"lifecycle_state": payload.get("lifecycle_state", "NONE"),
		"leader_character_id": payload.get("leader_character_id", ""),
		"current_room_id": payload.get("current_room_id", ""),
		"load_deadline_msec": payload.get("load_deadline_msec", 0),
		"outcome": payload.get("outcome", "NONE"),
		"active_combat_id": payload.get("active_combat_id", ""),
		"checkpoint_revision": payload.get("checkpoint_revision", 0),
		"visited_room_ids": (payload.get("visited_room_ids", []) as Array).duplicate(),
		"encounters": (payload.get("encounters", []) as Array).duplicate(true),
		"avatars": avatars,
	}
	_projection_revision = projection_revision
	var lifecycle := _snapshot.lifecycle_state as String
	if lifecycle != previous_lifecycle:
		lifecycle_changed.emit(lifecycle)
	snapshot_applied.emit(_snapshot.duplicate(true))
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_expedition_id() -> String:
	return _snapshot.get("expedition_id", "") as String


func get_revision() -> int:
	return int(_snapshot.get("revision", -1))


func clear() -> void:
	_snapshot.clear()
	_projection_revision = -1
