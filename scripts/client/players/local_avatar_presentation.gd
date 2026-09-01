class_name LocalAvatarPresentation
extends Node

@export var input_source_path: NodePath
@export var camera_path: NodePath
@export var interaction_detector_path: NodePath
@export var interaction_prompt_path: NodePath
@export var dialogue_ui_path: NodePath

var _is_active := false

@onready var _input_source: Node = get_node(input_source_path)
@onready var _camera: Camera2D = get_node(camera_path) as Camera2D
@onready var _interaction_detector: Area2D = get_node(interaction_detector_path) as Area2D
@onready var _interaction_prompt: CanvasLayer = get_node(interaction_prompt_path) as CanvasLayer
@onready var _dialogue_ui: CanvasLayer = get_node(dialogue_ui_path) as CanvasLayer


func configure(character_id: StringName, is_local_avatar: bool) -> void:
	_is_active = is_local_avatar
	_input_source.call("set_input_enabled", is_local_avatar)
	_camera.enabled = is_local_avatar
	_interaction_detector.call("configure_interactor", character_id, is_local_avatar)
	_dialogue_ui.process_mode = (
		Node.PROCESS_MODE_INHERIT if is_local_avatar else Node.PROCESS_MODE_DISABLED
	)

	if not is_local_avatar:
		_interaction_prompt.visible = false
		_dialogue_ui.visible = false
		_release_local_nodes.call_deferred()


func is_active() -> bool:
	return _is_active


func get_movement_direction() -> Vector2:
	if not _is_active:
		return Vector2.ZERO
	return _input_source.call("get_movement_direction") as Vector2


func set_camera_limits(bounds: Rect2i) -> void:
	if not _is_active or not bounds.has_area():
		return

	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y


func start_dialogue(conversation: Resource) -> bool:
	if not _is_active:
		return false
	return _dialogue_ui.call("start_dialogue", conversation) as bool


func set_interaction_enabled(is_enabled: bool) -> void:
	if not _is_active:
		return
	_interaction_detector.call("set_interaction_enabled", _is_active and is_enabled)


func set_facing_direction(direction: Vector2) -> void:
	if not _is_active:
		return
	_interaction_detector.call("set_facing_direction", direction)


func _release_local_nodes() -> void:
	for local_node: Node in [
		_input_source,
		_camera,
		_interaction_detector,
		_interaction_prompt,
		_dialogue_ui,
	]:
		if is_instance_valid(local_node):
			local_node.queue_free()
