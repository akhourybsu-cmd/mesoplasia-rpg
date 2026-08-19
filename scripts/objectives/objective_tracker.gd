class_name ObjectiveTracker
extends Node

signal progress_changed(objective_title: String, current_step_text: String, is_complete: bool)

@export var objective_definition: Resource

var _current_step_index := 0
var _is_complete := false


func _ready() -> void:
	_reset_progress()
	_emit_progress.call_deferred()


func record_zone_visit(zone_id: StringName) -> void:
	if _is_complete:
		return

	var current_step := _get_current_step()
	if current_step == null or not current_step.has_method("is_completed_by_zone"):
		return
	if current_step.call("is_completed_by_zone", zone_id):
		mark_current_step_complete()


func mark_current_step_complete() -> void:
	if _is_complete or _get_current_step() == null:
		return

	_current_step_index += 1
	var steps := _get_steps()
	_is_complete = _current_step_index >= steps.size()
	_emit_progress()


func get_objective_title() -> String:
	if objective_definition == null:
		return ""
	return objective_definition.get("title") as String


func get_current_step_text() -> String:
	var current_step := _get_current_step()
	if current_step == null:
		return ""
	return current_step.get("display_text") as String


func get_current_step_index() -> int:
	return _current_step_index


func is_step_complete(step_index: int) -> bool:
	return step_index >= 0 and step_index < _current_step_index


func is_complete() -> bool:
	return _is_complete


func _reset_progress() -> void:
	_current_step_index = 0
	_is_complete = objective_definition != null and _get_steps().is_empty()


func _get_steps() -> Array:
	if objective_definition == null:
		return []
	return objective_definition.get("steps") as Array


func _get_current_step() -> Resource:
	var steps := _get_steps()
	if _current_step_index < 0 or _current_step_index >= steps.size():
		return null
	return steps[_current_step_index] as Resource


func _emit_progress() -> void:
	progress_changed.emit(get_objective_title(), get_current_step_text(), _is_complete)
