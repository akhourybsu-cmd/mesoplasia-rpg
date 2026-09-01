class_name PatrolNpc
extends CharacterBody2D

enum PatrolAxis {
	HORIZONTAL,
	VERTICAL,
}

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_down",
	&"idle_left",
	&"idle_right",
	&"idle_up",
	&"walk_down",
	&"walk_left",
	&"walk_right",
	&"walk_up",
]

@export var npc_id: StringName
@export var character_sprite_frames: SpriteFrames
@export_enum("Horizontal", "Vertical") var patrol_axis: int = PatrolAxis.HORIZONTAL
@export_range(32.0, 512.0, 1.0) var patrol_distance := 128.0
@export_range(8.0, 96.0, 1.0) var move_speed := 28.0
@export_range(0.0, 5.0, 0.1) var pause_duration := 1.0
@export var start_toward_positive := true
@export var face_forward_while_idle := true
@export var placeholder_color := Color(0.55, 0.66, 0.78)

@onready var _placeholder_visual: Polygon2D = $PlaceholderVisual
@onready var _facing_marker: Polygon2D = $FacingMarker
@onready var _character_visual: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

var _negative_endpoint := Vector2.ZERO
var _positive_endpoint := Vector2.ZERO
var _target_endpoint := Vector2.ZERO
var _pause_remaining := 0.0
var _visual_is_valid := false
var _network_presentation_enabled := false


func _ready() -> void:
	_placeholder_visual.color = placeholder_color
	_character_visual.sprite_frames = character_sprite_frames
	_visual_is_valid = _validate_character_sprite_frames()
	_character_visual.visible = _visual_is_valid
	_placeholder_visual.visible = not _visual_is_valid
	_facing_marker.visible = not _visual_is_valid
	if not _visual_is_valid:
		push_error("PatrolNpc character art is missing the required v1 SpriteFrames contract.")

	var axis := _patrol_direction()
	var half_distance := patrol_distance * 0.5
	_negative_endpoint = global_position - axis * half_distance
	_positive_endpoint = global_position + axis * half_distance
	_target_endpoint = _positive_endpoint if start_toward_positive else _negative_endpoint
	_begin_pause()


func _physics_process(delta: float) -> void:
	if _network_presentation_enabled:
		return
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		if _pause_remaining == 0.0:
			_play_walk_toward(_target_endpoint)
		return

	var to_target := _target_endpoint - global_position
	var maximum_step := move_speed * delta
	if to_target.length() <= maximum_step:
		global_position = _target_endpoint
		_target_endpoint = _negative_endpoint if _target_endpoint == _positive_endpoint else _positive_endpoint
		_begin_pause()
		return

	velocity = to_target.normalized() * move_speed
	_play_walk(velocity)
	var collided := move_and_slide()
	if collided:
		_target_endpoint = _negative_endpoint if _target_endpoint == _positive_endpoint else _positive_endpoint
		_begin_pause()


func get_npc_id() -> StringName:
	return npc_id


func set_network_presentation_enabled(is_enabled: bool) -> void:
	_network_presentation_enabled = is_enabled
	set_physics_process(not is_enabled)
	velocity = Vector2.ZERO


func apply_authoritative_presentation_state(
	new_global_position: Vector2,
	movement_velocity: Vector2,
	facing_direction: Vector2
) -> bool:
	if not _network_presentation_enabled:
		return false
	global_position = new_global_position
	velocity = movement_velocity
	if movement_velocity != Vector2.ZERO:
		_play_walk(movement_velocity)
	else:
		_play_idle(facing_direction)
	return true


func _patrol_direction() -> Vector2:
	return Vector2.DOWN if patrol_axis == PatrolAxis.VERTICAL else Vector2.RIGHT


func _begin_pause() -> void:
	velocity = Vector2.ZERO
	_pause_remaining = pause_duration
	if face_forward_while_idle:
		_play_idle(Vector2.DOWN)
	else:
		_play_idle((_target_endpoint - global_position).normalized())


func _play_walk_toward(target: Vector2) -> void:
	_play_walk(target - global_position)


func _play_walk(direction: Vector2) -> void:
	var cardinal := _cardinal_direction(direction)
	_update_facing_marker(cardinal)
	if _visual_is_valid:
		_character_visual.play(StringName("walk_%s" % _direction_name(cardinal)))


func _play_idle(direction: Vector2) -> void:
	var cardinal := _cardinal_direction(direction)
	_update_facing_marker(cardinal)
	if _visual_is_valid:
		_character_visual.animation = StringName("idle_%s" % _direction_name(cardinal))
		_character_visual.stop()


func _update_facing_marker(direction: Vector2) -> void:
	_facing_marker.position = direction * 9.0
	_facing_marker.rotation = direction.angle() - Vector2.DOWN.angle()


func _cardinal_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	if direction.y < 0.0:
		return Vector2.UP
	return Vector2.DOWN


func _direction_name(direction: Vector2) -> String:
	if direction == Vector2.LEFT:
		return "left"
	if direction == Vector2.RIGHT:
		return "right"
	if direction == Vector2.UP:
		return "up"
	return "down"


func _validate_character_sprite_frames() -> bool:
	if character_sprite_frames == null:
		return false
	if character_sprite_frames.get_animation_names().size() != REQUIRED_ANIMATIONS.size():
		return false
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if not character_sprite_frames.has_animation(animation_name):
			return false
		var walking := animation_name.begins_with("walk_")
		if character_sprite_frames.get_frame_count(animation_name) != (4 if walking else 1):
			return false
		if character_sprite_frames.get_animation_loop(animation_name) != walking:
			return false
		if not is_equal_approx(character_sprite_frames.get_animation_speed(animation_name), 8.0):
			return false
	return true
