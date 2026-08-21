extends AnimatedSprite2D

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

@export var fallback_path: NodePath

var _fallback: CanvasItem
var _runtime_valid := false


func _ready() -> void:
	_fallback = get_node_or_null(fallback_path) as CanvasItem
	_runtime_valid = _validate_sprite_frames()
	visible = _runtime_valid
	if _fallback:
		_fallback.visible = not _runtime_valid

	if not _runtime_valid:
		push_error("Directional character visual is missing the required v1 SpriteFrames contract.")
		return

	update_visual_state(Vector2.ZERO, Vector2.DOWN)


func update_visual_state(movement_direction: Vector2, facing_direction: Vector2) -> void:
	if not _runtime_valid:
		return

	var is_walking := movement_direction != Vector2.ZERO
	var state := "walk" if is_walking else "idle"
	var requested_animation := StringName("%s_%s" % [state, _direction_name(facing_direction)])
	if animation != requested_animation:
		play(requested_animation)
	elif is_walking and not is_playing():
		play(requested_animation)


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	if direction.y < 0.0:
		return "up"
	return "down"


func _validate_sprite_frames() -> bool:
	if sprite_frames == null:
		return false
	if sprite_frames.get_animation_names().size() != REQUIRED_ANIMATIONS.size():
		return false

	for animation_name in REQUIRED_ANIMATIONS:
		if not sprite_frames.has_animation(animation_name):
			return false

		var expected_frame_count := 4 if animation_name.begins_with("walk_") else 1
		if sprite_frames.get_frame_count(animation_name) != expected_frame_count:
			return false
		if sprite_frames.get_animation_loop(animation_name) != animation_name.begins_with("walk_"):
			return false
		if not is_equal_approx(sprite_frames.get_animation_speed(animation_name), 8.0):
			return false

	return true
