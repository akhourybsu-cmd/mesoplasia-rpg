class_name Caden
extends Node2D

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
	_connect_zone_exits(_current_zone)

	_player.position = _current_zone.call("get_entry_position", entry_id) as Vector2
	_player.call("set_camera_limits", _current_zone.get("camera_bounds") as Rect2i)


func _connect_zone_exits(zone: Node2D) -> void:
	for node in zone.find_children("*", "Area2D", true, false):
		if node.is_in_group(&"zone_exits"):
			node.connect("transition_requested", _on_transition_requested)


func _on_transition_requested(destination_zone: StringName, destination_entry: StringName) -> void:
	if _transition_locked:
		return

	_transition_locked = true
	_load_zone.call_deferred(destination_zone, destination_entry)
	_unlock_transitions.call_deferred()


func _unlock_transitions() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_transition_locked = false
