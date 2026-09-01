class_name Caden
extends Node2D

signal zone_changed(zone_id: StringName)

const ZONE_SCENES := {
	&"wayfarers_approach": preload("res://scenes/world/caden/WayfarersApproach.tscn"),
	&"marketplace": preload("res://scenes/world/caden/Marketplace.tscn"),
	&"town_square": preload("res://scenes/world/caden/TownSquare.tscn"),
	&"residential": preload("res://scenes/world/caden/Residential.tscn"),
	&"commons": preload("res://scenes/world/caden/Commons.tscn"),
}

const STARTING_ZONE: StringName = &"wayfarers_approach"
const STARTING_ENTRY: StringName = &"arrival"

var _current_zone: Node2D
var _current_zone_id: StringName
var _current_exit_routes: Dictionary[StringName, Dictionary] = {}
var _transition_locked := false

@onready var _zone_container: Node2D = $CurrentZone
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	_load_zone(STARTING_ZONE, STARTING_ENTRY)


func _load_zone(zone_id: StringName, entry_id: StringName) -> void:
	var zone_scene := ZONE_SCENES.get(zone_id) as PackedScene
	if zone_scene == null:
		push_error("Caden has no registered zone named '%s'." % zone_id)
		_transition_locked = false
		return

	if _current_zone != null:
		_zone_container.remove_child(_current_zone)
		_current_zone.queue_free()

	_current_zone = zone_scene.instantiate() as Node2D
	_zone_container.add_child(_current_zone)
	_current_zone_id = zone_id
	_connect_zone_exits(_current_zone)
	_configure_depth_references(_current_zone, _player)

	_player.position = _current_zone.call("get_entry_position", entry_id) as Vector2
	_player.call("set_camera_limits", _current_zone.get("camera_bounds") as Rect2i)
	zone_changed.emit(zone_id)


func _connect_zone_exits(zone: Node2D) -> void:
	_current_exit_routes.clear()
	for node in zone.find_children("*", "Area2D", true, false):
		if node.is_in_group(&"zone_exits"):
			var exit_id := node.get("exit_id") as StringName
			if exit_id == &"" or _current_exit_routes.has(exit_id):
				push_error("Caden zone '%s' has a missing or duplicate exit ID." % _current_zone_id)
				continue
			_current_exit_routes[exit_id] = {
				"destination_zone": node.get("destination_zone") as StringName,
				"destination_entry": node.get("destination_entry") as StringName,
			}
			node.connect("transition_requested", _on_transition_requested)


func _configure_depth_references(zone: Node2D, avatar: Node2D) -> void:
	for node: Node in zone.find_children("*", "StaticBody2D", true, false):
		if node.has_method("set_depth_reference"):
			node.call("set_depth_reference", avatar)


func _on_transition_requested(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
) -> void:
	request_zone_transition(character_id, exit_id, destination_zone, destination_entry)


func request_zone_transition(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
) -> bool:
	if _transition_locked or _player.call("is_control_locked"):
		return false
	if not _player.call("is_locally_controlled"):
		return false
	if (_player.call("get_character_id") as StringName) != character_id:
		return false

	var registered_route := _current_exit_routes.get(exit_id, {}) as Dictionary
	if registered_route.is_empty():
		return false
	if (
		(registered_route.get("destination_zone", &"") as StringName) != destination_zone
		or (registered_route.get("destination_entry", &"") as StringName) != destination_entry
	):
		return false

	_transition_locked = true
	_load_zone.call_deferred(destination_zone, destination_entry)
	_unlock_transitions.call_deferred()
	return true


func _unlock_transitions() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_transition_locked = false
