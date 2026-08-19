class_name DialogueUI
extends CanvasLayer

signal dialogue_closed

var _conversation: Resource
var _lines: Array = []
var _line_index := -1
var _is_active := false
var _waiting_for_interact_release := false

@onready var _speaker_label: Label = $DialoguePanel/Content/SpeakerName
@onready var _dialogue_label: Label = $DialoguePanel/Content/DialogueText


func start_dialogue(conversation: Resource) -> bool:
	if _is_active or conversation == null:
		return false

	var conversation_lines: Array = conversation.get("lines")
	if conversation_lines.is_empty():
		return false

	_conversation = conversation
	_lines = conversation_lines.duplicate()
	_line_index = 0
	_is_active = true
	_waiting_for_interact_release = true
	_speaker_label.text = conversation.get("speaker_name") as String
	_show_current_line()
	visible = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event.is_action_released("interact"):
		_waiting_for_interact_release = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if not _waiting_for_interact_release:
			_advance_dialogue()
		get_viewport().set_input_as_handled()


func is_dialogue_active() -> bool:
	return _is_active


func get_current_line_index() -> int:
	return _line_index


func get_current_line_text() -> String:
	return _dialogue_label.text


func get_speaker_name() -> String:
	return _speaker_label.text


func _advance_dialogue() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_close_dialogue()
	else:
		_show_current_line()


func _show_current_line() -> void:
	_dialogue_label.text = _lines[_line_index] as String


func _close_dialogue() -> void:
	_is_active = false
	_waiting_for_interact_release = false
	_line_index = -1
	_lines.clear()
	_conversation = null
	visible = false
	dialogue_closed.emit()
