extends SceneTree

const SandboxScene := preload("res://scenes/network/NetworkExpeditionSandbox.tscn")
const WAIT_TIMEOUT_MSEC := 10000
const THRESHOLD_ROOM := "development.room.test_threshold"
const DEPTHS_ROOM := "development.room.test_depths"
const THRESHOLD_EXIT := "development.connection.threshold_to_depths"

var _sandbox: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_sandbox = SandboxScene.instantiate()
	root.add_child(_sandbox)
	_sandbox.call("start_demo_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_authenticated()):
		_fail("Phase F sandbox did not authenticate both loopback clients.")
		return

	_sandbox.call("prepare_party_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_show_ready_party()):
		_fail("Phase F sandbox did not prepare the two-member ready party.")
		return
	_sandbox.call("launch_expedition_for_test")
	if not await _wait_for(func() -> bool: return _both_clients_active_in(THRESHOLD_ROOM)):
		_fail("Phase F sandbox did not pass the content-ready barrier into exploration.")
		return

	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	var local_id := (
		(local.call("get_client_identity") as Dictionary).get("character_id", "") as String
	)
	var guest_id := (
		(guest.call("get_client_identity") as Dictionary).get("character_id", "") as String
	)
	var first_snapshot := local.call("get_expedition_snapshot") as Dictionary
	var stable_expedition_id := first_snapshot.get("expedition_id", "") as String
	var stable_dungeon_instance_id := first_snapshot.get("dungeon_instance_id", "") as String
	if stable_expedition_id.is_empty() or stable_dungeon_instance_id.is_empty():
		_fail("Phase F sandbox did not expose stable expedition and dungeon instance IDs.")
		return
	if not await _wait_for(func() -> bool: return _presentation_is_ready(local_id, guest_id)):
		_fail("Phase F sandbox did not present one local and one remote avatar.")
		return
	var guest_agent := _sandbox.call("get_guest_expedition_agent_for_test") as Node
	if guest_agent == null or guest_agent.call("is_presentation_enabled"):
		_fail("The headless guest agent unexpectedly created a second presentation.")
		return

	var initial_local := _avatar_position(local, local_id)
	var initial_guest := _avatar_position(guest, guest_id)
	Input.action_press("move_right")
	var both_moved := await _wait_for_msec(
		func() -> bool:
			return (
				_avatar_position(local, local_id).x > initial_local.x + 0.5
				and _avatar_position(guest, guest_id).x > initial_guest.x + 0.5
			),
		3000
	)
	Input.action_release("move_right")
	if not both_moved:
		_fail("Both expedition members did not move through authoritative shared-room input.")
		return
	var server := _sandbox.call("get_server_runtime_for_test") as Node
	var service := server.call("get_expedition_service_for_test") as RefCounted
	if not await _wait_for(
		func() -> bool: return _expedition_is_stationary(service, stable_expedition_id)
	):
		_fail("Expedition movement inputs did not settle before the structural room command.")
		return

	var old_presenter := _sandbox.call("get_expedition_presenter_for_test") as Node
	var old_presenter_id := old_presenter.get_instance_id()
	_sandbox.call("reload_expedition_presenter_for_test")
	if not await _wait_for(
		func() -> bool:
			var presenter := _sandbox.call("get_expedition_presenter_for_test") as Node
			return (
				presenter != null
				and presenter.get_instance_id() != old_presenter_id
				and presenter.call("get_current_room_id") == THRESHOLD_ROOM
				and presenter.call("get_presented_avatar_count") == 2
			)
	):
		_fail("Reloading the expedition presenter did not reconstruct the active room.")
		return
	var after_reload := local.call("get_expedition_snapshot") as Dictionary
	if (
		after_reload.get("expedition_id", "") != stable_expedition_id
		or after_reload.get("dungeon_instance_id", "") != stable_dungeon_instance_id
	):
		_fail("Presenter reload changed the authoritative expedition identity.")
		return

	if (
		not service.call("set_avatar_position_for_test", local_id, THRESHOLD_ROOM, Vector2(530, 170))
		or not service.call("set_avatar_position_for_test", guest_id, THRESHOLD_ROOM, Vector2(530, 210))
	):
		_fail("Test setup could not gather both members at the authored exit.")
		return
	var instance := service.call("get_instance_state", stable_expedition_id) as Dictionary
	local.call(
		"send_expedition_room_transition",
		stable_expedition_id,
		THRESHOLD_EXIT,
		int(instance.get("revision", -1))
	)
	if not await _wait_for(func() -> bool: return _both_clients_active_in(DEPTHS_ROOM)):
		_fail("The cohesive party did not transfer together into the authored second room.")
		return
	if not await _wait_for(
		func() -> bool:
			var presenter := _sandbox.call("get_expedition_presenter_for_test") as Node
			return presenter != null and presenter.call("get_current_room_id") == DEPTHS_ROOM
	):
		_fail("The client presenter did not replace the authored room after transfer.")
		return

	var previous_guest_instance_id := guest.get_instance_id()
	_sandbox.call("reconnect_guest_for_test")
	if not await _wait_for(
		func() -> bool:
			var replacement := _sandbox.call("get_guest_runtime_for_test") as Node
			if replacement == null or replacement.get_instance_id() == previous_guest_instance_id:
				return false
			var identity := replacement.call("get_client_identity") as Dictionary
			var snapshot := replacement.call("get_expedition_snapshot") as Dictionary
			return (
				identity.get("character_id", "") == guest_id
				and snapshot.get("expedition_id", "") == stable_expedition_id
				and snapshot.get("dungeon_instance_id", "") == stable_dungeon_instance_id
				and snapshot.get("current_room_id", "") == DEPTHS_ROOM
				and snapshot.get("lifecycle_state", "") == "ACTIVE_EXPLORATION"
			)
	):
		_fail("Guest reconnect did not reconstruct the same active dungeon instance and room.")
		return

	_sandbox.call("retreat_for_test")
	if not await _wait_for(
		func() -> bool:
			var local_snapshot := local.call("get_expedition_snapshot") as Dictionary
			var party := local.call("get_party_snapshot") as Dictionary
			return (
				local_snapshot.get("lifecycle_state", "") == "CLOSED"
				and local_snapshot.get("outcome", "") == "RETREAT"
				and party.get("lifecycle_state", "") == "FORMING"
				and party.get("current_expedition_id", "").is_empty()
			)
	):
		_fail("Retreat did not close the expedition and restore the party lifecycle.")
		return
	if not await _wait_for(
		func() -> bool:
			var presenter := _sandbox.call("get_caden_presenter_for_test") as Node
			var hub := local.call("get_hub_snapshot") as Dictionary
			return (
				presenter != null
				and hub.get("zone_id", "") == "wayfarers_approach"
				and _hub_has_character(hub, local_id)
			)
	):
		_fail("Safe return did not restore the local avatar and Caden presenter.")
		return
	var checkpoint_store := server.call("get_expedition_checkpoint_store_for_test") as RefCounted
	var checkpoint := checkpoint_store.call("load_checkpoint", stable_expedition_id) as Dictionary
	if (
		checkpoint.get("lifecycle_state", "") != "CLOSED"
		or checkpoint.get("outcome", "") != "RETREAT"
	):
		_fail("The final in-memory checkpoint did not record the closed retreat outcome.")
		return
	if not root.find_children("*", "Combat*", true, false).is_empty():
		_fail("Phase F sandbox unexpectedly instantiated an out-of-scope combat system.")
		return

	_cleanup()
	print("PASS: Phase F sandbox party launch, load barrier, two-avatar room, movement, reload, room transfer, reconnect, retreat, checkpoint, and Caden return.")
	quit(0)


func _both_clients_authenticated() -> bool:
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	return (
		local != null
		and guest != null
		and not (local.call("get_client_identity") as Dictionary).is_empty()
		and not (guest.call("get_client_identity") as Dictionary).is_empty()
	)


func _both_clients_show_ready_party() -> bool:
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	if local == null or guest == null:
		return false
	var local_party := local.call("get_party_snapshot") as Dictionary
	var guest_party := guest.call("get_party_snapshot") as Dictionary
	return (
		local_party.get("all_present_members_ready", false)
		and guest_party.get("all_present_members_ready", false)
		and (local_party.get("members", []) as Array).size() == 2
		and (guest_party.get("members", []) as Array).size() == 2
	)


func _both_clients_active_in(room_id: String) -> bool:
	var local := _sandbox.call("get_local_runtime_for_test") as Node
	var guest := _sandbox.call("get_guest_runtime_for_test") as Node
	if local == null or guest == null:
		return false
	for runtime: Node in [local, guest]:
		var snapshot := runtime.call("get_expedition_snapshot") as Dictionary
		if (
			snapshot.get("lifecycle_state", "") != "ACTIVE_EXPLORATION"
			or snapshot.get("current_room_id", "") != room_id
		):
			return false
	return true


func _presentation_is_ready(local_id: String, guest_id: String) -> bool:
	var presenter := _sandbox.call("get_expedition_presenter_for_test") as Node
	if presenter == null or presenter.call("get_current_room_id") != THRESHOLD_ROOM:
		return false
	if presenter.call("get_presented_avatar_count") != 2:
		return false
	var local_avatar := presenter.call("get_presented_avatar", local_id) as CharacterBody2D
	var remote_avatar := presenter.call("get_presented_avatar", guest_id) as CharacterBody2D
	return (
		local_avatar != null
		and remote_avatar != null
		and local_avatar.call("is_locally_controlled")
		and not remote_avatar.call("is_locally_controlled")
		and local_avatar.find_children("*", "Camera2D", true, false).size() == 1
		and remote_avatar.find_children("*", "Camera2D", true, false).is_empty()
	)


func _avatar_position(runtime: Node, character_id: String) -> Vector2:
	var snapshot := runtime.call("get_expedition_snapshot") as Dictionary
	for avatar_value: Variant in snapshot.get("avatars", []):
		var avatar := avatar_value as Dictionary
		if avatar.get("character_id", "") == character_id:
			return Vector2(float(avatar.position_x), float(avatar.position_y))
	return Vector2.ZERO


func _hub_has_character(snapshot: Dictionary, character_id: String) -> bool:
	for avatar_value: Variant in snapshot.get("avatars", []):
		if (avatar_value as Dictionary).get("character_id", "") == character_id:
			return true
	return false


func _expedition_is_stationary(service: RefCounted, expedition_id: String) -> bool:
	var instance := service.call("get_instance_state", expedition_id) as Dictionary
	if instance.is_empty():
		return false
	for avatar_value: Variant in (instance.get("avatars", {}) as Dictionary).values():
		var avatar := avatar_value as Dictionary
		if (
			(avatar.get("velocity", Vector2.ZERO) as Vector2) != Vector2.ZERO
			or (avatar.get("input_direction", Vector2.ZERO) as Vector2) != Vector2.ZERO
		):
			return false
	return true


func _wait_for(predicate: Callable) -> bool:
	return await _wait_for_msec(predicate, WAIT_TIMEOUT_MSEC)


func _wait_for_msec(predicate: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _cleanup() -> void:
	Input.action_release("move_right")
	if _sandbox != null and is_instance_valid(_sandbox):
		_sandbox.queue_free()


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
