class_name ZoneExit
extends Area2D

signal transition_requested(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
)

@export var exit_id: StringName
@export var destination_zone: StringName
@export var destination_entry: StringName


func _ready() -> void:
	add_to_group(&"zone_exits")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if (
		body.is_in_group(&"player")
		and body.has_method("get_character_id")
		and body.has_method("is_locally_controlled")
		and body.call("is_locally_controlled")
	):
		transition_requested.emit(
			body.call("get_character_id") as StringName,
			exit_id,
			destination_zone,
			destination_entry
		)
