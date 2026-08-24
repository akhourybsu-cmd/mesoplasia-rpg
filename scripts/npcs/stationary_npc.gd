class_name StationaryNpc
extends StaticBody2D

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

@export var conversation: Resource
@export var placeholder_color := Color(0.78, 0.52, 0.3)
@export var character_sprite_frames: SpriteFrames
@export var character_visual_enabled := false
@export var facing_direction := Vector2.DOWN:
	set(value):
		facing_direction = _cardinal_direction(value)
		if is_node_ready():
			_apply_facing_direction()

@onready var _placeholder_visual: Polygon2D = $PlaceholderVisual
@onready var _facing_marker: Polygon2D = $FacingMarker
@onready var _character_visual: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D


func _ready() -> void:
	_placeholder_visual.color = placeholder_color
	_character_visual.sprite_frames = character_sprite_frames
	var visual_is_valid := character_visual_enabled and _validate_character_sprite_frames()
	_character_visual.visible = visual_is_valid
	_placeholder_visual.visible = not visual_is_valid
	if character_visual_enabled and not visual_is_valid:
		push_error("StationaryNpc character art is missing the required v1 SpriteFrames contract.")
	_apply_facing_direction()


func _on_interacted(interactor: Node2D) -> void:
	if conversation != null and interactor.has_method("start_dialogue"):
		interactor.call("start_dialogue", conversation)


func _apply_facing_direction() -> void:
	var direction := _cardinal_direction(facing_direction)
	_facing_marker.position = direction * 9.0
	_facing_marker.rotation = direction.angle() - Vector2.DOWN.angle()
	if _character_visual.visible:
		_character_visual.animation = StringName("idle_%s" % _direction_name(direction))
		_character_visual.stop()
	_facing_marker.visible = not _character_visual.visible


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
