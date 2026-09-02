class_name DedicatedServerApp
extends Node

const Controller := preload(
	"res://scripts/server/dedicated/dedicated_server_controller.gd"
)
const Config := preload("res://scripts/server/dedicated/dedicated_server_config.gd")

var _controller: Node
var _admin_thread: Thread
var _admin_console_enabled := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	var arguments := OS.get_cmdline_user_args()
	if not OS.has_feature("dedicated_server") and not arguments.has("--server"):
		push_error("Dedicated server scene requires the explicit --server argument.")
		get_tree().quit(2)
		return
	var config_path := _argument_value(arguments, "--config=")
	if config_path.is_empty():
		config_path = "user://mesoplasia-server/config/server.json"
	var source_config := _read_json(config_path)
	if source_config.is_empty():
		push_error("Dedicated server configuration could not be read: %s" % config_path)
		get_tree().quit(2)
		return
	var secret_variable := source_config.get(
		"access_code_env_var", "MESOPLASIA_SERVER_ACCESS_CODE"
	) as String
	var access_code := OS.get_environment(secret_variable)
	var instance_root := _argument_value(arguments, "--data-root=")
	if instance_root.is_empty():
		instance_root = Config.DEFAULT_INSTANCE_ROOT
	_controller = Controller.new()
	add_child(_controller)
	var started := _controller.call("start", source_config, instance_root, access_code) as Dictionary
	if not started.get("accepted", false):
		push_error("Dedicated server start rejected: %s" % started.get("reason_code", "UNKNOWN"))
		get_tree().quit(3)
		return
	print("Mesoplasia dedicated server ready: %s" % JSON.stringify(started.status))
	if arguments.has("--validate-and-stop"):
		var stopped := _controller.call("graceful_shutdown") as Dictionary
		get_tree().quit(0 if stopped.get("accepted", false) else 4)
		return
	if arguments.has("--interactive-admin"):
		_admin_console_enabled = true
		print(
			"Local admin console ready: status, players, save, backup, drain, "
			+ "kick <peer_id>, shutdown"
		)
		_start_admin_read()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if _controller == null:
		get_tree().quit(0)
		return
	var result := _controller.call("graceful_shutdown") as Dictionary
	if result.get("accepted", false):
		get_tree().quit(0)
	else:
		push_error("Graceful shutdown refused: %s" % result.get("reason_code", "UNKNOWN"))


func _start_admin_read() -> void:
	if not _admin_console_enabled or _admin_thread != null:
		return
	_admin_thread = Thread.new()
	var error := _admin_thread.start(_read_admin_line)
	if error != OK:
		_admin_thread = null
		push_error("Local admin console could not start: %s" % error_string(error))


func _read_admin_line() -> void:
	var command_line := OS.read_string_from_stdin(1024)
	call_deferred("_handle_admin_line", command_line)


func _handle_admin_line(command_line: String) -> void:
	if _admin_thread != null:
		_admin_thread.wait_to_finish()
		_admin_thread = null
	if command_line.strip_edges().is_empty():
		_admin_console_enabled = false
		print("Local admin console closed because standard input ended.")
		return
	var result := _controller.call("execute_admin_command", command_line) as Dictionary
	print("ADMIN %s" % JSON.stringify(result))
	if command_line.strip_edges().to_lower() == "shutdown" and result.get("accepted", false):
		_admin_console_enabled = false
		get_tree().quit(0)
		return
	_start_admin_read()


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument: String in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return parser.data as Dictionary if parser.data is Dictionary else {}
