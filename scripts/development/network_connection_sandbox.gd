class_name NetworkConnectionSandbox
extends Control

const NETWORK_RUNTIME_SCENE := preload("res://scenes/network/NetworkRuntime.tscn")

@onready var _address_input: LineEdit = %AddressInput
@onready var _port_input: SpinBox = %PortInput
@onready var _access_code_input: LineEdit = %AccessCodeInput
@onready var _display_label_input: LineEdit = %DisplayLabelInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _guest_button: Button = %GuestButton
@onready var _disconnect_button: Button = %DisconnectButton
@onready var _status_label: Label = %StatusLabel
@onready var _identity_label: Label = %IdentityLabel
@onready var _avatar_cards: HBoxContainer = %AvatarCards
@onready var _runtime_root: Node = $Runtimes

var _server_runtime: Node
var _primary_client_runtime: Node
var _guest_client_runtime: Node


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_guest_button.pressed.connect(_on_guest_pressed)
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	_set_active_state(false, false)


func _exit_tree() -> void:
	_stop_runtime(_guest_client_runtime)
	_stop_runtime(_primary_client_runtime)
	_stop_runtime(_server_runtime)


func _on_host_pressed() -> void:
	if not _validate_form():
		return
	_on_disconnect_pressed()
	_server_runtime = _create_runtime("ServerRuntime")
	var port := int(_port_input.value)
	var error: Error = _server_runtime.call(
		"start_server", port, _access_code_input.text, 4, "Mesoplasia Phase C Sandbox"
	)
	if error != OK:
		_set_status("Host failed: %s" % error_string(error))
		_stop_runtime(_server_runtime)
		_server_runtime = null
		return
	_primary_client_runtime = _create_primary_client("HostClientRuntime")
	error = _primary_client_runtime.call(
		"start_client",
		"127.0.0.1",
		port,
		_access_code_input.text,
		_display_label_input.text
	)
	if error != OK:
		_set_status("Local host client failed: %s" % error_string(error))
		_on_disconnect_pressed()
		return
	_set_active_state(true, true)
	_set_status("Listen server started; local client is connecting over loopback ENet.")


func _on_join_pressed() -> void:
	if not _validate_form():
		return
	_on_disconnect_pressed()
	_primary_client_runtime = _create_primary_client("JoinClientRuntime")
	var error: Error = _primary_client_runtime.call(
		"start_client",
		_address_input.text,
		int(_port_input.value),
		_access_code_input.text,
		_display_label_input.text
	)
	if error != OK:
		_set_status("Join failed: %s" % error_string(error))
		_on_disconnect_pressed()
		return
	_set_active_state(true, false)


func _on_guest_pressed() -> void:
	if _server_runtime == null or _guest_client_runtime != null:
		return
	_guest_client_runtime = _create_runtime("LoopbackGuestRuntime")
	_guest_client_runtime.status_changed.connect(_on_guest_status_changed)
	var guest_label := ("%s Guest" % _display_label_input.text).left(24)
	var error: Error = _guest_client_runtime.call(
		"start_client",
		"127.0.0.1",
		int(_port_input.value),
		_access_code_input.text,
		guest_label
	)
	if error != OK:
		_set_status("Loopback guest failed: %s" % error_string(error))
		_stop_runtime(_guest_client_runtime)
		_guest_client_runtime = null
		return
	_guest_button.disabled = true
	_set_status("Loopback guest is connecting as a second independent client.")


func _on_disconnect_pressed() -> void:
	_stop_runtime(_guest_client_runtime)
	_stop_runtime(_primary_client_runtime)
	_stop_runtime(_server_runtime)
	_guest_client_runtime = null
	_primary_client_runtime = null
	_server_runtime = null
	_identity_label.text = "Identity: not authenticated"
	_clear_avatar_cards()
	_set_active_state(false, false)
	_set_status("Disconnected. Choose Host or Join.")


func _create_runtime(runtime_name: String) -> Node:
	var runtime := NETWORK_RUNTIME_SCENE.instantiate()
	runtime.name = runtime_name
	_runtime_root.add_child(runtime)
	return runtime


func _create_primary_client(runtime_name: String) -> Node:
	var runtime := _create_runtime(runtime_name)
	runtime.status_changed.connect(_set_status)
	runtime.client_authenticated.connect(_on_primary_authenticated)
	runtime.client_rejected.connect(_on_primary_rejected)
	runtime.avatar_spawned.connect(_on_avatar_presence_changed)
	runtime.avatar_despawned.connect(_on_avatar_presence_changed)
	return runtime


func _stop_runtime(runtime: Node) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	runtime.call("stop")
	if runtime.get_parent() != null:
		runtime.get_parent().remove_child(runtime)
	runtime.queue_free()


func _validate_form() -> bool:
	if _address_input.text.strip_edges().is_empty():
		_set_status("Enter an address; use 127.0.0.1 for this computer.")
		return false
	if _access_code_input.text.is_empty():
		_set_status("Choose a private-test access code and use the same code for every client.")
		return false
	if _display_label_input.text.strip_edges().is_empty():
		_set_status("Enter a display label.")
		return false
	return true


func _set_active_state(is_active: bool, is_host: bool) -> void:
	_host_button.disabled = is_active
	_join_button.disabled = is_active
	_disconnect_button.disabled = not is_active
	_guest_button.disabled = not is_active or not is_host or _guest_client_runtime != null
	_address_input.editable = not is_active
	_port_input.editable = not is_active
	_access_code_input.editable = not is_active
	_display_label_input.editable = not is_active


func _set_status(status_text: String) -> void:
	_status_label.text = "Status: %s" % status_text


func _on_guest_status_changed(status_text: String) -> void:
	_set_status("Guest — %s" % status_text)


func _on_primary_authenticated(identity: Dictionary) -> void:
	_identity_label.text = "Identity: %s  •  %s" % [identity.character_id, identity.session_id]
	_refresh_avatar_cards()


func _on_primary_rejected(reason_code: String, reason_text: String) -> void:
	_set_status("Rejected: %s — %s" % [reason_code, reason_text])


func _on_avatar_presence_changed(
	_arg1: Variant = null,
	_arg2: Variant = null,
	_arg3: Variant = null
) -> void:
	_refresh_avatar_cards()


func _refresh_avatar_cards() -> void:
	_clear_avatar_cards()
	if _primary_client_runtime == null:
		return
	var snapshots := _primary_client_runtime.call("get_avatar_snapshots") as Array
	for value: Variant in snapshots:
		var snapshot := value as Dictionary
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(190, 54)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = "%s\n%s" % [
			"LOCAL CLIENT" if snapshot.is_local else "REMOTE CLIENT",
			snapshot.display_label,
		]
		card.add_child(label)
		_avatar_cards.add_child(card)


func _clear_avatar_cards() -> void:
	for child: Node in _avatar_cards.get_children():
		_avatar_cards.remove_child(child)
		child.queue_free()
