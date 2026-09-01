class_name NetworkedCadenPresenter
extends Node2D

signal zone_presented(zone_id: String)

const PlayerScene := preload("res://scenes/Player.tscn")
const CadenZoneRegistry := preload("res://scripts/world/caden_zone_registry.gd")

const MOVEMENT_SEND_INTERVAL_SECONDS := 1.0 / 20.0

@onready var _zone_container: Node2D = $CurrentZone
@onready var _avatar_container: Node2D = $Avatars

var _runtime: Node
var _registry := CadenZoneRegistry.new()
var _current_zone: Node2D
var _current_zone_id := ""
var _local_character_id := ""
var _avatars_by_character_id: Dictionary = {}
var _patrols_by_npc_id: Dictionary = {}
var _interaction_nodes_by_id: Dictionary = {}
var _movement_accumulator := 0.0
var _movement_input_sequence := 0
var _last_sent_direction := Vector2.ZERO


func _ready() -> void:
	set_physics_process(false)


func _exit_tree() -> void:
	_disconnect_runtime()


func configure(runtime: Node) -> bool:
	if runtime == null or not _registry.is_valid():
		return false
	_disconnect_runtime()
	_runtime = runtime
	_runtime.hub_snapshot_received.connect(_on_hub_snapshot_received)
	_runtime.interaction_result_received.connect(_on_interaction_result_received)
	_runtime.client_authenticated.connect(_on_client_authenticated)
	var identity := _runtime.call("get_client_identity") as Dictionary
	_local_character_id = identity.get("character_id", "") as String
	set_physics_process(true)
	var current_snapshot := _runtime.call("get_hub_snapshot") as Dictionary
	if not current_snapshot.is_empty():
		_apply_snapshot(current_snapshot)
	return true


func get_current_zone_id() -> String:
	return _current_zone_id


func get_presented_avatar_count() -> int:
	return _avatars_by_character_id.size()


func get_presented_avatar(character_id: String) -> CharacterBody2D:
	return _avatars_by_character_id.get(character_id) as CharacterBody2D


func _physics_process(delta: float) -> void:
	if _runtime == null or _local_character_id.is_empty():
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
	_runtime.call("send_hub_movement", direction, _movement_input_sequence)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var zone_id := snapshot.get("zone_id", "") as String
	if zone_id.is_empty() or not _registry.has_zone(zone_id):
		return
	if _local_character_id.is_empty():
		var identity := _runtime.call("get_client_identity") as Dictionary
		_local_character_id = identity.get("character_id", "") as String
	if _local_character_id.is_empty():
		return
	if zone_id != _current_zone_id:
		_load_zone(zone_id)

	var visible_character_ids: Dictionary = {}
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar_snapshot := avatar_value as Dictionary
		var character_id := avatar_snapshot.get("character_id", "") as String
		if character_id.is_empty():
			continue
		visible_character_ids[character_id] = true
		var avatar := _ensure_avatar(character_id)
		avatar.call(
			"apply_authoritative_presentation_state",
			Vector2(
				float(avatar_snapshot.get("position_x", 0.0)),
				float(avatar_snapshot.get("position_y", 0.0))
			),
			Vector2(
				float(avatar_snapshot.get("velocity_x", 0.0)),
				float(avatar_snapshot.get("velocity_y", 0.0))
			),
			Vector2(
				float(avatar_snapshot.get("facing_x", 0.0)),
				float(avatar_snapshot.get("facing_y", 1.0))
			)
		)
	_remove_unscoped_avatars(visible_character_ids)
	_apply_patrol_snapshots(snapshot.get("npcs", []))
	_configure_depth_references()


func _load_zone(zone_id: String) -> void:
	if _current_zone != null:
		_zone_container.remove_child(_current_zone)
		_current_zone.queue_free()
	_current_zone = _registry.get_zone_scene(zone_id).instantiate() as Node2D
	_zone_container.add_child(_current_zone)
	_current_zone_id = zone_id
	_patrols_by_npc_id.clear()
	_interaction_nodes_by_id.clear()
	for node: Node in _current_zone.find_children("*", "CharacterBody2D", true, false):
		if not node.has_method("get_npc_id"):
			continue
		var npc_id := String(node.call("get_npc_id") as StringName)
		if npc_id.is_empty():
			continue
		node.call("set_network_presentation_enabled", true)
		_patrols_by_npc_id[npc_id] = node
	for node: Node in _current_zone.find_children("*", "Area2D", true, false):
		if node.has_signal("transition_requested"):
			node.connect("transition_requested", _on_transition_requested)
		if node.has_method("get_interactable_id"):
			var interactable_id := String(node.call("get_interactable_id") as StringName)
			if not interactable_id.is_empty():
				_interaction_nodes_by_id[interactable_id] = node
	zone_presented.emit(zone_id)


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
		avatar.call("set_camera_limits", _registry.get_camera_bounds(_current_zone_id))
	else:
		avatar.collision_layer = 0
		avatar.collision_mask = 0
	return avatar


func _remove_unscoped_avatars(visible_character_ids: Dictionary) -> void:
	for character_id: Variant in _avatars_by_character_id.keys():
		if visible_character_ids.has(character_id):
			continue
		var avatar := _avatars_by_character_id[character_id] as Node
		_avatars_by_character_id.erase(character_id)
		avatar.queue_free()


func _apply_patrol_snapshots(npc_snapshots: Array) -> void:
	for npc_value: Variant in npc_snapshots:
		var npc_snapshot := npc_value as Dictionary
		var npc_id := npc_snapshot.get("npc_id", "") as String
		var npc := _patrols_by_npc_id.get(npc_id) as Node2D
		if npc == null:
			continue
		npc.call(
			"apply_authoritative_presentation_state",
			Vector2(
				float(npc_snapshot.get("position_x", 0.0)),
				float(npc_snapshot.get("position_y", 0.0))
			),
			Vector2(
				float(npc_snapshot.get("velocity_x", 0.0)),
				float(npc_snapshot.get("velocity_y", 0.0))
			),
			Vector2(
				float(npc_snapshot.get("facing_x", 0.0)),
				float(npc_snapshot.get("facing_y", 1.0))
			)
		)


func _configure_depth_references() -> void:
	if _current_zone == null:
		return
	var local_avatar := get_presented_avatar(_local_character_id)
	if local_avatar == null:
		return
	local_avatar.call("set_camera_limits", _registry.get_camera_bounds(_current_zone_id))
	for node: Node in _current_zone.find_children("*", "StaticBody2D", true, false):
		if node.has_method("set_depth_reference"):
			node.call("set_depth_reference", local_avatar)


func _on_client_authenticated(identity: Dictionary) -> void:
	_local_character_id = identity.get("character_id", "") as String
	var current_snapshot := _runtime.call("get_hub_snapshot") as Dictionary
	if not current_snapshot.is_empty():
		_apply_snapshot(current_snapshot)


func _on_hub_snapshot_received(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _on_network_interaction_requested(interactable_id: StringName) -> void:
	if _runtime != null:
		_runtime.call("send_hub_interaction", String(interactable_id))


func _on_interaction_result_received(result: Dictionary) -> void:
	if not result.get("accepted", false):
		return
	var interactable_id := result.get("interactable_id", "") as String
	var interactable := _interaction_nodes_by_id.get(interactable_id) as Area2D
	var local_avatar := get_presented_avatar(_local_character_id)
	if interactable != null and local_avatar != null:
		interactable.call("interact", local_avatar)


func _on_transition_requested(
	character_id: StringName,
	exit_id: StringName,
	_destination_zone: StringName,
	_destination_entry: StringName
) -> void:
	if String(character_id) == _local_character_id and _runtime != null:
		_runtime.call("send_hub_zone_transition", String(exit_id))


func _disconnect_runtime() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = null
		return
	if _runtime.hub_snapshot_received.is_connected(_on_hub_snapshot_received):
		_runtime.hub_snapshot_received.disconnect(_on_hub_snapshot_received)
	if _runtime.interaction_result_received.is_connected(_on_interaction_result_received):
		_runtime.interaction_result_received.disconnect(_on_interaction_result_received)
	if _runtime.client_authenticated.is_connected(_on_client_authenticated):
		_runtime.client_authenticated.disconnect(_on_client_authenticated)
	_runtime = null
