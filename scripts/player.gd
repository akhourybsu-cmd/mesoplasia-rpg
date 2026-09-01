class_name Player
extends CharacterBody2D

const DIALOGUE_CONTROL_LOCK: StringName = &"dialogue"
const CharacterIdentityContract := preload("res://scripts/core/character_identity.gd")

@export_category("Identity")
@export var character_id: StringName = CharacterIdentityContract.LOCAL_PRIMARY
@export var is_local_avatar := true

@export_category("Movement")
@export var movement_speed: float = 96.0

@export_category("Camera")
@export var camera_limits := Rect2i()

var facing_direction := Vector2.DOWN
var _control_locks: Dictionary[StringName, bool] = {}

@onready var _character_visual: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var _movement_adapter: Node = $AvatarMovementAdapter
@onready var _local_presentation: Node = $LocalAvatarPresentation
@onready var _local_interaction_service: Node = $LocalInteractionService


func _ready() -> void:
	if not CharacterIdentityContract.is_valid(character_id):
		push_error("Player requires a stable, normalized CharacterId.")
		set_physics_process(false)
		return

	_local_presentation.call("configure", character_id, is_local_avatar)
	set_physics_process(is_local_avatar)
	if not is_local_avatar:
		_local_interaction_service.queue_free()
	_apply_camera_limits()
	_local_presentation.call("set_facing_direction", facing_direction)
	_update_character_visual(Vector2.ZERO)


func get_character_id() -> StringName:
	return character_id


func is_locally_controlled() -> bool:
	return is_local_avatar


func apply_remote_presentation_state(
	new_global_position: Vector2,
	movement_direction: Vector2,
	new_facing_direction: Vector2
) -> bool:
	if is_local_avatar:
		return false

	global_position = new_global_position
	if new_facing_direction != Vector2.ZERO:
		facing_direction = new_facing_direction.normalized()
	_update_character_visual(movement_direction)
	return true


func set_camera_limits(bounds: Rect2i) -> void:
	camera_limits = bounds
	_apply_camera_limits()


func _apply_camera_limits() -> void:
	if not camera_limits.has_area() or not is_node_ready():
		return
	_local_presentation.call("set_camera_limits", camera_limits)


func start_dialogue(conversation: Resource) -> bool:
	var dialogue_started: bool = _local_presentation.call("start_dialogue", conversation)
	if dialogue_started:
		lock_controls(DIALOGUE_CONTROL_LOCK)
	return dialogue_started


func lock_controls(reason: StringName) -> void:
	_control_locks[reason] = true
	_local_presentation.call("set_interaction_enabled", false)


func unlock_controls(reason: StringName) -> void:
	_control_locks.erase(reason)
	if not is_control_locked():
		_local_presentation.call("set_interaction_enabled", true)


func is_control_locked() -> bool:
	return not _control_locks.is_empty()


func _on_dialogue_closed() -> void:
	unlock_controls(DIALOGUE_CONTROL_LOCK)


func _physics_process(_delta: float) -> void:
	var movement_direction := Vector2.ZERO
	if not is_control_locked():
		movement_direction = _local_presentation.call("get_movement_direction") as Vector2
	if movement_direction != Vector2.ZERO:
		facing_direction = movement_direction
		_local_presentation.call("set_facing_direction", facing_direction)

	var applied_direction: Vector2 = _movement_adapter.call(
		"simulate_movement",
		self,
		movement_direction,
		movement_speed,
		is_control_locked()
	)
	_update_character_visual(applied_direction)


func _update_character_visual(movement_direction: Vector2) -> void:
	_character_visual.call("update_visual_state", movement_direction, facing_direction)


func _on_interaction_requested(
	requesting_character_id: StringName,
	interactable_id: StringName,
	interactable: Area2D
) -> void:
	_local_interaction_service.call(
		"request_interaction",
		requesting_character_id,
		self,
		interactable_id,
		interactable
	)
