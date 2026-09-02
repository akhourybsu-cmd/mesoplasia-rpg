class_name CadenResourceStateStore
extends RefCounted

signal snapshot_applied(snapshot: Dictionary)

var _snapshot: Dictionary = {}
var _projection_revision := -1


func apply_snapshot(payload: Dictionary) -> bool:
	if int(payload.get("resource_snapshot_schema_version", 0)) != 1:
		return false
	var projection_revision := int(payload.get("projection_revision", -1))
	if projection_revision <= _projection_revision:
		return false
	var inventory_resources: Variant = _normalize_resource_rows(
		payload.get("inventory_resources", [])
	)
	var stockpiles: Variant = _normalize_resource_rows(payload.get("stockpiles", []))
	if inventory_resources == null or stockpiles == null:
		return false
	var projects: Array[Dictionary] = []
	for value: Variant in payload.get("projects", []):
		if not value is Array or (value as Array).size() != 4:
			return false
		var row := value as Array
		if (
			not row[0] is String
			or not row[1] is String
			or not row[2] is int
			or not row[3] is int
		):
			return false
		projects.append(
			{
				"project_id": row[0],
				"state": row[1],
				"deposited_total": row[2],
				"required_total": row[3],
			}
		)
	_snapshot = {
		"resource_snapshot_schema_version": 1,
		"projection_revision": projection_revision,
		"world_id": payload.get("world_id", ""),
		"world_record_revision": payload.get("world_record_revision", -1),
		"inventory_record_revision": payload.get("inventory_record_revision", -1),
		"inventory_resources": inventory_resources,
		"stockpiles": stockpiles,
		"projects": projects,
	}
	_projection_revision = projection_revision
	snapshot_applied.emit(_snapshot.duplicate(true))
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_inventory_quantity(resource_id: String) -> int:
	return _quantity(_snapshot.get("inventory_resources", []), resource_id)


func get_stockpile_quantity(resource_id: String) -> int:
	return _quantity(_snapshot.get("stockpiles", []), resource_id)


func get_project_state(project_id: String) -> String:
	for value: Variant in _snapshot.get("projects", []):
		var project := value as Dictionary
		if project.get("project_id", "") == project_id:
			return project.get("state", "") as String
	return ""


func clear() -> void:
	_snapshot.clear()
	_projection_revision = -1


func _normalize_resource_rows(value: Variant) -> Variant:
	if not value is Array:
		return null
	var result: Array[Dictionary] = []
	for row_value: Variant in value as Array:
		if not row_value is Array or (row_value as Array).size() != 2:
			return null
		var row := row_value as Array
		if not row[0] is String or not row[1] is int:
			return null
		result.append({"resource_id": row[0], "quantity": row[1]})
	return result


func _quantity(rows: Array, resource_id: String) -> int:
	for value: Variant in rows:
		var row := value as Dictionary
		if row.get("resource_id", "") == resource_id:
			return int(row.get("quantity", 0))
	return 0
