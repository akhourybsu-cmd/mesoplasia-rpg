class_name NetworkedExpeditionPresenter
extends Node2D

signal room_presented(room_id: String)
signal return_to_caden_requested(outcome: String)
signal expedition_closed(outcome: String)

const PlayerScene := preload("res://scenes/Player.tscn")
const DefinitionRegistry := preload(
	"res://scripts/server/expedition/expedition_definition_registry.gd"
)

const MOVEMENT_SEND_INTERVAL_SECONDS := 1.0 / 20.0
const CAMERA_BOUNDS := Rect2i(64, 64, 512, 232)

@onready var _room_container: Node2D = $CurrentRoom
@onready var _avatar_container: Node2D = $Avatars

var _runtime: Node
var _registry := DefinitionRegistry.new()
var _presentation_enabled := true
var _auto_acknowledge_return := true
var _current_room: Node2D
var _current_room_id := ""
var _local_character_id := ""
var _avatars_by_character_id: Dictionary = {}
var _current_snapshot: Dictionary = {}
var _movement_accumulator := 0.0
var _movement_input_sequence := 0
var _last_sent_direction := Vector2.ZERO
var _last_content_ready_revision := -1
var _last_return_ack_revision := -1
var _return_signal_expedition_id := ""
var _closed_signal_expedition_id := ""


func _ready() -> void:
	set_physics_process(false)


func _exit_tree() -> void:
	_disconnect_runtime()


func configure(
	runtime: Node,
	presentation_enabled: bool = true,
	auto_acknowledge_return: bool = true
) -> bool:
	if runtime == null or not _registry.is_valid():
		return false
	_disconnect_runtime()
	_runtime = runtime
	_presentation_enabled = presentation_enabled
	_auto_acknowledge_return = auto_acknowledge_return
	_runtime.expedition_snapshot_received.connect(_on_expedition_snapshot_received)
	_runtime.client_authenticated.connect(_on_client_authenticated)
	var identity := _runtime.call("get_client_identity") as Dictionary
	_local_character_id = identity.get("character_id", "") as String
	set_physics_process(true)
	var snapshot := _runtime.call("get_expedition_snapshot") as Dictionary
	if not snapshot.is_empty():
		_apply_snapshot(snapshot)
	return true


func get_current_room_id() -> String:
	return _current_room_id


func get_presented_avatar_count() -> int:
	return _avatars_by_character_id.size()


func get_presented_avatar(character_id: String) -> CharacterBody2D:
	return _avatars_by_character_id.get(character_id) as CharacterBody2D


func is_presentation_enabled() -> bool:
	return _presentation_enabled


func _physics_process(delta: float) -> void:
	if (
		_runtime == null
		or not _presentation_enabled
		or _current_snapshot.get("lifecycle_state", "") != "ACTIVE_EXPLORATION"
		or _local_character_id.is_empty()
	):
		return
	var local_avatar := get_presented_avatar(_local_character_id)
	if local_avatar == null:
		return
	_movement_accumulator += delta
	var direction := local_avatar.call("get_local_movement_intent") as Vector2
	if direction == _last_sent_direction and _movement_accumulator < MOVEMENT_SEND_INTERVAL_SECONDS:
		return
	_movement_accumulator = 0.0
	_last_sent_direction = direction
	_movement_input_sequence += 1
	_runtime.call("send_expedition_movement", direction, _movement_input_sequence)


func _apply_snapshot(snapshot: Dictionary) -> void:
	_current_snapshot = snapshot.duplicate(true)
	if _local_character_id.is_empty() and _runtime != null:
		_local_character_id = (
			(_runtime.call("get_client_identity") as Dictionary).get("character_id", "") as String
		)
	var lifecycle := snapshot.get("lifecycle_state", "NONE") as String
	match lifecycle:
		"LOADING":
			_acknowledge_content_when_valid(snapshot)
		"ACTIVE_EXPLORATION":
			if _presentation_enabled:
				_present_active_snapshot(snapshot)
		"RETURNING_TO_CADEN":
			var expedition_id := snapshot.get("expedition_id", "") as String
			if expedition_id != _return_signal_expedition_id:
				_return_signal_expedition_id = expedition_id
				return_to_caden_requested.emit(snapshot.get("outcome", "NONE"))
			if _auto_acknowledge_return:
				_acknowledge_return(snapshot)
		"CLOSED":
			var expedition_id := snapshot.get("expedition_id", "") as String
			if expedition_id != _closed_signal_expedition_id:
				_closed_signal_expedition_id = expedition_id
				expedition_closed.emit(snapshot.get("outcome", "NONE"))


func _acknowledge_content_when_valid(snapshot: Dictionary) -> void:
	var expedition_id := snapshot.get("expedition_id", "") as String
	var definition_id := snapshot.get("expedition_definition_id", "") as String
	var room_id := snapshot.get("current_room_id", "") as String
	var revision := int(snapshot.get("revision", -1))
	if (
		expedition_id.is_empty()
		or revision < 0
		or revision == _last_content_ready_revision
		or not _registry.has_definition(definition_id)
		or _registry.get_room(definition_id, room_id).is_empty()
		or _local_avatar_flag(snapshot, "content_ready")
	):
		return
	_last_content_ready_revision = revision
	_runtime.call("send_expedition_content_ready", expedition_id, revision)


func _acknowledge_return(snapshot: Dictionary) -> void:
	var expedition_id := snapshot.get("expedition_id", "") as String
	var revision := int(snapshot.get("revision", -1))
	if (
		expedition_id.is_empty()
		or revision < 0
		or revision == _last_return_ack_revision
		or _local_avatar_flag(snapshot, "return_acknowledged")
	):
		return
	_last_return_ack_revision = revision
	_runtime.call("send_expedition_return_ack", expedition_id, revision)


func _present_active_snapshot(snapshot: Dictionary) -> void:
	var definition_id := snapshot.get("expedition_definition_id", "") as String
	var room_id := snapshot.get("current_room_id", "") as String
	var room_definition := _registry.get_room(definition_id, room_id)
	if room_definition.is_empty():
		return
	if room_id != _current_room_id:
		_load_room(room_definition)
	var visible_ids: Dictionary = {}
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar_snapshot := avatar_value as Dictionary
		var character_id := avatar_snapshot.get("character_id", "") as String
		if character_id.is_empty():
			continue
		visible_ids[character_id] = true
		var avatar := _ensure_avatar(character_id)
		avatar.call(
			"apply_authoritative_presentation_state",
			Vector2(avatar_snapshot.position_x, avatar_snapshot.position_y),
			Vector2(avatar_snapshot.velocity_x, avatar_snapshot.velocity_y),
			Vector2(avatar_snapshot.facing_x, avatar_snapshot.facing_y)
		)
	_remove_unscoped_avatars(visible_ids)


func _load_room(room_definition: Dictionary) -> void:
	if _current_room != null:
		_room_container.remove_child(_current_room)
		_current_room.queue_free()
	var packed := load(room_definition.scene_path) as PackedScene
	if packed == null:
		return
	_current_room = packed.instantiate() as Node2D
	_room_container.add_child(_current_room)
	_current_room_id = room_definition.room_id
	for avatar_value: Variant in _avatars_by_character_id.values():
		var avatar := avatar_value as CharacterBody2D
		if avatar != null and avatar.call("is_locally_controlled"):
			avatar.call("set_camera_limits", CAMERA_BOUNDS)
	room_presented.emit(_current_room_id)


func _ensure_avatar(character_id: String) -> CharacterBody2D:
	var existing := get_presented_avatar(character_id)
	if existing != null:
		return existing
	var avatar := PlayerScene.instantiate() as CharacterBody2D
	avatar.set("character_id", StringName(character_id))
	avatar.set("is_local_avatar", character_id == _local_character_id)
	avatar.set("uses_local_movement_simulation", false)
	avatar.z_index = 10
	_avatar_container.add_child(avatar)
	_avatars_by_character_id[character_id] = avatar
	if character_id == _local_character_id:
		avatar.connect("network_interaction_requested", _on_network_interaction_requested)
		avatar.call("set_camera_limits", CAMERA_BOUNDS)
	else:
		avatar.collision_layer = 0
		avatar.collision_mask = 0
	return avatar


func _remove_unscoped_avatars(visible_ids: Dictionary) -> void:
	for character_id: Variant in _avatars_by_character_id.keys():
		if visible_ids.has(character_id):
			continue
		var avatar := _avatars_by_character_id[character_id] as Node
		_avatars_by_character_id.erase(character_id)
		avatar.queue_free()


func _local_avatar_flag(snapshot: Dictionary, key: String) -> bool:
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar := avatar_value as Dictionary
		if avatar.get("character_id", "") == _local_character_id:
			return avatar.get(key, false)
	return false


func _on_network_interaction_requested(interactable_id: StringName) -> void:
	if _runtime == null or _current_snapshot.is_empty():
		return
	var stable_id := String(interactable_id)
	var expedition_id := _current_snapshot.get("expedition_id", "") as String
	var revision := int(_current_snapshot.get("revision", -1))
	if stable_id.begins_with("development.connection."):
		_runtime.call(
			"send_expedition_room_transition", expedition_id, stable_id, revision
		)
	elif stable_id == "development.expedition.stub.success":
		_runtime.call(
			"send_expedition_stub_outcome", expedition_id, "SUCCESS", revision
		)


func _on_client_authenticated(identity: Dictionary) -> void:
	_local_character_id = identity.get("character_id", "") as String
	var snapshot := _runtime.call("get_expedition_snapshot") as Dictionary
	if not snapshot.is_empty():
		_apply_snapshot(snapshot)


func _on_expedition_snapshot_received(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _disconnect_runtime() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = null
		return
	if _runtime.expedition_snapshot_received.is_connected(_on_expedition_snapshot_received):
		_runtime.expedition_snapshot_received.disconnect(_on_expedition_snapshot_received)
	if _runtime.client_authenticated.is_connected(_on_client_authenticated):
		_runtime.client_authenticated.disconnect(_on_client_authenticated)
	_runtime = null
