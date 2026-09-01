extends SceneTree

const DefinitionRegistry := preload("res://scripts/server/expedition/expedition_definition_registry.gd")
const CheckpointStore := preload("res://scripts/server/expedition/in_memory_expedition_checkpoint_store.gd")
const ExpeditionService := preload("res://scripts/server/expedition/expedition_service.gd")
const PartyService := preload("res://scripts/server/party/party_service.gd")

var _party: RefCounted
var _checkpoints: RefCounted
var _service: RefCounted


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var registry := DefinitionRegistry.new()
	if not registry.is_valid():
		_fail("Authored expedition definition is invalid: %s" % registry.get_validation_errors())
		return
	var definition := registry.get_definition("development.expedition.placeholder") as Dictionary
	if (
		definition.rooms.size() != 2
		or definition.entry_room_id != "development.room.test_threshold"
		or registry.get_connection(
			"development.expedition.placeholder",
			"development.room.test_threshold",
			"development.connection.threshold_to_depths"
		).is_empty()
	):
		_fail("Authored test dungeon rooms or stable links were not registered.")
		return

	_party = PartyService.new()
	_party.configure(2, 1000, 200)
	_party.connect_character(_identity("development.character.1", "Alice"), 0)
	_party.connect_character(_identity("development.character.2", "Bob"), 0)
	var invitation := _party.invite_character(
		"development.character.1", "development.character.2", -1, 0
	) as Dictionary
	var party_state := _party.get_party_for_character("development.character.1") as Dictionary
	_party.accept_invite(
		"development.character.2", invitation.invite_id, party_state.revision, 1
	)
	_checkpoints = CheckpointStore.new()
	_service = ExpeditionService.new()
	if not _service.configure(registry, _party, _checkpoints, 1, 100, 9000):
		_fail("Expedition service configuration failed.")
		return
	_service.connect_character(_identity("development.character.1", "Alice"), 0)
	_service.connect_character(_identity("development.character.2", "Bob"), 0)
	if not _prepare_party():
		return

	party_state = _party.get_party_for_character("development.character.1")
	var unauthorized := _service.launch_expedition(
		"development.character.2", party_state.revision, 2
	) as Dictionary
	if unauthorized.accepted or unauthorized.reason_code != "NOT_LEADER":
		_fail("A non-leader launched the expedition.")
		return
	var launch := _service.launch_expedition(
		"development.character.1", party_state.revision, 3
	) as Dictionary
	if not launch.accepted or launch.lifecycle_state != ExpeditionService.STATE_LOADING:
		_fail("Ready party could not reserve the authored expedition.")
		return
	var expedition_id := launch.expedition_id as String
	var dungeon_instance_id := launch.dungeon_instance_id as String
	if expedition_id.is_empty() or dungeon_instance_id.is_empty() or expedition_id == dungeon_instance_id:
		_fail("Launch did not allocate distinct stable expedition and dungeon instance IDs.")
		return
	if (_party.get_party_for_character("development.character.1") as Dictionary).lifecycle_state != PartyService.STATE_EXPEDITION_RESERVED:
		_fail("Party did not enter the reserved state during the load barrier.")
		return
	var duplicate := _service.launch_expedition(
		"development.character.1",
		(_party.get_party_for_character("development.character.1") as Dictionary).revision,
		4
	) as Dictionary
	if duplicate.accepted:
		_fail("One-active policy allowed a duplicate launch.")
		return

	var instance := _service.get_instance_state(expedition_id) as Dictionary
	var forged_ready := _service.acknowledge_content_ready(
		"development.character.3", expedition_id, instance.revision, 5
	) as Dictionary
	if forged_ready.accepted or forged_ready.reason_code != "NOT_A_MEMBER":
		_fail("A non-member acknowledged expedition content.")
		return
	var stale_ready := _service.acknowledge_content_ready(
		"development.character.1", expedition_id, instance.revision - 1, 6
	) as Dictionary
	if stale_ready.accepted or stale_ready.reason_code != "STALE_REVISION":
		_fail("Load acknowledgement ignored a stale instance revision.")
		return
	var alice_ready := _service.acknowledge_content_ready(
		"development.character.1", expedition_id, instance.revision, 7
	) as Dictionary
	instance = _service.get_instance_state(expedition_id)
	var bob_ready := _service.acknowledge_content_ready(
		"development.character.2", expedition_id, instance.revision, 8
	) as Dictionary
	if not alice_ready.accepted or not bob_ready.get("transfer_committed", false):
		_fail("Required content acknowledgements did not commit the transfer.")
		return
	instance = _service.get_instance_state(expedition_id)
	if (
		instance.lifecycle_state != ExpeditionService.STATE_ACTIVE_EXPLORATION
		or (_party.get_party_for_character("development.character.1") as Dictionary).lifecycle_state
			!= PartyService.STATE_IN_EXPEDITION
		or _checkpoints.get_checkpoint_count() != 1
	):
		_fail("Committed transfer did not preserve authoritative party/instance/checkpoint state.")
		return

	var alice_before := ((instance.avatars as Dictionary)["development.character.1"] as Dictionary).position as Vector2
	_service.submit_movement(
		"development.character.1", expedition_id, 1, Vector2.RIGHT, 10
	)
	_service.tick(0.1, 20)
	instance = _service.get_instance_state(expedition_id)
	var alice_after := ((instance.avatars as Dictionary)["development.character.1"] as Dictionary).position as Vector2
	if alice_after.x <= alice_before.x:
		_fail("Authoritative real-time expedition movement did not advance.")
		return
	var diagonal := _service.submit_movement(
		"development.character.1", expedition_id, 2, Vector2(1, 1), 21
	) as Dictionary
	if diagonal.accepted or diagonal.reason_code != "INVALID_DIRECTION":
		_fail("Diagonal expedition input bypassed cardinal validation.")
		return

	var transition_revision := int(instance.revision)
	var uncohesive := _service.request_room_transition(
		"development.character.1",
		expedition_id,
		"development.connection.threshold_to_depths",
		transition_revision,
		30
	) as Dictionary
	if uncohesive.accepted or uncohesive.reason_code != "PARTY_NOT_COHESIVE":
		_fail("Shared-room transition ignored party cohesion.")
		return
	_service.set_avatar_position_for_test(
		"development.character.1", "development.room.test_threshold", Vector2(530, 180)
	)
	_service.set_avatar_position_for_test(
		"development.character.2", "development.room.test_threshold", Vector2(550, 180)
	)
	instance = _service.get_instance_state(expedition_id)
	var nonleader_transition := _service.request_room_transition(
		"development.character.2",
		expedition_id,
		"development.connection.threshold_to_depths",
		instance.revision,
		31
	) as Dictionary
	if nonleader_transition.accepted or nonleader_transition.reason_code != "NOT_LEADER":
		_fail("A non-leader changed the shared party room.")
		return
	var transition := _service.request_room_transition(
		"development.character.1",
		expedition_id,
		"development.connection.threshold_to_depths",
		instance.revision,
		32
	) as Dictionary
	if not transition.accepted or transition.room_id != "development.room.test_depths":
		_fail("Cohesive leader room transition failed.")
		return
	instance = _service.get_instance_state(expedition_id)
	var retained_instance_id := instance.dungeon_instance_id as String
	_checkpoints.fail_next_write_for_test()
	_service.set_avatar_position_for_test(
		"development.character.1", "development.room.test_depths", Vector2(90, 180)
	)
	_service.set_avatar_position_for_test(
		"development.character.2", "development.room.test_depths", Vector2(110, 180)
	)
	instance = _service.get_instance_state(expedition_id)
	var failed_checkpoint_transition := _service.request_room_transition(
		"development.character.1",
		expedition_id,
		"development.connection.depths_to_threshold",
		instance.revision,
		33
	) as Dictionary
	if (
		failed_checkpoint_transition.accepted
		or failed_checkpoint_transition.reason_code != "CHECKPOINT_FAILED"
		or (_service.get_instance_state(expedition_id) as Dictionary).current_room_id
			!= "development.room.test_depths"
	):
		_fail("Failed checkpoint mutated the current room.")
		return

	_service.disconnect_character("development.character.2", 34)
	if not _service.has_character_in_active_expedition("development.character.2"):
		_fail("Disconnect removed the member's active expedition linkage.")
		return
	var reconnect := _service.connect_character(_identity("development.character.2", "Bob"), 35) as Dictionary
	if not reconnect.get("in_expedition", false):
		_fail("Reconnect did not restore the active expedition linkage.")
		return
	if (_service.get_instance_state(expedition_id) as Dictionary).dungeon_instance_id != retained_instance_id:
		_fail("Reconnect replaced the dungeon instance identity.")
		return

	_service.set_avatar_position_for_test(
		"development.character.1", "development.room.test_depths", Vector2(530, 180)
	)
	_service.set_avatar_position_for_test(
		"development.character.2", "development.room.test_depths", Vector2(550, 180)
	)
	instance = _service.get_instance_state(expedition_id)
	var invalid_outcome := _service.request_stub_outcome(
		"development.character.1", expedition_id, "REWARD_ME", instance.revision, 36
	) as Dictionary
	if invalid_outcome.accepted or invalid_outcome.reason_code != "INVALID_OUTCOME":
		_fail("Client supplied an unsupported expedition outcome.")
		return
	var success := _service.request_stub_outcome(
		"development.character.1",
		expedition_id,
		ExpeditionService.OUTCOME_SUCCESS,
		instance.revision,
		37
	) as Dictionary
	if not success.get("return_required", false):
		_fail("Validated success did not begin safe Caden return.")
		return
	instance = _service.get_instance_state(expedition_id)
	var first_ack := _service.acknowledge_caden_return(
		"development.character.1", expedition_id, instance.revision, 38
	) as Dictionary
	instance = _service.get_instance_state(expedition_id)
	var final_ack := _service.acknowledge_caden_return(
		"development.character.2", expedition_id, instance.revision, 39
	) as Dictionary
	if (
		not first_ack.accepted
		or not final_ack.get("closed", false)
		or (_service.get_instance_state(expedition_id) as Dictionary).lifecycle_state
			!= ExpeditionService.STATE_CLOSED
		or (_party.get_party_for_character("development.character.1") as Dictionary).lifecycle_state
			!= PartyService.STATE_FORMING
		or _service.get_active_expedition_count() != 0
	):
		_fail("Return acknowledgements did not close and clean up the active expedition.")
		return

	if not _prepare_party():
		return
	party_state = _party.get_party_for_character("development.character.1")
	var failure_launch := _service.launch_expedition(
		"development.character.1", party_state.revision, 50
	) as Dictionary
	if not failure_launch.accepted:
		_fail("Failure-outcome fixture could not launch after success cleanup.")
		return
	var failure_instance := _service.get_instance_state(failure_launch.expedition_id) as Dictionary
	_service.acknowledge_content_ready(
		"development.character.1", failure_launch.expedition_id, failure_instance.revision, 51
	)
	failure_instance = _service.get_instance_state(failure_launch.expedition_id)
	var failure_ready := _service.acknowledge_content_ready(
		"development.character.2", failure_launch.expedition_id, failure_instance.revision, 52
	) as Dictionary
	if not failure_ready.get("transfer_committed", false):
		_fail("Failure-outcome fixture did not complete its load barrier.")
		return
	failure_instance = _service.get_instance_state(failure_launch.expedition_id)
	var failure_outcome := _service.request_stub_outcome(
		"development.character.1",
		failure_launch.expedition_id,
		ExpeditionService.OUTCOME_FAILURE,
		failure_instance.revision,
		53
	) as Dictionary
	if not failure_outcome.get("return_required", false):
		_fail("Stub failure did not begin the same safe Caden return path.")
		return
	failure_instance = _service.get_instance_state(failure_launch.expedition_id)
	_service.acknowledge_caden_return(
		"development.character.1", failure_launch.expedition_id, failure_instance.revision, 54
	)
	failure_instance = _service.get_instance_state(failure_launch.expedition_id)
	var failure_closed := _service.acknowledge_caden_return(
		"development.character.2", failure_launch.expedition_id, failure_instance.revision, 55
	) as Dictionary
	if (
		not failure_closed.get("closed", false)
		or (_service.get_instance_state(failure_launch.expedition_id) as Dictionary).outcome
			!= ExpeditionService.OUTCOME_FAILURE
	):
		_fail("Stub failure did not checkpoint and close cleanly.")
		return

	if not _prepare_party():
		return
	party_state = _party.get_party_for_character("development.character.1")
	var timeout_launch := _service.launch_expedition(
		"development.character.1", party_state.revision, 100
	) as Dictionary
	if not timeout_launch.accepted:
		_fail("Second expedition could not launch after cleanup.")
		return
	var timeout_instance := _service.get_instance_state(timeout_launch.expedition_id) as Dictionary
	_service.acknowledge_content_ready(
		"development.character.1",
		timeout_launch.expedition_id,
		timeout_instance.revision,
		101
	)
	var timeout_result := _service.tick(0.0, 201) as Dictionary
	if (
		not timeout_result.load_cancelled
		or (_service.get_instance_state(timeout_launch.expedition_id) as Dictionary).lifecycle_state
			!= ExpeditionService.STATE_FAILED
		or (_party.get_party_for_character("development.character.1") as Dictionary).lifecycle_state
			!= PartyService.STATE_FORMING
	):
		_fail("Load timeout stranded the party in a reservation.")
		return

	if not _prepare_party():
		return
	party_state = _party.get_party_for_character("development.character.1")
	_checkpoints.fail_next_write_for_test()
	var failed_launch := _service.launch_expedition(
		"development.character.1", party_state.revision, 300
	) as Dictionary
	if (
		failed_launch.accepted
		or failed_launch.reason_code != "CHECKPOINT_FAILED"
		or (_party.get_party_for_character("development.character.1") as Dictionary).lifecycle_state
			!= PartyService.STATE_FORMING
		or _service.get_active_expedition_count() != 0
	):
		_fail("Launch checkpoint failure did not roll back safely to Caden party state.")
		return

	var checkpoint := _checkpoints.load_checkpoint(expedition_id) as Dictionary
	if (
		checkpoint.get("checkpoint_schema_version", 0) != 1
		or checkpoint.get("expedition_id", "") != expedition_id
		or checkpoint.get("checksum", "").is_empty()
		or (checkpoint.get("avatars", []) as Array).size() != 2
	):
		_fail("In-memory checkpoint serialization is incomplete.")
		return

	print("PASS: Phase F definitions, IDs/seed, load barrier, authority, movement, cohesion, checkpoints, reconnect, success/failure return, timeout, and rollback.")
	quit(0)


func _prepare_party() -> bool:
	var party_state := _party.get_party_for_character("development.character.1") as Dictionary
	var selected := _party.select_expedition(
		"development.character.1",
		"development.expedition.placeholder",
		party_state.revision
	) as Dictionary
	if not selected.accepted:
		return _fail("Party could not select the Phase F authored definition.")
	party_state = _party.get_party_for_character("development.character.1")
	var alice_ready := _party.set_ready(
		"development.character.1", true, party_state.revision
	) as Dictionary
	party_state = _party.get_party_for_character("development.character.1")
	var bob_ready := _party.set_ready(
		"development.character.2", true, party_state.revision
	) as Dictionary
	if not alice_ready.accepted or not bob_ready.accepted:
		return _fail("Party could not complete the ready check.")
	return true


func _identity(character_id: String, display_label: String) -> Dictionary:
	return {"character_id": character_id, "display_label": display_label}


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
