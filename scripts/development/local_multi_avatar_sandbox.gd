class_name LocalMultiAvatarSandbox
extends Node2D

signal transition_intent_observed(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
)

const LOCAL_CHARACTER_ID: StringName = &"local.character.primary"
const REMOTE_CHARACTER_ID: StringName = &"development.character.remote"
const SANDBOX_BOUNDS := Rect2i(0, 0, 640, 360)

var transition_intent_count := 0
var last_transition_character_id: StringName
var last_transition_exit_id: StringName
var last_transition_destination_zone: StringName
var last_transition_destination_entry: StringName

@onready var _avatar_registry: Node = $AvatarRegistry
@onready var _local_avatar: CharacterBody2D = $Actors/LocalAvatar
@onready var _remote_avatar: CharacterBody2D = $Actors/RemoteAvatar
@onready var _depth_probe: StaticBody2D = $World/DepthProbe


func _ready() -> void:
	if not _avatar_registry.call("register_avatar", _local_avatar):
		push_error("Multi-avatar sandbox could not register its local avatar.")
	if not _avatar_registry.call("register_avatar", _remote_avatar):
		push_error("Multi-avatar sandbox could not register its remote-style avatar.")
	_local_avatar.call("set_camera_limits", SANDBOX_BOUNDS)
	_depth_probe.call("set_depth_reference", _local_avatar)


func get_avatar_registry() -> Node:
	return _avatar_registry


func get_local_avatar() -> CharacterBody2D:
	return _local_avatar


func get_remote_avatar() -> CharacterBody2D:
	return _remote_avatar


func get_interaction_target() -> StaticBody2D:
	return $World/InteractionTarget as StaticBody2D


func get_transition_probe() -> Area2D:
	return $World/TransitionIntentProbe as Area2D


func get_depth_probe() -> StaticBody2D:
	return _depth_probe


func _on_transition_requested(
	character_id: StringName,
	exit_id: StringName,
	destination_zone: StringName,
	destination_entry: StringName
) -> void:
	if not _avatar_registry.call("has_avatar", character_id):
		return
	transition_intent_count += 1
	last_transition_character_id = character_id
	last_transition_exit_id = exit_id
	last_transition_destination_zone = destination_zone
	last_transition_destination_entry = destination_entry
	transition_intent_observed.emit(
		character_id,
		exit_id,
		destination_zone,
		destination_entry
	)
