class_name ExpeditionDefinitionRegistry
extends RefCounted

const DEFAULT_DEFINITION_PATH := "res://data/expeditions/development_test_expedition.json"

var _definitions_by_id: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_definition_file(DEFAULT_DEFINITION_PATH)


func load_definition_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_validation_errors.append("Definition file is missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_validation_errors.append("Definition file could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_validation_errors.append("Definition file is not a JSON object: %s" % path)
		return false
	var normalized := _normalize_definition(parsed as Dictionary)
	var errors := _validate_definition(normalized)
	if not errors.is_empty():
		_validation_errors.append_array(errors)
		return false
	var definition_id := normalized.expedition_definition_id as String
	if _definitions_by_id.has(definition_id):
		_validation_errors.append("Duplicate expedition definition ID: %s" % definition_id)
		return false
	_definitions_by_id[definition_id] = normalized
	return true


func is_valid() -> bool:
	return not _definitions_by_id.is_empty() and _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func has_definition(expedition_definition_id: String) -> bool:
	return _definitions_by_id.has(expedition_definition_id)


func get_definition(expedition_definition_id: String) -> Dictionary:
	var definition := _definitions_by_id.get(expedition_definition_id, {}) as Dictionary
	return definition.duplicate(true) if not definition.is_empty() else {}


func get_room(expedition_definition_id: String, room_id: String) -> Dictionary:
	var definition := _definitions_by_id.get(expedition_definition_id, {}) as Dictionary
	if definition.is_empty():
		return {}
	var room := (definition.rooms as Dictionary).get(room_id, {}) as Dictionary
	return room.duplicate(true) if not room.is_empty() else {}


func get_connection(
	expedition_definition_id: String,
	room_id: String,
	connection_id: String
) -> Dictionary:
	var room := get_room(expedition_definition_id, room_id)
	if room.is_empty():
		return {}
	var connection := (room.connections as Dictionary).get(connection_id, {}) as Dictionary
	return connection.duplicate(true) if not connection.is_empty() else {}


func _normalize_definition(source: Dictionary) -> Dictionary:
	var rooms: Dictionary = {}
	for room_value: Variant in source.get("rooms", []):
		if not room_value is Dictionary:
			continue
		var raw_room := room_value as Dictionary
		var room_id := raw_room.get("room_id", "") as String
		var connections: Dictionary = {}
		for connection_value: Variant in raw_room.get("connections", []):
			if not connection_value is Dictionary:
				continue
			var raw_connection := connection_value as Dictionary
			var connection_id := raw_connection.get("connection_id", "") as String
			connections[connection_id] = {
				"connection_id": connection_id,
				"destination_room_id": raw_connection.get("destination_room_id", ""),
				"activation_rect": _rect_from_array(raw_connection.get("activation_rect", [])),
				"destination_positions": _vectors_from_array(
					raw_connection.get("destination_positions", [])
				),
			}
		rooms[room_id] = {
			"room_id": room_id,
			"display_name": raw_room.get("display_name", room_id),
			"scene_path": raw_room.get("scene_path", ""),
			"bounds": _rect_from_array(raw_room.get("bounds", [])),
			"spawn_positions": _vectors_from_array(raw_room.get("spawn_positions", [])),
			"checkpoint_id": raw_room.get("checkpoint_id", ""),
			"goal_rect": _rect_from_array(raw_room.get("goal_rect", [])),
			"connections": connections,
		}
	return {
		"schema_version": int(source.get("schema_version", 0)),
		"expedition_definition_id": source.get("expedition_definition_id", ""),
		"dungeon_definition_id": source.get("dungeon_definition_id", ""),
		"display_name": source.get("display_name", ""),
		"entry_room_id": source.get("entry_room_id", ""),
		"return_zone_id": source.get("return_zone_id", ""),
		"return_entry_id": source.get("return_entry_id", ""),
		"rooms": rooms,
	}


func _validate_definition(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if definition.schema_version != 1:
		errors.append("Expedition definition schema must be 1.")
	for key: String in [
		"expedition_definition_id",
		"dungeon_definition_id",
		"entry_room_id",
		"return_zone_id",
		"return_entry_id",
	]:
		if not _stable_id(definition.get(key, "") as String):
			errors.append("Invalid stable ID in field %s." % key)
	var rooms := definition.rooms as Dictionary
	if rooms.is_empty() or not rooms.has(definition.entry_room_id):
		errors.append("Entry room is missing from the dungeon definition.")
	for room_id: Variant in rooms:
		var room := rooms[room_id] as Dictionary
		if not _stable_id(room_id as String) or not (room.bounds as Rect2).has_area():
			errors.append("Room ID or bounds is invalid: %s" % room_id)
		if (room.spawn_positions as Array).is_empty():
			errors.append("Room has no spawn positions: %s" % room_id)
		if not ResourceLoader.exists(room.scene_path):
			errors.append("Room scene is missing: %s" % room.scene_path)
		for connection_id: Variant in room.connections:
			var connection := (room.connections as Dictionary)[connection_id] as Dictionary
			if (
				not _stable_id(connection_id as String)
				or not rooms.has(connection.destination_room_id)
				or not (connection.activation_rect as Rect2).has_area()
				or (connection.destination_positions as Array).is_empty()
			):
				errors.append("Room connection is invalid: %s" % connection_id)
	if errors.is_empty():
		var reachable: Dictionary = {}
		_visit_rooms(definition.entry_room_id, rooms, reachable)
		if reachable.size() != rooms.size():
			errors.append("Dungeon contains an unreachable room.")
	return errors


func _visit_rooms(room_id: String, rooms: Dictionary, visited: Dictionary) -> void:
	if visited.has(room_id) or not rooms.has(room_id):
		return
	visited[room_id] = true
	var room := rooms[room_id] as Dictionary
	for connection_value: Variant in (room.connections as Dictionary).values():
		_visit_rooms((connection_value as Dictionary).destination_room_id, rooms, visited)


func _rect_from_array(value: Variant) -> Rect2:
	if not value is Array or (value as Array).size() != 4:
		return Rect2()
	var row := value as Array
	return Rect2(float(row[0]), float(row[1]), float(row[2]), float(row[3]))


func _vectors_from_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not value is Array:
		return result
	for vector_value: Variant in value:
		if vector_value is Array and (vector_value as Array).size() == 2:
			result.append(Vector2(float(vector_value[0]), float(vector_value[1])))
	return result


func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 122)
			or code in [46, 95, 45]
		):
			return false
	return true
