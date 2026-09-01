class_name PartyStateStore
extends RefCounted

signal snapshot_applied(snapshot: Dictionary)
signal party_changed(party_id: String)

var _snapshot: Dictionary = {}
var _projection_revision := -1


func apply_snapshot(payload: Dictionary) -> bool:
	if int(payload.get("party_snapshot_schema_version", 0)) != 1:
		return false
	var projection_revision := int(payload.get("projection_revision", -1))
	if projection_revision <= _projection_revision:
		return false
	var members: Array[Dictionary] = []
	for value: Variant in payload.get("members", []):
		if not value is Array or (value as Array).size() != 6:
			return false
		var row := value as Array
		members.append(
			{
				"character_id": row[0],
				"display_label": row[1],
				"connected": row[2],
				"ready": row[3],
				"join_order": row[4],
				"disconnect_deadline_msec": row[5],
			}
		)
	var invitations: Array[Dictionary] = []
	for value: Variant in payload.get("invitations", []):
		if not value is Array or (value as Array).size() != 10:
			return false
		var row := value as Array
		invitations.append(
			{
				"invite_id": row[0],
				"party_id": row[1],
				"party_revision_at_creation": row[2],
				"current_party_revision": row[3],
				"inviter_character_id": row[4],
				"inviter_display_label": row[5],
				"recipient_character_id": row[6],
				"created_msec": row[7],
				"expires_msec": row[8],
				"status": row[9],
			}
		)
	var previous_party_id := _snapshot.get("party_id", "") as String
	_snapshot = {
		"party_snapshot_schema_version": 1,
		"projection_revision": projection_revision,
		"party_id": payload.get("party_id", ""),
		"revision": payload.get("revision", -1),
		"lifecycle_state": payload.get("lifecycle_state", "UNPARTIED"),
		"leader_character_id": payload.get("leader_character_id", ""),
		"selected_expedition_definition_id": payload.get(
			"selected_expedition_definition_id", ""
		),
		"current_expedition_id": payload.get("current_expedition_id", ""),
		"max_party_size": payload.get("max_party_size", 0),
		"all_present_members_ready": payload.get("all_present_members_ready", false),
		"members": members,
		"invitations": invitations,
	}
	_projection_revision = projection_revision
	var party_id := _snapshot.party_id as String
	if party_id != previous_party_id:
		party_changed.emit(party_id)
	snapshot_applied.emit(_snapshot.duplicate(true))
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_party_id() -> String:
	return _snapshot.get("party_id", "") as String


func get_party_revision() -> int:
	return int(_snapshot.get("revision", -1))


func get_members() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member: Variant in _snapshot.get("members", []):
		result.append((member as Dictionary).duplicate(true))
	return result


func get_invitations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for invitation: Variant in _snapshot.get("invitations", []):
		result.append((invitation as Dictionary).duplicate(true))
	return result


func clear() -> void:
	_snapshot.clear()
	_projection_revision = -1
