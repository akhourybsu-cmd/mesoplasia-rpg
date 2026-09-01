class_name NetworkExpeditionSandbox
extends Node2D

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")
const CadenPresenterScene := preload("res://scenes/network/NetworkedCadenPresenter.tscn")
const ExpeditionPresenterScene := preload(
	"res://scenes/network/NetworkedExpeditionPresenter.tscn"
)

const ACCESS_CODE := "phase-f-local-demo"
const EXPEDITION_ID := "development.expedition.placeholder"
const GUEST_INPUT_INTERVAL_SECONDS := 1.0 / 20.0

enum SetupState {
	IDLE,
	SEND_INVITE,
	WAIT_INVITE,
	WAIT_JOIN,
	WAIT_SELECTION,
	WAIT_LOCAL_READY,
	WAIT_ALL_READY,
	DONE,
}

@onready var _start_button: Button = %StartButton
@onready var _prepare_button: Button = %PrepareButton
@onready var _launch_button: Button = %LaunchButton
@onready var _retreat_button: Button = %RetreatButton
@onready var _failure_button: Button = %FailureButton
@onready var _reconnect_button: Button = %ReconnectButton
@onready var _stop_button: Button = %StopButton
@onready var _status_label: Label = %StatusLabel
@onready var _party_label: Label = %PartyLabel
@onready var _expedition_label: Label = %ExpeditionLabel
@onready var _runtime_root: Node = $Runtimes
@onready var _presentation_root: Node2D = $PresentationRoot
@onready var _agent_root: Node = $ClientAgents

var _server_runtime: Node
var _local_runtime: Node
var _guest_runtime: Node
var _caden_presenter: Node
var _expedition_presenter: Node
var _guest_expedition_agent: Node
var _active_port := 0
var _guest_reconnect_token := ""
var _setup_state := SetupState.IDLE
var _guest_input_sequence := 0
var _guest_input_accumulator := 0.0


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_prepare_button.pressed.connect(_on_prepare_pressed)
	_launch_button.pressed.connect(_on_launch_pressed)
	_retreat_button.pressed.connect(_on_retreat_pressed)
	_failure_button.pressed.connect(_on_failure_pressed)
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_set_running(false)


func _exit_tree() -> void:
	_stop_all()


func _process(delta: float) -> void:
	_advance_party_setup()
	_mirror_guest_expedition_input(delta)


func start_demo_for_test() -> void:
	_on_start_pressed()


func prepare_party_for_test() -> void:
	_on_prepare_pressed()


func launch_expedition_for_test() -> void:
	_on_launch_pressed()


func retreat_for_test() -> void:
	_on_retreat_pressed()


func failure_for_test() -> void:
	_on_failure_pressed()


func reconnect_guest_for_test() -> void:
	_on_reconnect_pressed()


func reload_expedition_presenter_for_test() -> void:
	_remove_expedition_presenter()
	_create_local_expedition_presenter()


func get_local_runtime_for_test() -> Node:
	return _local_runtime


func get_guest_runtime_for_test() -> Node:
	return _guest_runtime


func get_server_runtime_for_test() -> Node:
	return _server_runtime


func get_expedition_presenter_for_test() -> Node:
	return _expedition_presenter


func get_caden_presenter_for_test() -> Node:
	return _caden_presenter


func get_guest_expedition_agent_for_test() -> Node:
	return _guest_expedition_agent


func _on_start_pressed() -> void:
	_stop_all()
	_server_runtime = _create_runtime("ServerRuntime")
	_active_port = _start_server_on_available_port()
	if _active_port == 0:
		_set_status("Could not open a local UDP port.")
		_stop_all()
		return
	_local_runtime = _create_client("LocalClientRuntime", "Local Player")
	_guest_runtime = _create_client("GuestClientRuntime", "Expedition Guest")
	if _local_runtime == null or _guest_runtime == null:
		_stop_all()
		return
	_create_caden_presenter()
	_create_local_expedition_presenter()
	_create_guest_expedition_agent()
	_setup_state = SetupState.IDLE
	_set_running(true)
	_set_status("Connecting both players. Choose Prepare Ready Party when identities appear.")


func _on_prepare_pressed() -> void:
	if not _clients_authenticated():
		_set_status("Wait until both clients authenticate.")
		return
	var snapshot := _local_runtime.call("get_party_snapshot") as Dictionary
	if snapshot.get("all_present_members_ready", false):
		_setup_state = SetupState.DONE
		_set_status("Party is already ready. Choose Launch Expedition.")
		return
	_setup_state = SetupState.SEND_INVITE
	_set_status("Preparing party: invite → accept → select → ready both members…")


func _on_launch_pressed() -> void:
	if _local_runtime == null:
		return
	var party := _local_runtime.call("get_party_snapshot") as Dictionary
	if not party.get("all_present_members_ready", false):
		_set_status("Prepare the party before launching.")
		return
	if _local_runtime.call("send_expedition_launch", int(party.revision)):
		_set_status("Launch reserved. Both clients are validating authored room content.")


func _on_retreat_pressed() -> void:
	_send_stub_outcome("RETREAT")


func _on_failure_pressed() -> void:
	_send_stub_outcome("FAILURE")


func _send_stub_outcome(outcome_code: String) -> void:
	if _local_runtime == null:
		return
	var snapshot := _local_runtime.call("get_expedition_snapshot") as Dictionary
	if snapshot.get("lifecycle_state", "") != "ACTIVE_EXPLORATION":
		_set_status("The test expedition is not in active exploration.")
		return
	_local_runtime.call(
		"send_expedition_stub_outcome",
		snapshot.expedition_id,
		outcome_code,
		snapshot.revision
	)


func _on_reconnect_pressed() -> void:
	if _guest_runtime == null or not is_instance_valid(_guest_runtime):
		return
	_guest_reconnect_token = _guest_runtime.call("get_reconnect_token") as String
	if _guest_reconnect_token.is_empty():
		_set_status("Wait for guest authentication before reconnecting.")
		return
	_remove_guest_expedition_agent()
	_stop_runtime(_guest_runtime)
	_guest_runtime = _create_client(
		"ReplacementGuestRuntime", "Expedition Guest", _guest_reconnect_token, ""
	)
	if _guest_runtime != null:
		_create_guest_expedition_agent()
		_guest_input_sequence = 0
		_set_status("Guest reconnecting; active instance ID, room, and state should reconstruct.")


func _on_stop_pressed() -> void:
	_stop_all()
	_set_status("Stopped. Start the authored expedition demo when ready.")


func _advance_party_setup() -> void:
	if _setup_state == SetupState.IDLE or _setup_state == SetupState.DONE:
		return
	if not _clients_authenticated():
		return
	var local_party := _local_runtime.call("get_party_snapshot") as Dictionary
	var guest_party := _guest_runtime.call("get_party_snapshot") as Dictionary
	var guest_id := (_guest_runtime.call("get_client_identity") as Dictionary).character_id as String
	match _setup_state:
		SetupState.SEND_INVITE:
			if _local_runtime.call("send_party_invite", guest_id, int(local_party.revision)):
				_setup_state = SetupState.WAIT_INVITE
		SetupState.WAIT_INVITE:
			var invitations := guest_party.get("invitations", []) as Array
			if not invitations.is_empty():
				var invite := invitations[0] as Dictionary
				_guest_runtime.call(
					"send_party_accept", invite.invite_id, invite.current_party_revision
				)
				_setup_state = SetupState.WAIT_JOIN
		SetupState.WAIT_JOIN:
			if (local_party.get("members", []) as Array).size() == 2:
				_local_runtime.call(
					"send_party_select_expedition", EXPEDITION_ID, local_party.revision
				)
				_setup_state = SetupState.WAIT_SELECTION
		SetupState.WAIT_SELECTION:
			if local_party.get("selected_expedition_definition_id", "") == EXPEDITION_ID:
				_local_runtime.call("send_party_ready", true, local_party.revision)
				_setup_state = SetupState.WAIT_LOCAL_READY
		SetupState.WAIT_LOCAL_READY:
			if _member_ready(guest_party, (_local_runtime.call("get_client_identity") as Dictionary).character_id):
				_guest_runtime.call("send_party_ready", true, guest_party.revision)
				_setup_state = SetupState.WAIT_ALL_READY
		SetupState.WAIT_ALL_READY:
			if local_party.get("all_present_members_ready", false):
				_setup_state = SetupState.DONE
				_set_status("Party ready. Choose Launch Expedition.")


func _mirror_guest_expedition_input(delta: float) -> void:
	if _guest_runtime == null or not is_instance_valid(_guest_runtime):
		return
	var snapshot := _guest_runtime.call("get_expedition_snapshot") as Dictionary
	if snapshot.get("lifecycle_state", "") != "ACTIVE_EXPLORATION":
		return
	_guest_input_accumulator += delta
	if _guest_input_accumulator < GUEST_INPUT_INTERVAL_SECONDS:
		return
	_guest_input_accumulator = fmod(_guest_input_accumulator, GUEST_INPUT_INTERVAL_SECONDS)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		if absf(direction.x) >= absf(direction.y):
			direction = Vector2(signf(direction.x), 0)
		else:
			direction = Vector2(0, signf(direction.y))
	_guest_input_sequence += 1
	_guest_runtime.call("send_expedition_movement", direction, _guest_input_sequence)


func _create_runtime(runtime_name: String) -> Node:
	var runtime := NetworkRuntimeScene.instantiate()
	runtime.name = runtime_name
	_runtime_root.add_child(runtime)
	return runtime


func _create_client(
	runtime_name: String,
	display_label: String,
	reconnect_token: String = "",
	access_code: String = ACCESS_CODE
) -> Node:
	var runtime := _create_runtime(runtime_name)
	var error: Error = runtime.call(
		"start_client", "127.0.0.1", _active_port, access_code, display_label, reconnect_token
	)
	if error != OK:
		_set_status("Client failed: %s" % error_string(error))
		_stop_runtime(runtime)
		return null
	if display_label == "Local Player":
		runtime.party_snapshot_received.connect(_on_local_party_snapshot)
		runtime.expedition_snapshot_received.connect(_on_local_expedition_snapshot)
		runtime.expedition_command_result_received.connect(_on_local_expedition_result)
	return runtime


func _create_caden_presenter() -> void:
	_remove_caden_presenter()
	if _local_runtime == null:
		return
	_caden_presenter = CadenPresenterScene.instantiate()
	_presentation_root.add_child(_caden_presenter)
	_caden_presenter.call("configure", _local_runtime)


func _create_local_expedition_presenter() -> void:
	_remove_expedition_presenter()
	if _local_runtime == null:
		return
	_expedition_presenter = ExpeditionPresenterScene.instantiate()
	_presentation_root.add_child(_expedition_presenter)
	_expedition_presenter.call("configure", _local_runtime, true, true)


func _create_guest_expedition_agent() -> void:
	_remove_guest_expedition_agent()
	if _guest_runtime == null:
		return
	_guest_expedition_agent = ExpeditionPresenterScene.instantiate()
	_agent_root.add_child(_guest_expedition_agent)
	_guest_expedition_agent.call("configure", _guest_runtime, false, true)


func _start_server_on_available_port() -> int:
	var starting_port := 29980
	for offset in 32:
		var candidate := starting_port + offset
		if _server_runtime.call(
			"start_expedition_caden_server", candidate, ACCESS_CODE, 4, 4, 5000
		) == OK:
			return candidate
	return 0


func _clients_authenticated() -> bool:
	return (
		_local_runtime != null
		and _guest_runtime != null
		and not (_local_runtime.call("get_client_identity") as Dictionary).is_empty()
		and not (_guest_runtime.call("get_client_identity") as Dictionary).is_empty()
	)


func _member_ready(party_snapshot: Dictionary, character_id: String) -> bool:
	for member_value: Variant in party_snapshot.get("members", []):
		var member := member_value as Dictionary
		if member.get("character_id", "") == character_id:
			return member.get("ready", false)
	return false


func _stop_all() -> void:
	_setup_state = SetupState.IDLE
	_remove_caden_presenter()
	_remove_expedition_presenter()
	_remove_guest_expedition_agent()
	_stop_runtime(_guest_runtime)
	_stop_runtime(_local_runtime)
	_stop_runtime(_server_runtime)
	_guest_runtime = null
	_local_runtime = null
	_server_runtime = null
	_active_port = 0
	_guest_reconnect_token = ""
	_guest_input_sequence = 0
	_guest_input_accumulator = 0.0
	if is_node_ready():
		_party_label.text = "PARTY: waiting"
		_expedition_label.text = "EXPEDITION: waiting"
		_set_running(false)


func _remove_caden_presenter() -> void:
	_caden_presenter = _remove_node(_caden_presenter)


func _remove_expedition_presenter() -> void:
	_expedition_presenter = _remove_node(_expedition_presenter)


func _remove_guest_expedition_agent() -> void:
	_guest_expedition_agent = _remove_node(_guest_expedition_agent)


func _remove_node(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()
	return null


func _stop_runtime(runtime: Node) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	runtime.call("stop")
	if runtime.get_parent() != null:
		runtime.get_parent().remove_child(runtime)
	runtime.queue_free()


func _set_running(is_running: bool) -> void:
	_start_button.disabled = is_running
	_stop_button.disabled = not is_running
	for button: Button in [
		_prepare_button,
		_launch_button,
		_retreat_button,
		_failure_button,
		_reconnect_button,
	]:
		button.disabled = not is_running


func _set_status(text: String) -> void:
	_status_label.text = "STATUS: %s" % text


func _on_local_party_snapshot(snapshot: Dictionary) -> void:
	_party_label.text = "PARTY: %s r%d • %s • members %d%s" % [
		snapshot.get("party_id", "UNPARTIED"),
		int(snapshot.get("revision", -1)),
		snapshot.get("lifecycle_state", "UNPARTIED"),
		(snapshot.get("members", []) as Array).size(),
		" • READY" if snapshot.get("all_present_members_ready", false) else "",
	]


func _on_local_expedition_snapshot(snapshot: Dictionary) -> void:
	_expedition_label.text = "EXPEDITION: %s r%d • %s • room %s • checkpoint %d" % [
		snapshot.get("expedition_id", "NONE"),
		int(snapshot.get("revision", -1)),
		snapshot.get("lifecycle_state", "NONE"),
		snapshot.get("current_room_id", ""),
		int(snapshot.get("checkpoint_revision", 0)),
	]
	var lifecycle := snapshot.get("lifecycle_state", "NONE") as String
	if lifecycle == "LOADING":
		_remove_caden_presenter()
	elif lifecycle in ["CLOSED", "FAILED"] and _caden_presenter == null:
		_create_caden_presenter()
		_set_status(
			"Returned safely to Caden with outcome %s." % snapshot.get("outcome", "NONE")
		)


func _on_local_expedition_result(result: Dictionary) -> void:
	if result.accepted:
		_set_status("%s accepted • %s" % [result.command_type, result.lifecycle_state])
	else:
		_set_status("%s rejected — %s" % [result.command_type, result.reason_code])


func _fail_status(message: String) -> void:
	_set_status(message)
