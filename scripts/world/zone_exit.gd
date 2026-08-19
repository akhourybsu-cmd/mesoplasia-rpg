class_name ZoneExit
extends Area2D

signal transition_requested(destination_zone: StringName, destination_entry: StringName)

@export var destination_zone: StringName
@export var destination_entry: StringName


func _ready() -> void:
	add_to_group(&"zone_exits")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		transition_requested.emit(destination_zone, destination_entry)
