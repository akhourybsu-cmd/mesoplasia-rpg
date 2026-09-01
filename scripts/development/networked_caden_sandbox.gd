class_name NetworkedCadenSandbox
extends Node2D

const NetworkRuntimeScene := preload("res://scenes/network/NetworkRuntime.tscn")
const PresenterScene := preload("res://scenes/network/NetworkedCadenPresenter.tscn")

const ACCESS_CODE := "phase-d-local-demo"
const GUEST_INPUT_INTERVAL_SECONDS := 0.1
const GUEST_TURN_INTERVAL_SECONDS := 2.0

@onready var _start_button: Button = %StartButton
@onready var _reconnect_button: Button = %ReconnectButton
@onready var _stop_button: Button = %StopButton
@onready var _status_label: Label = %StatusLabel
@onready var _identity_label: Label = %IdentityLabel
@onready var _zone_label: Label = %ZoneLabel
@onready var _runtime_root: Node = $Runtimes
@onready var _presentation_root: Node2D = $PresentationRoot

var _server_runtime: Node
var _primary_runtime: Node
var _guest_runtime: Node
var _presenter: Node
var _active_port := 0
var _reconnect_token := ""
var _guest_input_sequence := 0
var _guest_input_accumulator := 0.0
var _guest_turn_accumulator := 0.0
var _guest_direction := Vector2.RIGHT


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_set_active_state(false)
	set_process(false)


func _exit_tree() -> void:
	_stop_all()


func _process(delta: float) -> void:
	if _guest_runtime == null or (_guest_runtime.call("get_client_identity") as Dictionary).is_empty():
		return
	_guest_input_accumulator += delta
	_guest_turn_accumulator += delta
	if _guest_turn_accumulator >= GUEST_TURN_INTERVAL_SECONDS:
		_guest_turn_accumulator = fmod(_guest_turn_accumulator, GUEST_TURN_INTERVAL_SECONDS)
		_guest_direction = Vector2.LEFT if _guest_direction == Vector2.RIGHT else Vector2.RIGHT
	if _guest_input_accumulator < GUEST_INPUT_INTERVAL_SECONDS:
		return
	_guest_input_accumulator = fmod(_guest_input_accumulator, GUEST_INPUT_INTERVAL_SECONDS)
	_guest_input_sequence += 1
	_guest_runtime.call("send_hub_movement", _guest_direction, _guest_input_sequence)


func start_demo_for_test() -> void:
	_on_start_pressed()


func reconnect_local_for_test() -> void:
	_on_reconnect_pressed()


func get_primary_runtime_for_test() -> Node:
	return _primary_runtime


func get_guest_runtime_for_test() -> Node:
	return _guest_runtime


func get_presenter_for_test() -> Node:
	return _presenter


func _on_start_pressed() -> void:
	_stop_all()
	_server_runtime = _create_runtime("ServerRuntime")
	_active_port = _start_server_on_available_port()
	if _active_port == 0:
		_set_status("Could not open a local UDP port.")
		_stop_all()
		return
	_primary_runtime = _create_client("LocalClientRuntime", "Local Player")
	_guest_runtime = _create_client("LoopbackGuestRuntime", "Moving Guest")
	if _primary_runtime == null or _guest_runtime == null:
		_stop_all()
		return
	_create_presenter(_primary_runtime)
	_guest_input_sequence = 0
	_guest_input_accumulator = 0.0
	_guest_turn_accumulator = 0.0
	_guest_direction = Vector2.RIGHT
	_set_active_state(true)
	set_process(true)
	_set_status("Starting server, local player, and moving loopback guest…")


func _on_reconnect_pressed() -> void:
	if _primary_runtime == null:
		return
	_reconnect_token = _primary_runtime.call("get_reconnect_token") as String
	if _reconnect_token.is_empty():
		_set_status("Wait for authentication before reconnecting.")
		return
	_remove_presenter()
	_stop_runtime(_primary_runtime)
	_primary_runtime = _create_client("ReplacementLocalClientRuntime", "Local Player", _reconnect_token, "")
	if _primary_runtime == null:
		return
	_create_presenter(_primary_runtime)
	_set_status("Replacing the local peer; stable character and safe Caden location should return.")


func _on_stop_pressed() -> void:
	_stop_all()
	_set_status("Stopped. Start the two-client demo when ready.")


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
		runtime.status_changed.connect(_on_primary_status_changed)
		runtime.client_authenticated.connect(_on_primary_authenticated)
		runtime.hub_snapshot_received.connect(_on_primary_snapshot)
	return runtime


func _create_presenter(runtime: Node) -> void:
	_remove_presenter()
	_presenter = PresenterScene.instantiate()
	_presentation_root.add_child(_presenter)
	_presenter.call("configure", runtime)


func _start_server_on_available_port() -> int:
	var starting_port := 27890
	for offset in 32:
		var candidate := starting_port + offset
		if _server_runtime.call("start_caden_server", candidate, ACCESS_CODE, 4) == OK:
			return candidate
	return 0


func _stop_all() -> void:
	set_process(false)
	_remove_presenter()
	_stop_runtime(_guest_runtime)
	_stop_runtime(_primary_runtime)
	_stop_runtime(_server_runtime)
	_guest_runtime = null
	_primary_runtime = null
	_server_runtime = null
	_active_port = 0
	_identity_label.text = "Identity: waiting"
	_zone_label.text = "Zone: waiting  •  Same-zone avatars: 0"
	_set_active_state(false)


func _remove_presenter() -> void:
	if _presenter == null or not is_instance_valid(_presenter):
		_presenter = null
		return
	_presentation_root.remove_child(_presenter)
	_presenter.queue_free()
	_presenter = null


func _stop_runtime(runtime: Node) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	runtime.call("stop")
	if runtime.get_parent() != null:
		runtime.get_parent().remove_child(runtime)
	runtime.queue_free()


func _set_active_state(is_active: bool) -> void:
	_start_button.disabled = is_active
	_reconnect_button.disabled = not is_active
	_stop_button.disabled = not is_active


func _set_status(status_text: String) -> void:
	_status_label.text = "Status: %s" % status_text


func _on_primary_status_changed(status_text: String) -> void:
	_set_status(status_text)


func _on_primary_authenticated(identity: Dictionary) -> void:
	_reconnect_token = identity.get("reconnect_token", _primary_runtime.call("get_reconnect_token")) as String
	_identity_label.text = "Character: %s" % identity.character_id


func _on_primary_snapshot(snapshot: Dictionary) -> void:
	_zone_label.text = "Zone: %s  •  Same-zone avatars: %d" % [
		snapshot.zone_id,
		(snapshot.avatars as Array).size(),
	]
