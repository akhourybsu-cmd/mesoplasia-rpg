class_name CadenHubService
extends RefCounted

const ZoneRegistry := preload("res://scripts/world/caden_zone_registry.gd")

const SNAPSHOT_SCHEMA_VERSION := 1
const MOVEMENT_SPEED := 96.0
const INPUT_SILENCE_MSEC := 250
const PLAYER_HALF_SIZE := Vector2(12, 12)
const MAX_MOVEMENT_MESSAGES_PER_SECOND := 35

var _registry: RefCounted
var _avatars_by_character_id: Dictionary = {}
var _npc_states_by_zone: Dictionary = {}
var _world_revision := 0
var _server_tick := 0


func configure(registry: RefCounted = null) -> bool:
	_registry = registry if registry != null else ZoneRegistry.new()
	if not _registry.call("is_valid"):
		return false
	_initialize_npc_states()
	return true


func attach_avatar(identity: Dictionary, now_msec: int) -> Dictionary:
	var character_id := identity.get("character_id", "") as String
	if character_id.is_empty():
		return _rejected("INVALID_IDENTITY", "Server identity has no CharacterId.")
	var state: Dictionary
	var reconnected := _avatars_by_character_id.has(character_id)
	if reconnected:
		state = _avatars_by_character_id[character_id] as Dictionary
		if not _is_position_walkable(state.zone_id, state.position):
			state.zone_id = ZoneRegistry.STARTING_ZONE
			state.position = _registry.call(
				"get_entry_position", ZoneRegistry.STARTING_ZONE, ZoneRegistry.STARTING_ENTRY
			) as Vector2
	else:
		state = {
			"character_id": character_id,
			"zone_id": ZoneRegistry.STARTING_ZONE,
			"position": _registry.call(
				"get_entry_position", ZoneRegistry.STARTING_ZONE, ZoneRegistry.STARTING_ENTRY
			) as Vector2,
			"velocity": Vector2.ZERO,
			"facing": Vector2.DOWN,
			"input_direction": Vector2.ZERO,
			"last_input_sequence": 0,
			"last_input_msec": now_msec,
			"movement_rate_window_msec": now_msec,
			"movement_rate_count": 0,
		}
		_avatars_by_character_id[character_id] = state
	state.account_id = identity.get("account_id", "") as String
	state.session_id = identity.get("session_id", "") as String
	state.avatar_runtime_id = identity.get("avatar_runtime_id", "") as String
	state.display_label = identity.get("display_label", "") as String
	state.connected = true
	state.velocity = Vector2.ZERO
	state.input_direction = Vector2.ZERO
	state.last_input_sequence = 0
	state.last_input_msec = now_msec
	state.movement_rate_window_msec = now_msec
	state.movement_rate_count = 0
	_world_revision += 1
	return {
		"accepted": true,
		"reconnected": reconnected,
		"zone_id": state.zone_id,
		"position": state.position,
	}


func detach_avatar(character_id: String) -> bool:
	if not _avatars_by_character_id.has(character_id):
		return false
	var state := _avatars_by_character_id[character_id] as Dictionary
	state.connected = false
	state.velocity = Vector2.ZERO
	state.input_direction = Vector2.ZERO
	_world_revision += 1
	return true


func prepare_avatar_return(character_id: String, zone_id: String, entry_id: String) -> bool:
	if not _avatars_by_character_id.has(character_id) or not _registry.call("has_zone", zone_id):
		return false
	var position := _registry.call("get_entry_position", zone_id, entry_id) as Vector2
	if not _is_position_walkable(zone_id, position):
		return false
	var state := _avatars_by_character_id[character_id] as Dictionary
	state.zone_id = zone_id
	state.position = position
	state.velocity = Vector2.ZERO
	state.input_direction = Vector2.ZERO
	state.last_input_sequence = 0
	state.facing = Vector2.DOWN
	_world_revision += 1
	return true


func submit_movement_input(
	character_id: String,
	input_sequence: int,
	direction: Vector2,
	now_msec: int
) -> Dictionary:
	var state := _connected_avatar(character_id)
	if state.is_empty():
		return _rejected("INVALID_AVATAR_STATE", "Avatar is not active in Caden.")
	if not _consume_movement_rate(state, now_msec):
		return _rejected("RATE_LIMITED", "Movement input rate exceeded.")
	if input_sequence <= int(state.last_input_sequence):
		return _rejected("STALE_SEQUENCE", "Movement input sequence is stale.")
	if not _is_cardinal_or_zero(direction):
		return _rejected("INVALID_MOVEMENT", "Movement input must be cardinal or zero.")
	state.last_input_sequence = input_sequence
	state.last_input_msec = now_msec
	state.input_direction = direction
	if direction != Vector2.ZERO:
		state.facing = direction
	return {"accepted": true, "reason_code": "OK"}


func tick(delta: float, now_msec: int) -> void:
	_server_tick += 1
	var changed := false
	var safe_delta := clampf(delta, 0.0, 0.1)
	for character_id: Variant in _avatars_by_character_id:
		var state := _avatars_by_character_id[character_id] as Dictionary
		if not state.connected:
			continue
		var direction := state.input_direction as Vector2
		if now_msec - int(state.last_input_msec) > INPUT_SILENCE_MSEC:
			direction = Vector2.ZERO
			state.input_direction = Vector2.ZERO
		var velocity := direction * MOVEMENT_SPEED
		state.velocity = velocity
		if velocity != Vector2.ZERO:
			var proposed := (state.position as Vector2) + velocity * safe_delta
			if _is_position_walkable(state.zone_id, proposed):
				state.position = proposed
				changed = true
			else:
				state.velocity = Vector2.ZERO
	changed = _tick_npcs(safe_delta) or changed
	if changed:
		_world_revision += 1


func request_interaction(character_id: String, interactable_id: String) -> Dictionary:
	var state := _connected_avatar(character_id)
	if state.is_empty():
		return _rejected("INVALID_AVATAR_STATE", "Avatar is not active in Caden.")
	var target := _registry.call("get_interactable", state.zone_id, interactable_id) as Dictionary
	if target.is_empty():
		return _rejected("INVALID_TARGET", "Interactable is not registered in the avatar's zone.")
	var activation_rect := target.activation_rect as Rect2
	if not activation_rect.grow(16.0).has_point(state.position):
		return _rejected("OUT_OF_RANGE", "Avatar is outside the interaction range.")
	return {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Interaction accepted.",
		"interactable_id": interactable_id,
		"zone_id": state.zone_id,
	}


func request_zone_transition(character_id: String, exit_id: String) -> Dictionary:
	var state := _connected_avatar(character_id)
	if state.is_empty():
		return _rejected("INVALID_AVATAR_STATE", "Avatar is not active in Caden.")
	var route := _registry.call("get_exit_route", state.zone_id, exit_id) as Dictionary
	if route.is_empty():
		return _rejected("INVALID_EXIT", "Exit is not registered in the avatar's zone.")
	var activation_rect := route.activation_rect as Rect2
	if not activation_rect.grow(20.0).has_point(state.position):
		return _rejected("OUT_OF_RANGE", "Avatar is outside the exit range.")
	var destination_zone := route.destination_zone as String
	var destination_entry := route.destination_entry as String
	var destination_position := _registry.call(
		"get_entry_position", destination_zone, destination_entry
	) as Vector2
	if destination_position.x < 0.0 or destination_position.y < 0.0:
		return _rejected("INVALID_DESTINATION", "Exit destination is not registered.")
	state.zone_id = destination_zone
	state.position = destination_position
	state.velocity = Vector2.ZERO
	state.input_direction = Vector2.ZERO
	_world_revision += 1
	return {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Zone transfer accepted.",
		"exit_id": exit_id,
		"zone_id": destination_zone,
		"entry_id": destination_entry,
		"world_revision": _world_revision,
	}


func get_snapshot_for(character_id: String) -> Dictionary:
	var owner := _connected_avatar(character_id)
	if owner.is_empty():
		return {}
	var zone_id := owner.zone_id as String
	var avatar_snapshots: Array = []
	var character_ids := _avatars_by_character_id.keys()
	character_ids.sort()
	for stored_character_id: Variant in character_ids:
		var state := _avatars_by_character_id[stored_character_id] as Dictionary
		if state.connected and state.zone_id == zone_id:
			avatar_snapshots.append(_avatar_snapshot(state))
	var npc_snapshots: Array = []
	var npc_states := _npc_states_by_zone.get(zone_id, {}) as Dictionary
	var npc_ids := npc_states.keys()
	npc_ids.sort()
	for npc_id: Variant in npc_ids:
		npc_snapshots.append(_npc_snapshot(npc_states[npc_id] as Dictionary))
	return {
		"snapshot_schema_version": SNAPSHOT_SCHEMA_VERSION,
		"zone_id": zone_id,
		"world_revision": _world_revision,
		"server_tick": _server_tick,
		"avatars": avatar_snapshots,
		"npcs": npc_snapshots,
	}


func get_avatar_state(character_id: String) -> Dictionary:
	if not _avatars_by_character_id.has(character_id):
		return {}
	return (_avatars_by_character_id[character_id] as Dictionary).duplicate(true)


func get_zone_member_ids(zone_id: String) -> Array[String]:
	var result: Array[String] = []
	for character_id: Variant in _avatars_by_character_id:
		var state := _avatars_by_character_id[character_id] as Dictionary
		if state.connected and state.zone_id == zone_id:
			result.append(character_id as String)
	result.sort()
	return result


func get_npc_state(zone_id: String, npc_id: String) -> Dictionary:
	var zone_states := _npc_states_by_zone.get(zone_id, {}) as Dictionary
	return (zone_states.get(npc_id, {}) as Dictionary).duplicate(true)


func set_avatar_position_for_test(character_id: String, zone_id: String, position: Vector2) -> bool:
	if not _avatars_by_character_id.has(character_id) or not _registry.call("has_zone", zone_id):
		return false
	var state := _avatars_by_character_id[character_id] as Dictionary
	state.zone_id = zone_id
	state.position = position
	state.velocity = Vector2.ZERO
	state.input_direction = Vector2.ZERO
	_world_revision += 1
	return true


func _initialize_npc_states() -> void:
	_npc_states_by_zone.clear()
	for zone_id: String in _registry.call("get_zone_ids"):
		var zone_states: Dictionary = {}
		for definition: Dictionary in _registry.call("get_patrol_definitions", zone_id):
			var target_positive := bool(definition.start_toward_positive)
			zone_states[definition.npc_id] = {
				"npc_id": definition.npc_id,
				"position": definition.start_position,
				"negative_endpoint": definition.negative_endpoint,
				"positive_endpoint": definition.positive_endpoint,
				"target_positive": target_positive,
				"move_speed": definition.move_speed,
				"pause_duration": definition.pause_duration,
				"pause_remaining": definition.pause_duration,
				"velocity": Vector2.ZERO,
				"facing": Vector2.DOWN,
			}
		_npc_states_by_zone[zone_id] = zone_states


func _tick_npcs(delta: float) -> bool:
	var changed := false
	for zone_id: Variant in _npc_states_by_zone:
		var zone_states := _npc_states_by_zone[zone_id] as Dictionary
		for npc_id: Variant in zone_states:
			var state := zone_states[npc_id] as Dictionary
			if float(state.pause_remaining) > 0.0:
				state.pause_remaining = maxf(float(state.pause_remaining) - delta, 0.0)
				state.velocity = Vector2.ZERO
				continue
			var target := (
				state.positive_endpoint if state.target_positive else state.negative_endpoint
			) as Vector2
			var offset := target - (state.position as Vector2)
			var maximum_step := float(state.move_speed) * delta
			if offset.length() <= maximum_step:
				state.position = target
				state.target_positive = not bool(state.target_positive)
				state.pause_remaining = state.pause_duration
				state.velocity = Vector2.ZERO
				changed = true
				continue
			var velocity := offset.normalized() * float(state.move_speed)
			state.velocity = velocity
			state.facing = _cardinal_direction(velocity)
			state.position = (state.position as Vector2) + velocity * delta
			changed = true
	return changed


func _is_position_walkable(zone_id: String, position: Vector2) -> bool:
	var bounds := _registry.call("get_camera_bounds", zone_id) as Rect2i
	var allowed := Rect2(bounds).grow(-PLAYER_HALF_SIZE.x)
	if not allowed.has_point(position):
		return false
	var player_rect := Rect2(position - PLAYER_HALF_SIZE, PLAYER_HALF_SIZE * 2.0)
	for collision_rect: Rect2 in _registry.call("get_collision_rectangles", zone_id):
		if collision_rect.intersects(player_rect):
			return false
	return true


func _connected_avatar(character_id: String) -> Dictionary:
	if not _avatars_by_character_id.has(character_id):
		return {}
	var state := _avatars_by_character_id[character_id] as Dictionary
	return state if state.get("connected", false) else {}


func _consume_movement_rate(state: Dictionary, now_msec: int) -> bool:
	if now_msec - int(state.movement_rate_window_msec) >= 1000:
		state.movement_rate_window_msec = now_msec
		state.movement_rate_count = 0
	state.movement_rate_count += 1
	return int(state.movement_rate_count) <= MAX_MOVEMENT_MESSAGES_PER_SECOND


func _is_cardinal_or_zero(direction: Vector2) -> bool:
	return direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]


func _avatar_snapshot(state: Dictionary) -> Array:
	var position := state.position as Vector2
	var velocity := state.velocity as Vector2
	var facing := state.facing as Vector2
	return [
		state.character_id,
		position.x,
		position.y,
		velocity.x,
		velocity.y,
		facing.x,
		facing.y,
	]


func _npc_snapshot(state: Dictionary) -> Array:
	var position := state.position as Vector2
	var velocity := state.velocity as Vector2
	var facing := state.facing as Vector2
	return [
		state.npc_id,
		position.x,
		position.y,
		velocity.x,
		velocity.y,
		facing.x,
		facing.y,
	]


func _cardinal_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.UP if direction.y < 0.0 else Vector2.DOWN


func _rejected(reason_code: String, reason_text: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "reason_text": reason_text}
