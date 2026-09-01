class_name NetworkPartySandbox
extends Node2D

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")
const PresenterScene := preload("res://scenes/network/NetworkedCadenPresenter.tscn")

const ACCESS_CODE := "phase-e-local-demo"
const EXPEDITION_ID := "development.expedition.placeholder"

@onready var _start_button: Button = %StartButton
@onready var _stop_button: Button = %StopButton
@onready var _invite_button: Button = %InviteButton
@onready var _accept_button: Button = %AcceptButton
@onready var _select_button: Button = %SelectButton
@onready var _local_ready_button: Button = %LocalReadyButton
@onready var _guest_ready_button: Button = %GuestReadyButton
@onready var _transfer_button: Button = %TransferButton
@onready var _reconnect_button: Button = %ReconnectButton
@onready var _leave_button: Button = %LeaveButton
@onready var _status_label: Label = %StatusLabel
@onready var _local_state_label: Label = %LocalStateLabel
@onready var _guest_state_label: Label = %GuestStateLabel
@onready var _runtime_root: Node = $Runtimes
@onready var _presentation_root: Node2D = $PresentationRoot

var _server_runtime: Node
var _local_runtime: Node
var _guest_runtime: Node
var _presenter: Node
var _active_port := 0
var _guest_reconnect_token := ""


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_invite_button.pressed.connect(_on_invite_pressed)
	_accept_button.pressed.connect(_on_accept_pressed)
	_select_button.pressed.connect(_on_select_pressed)
	_local_ready_button.pressed.connect(_on_local_ready_pressed)
	_guest_ready_button.pressed.connect(_on_guest_ready_pressed)
	_transfer_button.pressed.connect(_on_transfer_pressed)
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_set_running(false)


func _exit_tree() -> void:
	_stop_all()


func start_demo_for_test() -> void:
	_on_start_pressed()


func invite_guest_for_test() -> void:
	_on_invite_pressed()


func accept_guest_for_test() -> void:
	_on_accept_pressed()


func select_expedition_for_test() -> void:
	_on_select_pressed()


func ready_local_for_test() -> void:
	_on_local_ready_pressed()


func ready_guest_for_test() -> void:
	_on_guest_ready_pressed()


func reconnect_guest_for_test() -> void:
	_on_reconnect_pressed()


func get_local_runtime_for_test() -> Node:
	return _local_runtime


func get_guest_runtime_for_test() -> Node:
	return _guest_runtime


func get_server_runtime_for_test() -> Node:
	return _server_runtime


func _on_start_pressed() -> void:
	_stop_all()
	_server_runtime = _create_runtime("ServerRuntime")
	_active_port = _start_server_on_available_port()
	if _active_port == 0:
		_set_status("Could not open a local UDP port.")
		_stop_all()
		return
	_local_runtime = _create_client("LocalClientRuntime", "Local Player")
	_guest_runtime = _create_client("GuestClientRuntime", "Party Guest")
	if _local_runtime == null or _guest_runtime == null:
		_stop_all()
		return
	_create_presenter(_local_runtime)
	_set_running(true)
	_set_status("Connecting both players. Invite the guest when both identity labels appear.")


func _on_stop_pressed() -> void:
	_stop_all()
	_set_status("Stopped. Start the two-player party demo when ready.")


func _on_invite_pressed() -> void:
	if not _clients_authenticated():
		_set_status("Wait until both clients are authenticated.")
		return
	var guest_id := (_guest_runtime.call("get_client_identity") as Dictionary).character_id as String
	var local_snapshot := _local_runtime.call("get_party_snapshot") as Dictionary
	var expected_revision := int(local_snapshot.get("revision", -1))
	if _local_runtime.call("send_party_invite", guest_id, expected_revision):
		_set_status("Invitation sent. Click Guest Accept after it appears.")


func _on_accept_pressed() -> void:
	if _guest_runtime == null:
		return
	var snapshot := _guest_runtime.call("get_party_snapshot") as Dictionary
	var invitations := snapshot.get("invitations", []) as Array
	if invitations.is_empty():
		_set_status("The guest has no pending invitation yet.")
		return
	var invitation := invitations[0] as Dictionary
	if _guest_runtime.call(
		"send_party_accept", invitation.invite_id, int(invitation.current_party_revision)
	):
		_set_status("Guest accepted. The leader can select the test expedition.")


func _on_select_pressed() -> void:
	_send_with_current_revision(
		_local_runtime,
		func(runtime: Node, revision: int) -> bool:
			return runtime.call("send_party_select_expedition", EXPEDITION_ID, revision),
		"Selected the Phase E expedition placeholder. Ready both members."
	)


func _on_local_ready_pressed() -> void:
	_send_with_current_revision(
		_local_runtime,
		func(runtime: Node, revision: int) -> bool:
			return runtime.call("send_party_ready", true, revision),
		"Local player submitted ready."
	)


func _on_guest_ready_pressed() -> void:
	_send_with_current_revision(
		_guest_runtime,
		func(runtime: Node, revision: int) -> bool:
			return runtime.call("send_party_ready", true, revision),
		"Guest submitted ready. Watch for ALL READY on both projections."
	)


func _on_transfer_pressed() -> void:
	if not _clients_authenticated():
		return
	var guest_id := (_guest_runtime.call("get_client_identity") as Dictionary).character_id as String
	_send_with_current_revision(
		_local_runtime,
		func(runtime: Node, revision: int) -> bool:
			return runtime.call("send_party_transfer_leadership", guest_id, revision),
		"Leadership transfer sent. The guest should become leader on both projections."
	)


func _on_reconnect_pressed() -> void:
	if _guest_runtime == null or not is_instance_valid(_guest_runtime):
		return
	_guest_reconnect_token = _guest_runtime.call("get_reconnect_token") as String
	if _guest_reconnect_token.is_empty():
		_set_status("Wait for guest authentication before reconnecting.")
		return
	_stop_runtime(_guest_runtime)
	_guest_runtime = _create_client(
		"ReplacementGuestRuntime", "Party Guest", _guest_reconnect_token, ""
	)
	if _guest_runtime != null:
		_set_status("Guest reconnecting inside grace; membership should remain and ready should clear.")


func _on_leave_pressed() -> void:
	_send_with_current_revision(
		_guest_runtime,
		func(runtime: Node, revision: int) -> bool:
			return runtime.call("send_party_leave", revision),
		"Guest leave sent. The local projection should return to one member."
	)


func _send_with_current_revision(
	runtime: Node,
	sender: Callable,
	status_text: String
) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	var snapshot := runtime.call("get_party_snapshot") as Dictionary
	if snapshot.get("party_id", "").is_empty():
		_set_status("That player is not currently in a party.")
		return
	if sender.call(runtime, int(snapshot.revision)):
		_set_status(status_text)


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
	runtime.party_snapshot_received.connect(_on_party_snapshot_received.bind(runtime))
	runtime.party_command_result_received.connect(_on_party_command_result.bind(display_label))
	runtime.client_authenticated.connect(_on_client_authenticated.bind(runtime))
	return runtime


func _create_presenter(runtime: Node) -> void:
	_remove_presenter()
	_presenter = PresenterScene.instantiate()
	_presentation_root.add_child(_presenter)
	_presenter.call("configure", runtime)


func _start_server_on_available_port() -> int:
	var starting_port := 28940
	for offset in 32:
		var candidate := starting_port + offset
		if _server_runtime.call(
			"start_party_caden_server", candidate, ACCESS_CODE, 4, 4
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


func _stop_all() -> void:
	_remove_presenter()
	_stop_runtime(_guest_runtime)
	_stop_runtime(_local_runtime)
	_stop_runtime(_server_runtime)
	_guest_runtime = null
	_local_runtime = null
	_server_runtime = null
	_active_port = 0
	_guest_reconnect_token = ""
	if is_node_ready():
		_local_state_label.text = "LOCAL: waiting"
		_guest_state_label.text = "GUEST: waiting"
		_set_running(false)


func _remove_presenter() -> void:
	if _presenter == null or not is_instance_valid(_presenter):
		_presenter = null
		return
	if _presenter.get_parent() != null:
		_presenter.get_parent().remove_child(_presenter)
	_presenter.queue_free()
	_presenter = null


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
		_invite_button,
		_accept_button,
		_select_button,
		_local_ready_button,
		_guest_ready_button,
		_transfer_button,
		_reconnect_button,
		_leave_button,
	]:
		button.disabled = not is_running


func _set_status(status_text: String) -> void:
	_status_label.text = "STATUS: %s" % status_text


func _on_client_authenticated(_identity: Dictionary, runtime: Node) -> void:
	_update_runtime_label(runtime)


func _on_party_snapshot_received(_snapshot: Dictionary, runtime: Node) -> void:
	_update_runtime_label(runtime)


func _on_party_command_result(result: Dictionary, display_label: String) -> void:
	if result.accepted:
		_set_status("%s: %s accepted." % [display_label, result.command_type])
	else:
		_set_status(
			"%s: %s rejected — %s" % [
				display_label,
				result.command_type,
				result.reason_code,
			]
		)


func _update_runtime_label(runtime: Node) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	var identity := runtime.call("get_client_identity") as Dictionary
	var snapshot := runtime.call("get_party_snapshot") as Dictionary
	var prefix := "LOCAL" if runtime == _local_runtime else "GUEST"
	var label := _local_state_label if runtime == _local_runtime else _guest_state_label
	if identity.is_empty():
		label.text = "%s: connecting" % prefix
		return
	if snapshot.get("party_id", "").is_empty():
		var invitation_count := (snapshot.get("invitations", []) as Array).size()
		label.text = "%s %s: UNPARTIED • pending invites %d" % [
			prefix,
			identity.character_id,
			invitation_count,
		]
		return
	var member_states: Array[String] = []
	for member_value: Variant in snapshot.members:
		var member := member_value as Dictionary
		member_states.append(
			"%s[%s%s]" % [
				member.display_label,
				"online" if member.connected else "grace",
				",ready" if member.ready else "",
			]
		)
	label.text = "%s %s r%d • leader %s • %s%s" % [
		prefix,
		snapshot.party_id,
		int(snapshot.revision),
		snapshot.leader_character_id,
		", ".join(member_states),
		" • ALL READY" if snapshot.all_present_members_ready else "",
	]
