class_name LocalAvatarInput
extends Node

enum MovementAxis {
	HORIZONTAL,
	VERTICAL,
}

var _active_movement_axis: MovementAxis = MovementAxis.VERTICAL
var _input_enabled := true


func set_input_enabled(is_enabled: bool) -> void:
	_input_enabled = is_enabled


func get_movement_direction() -> Vector2:
	if not _input_enabled:
		return Vector2.ZERO

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if input_direction == Vector2.ZERO:
		return Vector2.ZERO

	_update_active_movement_axis(input_direction)
	if _active_movement_axis == MovementAxis.HORIZONTAL:
		return Vector2.RIGHT if input_direction.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if input_direction.y > 0.0 else Vector2.UP


func _update_active_movement_axis(input_direction: Vector2) -> void:
	var horizontal_just_pressed := (
		Input.is_action_just_pressed("move_left")
		or Input.is_action_just_pressed("move_right")
	)
	var vertical_just_pressed := (
		Input.is_action_just_pressed("move_up")
		or Input.is_action_just_pressed("move_down")
	)

	if horizontal_just_pressed and not vertical_just_pressed:
		_active_movement_axis = MovementAxis.HORIZONTAL
	elif vertical_just_pressed and not horizontal_just_pressed:
		_active_movement_axis = MovementAxis.VERTICAL
	elif absf(input_direction.x) > absf(input_direction.y):
		_active_movement_axis = MovementAxis.HORIZONTAL
	elif absf(input_direction.y) > absf(input_direction.x):
		_active_movement_axis = MovementAxis.VERTICAL
