class_name Player
extends CharacterBody2D

enum MovementAxis {
	HORIZONTAL,
	VERTICAL,
}

const DIALOGUE_CONTROL_LOCK: StringName = &"dialogue"

@export_category("Movement")
@export var movement_speed: float = 96.0

@export_category("Camera")
@export var camera_limits := Rect2i()

var _active_movement_axis: MovementAxis = MovementAxis.VERTICAL
var facing_direction := Vector2.DOWN
var _control_locks: Dictionary[StringName, bool] = {}

@onready var _camera: Camera2D = $Camera2D
@onready var _interaction_detector: Area2D = $InteractionDetector
@onready var _dialogue_ui: CanvasLayer = $DialogueUI


func _ready() -> void:
	_apply_camera_limits()
	_interaction_detector.call("set_facing_direction", facing_direction)


func set_camera_limits(bounds: Rect2i) -> void:
	camera_limits = bounds
	_apply_camera_limits()


func _apply_camera_limits() -> void:
	if not camera_limits.has_area() or not is_node_ready():
		return

	_camera.limit_left = camera_limits.position.x
	_camera.limit_top = camera_limits.position.y
	_camera.limit_right = camera_limits.end.x
	_camera.limit_bottom = camera_limits.end.y


func start_dialogue(conversation: Resource) -> bool:
	var dialogue_started: bool = _dialogue_ui.call("start_dialogue", conversation)
	if dialogue_started:
		lock_controls(DIALOGUE_CONTROL_LOCK)
	return dialogue_started


func lock_controls(reason: StringName) -> void:
	_control_locks[reason] = true
	_interaction_detector.call("set_interaction_enabled", false)


func unlock_controls(reason: StringName) -> void:
	_control_locks.erase(reason)
	if not is_control_locked():
		_interaction_detector.call("set_interaction_enabled", true)


func is_control_locked() -> bool:
	return not _control_locks.is_empty()


func _on_dialogue_closed() -> void:
	unlock_controls(DIALOGUE_CONTROL_LOCK)


func _physics_process(_delta: float) -> void:
	if is_control_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var movement_direction := _get_four_direction_input()
	if movement_direction != Vector2.ZERO:
		facing_direction = movement_direction
		_interaction_detector.call("set_facing_direction", facing_direction)

	velocity = movement_direction * movement_speed
	move_and_slide()


func _get_four_direction_input() -> Vector2:
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
