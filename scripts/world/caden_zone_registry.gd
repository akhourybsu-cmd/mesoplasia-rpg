class_name CadenZoneRegistry
extends RefCounted

const STARTING_ZONE := "wayfarers_approach"
const STARTING_ENTRY := "arrival"

const ZONE_SCENES := {
	"wayfarers_approach": preload("res://scenes/world/caden/WayfarersApproach.tscn"),
	"marketplace": preload("res://scenes/world/caden/Marketplace.tscn"),
	"town_square": preload("res://scenes/world/caden/TownSquare.tscn"),
	"residential": preload("res://scenes/world/caden/Residential.tscn"),
	"commons": preload("res://scenes/world/caden/Commons.tscn"),
}

var _zone_records: Dictionary = {}
var _is_valid := true


func _init() -> void:
	_build_records()


func is_valid() -> bool:
	return _is_valid and _zone_records.size() == ZONE_SCENES.size()


func has_zone(zone_id: String) -> bool:
	return _zone_records.has(zone_id)


func get_zone_ids() -> Array[String]:
	var zone_ids: Array[String] = []
	zone_ids.assign(_zone_records.keys())
	zone_ids.sort()
	return zone_ids


func get_zone_scene(zone_id: String) -> PackedScene:
	return ZONE_SCENES.get(zone_id) as PackedScene


func get_camera_bounds(zone_id: String) -> Rect2i:
	return (_zone_records.get(zone_id, {}) as Dictionary).get("camera_bounds", Rect2i()) as Rect2i


func get_entry_position(zone_id: String, entry_id: String) -> Vector2:
	var record := _zone_records.get(zone_id, {}) as Dictionary
	var entries := record.get("entries", {}) as Dictionary
	return entries.get(entry_id, Vector2(-1, -1)) as Vector2


func get_exit_route(zone_id: String, exit_id: String) -> Dictionary:
	var record := _zone_records.get(zone_id, {}) as Dictionary
	var exits := record.get("exits", {}) as Dictionary
	return (exits.get(exit_id, {}) as Dictionary).duplicate(true)


func get_interactable(zone_id: String, interactable_id: String) -> Dictionary:
	var record := _zone_records.get(zone_id, {}) as Dictionary
	var interactables := record.get("interactables", {}) as Dictionary
	return (interactables.get(interactable_id, {}) as Dictionary).duplicate(true)


func get_collision_rectangles(zone_id: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var record := _zone_records.get(zone_id, {}) as Dictionary
	result.assign(record.get("collision_rectangles", []))
	return result


func get_patrol_definitions(zone_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var record := _zone_records.get(zone_id, {}) as Dictionary
	for definition: Variant in record.get("patrols", []):
		result.append((definition as Dictionary).duplicate(true))
	return result


func _build_records() -> void:
	for zone_id: String in ZONE_SCENES:
		var scene := ZONE_SCENES[zone_id] as PackedScene
		var zone := scene.instantiate() as Node2D
		if zone == null:
			_invalidate("Caden zone '%s' could not be instantiated." % zone_id)
			continue
		var record := {
			"camera_bounds": zone.get("camera_bounds") as Rect2i,
			"entries": {},
			"exits": {},
			"interactables": {},
			"collision_rectangles": [],
			"patrols": [],
		}
		_collect_entries(zone_id, zone, record)
		_collect_exits_and_interactables(zone_id, zone, record)
		_collect_collisions(zone, record)
		_collect_patrols(zone_id, zone, record)
		_zone_records[zone_id] = record
		zone.free()


func _collect_entries(zone_id: String, zone: Node2D, record: Dictionary) -> void:
	var entry_root := zone.get_node_or_null("EntryPoints")
	if entry_root == null:
		_invalidate("Caden zone '%s' has no EntryPoints node." % zone_id)
		return
	var entries := record.entries as Dictionary
	for child: Node in entry_root.get_children():
		if child is Marker2D:
			entries[String(child.name)] = (child as Marker2D).position
	if entries.is_empty():
		_invalidate("Caden zone '%s' exposes no entry positions." % zone_id)


func _collect_exits_and_interactables(
	zone_id: String,
	zone: Node2D,
	record: Dictionary
) -> void:
	var exits := record.exits as Dictionary
	var interactables := record.interactables as Dictionary
	for node: Node in zone.find_children("*", "Area2D", true, false):
		if node.has_method("get_exit_id") or node.get_script() != null and node.get_script().resource_path.ends_with("zone_exit.gd"):
			var exit_id := String(node.get("exit_id") as StringName)
			if exit_id.is_empty() or exits.has(exit_id):
				_invalidate("Caden zone '%s' has a missing or duplicate ExitId." % zone_id)
				continue
			exits[exit_id] = {
				"exit_id": exit_id,
				"destination_zone": String(node.get("destination_zone") as StringName),
				"destination_entry": String(node.get("destination_entry") as StringName),
				"activation_rect": _collision_union(node as CollisionObject2D),
			}
		elif node.has_method("get_interactable_id"):
			var interactable_id := String(node.call("get_interactable_id") as StringName)
			if interactable_id.is_empty() and node.get_parent() != null:
				var parent_value: Variant = node.get_parent().get("interactable_id")
				if parent_value is StringName:
					interactable_id = String(parent_value)
			if interactable_id.is_empty() or interactables.has(interactable_id):
				_invalidate("Caden zone '%s' has a missing or duplicate InteractableId." % zone_id)
				continue
			interactables[interactable_id] = {
				"interactable_id": interactable_id,
				"activation_rect": _collision_union(node as CollisionObject2D),
			}


func _collect_collisions(zone: Node2D, record: Dictionary) -> void:
	var collision_rectangles := record.collision_rectangles as Array
	for node: Node in zone.find_children("*", "StaticBody2D", true, false):
		var body := node as StaticBody2D
		if body.collision_layer & 1 == 0:
			continue
		for child: Node in body.find_children("*", "CollisionShape2D", true, false):
			var collision_shape := child as CollisionShape2D
			if not collision_shape.disabled:
				var shape_rect := _shape_rect(collision_shape)
				if shape_rect.has_area():
					collision_rectangles.append(shape_rect)


func _collect_patrols(zone_id: String, zone: Node2D, record: Dictionary) -> void:
	var patrols := record.patrols as Array
	var seen_ids: Dictionary = {}
	for node: Node in zone.find_children("*", "CharacterBody2D", true, false):
		if not node.has_method("get_npc_id"):
			continue
		var npc_id := String(node.call("get_npc_id") as StringName)
		if npc_id.is_empty() or seen_ids.has(npc_id):
			_invalidate("Caden zone '%s' has a missing or duplicate patrol NpcId." % zone_id)
			continue
		seen_ids[npc_id] = true
		var axis := Vector2.DOWN if int(node.get("patrol_axis")) == 1 else Vector2.RIGHT
		var start_position := (node as Node2D).global_position
		var half_distance := float(node.get("patrol_distance")) * 0.5
		patrols.append(
			{
				"npc_id": npc_id,
				"start_position": start_position,
				"negative_endpoint": start_position - axis * half_distance,
				"positive_endpoint": start_position + axis * half_distance,
				"move_speed": float(node.get("move_speed")),
				"pause_duration": float(node.get("pause_duration")),
				"start_toward_positive": bool(node.get("start_toward_positive")),
			}
		)


func _collision_union(object: CollisionObject2D) -> Rect2:
	var result := Rect2()
	var has_shape := false
	for node: Node in object.find_children("*", "CollisionShape2D", true, false):
		var collision_shape := node as CollisionShape2D
		if collision_shape.disabled:
			continue
		var shape_rect := _shape_rect(collision_shape)
		if not shape_rect.has_area():
			continue
		result = shape_rect if not has_shape else result.merge(shape_rect)
		has_shape = true
	if not has_shape:
		return Rect2(object.global_position - Vector2(24, 24), Vector2(48, 48))
	return result


func _shape_rect(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape.shape == null:
		return Rect2()
	var local_half_size := Vector2.ZERO
	if collision_shape.shape is RectangleShape2D:
		local_half_size = (collision_shape.shape as RectangleShape2D).size * 0.5
	elif collision_shape.shape is CircleShape2D:
		var radius := (collision_shape.shape as CircleShape2D).radius
		local_half_size = Vector2(radius, radius)
	else:
		return Rect2()
	var corners := [
		Vector2(-local_half_size.x, -local_half_size.y),
		Vector2(local_half_size.x, -local_half_size.y),
		Vector2(local_half_size.x, local_half_size.y),
		Vector2(-local_half_size.x, local_half_size.y),
	]
	var first := collision_shape.global_transform * (corners[0] as Vector2)
	var minimum := first
	var maximum := first
	for corner: Vector2 in corners:
		var point := collision_shape.global_transform * corner
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _invalidate(message: String) -> void:
	_is_valid = false
	push_error(message)
