class_name StationaryNpc
extends StaticBody2D

@export var conversation: Resource
@export var placeholder_color := Color(0.78, 0.52, 0.3)
@export var facing_direction := Vector2.DOWN

@onready var _placeholder_visual: Polygon2D = $PlaceholderVisual
@onready var _facing_marker: Polygon2D = $FacingMarker


func _ready() -> void:
	_placeholder_visual.color = placeholder_color
	_apply_facing_direction()


func _on_interacted(interactor: Node2D) -> void:
	if conversation != null and interactor.has_method("start_dialogue"):
		interactor.call("start_dialogue", conversation)


func _apply_facing_direction() -> void:
	var direction := facing_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	_facing_marker.position = direction * 9.0
	_facing_marker.rotation = direction.angle() - Vector2.DOWN.angle()
