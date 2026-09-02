class_name CombatStateStore
extends RefCounted

signal snapshot_applied(snapshot: Dictionary)
signal lifecycle_changed(lifecycle_state: String)

var _snapshot: Dictionary = {}
var _projection_revision := -1


func apply_snapshot(payload: Dictionary) -> bool:
	if int(payload.get("combat_snapshot_schema_version", 0)) != 1:
		return false
	var projection_revision := int(payload.get("projection_revision", -1))
	if projection_revision <= _projection_revision:
		return false
	var combatants: Array[Dictionary] = []
	for value: Variant in payload.get("combatants", []):
		if not value is Array or (value as Array).size() != 13:
			return false
		var row := value as Array
		combatants.append(
			{
				"combatant_id": row[0],
				"template_id": row[1],
				"display_name": row[2],
				"team_id": row[3],
				"health": row[4],
				"max_health": row[5],
				"resource": row[6],
				"max_resource": row[7],
				"controller_id": row[8],
				"ai_controlled": row[9],
				"alive": row[10],
				"connected": row[11],
				"status_summary": row[12],
			}
		)
	var events: Array[Dictionary] = []
	for value: Variant in payload.get("events", []):
		if not value is Array or (value as Array).size() != 6:
			return false
		var row := value as Array
		events.append(
			{
				"event_sequence": row[0],
				"revision": row[1],
				"event_type": row[2],
				"actor_id": row[3],
				"target_ids": (row[4] as String).split(",", false),
				"detail": row[5],
			}
		)
	var previous_lifecycle := _snapshot.get("lifecycle_state", "NONE") as String
	_snapshot = payload.duplicate(true)
	_snapshot.combatants = combatants
	_snapshot.events = events
	_projection_revision = projection_revision
	var lifecycle := _snapshot.lifecycle_state as String
	if lifecycle != previous_lifecycle:
		lifecycle_changed.emit(lifecycle)
	snapshot_applied.emit(_snapshot.duplicate(true))
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func clear() -> void:
	_snapshot.clear()
	_projection_revision = -1
